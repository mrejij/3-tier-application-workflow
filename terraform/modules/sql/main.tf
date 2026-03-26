# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# modules/sql/main.tf
#
# Creates:
#   - Azure SQL Logical Server (v12.0, TLS 1.2 minimum)
#   - Azure SQL Database (Basic DTU tier — 5 DTUs, 2 GB max)
#   - Firewall rule: allow Azure services (0.0.0.0 → 0.0.0.0)
#   - Firewall rule: allow AKS subnet CIDR range
#   - Firewall rule: allow Build VM subnet CIDR range
#
# COST NOTE: Basic database with 5 DTUs ≈ $5/month. Cheapest paused option.
#            Serverless can auto-pause but requires GP tier which costs more.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ── Azure SQL Logical Server ─────────────────────────────────────────────────
resource "azurerm_mssql_server" "main" {
  name                = "sql-${var.project}-${var.environment}-${var.suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  version             = "12.0"

  administrator_login          = var.admin_username
  administrator_login_password = var.admin_password

  # TLS 1.2 minimum — OWASP A02: Cryptographic Failures
  minimum_tls_version = "1.2"

  # Disable public network access for extra security in prod
  # Note: leave enabled here so AKS and build VM can reach it via firewall rules
  public_network_access_enabled = true

  tags = var.tags
}

# ── Azure SQL Database (Basic DTU tier) ──────────────────────────────────────
resource "azurerm_mssql_database" "main" {
  name      = "sqldb-${var.project}-${var.environment}"
  server_id = azurerm_mssql_server.main.id

  # Basic = 5 DTUs, 2 GB — cheapest non-serverless option
  sku_name     = var.db_sku
  max_size_gb  = var.db_max_size_gb
  collation    = "SQL_Latin1_General_CP1_CI_AS"

  # Zone redundancy not available in Basic tier
  zone_redundant = false

  # No long-term backup retention to save cost in dev
  tags = var.tags
}

# ── Firewall rule: allow Azure services (required for AKS + GitHub Actions) ──
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# ── Firewall rule: allow AKS subnet CIDR ─────────────────────────────────────
# AKS pods use IPs in the node subnet (snet-aks = 10.0.1.0/24)
resource "azurerm_mssql_firewall_rule" "allow_aks_subnet" {
  name             = "AllowAksSubnet"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = cidrhost(var.aks_subnet_cidr, 0)
  end_ip_address   = cidrhost(var.aks_subnet_cidr, 255)
}

# ── Firewall rule: allow Build VM subnet CIDR ────────────────────────────────
# Build VM EF migrations and health-checks need SQL access
resource "azurerm_mssql_firewall_rule" "allow_vm_subnet" {
  name             = "AllowVmSubnet"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = cidrhost(var.vm_subnet_cidr, 0)
  end_ip_address   = cidrhost(var.vm_subnet_cidr, 255)
}
