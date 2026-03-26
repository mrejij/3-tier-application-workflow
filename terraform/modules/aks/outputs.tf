output "cluster_name" {
  value = azurerm_kubernetes_cluster.main.name
}

output "cluster_id" {
  value = azurerm_kubernetes_cluster.main.id
}

output "kube_config_raw" {
  value     = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive = true
}

output "host" {
  value     = azurerm_kubernetes_cluster.main.kube_config[0].host
  sensitive = true
}

output "kubelet_identity_object_id" {
  description = "Object ID of the AKS kubelet managed identity (used for Key Vault access)."
  value       = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

output "cluster_identity_object_id" {
  description = "Object ID of the AKS control-plane managed identity."
  value       = azurerm_kubernetes_cluster.main.identity[0].principal_id
}
