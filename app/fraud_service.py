import logging
import os
import time
from typing import Dict

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from config import get_app_context
from validation import PaymentValidator
from prometheus_client import Counter, Histogram, make_asgi_app

from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.resources import SERVICE_NAME, Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("fraud-service")

app = FastAPI(title="payment-fraud-detection", version="1.0.0")
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)

REQUEST_COUNT = Counter(
    "fraud_service_requests_total",
    "Total API requests",
    ["endpoint", "fraud_detected"],
)

REQUEST_LATENCY = Histogram(
    "fraud_service_latency_seconds",
    "Request latency in seconds",
    ["endpoint"],
)

FRAUD_EVENTS = Counter(
    "fraud_service_fraud_decisions_total",
    "Fraud decisions by reason",
    ["reason"],
)

LAST_TX_TS: Dict[str, float] = {}
USER_HOME_LOCATION: Dict[str, str] = {
    "U100": "Mumbai",
    "U101": "Delhi",
    "U102": "Bengaluru",
}
RAPID_TX_WINDOW_SECONDS = 20


class PaymentRequest(BaseModel):
    transaction_id: str = Field(..., json_schema_extra={"example": "12345"})
    user_id: str = Field(..., json_schema_extra={"example": "U100"})
    amount: float = Field(..., ge=0, json_schema_extra={"example": 12000})
    location: str = Field(..., json_schema_extra={"example": "Delhi"})


class FraudResponse(BaseModel):
    transaction_id: str
    fraud_detected: bool
    risk_score: float
    message: str


def configure_otel() -> None:
    ctx = get_app_context()
    if not ctx.otel.enabled:
        logger.info("OpenTelemetry disabled by configuration")
        return

    endpoint = ctx.otel.endpoint

    resource = Resource(attributes={SERVICE_NAME: "fraud-detection-service"})
    tracer_provider = TracerProvider(resource=resource)
    otlp_exporter = OTLPSpanExporter(endpoint=endpoint, insecure=True)
    tracer_provider.add_span_processor(BatchSpanProcessor(otlp_exporter))
    trace.set_tracer_provider(tracer_provider)
    FastAPIInstrumentor.instrument_app(app)


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok"}


@app.post("/check-payment", response_model=FraudResponse)
def check_payment(request: PaymentRequest) -> FraudResponse:
    valid, errors = PaymentValidator.validate_all(
        request.transaction_id,
        request.user_id,
        request.amount,
        request.location,
    )
    if not valid:
        raise HTTPException(
            status_code=400,
            detail=[{"field": e.field, "message": e.message, "code": e.code} for e in errors],
        )

    start = time.time()
    tracer = trace.get_tracer("fraud-detection-service")

    with tracer.start_as_current_span("fraud-evaluation") as span:
        try:
            score = 0.0
            reasons = []

            if request.amount > 10000:
                score += 0.45
                reasons.append("high_value")
                FRAUD_EVENTS.labels(reason="high_value").inc()

            expected_location = USER_HOME_LOCATION.get(request.user_id)
            if expected_location and expected_location.lower() != request.location.lower():
                score += 0.25
                reasons.append("location_mismatch")
                FRAUD_EVENTS.labels(reason="location_mismatch").inc()

            now = time.time()
            last_seen = LAST_TX_TS.get(request.user_id)
            if last_seen and (now - last_seen) < RAPID_TX_WINDOW_SECONDS:
                score += 0.2
                reasons.append("rapid_transactions")
                FRAUD_EVENTS.labels(reason="rapid_transactions").inc()

            LAST_TX_TS[request.user_id] = now

            fraud_detected = len(reasons) > 0
            risk_score = min(score, 0.99)

            if fraud_detected and "high_value" in reasons:
                message = "High value transaction detected"
            elif fraud_detected:
                message = "Suspicious payment pattern detected"
            else:
                message = "Payment appears normal"

            span.set_attribute("transaction.id", request.transaction_id)
            span.set_attribute("user.id", request.user_id)
            span.set_attribute("fraud.detected", fraud_detected)
            span.set_attribute("fraud.risk_score", risk_score)
            span.set_attribute("fraud.reasons", ",".join(reasons) if reasons else "none")

            REQUEST_COUNT.labels(endpoint="/check-payment", fraud_detected=str(fraud_detected)).inc()
            REQUEST_LATENCY.labels(endpoint="/check-payment").observe(time.time() - start)

            logger.info(
                "Fraud decision tx=%s user=%s fraud=%s score=%.2f reasons=%s",
                request.transaction_id,
                request.user_id,
                fraud_detected,
                risk_score,
                reasons,
            )

            return FraudResponse(
                transaction_id=request.transaction_id,
                fraud_detected=fraud_detected,
                risk_score=round(risk_score, 2),
                message=message,
            )
        except Exception as exc:
            span.record_exception(exc)
            logger.exception("Failed to process payment check")
            raise HTTPException(status_code=500, detail="Internal fraud engine error") from exc


configure_otel()
