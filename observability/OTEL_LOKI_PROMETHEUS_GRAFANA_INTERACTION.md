# OpenTelemetry Interaction with Loki, Prometheus, and Grafana

This document explains how telemetry flows in this lab and how to view it in Grafana.

## 1) Who does what

- OpenTelemetry Collector (`observability/otel-collector.yaml`)
  - Receives OTLP telemetry from applications on ports `4317` (gRPC) and `4318` (HTTP).
  - Publishes traces/logs/metrics to Kafka topics (`otel-traces`, `otel-logs`, `otel-metrics`).
  - Consumes telemetry from Kafka and exports traces to Tempo and logs to Loki.
  - Exposes metrics in Prometheus format on `:8889` after Kafka consumption.

- Kafka (`observability/kafka-values.yaml`)
  - Acts as the buffering/decoupling layer for OTEL telemetry.
  - Allows back-pressure handling and smoother downstream exporter behavior.

- Loki (`observability/loki-values.yaml`)
  - Stores logs.
  - Receives logs from:
    - Fluent Bit (container stdout/stderr logs)
    - OpenTelemetry Collector (OTLP logs pipeline)

- Prometheus (`observability/prometheus-values.yaml`)
  - Scrapes metrics endpoints.
  - Collects OpenTelemetry Collector exported metrics (`:8889`) through ServiceMonitor.

- Grafana (`observability/prometheus-values.yaml`)
  - Visualizes data from all backends using data sources:
    - Prometheus (metrics)
    - Loki (logs)
    - Tempo (traces)

## 2) End-to-end interaction flow

### Metrics path

1. App emits OTLP metrics -> OpenTelemetry Collector.
2. Collector processes metrics (`memory_limiter`, `batch`) and exports to Kafka topic `otel-metrics`.
3. Collector receives metrics back from Kafka and exporter `prometheus` exposes them at `0.0.0.0:8889`.
4. Prometheus scrapes this endpoint.
5. Grafana reads from Prometheus and renders dashboards.

### Logs path

There are two log ingestion paths in this setup:

1. Kubernetes container logs -> Fluent Bit -> Loki.
2. OTLP logs from instrumented app -> OpenTelemetry Collector -> Kafka (`otel-logs`) -> OpenTelemetry Collector -> Loki.

Grafana reads both in Loki Explore, and you can filter by labels such as `namespace`, `pod`, and `container`.

### Trace path

1. App emits OTLP traces -> OpenTelemetry Collector.
2. Collector exports traces to Kafka topic `otel-traces`.
3. Collector consumes `otel-traces` and exports traces to Tempo.
4. Grafana Explore (Tempo data source) is used to search traces and inspect spans.

## 3) Why this is useful

- Prometheus tells you if something is wrong (latency, errors, saturation).
- Loki shows exact log events around that time window.
- Tempo shows where the request slowed down or failed.

This is the classic metrics -> logs -> traces troubleshooting workflow.

## 4) How to open Grafana

### Get Grafana URL

```bash
kubectl -n observability get svc kube-prometheus-stack-grafana
```

If service type is `LoadBalancer`, use `EXTERNAL-IP` in your browser:

```text
http://<EXTERNAL-IP>
```

### Get Grafana admin username and password

```bash
kubectl -n observability get secret kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-user}' | base64 -d && echo

kubectl -n observability get secret kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d && echo
```

In this repo values, admin password is also set as `admin123` under Grafana values.

## 5) What to check in Grafana

### Metrics (Prometheus)

Go to `Explore` -> choose `Prometheus` and try:

```promql
up
```

```promql
rate(http_requests_total[5m])
```

### Logs (Loki)

Go to `Explore` -> choose `Loki` and try:

```logql
{namespace="application"}
```

```logql
{namespace="application", pod=~"fraud-detection.*"}
```

### Traces (Tempo)

Go to `Explore` -> choose `Tempo` and search by service name:

- `fraud-detection-service`

Then open a trace and inspect span durations, errors, and downstream calls.

## 6) Quick validation checklist

- `kubectl -n observability get pods` shows Prometheus/Loki/Tempo/Grafana/OTel Collector/Kafka running.
- `kubectl -n application get pods` shows app pods running.
- Loki query `{namespace="application"}` returns streams.
- Tempo has received spans (for example via `tempo_distributor_spans_received_total`).
- Prometheus target list includes OTel Collector metrics endpoint.

## 7) Important note for this repository

Even though OTel has a logs pipeline to Loki, most Kubernetes app logs are already collected by Fluent Bit. In practice, you can use both:

- Fluent Bit for cluster/container logs.
- OTel logs pipeline for OTLP-native application logs.

That combined model is normal and useful in EKS environments.