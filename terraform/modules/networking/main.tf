# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# modules/networking/main.tf
#
# Creates:
#   - Virtual Network (10.0.0.0/16)
#   - Subnet: snet-aks        10.0.1.0/24
#   - Subnet: snet-vm         10.0.2.0/24
#   - Subnet: AzureBastionSubnet  10.0.3.0/27  (must be /27 or larger)
#   - Subnet: snet-sql        10.0.4.0/24
#   - NSG: nsg-vm   (deny direct inbound; Bastion handles SSH)
#   - NSG: nsg-aks  (minimal AKS requirements)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ── Virtual Network ───────────────────────────────────────────────────────────
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.project}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = ["10.0.0.0/16"]

  tags = var.tags
}

# ── NSG: Build VM (no direct internet inbound; Bastion only) ──────────────────
resource "azurerm_network_security_group" "vm" {
  name                = "nsg-vm-${var.project}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location

  # Allow Bastion → VM (ports 22 and 3389)
  security_rule {
    name                       = "AllowBastionSsh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "3389"]
    source_address_prefix      = "10.0.3.0/27"
    destination_address_prefix = "*"
  }

  # Allow VNet-internal traffic (AKS → VM on Nexus/SonarQube ports)
  security_rule {
    name                       = "AllowVnetInbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["8080", "8081", "9000"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # Allow SSH from internet — restrict source_address_prefix to "YOUR_IP/32" for production
  security_rule {
    name                       = "AllowSshInternet"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  # Allow SonarQube UI from internet (port 9000)
  security_rule {
    name                       = "AllowSonarQubeInternet"
    priority                   = 210
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9000"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  # Allow Nexus Repository UI from internet (port 8081)
  security_rule {
    name                       = "AllowNexusInternet"
    priority                   = 220
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8081"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

# ── NSG: AKS subnet ───────────────────────────────────────────────────────────
resource "azurerm_network_security_group" "aks" {
  name                = "nsg-aks-${var.project}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location

  # AKS manages its own rules; allow HTTPS inbound for Ingress/LoadBalancer
  security_rule {
    name                       = "AllowHttpsInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHttpInbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

# ── Subnets ───────────────────────────────────────────────────────────────────
resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]

  # Allow SQL service endpoint from AKS subnet
  service_endpoints = ["Microsoft.Sql"]
}

resource "azurerm_subnet" "vm" {
  name                 = "snet-vm"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]

  service_endpoints = ["Microsoft.Sql", "Microsoft.KeyVault"]
}

# Azure Bastion requires a subnet named exactly "AzureBastionSubnet" (/27 min)
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.3.0/27"]
}

resource "azurerm_subnet" "sql" {
  name                 = "snet-sql"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.4.0/24"]

  service_endpoints = ["Microsoft.Sql"]
}

# ── NSG Associations ──────────────────────────────────────────────────────────
resource "azurerm_subnet_network_security_group_association" "vm" {
  subnet_id                 = azurerm_subnet.vm.id
  network_security_group_id = azurerm_network_security_group.vm.id
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}
