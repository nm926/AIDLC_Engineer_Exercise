resource "kubernetes_namespace" "application" {
  metadata {
    name = "application"
  }

  depends_on = [time_sleep.cluster_endpoint_settle]
}

resource "kubernetes_config_map" "load_generator_code" {
  metadata {
    name      = "load-generator-code"
    namespace = kubernetes_namespace.application.metadata[0].name
  }

  data = {
    "load_generator.py" = file("${path.module}/../app/load_generator.py")
  }

  depends_on = [kubernetes_namespace.application]
}

# Load generator deployment for continuous traffic generation
resource "kubernetes_deployment" "load_generator" {
  metadata {
    name      = "load-generator"
    namespace = kubernetes_namespace.application.metadata[0].name
    labels = {
      app = "load-generator"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "load-generator"
      }
    }

    template {
      metadata {
        labels = {
          app = "load-generator"
        }
      }

      spec {
        container {
          name              = "load-generator"
          image             = "python:3.11-slim"
          image_pull_policy = "IfNotPresent"

          command = ["/bin/sh", "-c"]
          args = [
            "pip install --no-cache-dir requests==2.31.0 && python /app/load_generator.py"
          ]

          env {
            name  = "PYTHONUNBUFFERED"
            value = "1"
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }

          volume_mount {
            name       = "load-gen-code"
            mount_path = "/app/load_generator.py"
            sub_path   = "load_generator.py"
          }
        }

        volume {
          name = "load-gen-code"
          config_map {
            name             = "load-generator-code"
            default_mode     = "0555"
          }
        }
      }
    }
  }

  depends_on = [
    time_sleep.cluster_endpoint_settle,
    kubernetes_namespace.application,
    kubernetes_config_map.load_generator_code
  ]
}
