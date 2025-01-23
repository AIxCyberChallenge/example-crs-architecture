resource "kubernetes_secret" "docker-registry" {
  metadata {
    name = "ghcr-creds"
  }

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "ghcr.io" = {
          "auth" = var.GHCR_AUTH
        }
      }
    })
  }

  type = "kubernetes.io/dockerconfigjson"
}
