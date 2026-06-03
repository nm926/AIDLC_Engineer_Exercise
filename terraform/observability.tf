resource "kubernetes_namespace" "observability" {
  metadata {
    name = "observability"
  }

  depends_on = [time_sleep.cluster_endpoint_settle]
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.12.2"

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }

  depends_on = [time_sleep.cluster_endpoint_settle]
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.observability.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "68.4.4"

  values = [file("${path.module}/../observability/prometheus-values.yaml")]

  depends_on = [kubernetes_namespace.observability, time_sleep.cluster_endpoint_settle]
}

resource "kubernetes_config_map" "grafana_slo_dashboard" {
  metadata {
    name      = "grafana-slo-dashboard"
    namespace = kubernetes_namespace.observability.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "sla-slo-sli-error-budget-dashboard.json" = file("${path.module}/../observability/sla-slo-sli-error-budget-dashboard.json")
  }

  depends_on = [kubernetes_namespace.observability]
}

resource "helm_release" "loki" {
  name            = "loki"
  namespace       = kubernetes_namespace.observability.metadata[0].name
  repository      = "https://grafana.github.io/helm-charts"
  chart           = "loki"
  version         = "6.16.0"
  timeout         = 900
  wait            = true
  wait_for_jobs   = true
  cleanup_on_fail = true

  values = [file("${path.module}/../observability/loki-values.yaml")]

  depends_on = [
    kubernetes_namespace.observability,
    time_sleep.cluster_endpoint_settle,
    helm_release.kube_prometheus_stack
  ]
}

resource "helm_release" "tempo" {
  name       = "tempo"
  namespace  = kubernetes_namespace.observability.metadata[0].name
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo"
  version    = "1.17.0"

  values = [file("${path.module}/../observability/tempo-values.yaml")]

  depends_on = [
    kubernetes_namespace.observability,
    time_sleep.cluster_endpoint_settle,
    helm_release.kube_prometheus_stack
  ]
}

resource "helm_release" "otel_collector" {
  name            = "otel-collector"
  namespace       = kubernetes_namespace.observability.metadata[0].name
  repository      = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart           = "opentelemetry-collector"
  version         = "0.112.0"
  timeout         = 1800
  wait            = false
  wait_for_jobs   = false
  cleanup_on_fail = true

  values = [file("${path.module}/../observability/otel-collector.yaml")]

  depends_on = [
    kubernetes_namespace.observability,
    time_sleep.cluster_endpoint_settle,
    helm_release.kube_prometheus_stack,
    helm_release.loki,
    helm_release.tempo,
  ]
}

resource "helm_release" "fluent_bit" {
  name            = "fluent-bit"
  namespace       = kubernetes_namespace.observability.metadata[0].name
  repository      = "https://fluent.github.io/helm-charts"
  chart           = "fluent-bit"
  version         = "0.48.9"
  timeout         = 600
  wait            = true
  wait_for_jobs   = true
  cleanup_on_fail = true

  values = [file("${path.module}/../observability/fluent-bit-values.yaml")]

  depends_on = [
    kubernetes_namespace.observability,
    time_sleep.cluster_endpoint_settle,
    helm_release.loki
  ]
}
