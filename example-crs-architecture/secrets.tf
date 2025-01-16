resource "kubernetes_secret" "docker-registry" {
  metadata {
    name = "ghcr-creds"
  }

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "ghcr.io" = {
          "auth" = "<your_base64_encoded_credentials>"
        }
      }
    })
  }

  type = "kubernetes.io/dockerconfigjson"
}
