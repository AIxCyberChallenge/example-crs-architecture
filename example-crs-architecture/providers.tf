provider "azurerm" {
  features {}
  #Can setup your service principal here, currently commented out to use az cli apply terraform
  #subscription_id   = "<azure_subscription_id>"
  #tenant_id         = "<azure_subscription_tenant_id>"
  #client_id         = "<service_principal_appid>"
  #client_secret     = "<service_principal_password>"
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.primary.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.primary.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.primary.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.primary.kube_config[0].cluster_ca_certificate)
}
