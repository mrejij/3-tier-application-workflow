# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# outputs.tf — Root module outputs
# Run: terraform output  (after apply)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

output "resource_group_name" {
  description = "Name of the main resource group."
  value       = azurerm_resource_group.main.name
}

# ── Networking ────────────────────────────────────────────────────────────────
output "vnet_name" {
  description = "Virtual network name."
  value       = module.networking.vnet_name
}

output "vnet_id" {
  description = "Virtual network resource ID."
  value       = module.networking.vnet_id
}

# ── ACR ───────────────────────────────────────────────────────────────────────
output "acr_login_server" {
  description = "ACR login server URL (e.g. myacr.azurecr.io)."
  value       = module.acr.login_server
}

output "acr_admin_username" {
  description = "ACR admin username."
  value       = module.acr.admin_username
  sensitive   = true
}

# ── AKS ───────────────────────────────────────────────────────────────────────
output "aks_cluster_name" {
  description = "AKS cluster name."
  value       = module.aks.cluster_name
}

output "aks_kube_config_command" {
  description = "Azure CLI command to configure kubectl."
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${module.aks.cluster_name} --overwrite-existing"
}

# ── Build VM ──────────────────────────────────────────────────────────────────
output "build_vm_name" {
  description = "Build VM name."
  value       = module.build_vm.vm_name
}

output "build_vm_public_ip" {
  description = "Build VM public IP. SSH: ssh azureuser@<ip> | SonarQube: http://<ip>:9000 | Nexus: http://<ip>:8081"
  value       = module.build_vm.public_ip_address
}

output "build_vm_private_ip" {
  description = "Build VM private IP address."
  value       = module.build_vm.private_ip_address
}

# ── SQL ───────────────────────────────────────────────────────────────────────
output "sql_server_fqdn" {
  description = "Azure SQL Server fully qualified domain name."
  value       = module.sql.server_fqdn
}

output "sql_database_name" {
  description = "Azure SQL Database name."
  value       = module.sql.database_name
}

# ── Bastion ───────────────────────────────────────────────────────────────────
output "bastion_name" {
  description = "Azure Bastion host name."
  value       = module.bastion.bastion_name
}

output "bastion_connect_hint" {
  description = "How to connect to the build VM via Bastion."
  value       = "Azure Portal → Virtual Machines → ${module.build_vm.vm_name} → Connect → Bastion"
}

# ── Key Vault ─────────────────────────────────────────────────────────────────
output "key_vault_name" {
  description = "Key Vault name (all credentials stored here)."
  value       = module.keyvault.key_vault_name
}

output "key_vault_uri" {
  description = "Key Vault URI."
  value       = module.keyvault.key_vault_uri
}

output "key_vault_secrets_list" {
  description = "Secrets stored in the Key Vault."
  value = [
    "vm-ssh-private-key",
    "sql-admin-password",
    "sql-connection-string",
    "acr-login-server",
    "acr-admin-username",
    "acr-admin-password",
    "aks-kubeconfig"
  ]
}
