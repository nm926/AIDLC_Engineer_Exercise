import os

os.environ["ENABLE_OTEL"] = "false"

from fastapi.testclient import TestClient

from fraud_service import app


client = TestClient(app)


def test_high_value_transaction_detected() -> None:
    payload = {
        "transaction_id": "12345",
        "user_id": "U100",
        "amount": 12000,
        "location": "Delhi",
    }
    response = client.post("/check-payment", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["transaction_id"] == "12345"
    assert data["fraud_detected"] is True


def test_rapid_transactions_detected() -> None:
    payload = {
        "transaction_id": "TX-1",
        "user_id": "U101",
        "amount": 200,
        "location": "Delhi",
    }
    first = client.post("/check-payment", json=payload)
    assert first.status_code == 200

    payload["transaction_id"] = "TX-2"
    second = client.post("/check-payment", json=payload)
    assert second.status_code == 200
    assert second.json()["fraud_detected"] is True


def test_healthcheck() -> None:
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_invalid_payload_rejected() -> None:
    payload = {
        "transaction_id": "<script>alert(1)</script>",
        "user_id": "U100",
        "amount": 100,
        "location": "Delhi",
    }
    response = client.post("/check-payment", json=payload)
    assert response.status_code == 400
