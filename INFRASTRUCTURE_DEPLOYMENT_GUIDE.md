# Infrastructure AIDLC Implementation Guide

**Step-by-Step Deployment Instructions**  
**Target Audience:** DevOps Engineers, Platform Teams  
**Estimated Duration:** 4 weeks  

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Phase 1: Application Layer](#phase-1-application-layer)
3. [Phase 2: Kubernetes Security](#phase-2-kubernetes-security)
4. [Phase 3: Terraform Improvements](#phase-3-terraform-improvements)
5. [Phase 4: Observability](#phase-4-observability)
6. [Validation & Testing](#validation--testing)
7. [Rollback Procedures](#rollback-procedures)

---

## Prerequisites

### Required Tools
- `kubectl` 1.27+ with cluster access
- `helm` 3.10+
- `terraform` 1.5+
- `aws-cli` 2.13+
- `python` 3.11+ with pip

### Required Access
- AWS account with EKS cluster access
- Kubernetes admin role
- Terraform state file access
- Docker registry push access

### Verification
```bash
# Verify cluster access
kubectl cluster-info
kubectl auth can-i create deployments --namespace=application

# Verify Terraform state
terraform state list | head -5

# Verify Python environment
python3 --version
pip list | grep -E "pydantic|fastapi"
```

---

## Phase 1: Application Layer

### Goal
Deploy configuration management and input validation modules.

### Step 1.1: Create Configuration Module

**File:** `app/config.py`

```bash
# Copy the config.py file to app directory
cp app/config.py app/config.py.new

# Verify syntax
python3 -m py_compile app/config.py

# Expected output: (no output = success)
```

### Step 1.2: Create Validation Module

**File:** `app/validation.py`

```bash
# Copy the validation.py file to app directory
python3 -m py_compile app/validation.py

# Test basic validation
python3 << 'EOF'
from app.validation import PaymentValidator

# Test valid payment
valid, error = PaymentValidator.validate_transaction_id("TXN-12345")
print(f"Valid TXN: {valid}, Error: {error}")

# Test injection attempt (should be invalid)
valid, error = PaymentValidator.validate_transaction_id("TXN'; DROP TABLE--")
print(f"Injection blocked: {not valid}, Error: {error}")

# Test amount validation
valid, error = PaymentValidator.validate_amount(150.50)
print(f"Valid amount: {valid}, Error: {error}")

# Test amount too high
valid, error = PaymentValidator.validate_amount(999999999999)
print(f"Amount too high blocked: {not valid}, Error: {error}")
EOF
```

**Expected Output:**
```
Valid TXN: True, Error: None
Injection blocked: True, Error: ValidationError(field='transaction_id', ...)
Valid amount: True, Error: None
Amount too high blocked: True, Error: ValidationError(...)
```

### Step 1.3: Update fraud_service.py

**Modify:** `app/fraud_service.py`

Add imports:
```python
from app.config import get_app_context
from app.validation import PaymentValidator

# At startup
app_context = get_app_context()
logger = logging.getLogger(__name__)
logger.info(f"Application context: {app_context}")
```

Update endpoint:
```python
@app.post("/check-payment")
async def check_payment(payment_request: PaymentRequest):
    # Validate input
    valid, errors = PaymentValidator.validate_all(
        transaction_id=payment_request.transaction_id,
        user_id=payment_request.user_id,
        amount=payment_request.amount,
        location=payment_request.location
    )
    
    if not errors:
        return {"error": "Invalid payment request", "details": errors}
    
    # Rest of logic...
```

### Step 1.4: Update Kubernetes Deployment

**File:** `k8s/deployment.yaml`

Add environment variables for configuration:
```yaml
env:
  - name: ENVIRONMENT
    value: "production"
  - name: LOG_LEVEL
    value: "INFO"
  - name: FRAUD_HIGH_VALUE_THRESHOLD
    value: "10000"
  - name: ENABLE_REQUEST_ID
    value: "true"
  - name: OTEL_SERVICE_NAME
    value: "fraud-detection-service"
```

Update ConfigMap with new Python modules:
```yaml
data:
  config.py: |
    # Full content of app/config.py
  validation.py: |
    # Full content of app/validation.py
```

### Step 1.5: Test Application

```bash
# Build and push Docker image with new modules
docker build -t fraud-detection:v2 app/
docker push <account>.dkr.ecr.ap-south-1.amazonaws.com/fraud-detection:v2

# Update deployment image
kubectl set image deployment/fraud-detection \
  fraud-detection=<account>.dkr.ecr.ap-south-1.amazonaws.com/fraud-detection:v2 \
  -n application

# Monitor rollout
kubectl rollout status deployment/fraud-detection -n application

# Test endpoint
POD=$(kubectl get pod -n application -l app=fraud-detection -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward $POD 8000:8000 -n application &

# Test with valid payment
curl -X POST http://localhost:8000/check-payment \
  -H "Content-Type: application/json" \
  -d '{
    "transaction_id": "TXN-12345",
    "user_id": "U100",
    "amount": 150.50,
    "location": "Mumbai"
  }'

# Expected: {"fraud_score": 0.0, "status": "approved"}

# Test with injection attempt
curl -X POST http://localhost:8000/check-payment \
  -H "Content-Type: application/json" \
  -d '{
    "transaction_id": "TXN'\'''; DROP TABLE--",
    "user_id": "U100",
    "amount": 150.50,
    "location": "Mumbai"
  }'

# Expected: {"error": "Invalid payment request", ...}
```

---

## Phase 2: Kubernetes Security

### Goal
Deploy network policies, RBAC, and resource quotas.

### Step 2.1: Deploy Network Policies

```bash
# Create network policies for fraud detection service
kubectl apply -f k8s/network-policy.yaml

# Verify policies created
kubectl get networkpolicy -n application
kubectl describe networkpolicy fraud-detection-network-policy -n application

# Expected output:
# - Ingress: Allow from load-generator, ingress-nginx, monitoring
# - Egress: Allow to DNS, otel-collector, external APIs
```

### Step 2.2: Deploy RBAC

```bash
# Create service accounts and roles
kubectl apply -f k8s/rbac.yaml

# Verify RBAC created
kubectl get serviceaccount -n application
kubectl get role -n application
kubectl get rolebinding -n application

# Test RBAC enforcement
# This should FAIL (pod accessing wrong ConfigMap)
POD=$(kubectl get pod -n application -l app=fraud-detection -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -n application -- kubectl get secrets -n application

# Expected error: Error from server (Forbidden): ...
```

### Step 2.3: Deploy Resource Quotas

```bash
# Create resource quotas and limit ranges
kubectl apply -f k8s/resource-quota.yaml

# Verify quotas created
kubectl get resourcequota -n application
kubectl get limitrange -n application

# Check current usage
kubectl describe resourcequota application-quota -n application

# Expected output:
# Resource                Requests    Limits
# --------                --------    ------
# pods                    2/50        
# cpu                     600m/10    
# memory                  640Mi/20Gi  
```

### Step 2.4: Test Network Policy

```bash
# Test 1: Load generator CAN reach fraud detection
kubectl exec deployment/load-generator -n application -- \
  curl -v http://fraud-detection:8000/healthz

# Expected: HTTP 200

# Test 2: Observability pods CANNOT reach fraud detection
# (Create test pod if needed)
kubectl run test-pod --image=nginx -n observability -- sleep 3600
kubectl exec test-pod -n observability -- \
  curl -v http://fraud-detection.application.svc.cluster.local:8000/healthz

# Expected: Connection timeout or refused

# Clean up test pod
kubectl delete pod test-pod -n observability
```

### Step 2.5: Verify Security Improvements

```bash
# Audit policy changes
kubectl get events -n application --sort-by='.lastTimestamp' | tail -20

# Check pod security status
kubectl get pods -n application -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.serviceAccountName}{"\n"}{end}'

# Verify all pods have service accounts
# Expected output:
# fraud-detection-xyz     fraud-detection
# load-generator-abc      load-generator
# frontend-def            default
```

---

## Phase 3: Terraform Improvements

### Goal
Add input validation and organize outputs.

### Step 3.1: Add Variable Validation

```bash
# Copy validation file to terraform directory
cp terraform/variables-validation.tf terraform/variables-validation.tf

# Test Terraform validation
cd terraform/
terraform init

# This will validate against existing variables
terraform plan

# Expected: Plan should show no changes (validation only)
```

### Step 3.2: Add Output Organization

```bash
# Copy outputs file
cp terraform/outputs-organized.tf terraform/outputs-organized.tf

# Verify outputs
terraform output

# Expected output includes all components:
# eks_cluster
# eks_cluster_name
# security_groups
# iam_roles
# ecr_repositories
# etc.
```

### Step 3.3: Test Input Validation

```bash
# Create test terraform with invalid input
cat > test.tf << 'EOF'
variable "test_cluster_version" {
  type = string
  validation {
    condition = can(regex("^1\\.(2[7-9]|[3-9][0-9])$", var.test_cluster_version))
    error_message = "Cluster version must be 1.27 or later"
  }
}
EOF

# Test invalid version (should fail)
terraform plan -var='test_cluster_version=1.24'

# Expected error: error message from validation block

# Test valid version
terraform plan -var='test_cluster_version=1.32'

# Expected: Plan succeeds

# Clean up
rm test.tf terraform.tfvars
```

### Step 3.4: Document Outputs

```bash
# Generate outputs documentation
terraform output -json | jq . > terraform-outputs.json

# Verify all critical outputs present
grep -E "eks_cluster|security_groups|iam_roles" terraform-outputs.json

# Expected: All sections present
```

---

## Phase 4: Observability

### Goal
Implement SLO/SLI definitions and alerting.

### Step 4.1: Copy Alert Definitions

```bash
# Copy SLO/SLI/Alert definitions
cp observability/SLO_SLI_ALERTS.md observability/SLO_SLI_ALERTS.md

# Review alert rules
grep "alert:" observability/SLO_SLI_ALERTS.md

# Expected: List of alert definitions
```

### Step 4.2: Add Prometheus Alert Rules

```bash
# Create PrometheusRule CRD for alerting
cat > k8s/prometheus-alert-rules.yaml << 'EOF'
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: fraud-service-alerts
  namespace: observability
spec:
  groups:
  - name: fraud-service
    interval: 30s
    rules:
    - alert: FraudServiceHighErrorRate
      expr: |
        (increase(fraud_service_requests_total{status="5xx"}[5m]) /
         increase(fraud_service_requests_total[5m])) > 0.05
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "High error rate in fraud service"
    
    - alert: FraudServiceDown
      expr: up{job="fraud-detection"} == 0
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "Fraud detection service is down"
    
    - alert: HighLatency
      expr: |
        histogram_quantile(0.95, rate(fraud_service_latency_seconds_bucket[5m])) > 0.5
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "P95 latency exceeds 500ms"
EOF

# Apply alert rules
kubectl apply -f k8s/prometheus-alert-rules.yaml

# Verify rules applied
kubectl get prometheusrule -n observability
```

### Step 4.3: Create Runbooks

```bash
# Create runbook directory
mkdir -p observability/runbooks

# Create runbooks for each alert
cat > observability/runbooks/fraud-service-down.md << 'EOF'
# Runbook: Fraud Service Down

## Alert: FraudServiceDown
Fraud detection service is not responding.

### Immediate Actions (1 minute)
1. Check pod status: `kubectl get pods -n application -l app=fraud-detection`
2. Check events: `kubectl describe pod <pod-name> -n application`

### Diagnosis (5 minutes)
1. Check logs: `kubectl logs -f <pod-name> -n application --tail=100`
2. Check resource usage: `kubectl top pod <pod-name> -n application`
3. Check network: `kubectl exec <pod-name> -n application -- curl -v http://localhost:8000/healthz`

### Recovery (10 minutes)
1. Restart deployment: `kubectl rollout restart deployment/fraud-detection -n application`
2. Monitor rollout: `kubectl rollout status deployment/fraud-detection -n application`
3. Verify endpoint: `curl http://<service-ip>:8000/healthz`

### Post-Incident
1. Review logs for root cause
2. Document findings in incident ticket
3. Create improvement task if needed
EOF

# Create runbook for high error rate
cat > observability/runbooks/high-error-rate.md << 'EOF'
# Runbook: High Error Rate

## Alert: FraudServiceHighErrorRate
Error rate exceeds 5% for 5+ minutes.

### Immediate Actions
1. Check recent errors: `kubectl logs -n application -l app=fraud-detection --tail=1000 | grep ERROR`
2. Check recent deployments: `kubectl rollout history deployment/fraud-detection -n application`

### Diagnosis
1. Get error distribution: `kubectl logs -n application -l app=fraud-detection | grep ERROR | cut -d: -f2 | sort | uniq -c | sort -rn`
2. Check OpenTelemetry traces
3. Review fraud detection logic for edge cases

### Mitigation
- Option 1 (Scale up): `kubectl scale deployment fraud-detection --replicas=5 -n application`
- Option 2 (Rollback): `kubectl rollout undo deployment fraud-detection -n application`
- Option 3 (Reduce load): `kubectl scale deployment load-generator --replicas=0 -n application`

### Recovery
Apply permanent fix based on root cause analysis.
EOF

# Verify runbooks created
ls -la observability/runbooks/
```

### Step 4.4: Test Alerts

```bash
# Trigger high error rate alert
# Start port forward to service
kubectl port-forward svc/fraud-detection 8000:8000 -n application &

# Send invalid requests to trigger errors
for i in {1..100}; do
  curl -X POST http://localhost:8000/check-payment \
    -H "Content-Type: application/json" \
    -d '{"invalid": "request"}' &
done
wait

# Check if alert fires in Prometheus
# Navigate to Prometheus UI and check for firing alerts
kubectl port-forward svc/prometheus-operated 9090:9090 -n observability &
# Browse to http://localhost:9090/alerts
```

### Step 4.5: Create Grafana Dashboards

```bash
# Create SLO/SLI dashboard JSON
cat > observability/slo-sli-dashboard.json << 'EOF'
{
  "dashboard": {
    "title": "Fraud Service SLO/SLI",
    "panels": [
      {
        "title": "Availability SLO (99.5%)",
        "targets": [{
          "expr": "increase(fraud_service_requests_total{status!=\"5xx\"}[5m]) / increase(fraud_service_requests_total[5m])"
        }],
        "thresholds": [0.995]
      },
      {
        "title": "Error Rate (Target < 0.1%)",
        "targets": [{
          "expr": "increase(fraud_service_requests_total{status=\"5xx\"}[5m]) / increase(fraud_service_requests_total[5m])"
        }],
        "thresholds": [0.001]
      },
      {
        "title": "P95 Latency (Target < 200ms)",
        "targets": [{
          "expr": "histogram_quantile(0.95, rate(fraud_service_latency_seconds_bucket[5m]))"
        }],
        "thresholds": [0.2]
      },
      {
        "title": "P99 Latency (Target < 500ms)",
        "targets": [{
          "expr": "histogram_quantile(0.99, rate(fraud_service_latency_seconds_bucket[5m]))"
        }],
        "thresholds": [0.5]
      }
    ]
  }
}
EOF

# Import into Grafana through UI or API
```

---

## Validation & Testing

### Checklist for Phase Completion

**Phase 1: Application Layer**
- [ ] config.py deploys without syntax errors
- [ ] validation.py validates all inputs correctly
- [ ] fraud_service.py uses config module
- [ ] Injection attempts are blocked
- [ ] Configuration from environment variables
- [ ] Application starts successfully

**Phase 2: Kubernetes Security**
- [ ] Network policies created and active
- [ ] RBAC roles assigned to service accounts
- [ ] Resource quotas enforced
- [ ] Pod connections respect network policies
- [ ] RBAC denies unauthorized access
- [ ] Pod restart due to resource limits is caught

**Phase 3: Terraform**
- [ ] variables-validation.tf integrates without errors
- [ ] outputs-organized.tf provides all expected outputs
- [ ] terraform plan validates input correctly
- [ ] Invalid inputs rejected with clear messages
- [ ] All outputs accessible via terraform output

**Phase 4: Observability**
- [ ] SLO/SLI definitions documented
- [ ] Alert rules created in Prometheus
- [ ] Runbooks accessible to on-call team
- [ ] Alerts fire when conditions met
- [ ] Alerts clear when conditions resolved

### Testing Commands

```bash
# Full validation script
bash << 'EOF'
echo "=== Phase 1: Application ==="
python3 -m py_compile app/config.py && echo "✓ config.py syntax OK" || echo "✗ config.py syntax FAILED"
python3 -m py_compile app/validation.py && echo "✓ validation.py syntax OK" || echo "✗ validation.py syntax FAILED"

echo "=== Phase 2: Kubernetes ==="
kubectl get networkpolicy -n application && echo "✓ Network policies deployed" || echo "✗ Network policies missing"
kubectl get role -n application | grep fraud-detection && echo "✓ RBAC deployed" || echo "✗ RBAC missing"
kubectl get resourcequota -n application && echo "✓ Resource quotas deployed" || echo "✗ Resource quotas missing"

echo "=== Phase 3: Terraform ==="
cd terraform && terraform plan > /dev/null 2>&1 && echo "✓ Terraform validation OK" || echo "✗ Terraform validation FAILED"

echo "=== Phase 4: Observability ==="
test -f observability/SLO_SLI_ALERTS.md && echo "✓ SLO/SLI definitions present" || echo "✗ SLO/SLI definitions missing"
kubectl get prometheusrule -n observability && echo "✓ Alert rules deployed" || echo "✗ Alert rules missing"
test -d observability/runbooks && echo "✓ Runbooks present" || echo "✗ Runbooks missing"
EOF
```

---

## Rollback Procedures

### If Phase 1 Fails

```bash
# Revert deployment to previous image
kubectl set image deployment/fraud-detection \
  fraud-detection=<previous-image-uri> \
  -n application

# Monitor rollback
kubectl rollout status deployment/fraud-detection -n application

# Verify service restored
curl http://fraud-detection:8000/healthz
```

### If Phase 2 Fails (Network Policy Issues)

```bash
# Remove network policies
kubectl delete networkpolicy --all -n application

# Restart affected pods
kubectl rollout restart deployment/fraud-detection -n application
kubectl rollout restart deployment/load-generator -n application

# Verify connectivity restored
kubectl exec deployment/load-generator -n application -- \
  curl http://fraud-detection:8000/healthz
```

### If Phase 2 Fails (RBAC Issues)

```bash
# Revert to default service account temporarily
kubectl patch deployment fraud-detection -n application \
  -p '{"spec":{"template":{"spec":{"serviceAccountName":"default"}}}}'

# Diagnose RBAC issue
kubectl get rolebinding fraud-detection-role-binding -n application -o yaml
kubectl auth can-i get configmaps --as=system:serviceaccount:application:fraud-detection
```

### If Phase 3 Fails (Terraform)

```bash
# Revert to previous terraform state
terraform state pull > current.state
terraform state push backup.state

# Re-apply infrastructure
terraform apply
```

### If Phase 4 Fails (Alerts)

```bash
# Check Prometheus targets
kubectl port-forward svc/prometheus-operated 9090:9090 -n observability &
# Navigate to http://localhost:9090/targets

# Verify ServiceMonitor
kubectl get servicemonitor -n observability
kubectl describe servicemonitor fraud-detection -n observability

# Delete problematic alert rules
kubectl delete prometheusrule fraud-service-alerts -n observability

# Reapply
kubectl apply -f k8s/prometheus-alert-rules.yaml
```

---

## Support & Troubleshooting

### Common Issues

**Issue: "connection refused" when testing network policies**
```bash
# Solution: Network policies might be dropping DNS
# Check if DNS works from pod:
kubectl exec <pod-name> -n application -- nslookup fraud-detection.application.svc.cluster.local
```

**Issue: "Forbidden" when testing RBAC**
```bash
# This is expected! Verify it's the right error:
kubectl auth can-i get configmaps --as=system:serviceaccount:application:fraud-detection

# Should output "no"
```

**Issue: Pod stuck in pending due to resource quotas**
```bash
# Check quota status:
kubectl describe resourcequota application-quota -n application

# Increase quota if needed:
kubectl patch resourcequota application-quota -n application \
  -p '{"spec":{"hard":{"pods":"100"}}}'
```

**Issue: Terraform validation error with regex**
```bash
# Add `?` for optional in regex:
# Before: ^1\.(2[7-9]|[3-9][0-9])$
# After: ^1\.([0-9]{2})$  # More permissive
```

---

## Next Steps

After completing all phases:

1. **Schedule Security Audit** - Have security team review network policies
2. **Train On-Call Team** - Review runbooks together
3. **Create Monitoring Dashboard** - For leadership visibility
4. **Plan Canary Deployment** - For future safe rollouts
5. **Document Lessons Learned** - For future reference

---

**Document Version:** 1.0  
**Last Updated:** June 2, 2026  
**Maintained by:** DevOps Team  
**Next Review:** September 2, 2026
