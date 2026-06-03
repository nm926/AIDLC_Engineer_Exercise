# AIDLC Engineer Exercise — Payment Fraud Detection on EKS

**Candidate:** Nilesh Mishra · **Role:** Sr. DevOps (12.6 years)  
**Repository:** [nm926/AIDLC_Engineer_Exercise](https://github.com/nm926/AIDLC_Engineer_Exercise)

AWS lab (EKS, Karpenter, observability, CI/CD) with the **main application in [`app/`](./app/)** — FastAPI payment fraud detection, React frontend, validation, and config management.

> **AIDLC scope:** `app/`, `k8s/`, `terraform/`, `observability/`, `.github/workflows/`  
> `bedrock-chat/` is a separate optional lab component — **not part of this assessment.**

---

## Start here (for interviewer)

| Order | Document | Purpose |
|-------|----------|---------|
| 1 | [COMPLETE_DELIVERY_SUMMARY.md](./COMPLETE_DELIVERY_SUMMARY.md) | What was delivered |
| 2 | [AIDLC_ASSESSMENT_RESPONSE.md](./AIDLC_ASSESSMENT_RESPONSE.md) | All 7 assessment sections |
| 3 | [INTERVIEW_PREPARATION_GUIDE.md](./INTERVIEW_PREPARATION_GUIDE.md) | Pitch, demo, Q&A |
| 4 | [FILE_INDEX_AND_NAVIGATION.md](./FILE_INDEX_AND_NAVIGATION.md) | File map |

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
