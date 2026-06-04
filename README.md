# AIDLC Engineer Exercise — Payment Fraud Detection on EKS

AWS lab (EKS, Karpenter, observability, CI/CD) with the **main application in [`app/`](./app/)** — FastAPI payment fraud detection, React frontend, validation, and config management.

> **AIDLC scope:** `app/`, `k8s/`, `terraform/`, `observability/`, `.github/workflows/`  

**Quick proof (application in `app/`):**

```bash
cd app
pip install -r requirements.txt pytest pytest-cov
pytest test_validation.py test_fraud_service.py -v
```

---

## Application (`app/`)

| File | Role |
|------|------|
| `fraud_service.py` | FastAPI service — `/check-payment`, metrics, OTEL |
| `validation.py` | `PaymentValidator` — injection/length/format checks |
| `config.py` | Environment-based config (12-factor) |
| `test_validation.py` | Unit tests for validation |
| `test_fraud_service.py` | API / fraud-rule integration tests |
| `frontend/` | React UI for payment checks |

---

## Architecture (simple)

```
User → ALB → FastAPI (app/fraud_service.py) → fraud rules + validation
                    ↓
         EKS + Karpenter + Prometheus / Loki / Tempo / Grafana
```

Lab deploy guide: [md_files/README.md](./md_files/README.md)
