# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# modules/build_vm/main.tf
#
# Creates:
#   - Public IP (Standard Static) — for SSH, SonarQube UI, Nexus UI access
#   - NIC (private + public IP)
#   - Linux VM (Ubuntu 22.04 LTS, Standard_D2ls_v5)
#   - SSH key authentication (public key passed in; private key in Key Vault)
#   - System-assigned managed identity → grants access to ACR and Key Vault
#   - cloud-init script to install all build tools on first boot
#
# SECURITY NOTE: Ports 22, 8081, 9000 are open to the internet (0.0.0.0/0).
#   To restrict access to your IP only, set the NSG rules in networking/main.tf
#   source_address_prefix to "YOUR_IP/32".
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

# ── cloud-init script (runs once on first boot, ~10-15 minutes) ──────────────
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
      - python3
      - python3-pip
      - apt-transport-https
      - ca-certificates
      - gnupg
      - lsb-release
      - software-properties-common
      - build-essential

    runcmd:
      # ── Docker ──────────────────────────────────────────────────────────────
      - install -m 0755 -d /etc/apt/keyrings
      - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      - chmod a+r /etc/apt/keyrings/docker.gpg
      - echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | tee /etc/apt/sources.list.d/docker.list
      - apt-get update
      - apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      - systemctl enable docker
      - systemctl start docker
      - usermod -aG docker ${var.admin_username}

      # ── .NET 8 SDK ──────────────────────────────────────────────────────────
      - wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O /tmp/ms-prod.deb
      - dpkg -i /tmp/ms-prod.deb
      - apt-get update
      - apt-get install -y dotnet-sdk-8.0

      # ── Node.js 20 LTS ──────────────────────────────────────────────────────
      - curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
      - apt-get install -y nodejs
      - npm install -g @angular/cli sonar-scanner

      # ── kubectl ─────────────────────────────────────────────────────────────
      - curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
      - install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

      # ── Helm 3 ──────────────────────────────────────────────────────────────
      - curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

      # ── Azure CLI ───────────────────────────────────────────────────────────
      - curl -sL https://aka.ms/InstallAzureCLIDeb | bash

      # ── Trivy ───────────────────────────────────────────────────────────────
      - wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | tee /usr/share/keyrings/trivy.gpg > /dev/null
      - echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | tee /etc/apt/sources.list.d/trivy.list
      - apt-get update
      - apt-get install -y trivy

      # ── Gitleaks ────────────────────────────────────────────────────────────
      - curl -sSfL https://github.com/zricethezav/gitleaks/releases/download/v8.18.4/gitleaks_8.18.4_linux_x64.tar.gz -o /tmp/gitleaks.tar.gz
      - tar -xzf /tmp/gitleaks.tar.gz -C /tmp gitleaks
      - mv /tmp/gitleaks /usr/local/bin/gitleaks
      - chmod +x /usr/local/bin/gitleaks

      # ── OWASP Dependency-Check ───────────────────────────────────────────────
      - mkdir -p /opt/dependency-check
      - curl -sSfL https://github.com/jeremylong/DependencyCheck/releases/download/v10.0.3/dependency-check-10.0.3-release.zip -o /tmp/depcheck.zip
      - unzip -q /tmp/depcheck.zip -d /opt/
      - chmod +x /opt/dependency-check/bin/dependency-check.sh
      - echo 'export PATH="$PATH:/opt/dependency-check/bin"' >> /etc/profile.d/depcheck.sh

      # ── Checkov ─────────────────────────────────────────────────────────────
      - pip3 install checkov

      # ── SonarQube (Docker) ───────────────────────────────────────────────────
      - echo "vm.max_map_count=524288" >> /etc/sysctl.conf
      - sysctl -w vm.max_map_count=524288
      - mkdir -p /opt/sonarqube/{data,logs,extensions}
      - chown -R 1000:1000 /opt/sonarqube
      - docker run -d --name sonarqube --restart unless-stopped -p 9000:9000 -v /opt/sonarqube/data:/opt/sonarqube/data -v /opt/sonarqube/logs:/opt/sonarqube/logs -v /opt/sonarqube/extensions:/opt/sonarqube/extensions sonarqube:10-community

      # ── Nexus Repository Manager (Docker) ───────────────────────────────────
      - mkdir -p /opt/nexus-data
      - chown -R 200:200 /opt/nexus-data
      - docker run -d --name nexus --restart unless-stopped -p 8081:8081 -v /opt/nexus-data:/nexus-data sonatype/nexus3:latest

      # ── dotnet SonarScanner global tool ─────────────────────────────────────
      - dotnet tool install --global dotnet-sonarscanner
      - echo 'export PATH="$PATH:/root/.dotnet/tools"' >> /etc/profile.d/dotnet-tools.sh

      # ── Done ────────────────────────────────────────────────────────────────
      - echo "Build VM setup complete" > /tmp/vm-setup-done.txt
  CLOUDINIT
}
