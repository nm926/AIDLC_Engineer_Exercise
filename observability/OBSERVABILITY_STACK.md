# Observability Stack: Prometheus + Loki + OpenTelemetry + Tempo

This document explains how the observability components in this lab work together.

## What each tool does

### Prometheus (metrics)
Prometheus collects numeric time-series data such as:
- request count
- latency
- error rate
- CPU and memory usage

Prometheus is best for questions like:
- Is traffic increasing?
- Is p95 latency going up?
- Is error rate above threshold?

### Loki (logs)
Loki stores and indexes logs efficiently (mostly by labels, not full-text indexing of everything).
It is useful for:
- searching application and pod logs
- filtering logs by namespace, pod, app, or severity
- debugging failures with exact log lines

### OpenTelemetry (telemetry standard and pipeline)
OpenTelemetry (OTel) provides a standard way to generate and ship telemetry data (traces, metrics, logs).

In Kubernetes setups like this lab, an OTel Collector usually:
- receives telemetry from applications/instrumentation libraries
- processes it (batching, filtering, enrichment)
- exports it to backend systems such as Tempo and Prometheus-compatible endpoints

### Tempo (distributed tracing)
Tempo stores traces (spans across services and operations).
Tracing helps answer:
- Why is one request slow?
- Which downstream call failed?
- Where is most time spent in a request path?

Tempo is focused on traces and integrates well with Grafana for trace exploration.

## How they work together

## End-to-end flow
1. Your application emits telemetry:
- metrics (for Prometheus)
- logs (for Loki)
- traces (via OpenTelemetry)

2. OpenTelemetry Collector receives traces/telemetry and routes it to backends.

3. Prometheus scrapes metrics endpoints from app and cluster components.

4. Loki ingests logs from Kubernetes workloads.

5. Tempo stores distributed traces.

6. Grafana visualizes all of them in one place:
- dashboards for metrics
- log queries for incidents
- trace views for request-level debugging

## Logs and metrics flow (interview quick answer)

Use this short explanation:

- OTEL receives telemetry from apps through OTLP.
- OTEL publishes traces/logs/metrics to Kafka topics.
- OTEL consumes telemetry from Kafka and exports logs to Loki.
- OTEL consumes telemetry from Kafka and exports metrics to a Prometheus scrape endpoint.
- Prometheus scrapes OTEL metrics and stores time-series data.
- Grafana reads metrics from Prometheus and logs from Loki.

ASCII flow:

```text
Application
	| OTLP logs, metrics, traces
	v
OpenTelemetry Collector
	|-- producer pipeline --> Kafka topics (otel-logs / otel-metrics / otel-traces)
	|
	|-- consumer pipelines --> Loki / Prometheus / Tempo
															 |
															 v
														 Prometheus scrape + Loki + Tempo --> Grafana
```

Note for this repo:

- Container logs are also collected by Fluent Bit and sent to Loki.
- So Loki receives logs from both OTEL (OTLP logs) and Fluent Bit (pod/container logs).

## Why this combination is powerful

- Metrics (Prometheus) tell you that there is a problem.
- Logs (Loki) tell you what happened.
- Traces (Tempo via OpenTelemetry) tell you where and why it happened across services.

Together, this gives fast root-cause analysis.

## Typical troubleshooting workflow
1. Detect spike in error rate or latency on a Prometheus dashboard.
2. Open related logs in Loki for the affected pod/service and time window.
3. Jump to traces in Tempo to inspect full request path and slow/error spans.
4. Identify bottleneck or failing dependency and fix.

## In this repository

Related config files:
- observability/prometheus-values.yaml
- observability/loki-values.yaml
- observability/kafka-values.yaml
- observability/otel-collector.yaml
- observability/tempo-values.yaml
- observability/fraud-service-dashboard.json

These files define how the observability components are deployed and wired for the EKS lab.
