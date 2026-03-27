# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# modules/build_vm/main.tf
#
# DEPLOYMENT-ONLY self-hosted runner — runs only AKS/ACR deployment jobs that
# require private VNet access. All CPU-bound CI steps (build, test, lint, scan)
# run on GitHub Actions hosted runners.
#
# Creates:
#   - Public IP (Standard Static) — for SSH access via Azure Bastion
#   - NIC (private + public IP)
#   - Linux VM (Ubuntu 22.04 LTS, Standard_D2ls_v5)
#   - SSH key authentication (public key passed in; private key in Key Vault)
#   - System-assigned managed identity → grants access to ACR and Key Vault
#   - cloud-init script: installs Docker, kubectl, Helm, Azure CLI only
#
# Tools NOT installed here (run on GitHub Actions hosted runners instead):
#   .NET SDK, Node.js, Angular CLI, Trivy, Gitleaks, OWASP Dependency-Check,
#   Checkov, dotnet-sonarscanner, SonarQube server, Nexus Repository Manager.
#
# SECURITY NOTE: Port 22 is only accessible via Azure Bastion (no public SSH).
#
# COST NOTE: Standard_D2ls_v5 ≈ $0.085/hour ≈ $62/month in Central India.
#            Standard Static Public IP ≈ $0.005/hour ≈ $3.65/month.
#            Stop the VM when not in use to reduce costs.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ── Public IP (Standard SKU, Static allocation) ───────────────────────────────
resource "azurerm_public_ip" "vm" {
  name                = "pip-vm-${var.project}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"
  allocation_method   = "Static"

  tags = var.tags
}

# ── Network Interface (public + private IP) ───────────────────────────────────
resource "azurerm_network_interface" "main" {
  name                = "nic-vm-${var.project}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }

  tags = var.tags
}

# ── Linux Virtual Machine ─────────────────────────────────────────────────────
resource "azurerm_linux_virtual_machine" "main" {
  name                = "vm-${var.project}-build"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size

  admin_username                  = var.admin_username
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  network_interface_ids = [azurerm_network_interface.main.id]

  # ── OS disk ────────────────────────────────────────────────────────────────
  os_disk {
    name                 = "osdisk-vm-${var.project}-build"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"   # cheapest — LRS for dev
    disk_size_gb         = var.os_disk_size_gb
  }

  # ── OS image: Ubuntu 22.04 LTS ────────────────────────────────────────────
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # ── System-assigned managed identity ─────────────────────────────────────
  # Allows VM to authenticate to Azure services (ACR, Key Vault) without creds
  identity {
    type = "SystemAssigned"
  }

  # ── cloud-init: install all build tools on first boot ─────────────────────
  custom_data = base64encode(local.cloud_init_script)

  tags = var.tags
}

# ── cloud-init script (runs once on first boot, ~5 minutes) ─────────────────
# Installs ONLY the tools needed for VNet-access deployment jobs:
#   Docker Engine  — build final image layer / run containers if needed
#   kubectl        — apply manifests to AKS
#   Helm           — deploy Helm charts to AKS
#   Azure CLI      — az aks get-credentials, az acr login, managed-identity auth
#
# CPU-bound CI steps (build / test / lint / scan) run on GitHub Actions
# hosted runners and do NOT need this VM.
locals {
  cloud_init_script = <<-CLOUDINIT
    #cloud-config
    package_update: true
    package_upgrade: true

    packages:
      - curl
      - wget
      - git
      - unzip
      - zip
      - jq
      - apt-transport-https
      - ca-certificates
      - gnupg
      - lsb-release
      - software-properties-common

    runcmd:
      # ── Docker Engine ───────────────────────────────────────────────────────
      - install -m 0755 -d /etc/apt/keyrings
      - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      - chmod a+r /etc/apt/keyrings/docker.gpg
      - echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | tee /etc/apt/sources.list.d/docker.list
      - apt-get update
      - apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      - systemctl enable docker
      - systemctl start docker
      - usermod -aG docker ${var.admin_username}

      # ── kubectl ─────────────────────────────────────────────────────────────
      - curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
      - install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
      - rm -f kubectl

      # ── Helm 3 ──────────────────────────────────────────────────────────────
      - curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

      # ── Azure CLI ───────────────────────────────────────────────────────────
      - curl -sL https://aka.ms/InstallAzureCLIDeb | bash

      # ── Done ────────────────────────────────────────────────────────────────
      - echo "Build VM setup complete (deployment-only runner)" > /tmp/vm-setup-done.txt
  CLOUDINIT
}
