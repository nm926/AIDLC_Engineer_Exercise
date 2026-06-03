# Observability Stack: SLO, SLI, and Alerting Rules

## Service Level Objectives (SLOs) & Indicators (SLIs)

### Fraud Detection Service

#### Availability SLI
- **Definition:** Percentage of requests that don't result in HTTP 5xx errors
- **SLO:** 99.5% availability (4 hours 23 minutes down per month)
- **Target:** fraud_service_requests_total{endpoint="/check-payment",status!="5xx"} / fraud_service_requests_total{endpoint="/check-payment"} >= 0.995

#### Latency SLI
- **Definition:** Percentage of requests completing within target latency
- **Target P95 Latency:** < 200ms
- **Target P99 Latency:** < 500ms
- **SLO:** 95% of requests complete in < 200ms
- **Metric:** histogram_quantile(0.95, rate(fraud_service_latency_seconds_bucket[5m])) < 0.2

#### Error Rate SLI
- **Definition:** Percentage of requests that fail due to service errors
- **SLO:** Error rate < 0.1%
- **Metric:** increase(fraud_service_requests_total{status="5xx"}[5m]) / increase(fraud_service_requests_total[5m]) < 0.001

#### Fraud Detection Accuracy SLI
- **Definition:** System's ability to detect fraud patterns correctly
- **Target:** 98% accuracy on known fraud patterns
- **Metric:** Manual validation + confusion matrix from logs

---

## Alert Rules

### Critical Alerts (Page on-call)

**Alert: High Error Rate**
```yaml
- alert: FraudServiceHighErrorRate
  expr: |
    (increase(fraud_service_requests_total{status="5xx"}[5m]) /
     increase(fraud_service_requests_total[5m])) > 0.05
  for: 5m
  severity: critical
  message: "Fraud detection service error rate > 5% for 5 minutes"
```

**Alert: Service Unavailable**
```yaml
- alert: FraudServiceDown
  expr: up{job="fraud-detection"} == 0
  for: 1m
  severity: critical
  message: "Fraud detection service is down"
```

**Alert: P95 Latency Degradation**
```yaml
- alert: HighLatency
  expr: |
    histogram_quantile(0.95, rate(fraud_service_latency_seconds_bucket[5m])) > 0.5
  for: 10m
  severity: warning
  message: "Fraud detection P95 latency > 500ms for 10 minutes"
```

### Warning Alerts (Notify team)

**Alert: Memory Usage High**
```yaml
- alert: HighMemoryUsage
  expr: |
    container_memory_working_set_bytes{pod="fraud-detection"} /
    container_spec_memory_limit_bytes > 0.8
  for: 5m
  severity: warning
  message: "Fraud detection pod memory usage > 80%"
```

**Alert: CPU Throttling**
```yaml
- alert: CPUThrottling
  expr: |
    rate(container_cpu_cfs_throttled_seconds_total{pod="fraud-detection"}[5m]) > 0.1
  for: 5m
  severity: warning
  message: "Fraud detection pod CPU throttling detected"
```

**Alert: Pod Restart Loop**
```yaml
- alert: PodRestartingLoop
  expr: |
    rate(kube_pod_container_status_restarts_total{pod="fraud-detection"}[15m]) > 0.1
  for: 5m
  severity: warning
  message: "Fraud detection pod restarting excessively"
```

---

## Runbook Templates

### When Alert: FraudServiceDown

1. **Immediate Action (1 min)**
   - Check pod status: `kubectl get pods -n application -l app=fraud-detection`
   - Check events: `kubectl describe pod <pod-name> -n application`

2. **Diagnosis (5 min)**
   - Check logs: `kubectl logs -f <pod-name> -n application`
   - Check resource limits: `kubectl top pod <pod-name> -n application`
   - Check network: `kubectl exec <pod-name> -n application -- ping otel-collector`

3. **Recovery (10 min)**
   - Restart pods: `kubectl rollout restart deployment fraud-detection -n application`
   - Verify recovery: Check /healthz endpoint
   - Check metrics returning

4. **Post-Incident**
   - Review pod logs for root cause
   - Document findings
   - Create improvement tasks if needed

### When Alert: HighErrorRate

1. **Check Recent Changes**
   - `kubectl rollout history deployment fraud-detection -n application`
   - Review recent commits/deployments

2. **Analyze Errors**
   - `kubectl logs -n application -l app=fraud-detection --tail=1000 | grep ERROR`
   - Look for patterns: configuration, dependency, or code issues

3. **Mitigation Options**
   - Increase replicas if capacity issue: `kubectl scale deployment fraud-detection --replicas=5 -n application`
   - Rollback if recent change: `kubectl rollout undo deployment fraud-detection -n application`
   - Scale down load generator if testing: `kubectl scale deployment load-generator --replicas=0 -n application`

4. **Root Cause Analysis**
   - Check OpenTelemetry traces
   - Review fraud detection logic for edge cases
   - Verify dependencies are healthy

---

## Dashboards to Create

### Application Health Dashboard
- Request rate (RPS)
- Error rate (%)
- P50, P95, P99 latency
- Pod count and restart count
- CPU and memory usage

### Fraud Detection Analytics Dashboard
- Fraud detection rate (%)
- Fraud reasons distribution
- Transaction amount distribution
- User activity patterns
- High-value transaction tracking

### Infrastructure Dashboard
- Node health
- Pod scheduling status
- Network I/O
- Storage usage
- Karpenter provisioning status

---

## Service Dependencies Map

```
External Users
    ↓
[ALB Ingress] (AWS)
    ↓
[Frontend] (React, nginx)
    ↓
[Fraud Detection] (FastAPI)
    ↓
[Prometheus] (metrics collection)
[OpenTelemetry Collector] (trace collection)
[Loki] (log aggregation)
    ↓
[Grafana] (visualization)

Critical Path:
Load Generator → Fraud Detection → Prometheus/OTEL → Observability Stack
```

---

## Monitoring Best Practices

1. **Alert Fatigue Prevention**
   - Set thresholds based on actual baselines
   - Use "for" clause to prevent flapping
   - Aggregate related alerts

2. **Observability Coverage**
   - Monitor business metrics (fraud detection accuracy)
   - Monitor technical metrics (latency, errors, resources)
   - Correlate with traces for deep insights

3. **Runbook Ownership**
   - Each alert has a runbook
   - Runbooks regularly tested and updated
   - On-call team trained on runbooks

4. **Metrics Naming Convention**
   - prefix: `fraud_service_`, `frontend_`, etc.
   - suffixes: `_total` (counters), `_seconds` (histograms)
   - labels: `endpoint`, `method`, `status`, `reason`

---

*Last Updated: June 2, 2026*  
*Maintained by: DevOps Team*
