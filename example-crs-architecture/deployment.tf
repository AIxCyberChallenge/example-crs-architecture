resource "kubernetes_deployment" "crs-example-webservice" {
  #ts:skip=AC-K8-NS-PO-M-0122 Security context not required
  metadata {
    name = "crs-webservice"
    labels = {
      app = "CRSWebservice"
    }
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "CRSWebservice"
      }
    }

    template {
      metadata {
        labels = {
          app = "CRSWebservice"
        }
      }

      spec {
        container {
          image = "ghcr.io/aixcc-finals/example-crs-architecture/example-crs-webservice:v0.1"
          name  = "crs-webservice"

          port {
            container_port = 8000
          }

          # environment variables
          env {
            name  = "CRS_KEY_ID"
            value = var.CRS_KEY_ID
          }

          env {
            name  = "CRS_KEY_TOKEN"
            value = var.CRS_KEY_TOKEN
          }

          env {
            name  = "CRS_CONTROLLER_KEY_ID"
            value = var.CRS_CONTROLLER_KEY_ID
          }

          env {
            name  = "CRS_CONTROLLER_KEY_TOKEN"
            value = var.CRS_CONTROLLER_KEY_TOKEN
          }

          # resource limits
          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
        }

        image_pull_secrets {
          name = kubernetes_secret.docker-registry.metadata[0].name
        }
      }
    }
  }
}

resource "kubernetes_service" "crs-webservice-lb" {
  metadata {
    name = "crs-webservice-lb"
    annotations = {
      "service.beta.kubernetes.io/azure-load-balancer-internal" = "true"
    }
  }

  spec {
    selector = {
      app = kubernetes_deployment.crs-example-webservice.metadata[0].labels.app
    }

    port {
      port        = 80
      target_port = 8000
    }

    type = "LoadBalancer"

  }
}
