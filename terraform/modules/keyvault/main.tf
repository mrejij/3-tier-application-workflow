# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# modules/keyvault/main.tf
#
# Creates:
#   - Azure Key Vault (Standard SKU, RBAC authorization)
#   - Role assignment: Terraform operator → Key Vault Secrets Officer
#   - Secrets: vm-ssh-private-key, sql-admin-password, sql-admin-username
#
# WHY RBAC instead of access policies:
#   Vault access policies have a propagation race condition — Azure may return
#   a 403 for several seconds after the policy is written. Azure RBAC role
#   assignments are propagated faster and are the recommended modern approach.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

resource "azurerm_key_vault" "main" {
  name                = "kv-${var.project}-${var.suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  # Use Azure RBAC for authorization — access policies are legacy
  enable_rbac_authorization = true

  soft_delete_retention_days = 7
  purge_protection_enabled   = false   # Set true for production

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = var.tags
}

# ── RBAC: Terraform operator gets full secrets management ─────────────────────
# "Key Vault Secrets Officer" = Get, List, Set, Delete, Recover, Purge secrets
resource "azurerm_role_assignment" "terraform_kv_secrets_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.current_user_object_id
}

# Wait for RBAC propagation before writing any secrets
resource "time_sleep" "wait_rbac" {
  depends_on      = [azurerm_role_assignment.terraform_kv_secrets_officer]
  create_duration = "30s"
}

# ── Secret: SSH private key (for build VM authentication) ────────────────────
resource "azurerm_key_vault_secret" "vm_ssh_private_key" {
  name         = "vm-ssh-private-key"
  value        = var.vm_ssh_private_key
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  depends_on   = [time_sleep.wait_rbac]
  tags         = var.tags
}

# ── Secret: SQL admin password ────────────────────────────────────────────────
resource "azurerm_key_vault_secret" "sql_admin_password" {
  name         = "sql-admin-password"
  value        = var.sql_admin_password
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  depends_on   = [time_sleep.wait_rbac]
  tags         = var.tags
}

# ── Secret: SQL admin username ────────────────────────────────────────────────
resource "azurerm_key_vault_secret" "sql_admin_username" {
  name         = "sql-admin-username"
  value        = var.sql_admin_username
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  depends_on   = [time_sleep.wait_rbac]
  tags         = var.tags
}
