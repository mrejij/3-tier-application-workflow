# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# main.tf — Root orchestration module
#
# Deployment order (Terraform resolves dependencies automatically):
#   1. Resource Group
#   2. networking  (VNet + subnets)
#   3. keyvault    (Key Vault — needs RG + current user identity)
#   4. acr         (Container Registry)
#   5. sql         (SQL Server + Database)
#   6. build_vm    (Linux build/deploy server)
#   7. aks         (Kubernetes cluster)
#   8. bastion     (Azure Bastion — browser SSH)
#   9. KV secrets for ACR + AKS kubeconfig (after all services are created)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ── Current caller identity ────────────────────────────────────────────────────
data "azurerm_client_config" "current" {}

# ── Unique suffix for globally unique resource names ───────────────────────────
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
  numeric = true
}

# ── SSH key pair for the build VM ─────────────────────────────────────────────
resource "tls_private_key" "vm_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# ── SQL admin password ────────────────────────────────────────────────────────
resource "random_password" "sql_admin" {
  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]<>?"
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
}

# ── Resource Group ────────────────────────────────────────────────────────────
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project}-${var.environment}"
  location = var.location

  tags = local.common_tags
}

# ── Common tags ───────────────────────────────────────────────────────────────
locals {
  suffix = random_string.suffix.result

  common_tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

# ── Module: Networking ────────────────────────────────────────────────────────
module "networking" {
  source = "./modules/networking"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  project             = var.project
  environment         = var.environment
  tags                = local.common_tags
}

# ── Module: Key Vault ────────────────────────────────────────────────────────
# Created early so other modules can reference KV for secrets
module "keyvault" {
  source = "./modules/keyvault"

  resource_group_name    = azurerm_resource_group.main.name
  location               = var.location
  project                = var.project
  environment            = var.environment
  suffix                 = local.suffix
  tenant_id              = data.azurerm_client_config.current.tenant_id
  current_user_object_id = data.azurerm_client_config.current.object_id
  vm_ssh_private_key     = tls_private_key.vm_ssh.private_key_pem
  sql_admin_password     = random_password.sql_admin.result
  sql_admin_username     = var.sql_admin_username
  tags                   = local.common_tags
}

# ── Module: Azure Container Registry ─────────────────────────────────────────
module "acr" {
  source = "./modules/acr"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  project             = var.project
  environment         = var.environment
  suffix              = local.suffix
  tags                = local.common_tags
}

# ── Module: Azure SQL Database ────────────────────────────────────────────────
module "sql" {
  source = "./modules/sql"

  resource_group_name  = azurerm_resource_group.main.name
  location             = var.location
  project              = var.project
  environment          = var.environment
  suffix               = local.suffix
  admin_username       = var.sql_admin_username
  admin_password       = random_password.sql_admin.result
  db_sku               = var.sql_db_sku
  db_max_size_gb       = var.sql_db_max_size_gb
  aks_subnet_cidr      = module.networking.aks_subnet_cidr
  vm_subnet_cidr       = module.networking.vm_subnet_cidr
  tags                 = local.common_tags
}

# ── Module: Build / Deploy VM ────────────────────────────────────────────────
module "build_vm" {
  source = "./modules/build_vm"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  project             = var.project
  environment         = var.environment
  vm_size             = var.vm_sku
  os_disk_size_gb     = var.vm_os_disk_size_gb
  admin_username      = var.vm_admin_username
  ssh_public_key      = tls_private_key.vm_ssh.public_key_openssh
  subnet_id           = module.networking.vm_subnet_id
  tags                = local.common_tags
}

# ── Module: AKS ───────────────────────────────────────────────────────────────
module "aks" {
  source = "./modules/aks"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  project             = var.project
  environment         = var.environment
  node_count          = var.aks_node_count
  node_vm_size        = var.vm_sku
  os_disk_size_gb     = var.aks_os_disk_size_gb
  subnet_id           = module.networking.aks_subnet_id
  acr_id              = module.acr.acr_id
  tags                = local.common_tags
}

# ── Module: Azure Bastion ─────────────────────────────────────────────────────
module "bastion" {
  source = "./modules/bastion"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  project             = var.project
  environment         = var.environment
  subnet_id           = module.networking.bastion_subnet_id
  tags                = local.common_tags
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Post-creation: Store service credentials in Key Vault
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Azure RBAC role assignments take up to ~30 seconds to propagate after the
# API call returns. Without this sleep the Key Vault secret writes fail with
# 403 ForbiddenByRbac even though the role assignment exists in state.
resource "time_sleep" "wait_kv_rbac" {
  depends_on      = [module.keyvault]
  create_duration = "30s"
}

resource "azurerm_key_vault_secret" "acr_login_server" {
  name         = "acr-login-server"
  value        = module.acr.login_server
  key_vault_id = module.keyvault.key_vault_id
  content_type = "text/plain"
  depends_on   = [time_sleep.wait_kv_rbac]
  tags         = local.common_tags
}

resource "azurerm_key_vault_secret" "acr_admin_username" {
  name         = "acr-admin-username"
  value        = module.acr.admin_username
  key_vault_id = module.keyvault.key_vault_id
  content_type = "text/plain"
  depends_on   = [time_sleep.wait_kv_rbac]
  tags         = local.common_tags
}

resource "azurerm_key_vault_secret" "acr_admin_password" {
  name         = "acr-admin-password"
  value        = module.acr.admin_password
  key_vault_id = module.keyvault.key_vault_id
  content_type = "text/plain"
  depends_on   = [time_sleep.wait_kv_rbac]
  tags         = local.common_tags
}

resource "azurerm_key_vault_secret" "aks_kubeconfig" {
  name         = "aks-kubeconfig"
  value        = module.aks.kube_config_raw
  key_vault_id = module.keyvault.key_vault_id
  content_type = "text/plain"
  depends_on   = [time_sleep.wait_kv_rbac]
  tags         = local.common_tags
}

resource "azurerm_key_vault_secret" "sql_connection_string" {
  name         = "sql-connection-string"
  value        = "Server=tcp:${module.sql.server_fqdn},1433;Initial Catalog=${module.sql.database_name};Persist Security Info=False;User ID=${var.sql_admin_username};Password=${random_password.sql_admin.result};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  key_vault_id = module.keyvault.key_vault_id
  content_type = "text/plain"
  depends_on   = [time_sleep.wait_kv_rbac]
  tags         = local.common_tags
}

# Grant AKS kubelet managed identity read access to Key Vault secrets
# "Key Vault Secrets User" = Get + List only (read-only)
resource "azurerm_role_assignment" "aks_kv_secrets_user" {
  scope                = module.keyvault.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.aks.kubelet_identity_object_id
}

# Grant build VM managed identity read access to Key Vault secrets
resource "azurerm_role_assignment" "vm_kv_secrets_user" {
  scope                = module.keyvault.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.build_vm.identity_object_id
}
