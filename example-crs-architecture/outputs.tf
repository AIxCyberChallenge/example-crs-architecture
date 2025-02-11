output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "kubernetes_cluster_name" {
  value = azurerm_kubernetes_cluster.primary.name
}

output "host" {
  value     = azurerm_kubernetes_cluster.primary.kube_config[0].host
  sensitive = true
}

output "client_certificate" {
  value     = azurerm_kubernetes_cluster.primary.kube_config[0].client_certificate
  sensitive = true
}

output "client_key" {
  value     = azurerm_kubernetes_cluster.primary.kube_config[0].client_key
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = azurerm_kubernetes_cluster.primary.kube_config[0].cluster_ca_certificate
  sensitive = true
}

output "cluster_password" {
  value     = azurerm_kubernetes_cluster.primary.kube_config[0].password
  sensitive = true
}

output "cluster_username" {
  value     = azurerm_kubernetes_cluster.primary.kube_config[0].username
  sensitive = true
}

output "kube_config" {
  value     = azurerm_kubernetes_cluster.primary.kube_config_raw
  sensitive = true
}

output "GHCR_AUTH" {
  value     = var.GHCR_AUTH
  sensitive = true
}

output "CRS_KEY_ID" {
  value     = var.CRS_KEY_ID
  sensitive = true
}

output "CRS_KEY_TOKEN" {
  value     = var.CRS_KEY_TOKEN
  sensitive = true
}

output "CRS_CONTROLLER_KEY_ID" {
  value     = var.CRS_CONTROLLER_KEY_ID
  sensitive = true
}

output "CRS_CONTROLLER_KEY_TOKEN" {
  value     = var.CRS_CONTROLLER_KEY_TOKEN
  sensitive = true
}
