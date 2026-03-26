# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# modules/bastion/main.tf
#
# Creates:
#   - Standard Static Public IP (required by Azure Bastion)
#   - Azure Bastion Host (Basic SKU)
#       - Browser-based SSH/RDP to VMs — no public IP needed on the VMs
#       - Subnet MUST be named "AzureBastionSubnet" with a /27+ CIDR
#
# COST NOTE: Basic Bastion ≈ $0.19/hour ≈ $140/month.
#            Deallocate or destroy Bastion when not using browser SSH sessions
#            to save costs. The VM remains accessible via re-deployment.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ── Public IP (Standard SKU, Static — required by Bastion) ───────────────────
resource "azurerm_public_ip" "bastion" {
  name                = "pip-bastion-${var.project}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location

  # Standard + Static is mandatory for Azure Bastion
  sku               = "Standard"
  allocation_method = "Static"

  tags = var.tags
}

# ── Azure Bastion Host (Basic SKU) ───────────────────────────────────────────
resource "azurerm_bastion_host" "main" {
  name                = "bastion-${var.project}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location

  # Basic = cheapest tier; supports browser SSH + RDP
  sku = "Basic"

  # Basic SKU does not support tunneling or shareable links
  # Use Standard SKU if you need kubectl tunneling or custom ports

  ip_configuration {
    name                 = "ipconfig1"
    subnet_id            = var.subnet_id   # must be AzureBastionSubnet
    public_ip_address_id = azurerm_public_ip.bastion.id
  }

  tags = var.tags
}
