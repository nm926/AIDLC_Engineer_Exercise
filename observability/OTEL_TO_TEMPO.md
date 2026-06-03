# OpenTelemetry to Tempo: How the Link Works

This guide explains how traces flow from your app to Tempo in this repository.

## Data flow

1. App emits traces using OpenTelemetry auto-instrumentation.
2. App sends traces to OpenTelemetry Collector over OTLP gRPC.
3. Collector exports traces to Tempo.
4. Grafana reads traces from Tempo for visualization.

## 1) App side configuration

The app deployment sends OTLP traces to the collector service:

- OTEL_EXPORTER_OTLP_ENDPOINT: `http://otel-collector-opentelemetry-collector.observability.svc.cluster.local:4317`
- OTEL_EXPORTER_OTLP_PROTOCOL: `grpc`
- OTEL_TRACES_EXPORTER: `otlp`
- OTEL_SERVICE_NAME: `fraud-detection-service`

Reference:
- `k8s/deployment.yaml`

The container starts with auto-instrumentation:

- `opentelemetry-instrument uvicorn fraud_service:app --host 0.0.0.0 --port 8000`

Reference:
- `app/Dockerfile`

## 2) Collector side configuration

The collector receives OTLP and forwards traces to Tempo.

Receiver:
- `otlp` on `0.0.0.0:4317` (gRPC)

Trace exporter:
- `otlp/tempo`
- endpoint: `tempo.observability.svc.cluster.local:4317`
- TLS insecure: true (inside cluster)

Trace pipeline:
- receivers: `[otlp]`
- processors: `[memory_limiter, batch]`
- exporters: `[otlp/tempo]`

Reference:
- `observability/otel-collector.yaml`

## 3) Tempo side requirement

Tempo must expose OTLP gRPC endpoint so collector can write traces.

Reference:
- `observability/tempo-values.yaml`

## 4) Verify the integration

1. Deploy/update collector and Tempo.
2. Deploy your app with OTEL env vars.
3. Send test traffic to `/check-payment`.
4. Open Grafana Explore -> Tempo data source.
5. Query using service name: `fraud-detection-service`.

## Quick troubleshooting

- No traces visible:
  - Check app env vars in deployment.
  - Check collector logs for export errors.
  - Check Tempo service DNS and port 4317.
- Spans missing attributes:
  - Ensure app is started using `opentelemetry-instrument`.
- Intermittent traces:
  - Increase collector resources and tune `batch` settings.

## Files involved in this repo

- `app/Dockerfile`
- `k8s/deployment.yaml`
- `observability/otel-collector.yaml`
- `observability/tempo-values.yaml`
