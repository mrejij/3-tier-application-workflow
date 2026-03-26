# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# modules/acr/main.tf
#
# Creates:
#   - Azure Container Registry (Basic SKU — cheapest, ~$5/month)
#     Basic supports push/pull but no geo-replication or webhooks.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

resource "azurerm_container_registry" "main" {
  # ACR names: alphanumeric only, globally unique, 5-50 chars
  name                = "acr${var.project}${var.environment}${var.suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location

  sku           = "Basic"
  admin_enabled = true   # Required for AKS image pull with admin credentials

  tags = var.tags
}
