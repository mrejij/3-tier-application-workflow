# Build Server Setup Guide — Azure VM (GitHub Actions Self-Hosted Runner)

This guide covers provisioning and configuring an Azure VM as a GitHub Actions
self-hosted runner and installing all required third-party build tools.

> **Infrastructure provisioned by Terraform.**
> All Azure resources — VM, VNet, AKS, ACR, SQL, Key Vault, and Azure Bastion —
> are created by the Terraform modules in `terraform/`. Follow
> [Step 0 — Terraform Deployment](#0-terraform-deployment) first, then continue
> from [Step 2 — Initial OS Setup](#2-initial-os-setup) for any manual
> configuration not covered by cloud-init.
>
> **No public IP on the VM.** SSH access is provided exclusively through
> **Azure Bastion** (browser-based SSH at portal.azure.com). There is no
> direct SSH port open to the internet.

---

## 0. Terraform Deployment

### VM Spec (provisioned by Terraform)

| Parameter       | Value                                          |
|-----------------|------------------------------------------------|
| VM Size         | `Standard_D2ls_v5` (2 vCPU, 4 GB RAM)         |
| OS Image        | Ubuntu Server 22.04 LTS Gen2                   |
| OS Disk         | Standard LRS 64 GB                             |
| Region          | Central India (`centralindia`)                 |
| Networking      | Private subnet `snet-vm` (10.0.2.0/24) — no public IP |
| SSH Access      | Azure Bastion (Basic SKU) only                 |
| Identity        | System-assigned managed identity               |

### 0a. Set up the Terraform remote backend (run once)

Before the first `terraform apply`, create the Azure Storage Account that will
hold the `.tfstate` file securely:

```bash
# From the repo root
chmod +x terraform/scripts/create-remote-backend.sh
./terraform/scripts/create-remote-backend.sh
```

The script will:
- Create resource group `rg-tfstate-dev` in Central India
- Create a Storage Account with TLS 1.2, blob versioning, and 7-day soft delete
- Create blob container `tfstate` (private, no public access)
- Apply a `CanNotDelete` lock on the resource group
- Write `terraform/.backend-config` (gitignored — contains the storage key)
- Patch `terraform/backend.tf` to activate the `azurerm` backend
- Run `terraform init -reconfigure` automatically

### 0b. Deploy all infrastructure

```bash
cd terraform

# Plan
terraform plan -var-file=terraform.tfvars -out=tfplan

# Apply (creates RG, VNet, NSGs, AKS, ACR, SQL, Key Vault, Bastion, VM)
terraform apply tfplan
```

After apply, Terraform prints all outputs — ACR login server, AKS cluster
name, VM name, SQL FQDN, Bastion name, and Key Vault URI.

> **Note:** The VM runs a `cloud-init` script on first boot that installs
> Docker, .NET 8 SDK, Node.js 20, kubectl, Helm, Azure CLI, Trivy, Gitleaks,
> OWASP Dependency-Check, Checkov, SonarQube (Docker), and Nexus (Docker).
> First-boot provisioning takes approximately 10–15 minutes.
> Monitor progress: `sudo tail -f /var/log/cloud-init-output.log`

### 0c. Connect to the VM via Azure Bastion

The VM has **no public IP**. Use Azure Bastion for browser-based SSH:

1. Open the [Azure Portal](https://portal.azure.com)
2. Navigate to the VM → **Connect → Bastion**
3. Enter username: `azureuser`
4. Retrieve the private SSH key from Key Vault:
   ```bash
   # From your local machine using Azure CLI
   az keyvault secret show \
     --vault-name $(terraform -chdir=terraform output -raw key_vault_name) \
     --name vm-ssh-private-key \
     --query value -o tsv > ~/.ssh/vm_ecommerce_key
   chmod 600 ~/.ssh/vm_ecommerce_key
   ```
5. Upload the private key in the Bastion SSH connection dialog

---

## 2. Initial OS Setup

Connect to the VM via **Azure Bastion** (see [Step 0c](#0c-connect-to-the-vm-via-azure-bastion)).
There is no public IP — direct SSH is not available.

Check whether cloud-init has finished installing tools:

```bash
# Cloud-init log (follow until 'Build VM setup complete' appears)
sudo tail -f /var/log/cloud-init-output.log

# Confirm build tools are present
docker --version
dotnet --version
node --version
kubectl version --client
trivy --version
gitleaks version
```

If cloud-init is still in progress, wait for it to complete before proceeding.
The steps below cover any additional manual configuration needed after first boot.

Run the following setup commands:

```bash
# Update OS
sudo apt-get update && sudo apt-get upgrade -y

# Install any additional packages not covered by cloud-init
sudo apt-get install -y \
  curl wget git unzip zip jq \
  apt-transport-https ca-certificates \
  gnupg lsb-release software-properties-common \
  python3 python3-pip build-essential
```

> **No data disk needed.** The Terraform module provisions a 64 GB OS disk
> (Standard LRS). SonarQube and Nexus data directories are placed under
> `/opt/sonarqube` and `/opt/nexus-data` respectively by cloud-init.

---

## 3. Docker Engine

> **Installed automatically by cloud-init.** Verify it is running:

```bash
docker --version
docker compose version
sudo systemctl status docker

# If not running, start it
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
newgrp docker
```

To configure Docker log rotation (optional — not done by cloud-init):

```bash
sudo tee /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "3"
  }
}
EOF
sudo systemctl restart docker
```

---

## 4. .NET 8 SDK

> **Installed automatically by cloud-init.** Verify:

```bash
dotnet --version   # Expected: 8.0.x

# dotnet-sonarscanner global tool (also installed by cloud-init)
export PATH="$PATH:$HOME/.dotnet/tools"
dotnet sonarscanner --version
```

If for any reason it is missing, install manually:

```bash
wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O /tmp/ms-prod.deb
sudo dpkg -i /tmp/ms-prod.deb
sudo apt-get update && sudo apt-get install -y dotnet-sdk-8.0
dotnet tool install --global dotnet-sonarscanner
echo 'export PATH="$PATH:$HOME/.dotnet/tools"' >> ~/.bashrc
source ~/.bashrc
```

---

## 5. Node.js 20 LTS

> **Installed automatically by cloud-init**, including `@angular/cli` and `sonar-scanner`. Verify:

```bash
node --version   # Expected: v20.x.x
npm --version
ng version
```

If missing, install manually:

```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
npm install -g @angular/cli sonar-scanner
```

---

## 6. kubectl & Helm

> **Installed automatically by cloud-init.** Verify:

```bash
kubectl version --client
helm version
```

### Configure kubectl to talk to AKS

After Terraform apply, fetch the AKS kubeconfig (do this once per machine):

```bash
# Option A — via Azure CLI
az aks get-credentials \
  --resource-group rg-ecommerce-dev \
  --name aks-ecommerce-dev \
  --overwrite-existing

# Option B — retrieve from Key Vault (where terraform stored it)
az keyvault secret show \
  --vault-name <KEY_VAULT_NAME> \
  --name aks-kubeconfig \
  --query value -o tsv > ~/.kube/config
chmod 600 ~/.kube/config

# Verify cluster access
kubectl get nodes
kubectl get namespaces
```

---

## 7. Azure CLI

> **Installed automatically by cloud-init.** Verify:

```bash
az --version
```

### Authenticate the VM to Azure

The VM has a **system-assigned managed identity** — no service principal secrets
needed for operations performed on the VM itself:

```bash
# Log in via managed identity (works inside the VM)
az login --identity

# Verify the identity can see the subscription
az account show
```

For GitHub Actions workflows running on the VM as a self-hosted runner,
use the **service principal** created in [Step 16](#16-azure-service-principal-for-aks-deployment).

---

## 8. Trivy (Container & Filesystem Scanner)

> **Installed automatically by cloud-init.** Verify:

```bash
trivy --version

# Pre-populate the vulnerability database (saves time in CI)
trivy image --download-db-only
```

If missing, install manually:

```bash
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | \
  gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | \
  sudo tee /etc/apt/sources.list.d/trivy.list
sudo apt-get update && sudo apt-get install -y trivy
```

---

## 9. Gitleaks (Secret Scanner)

> **Installed automatically by cloud-init** (v8.18.4). Verify:

```bash
gitleaks version
```

If missing, install manually:

```bash
GITLEAKS_VERSION="8.18.4"
curl -sSfL \
  "https://github.com/zricethezav/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" \
  -o /tmp/gitleaks.tar.gz
tar -xzf /tmp/gitleaks.tar.gz -C /tmp gitleaks
sudo mv /tmp/gitleaks /usr/local/bin/ && sudo chmod +x /usr/local/bin/gitleaks
```

---

## 10. OWASP Dependency-Check

> **Installed automatically by cloud-init** (v10.0.3 at `/opt/dependency-check`). Verify:

```bash
source /etc/profile.d/depcheck.sh
dependency-check.sh --version
```

Pre-populate the NVD database (takes ~30 minutes, requires an API key):

```bash
# Get a free API key from https://nvd.nist.gov/developers/request-an-api-key
dependency-check.sh --updateonly --nvdApiKey YOUR_NVD_API_KEY
```

If missing, install manually:

```bash
DEPCHECK_VERSION="10.0.3"
sudo mkdir -p /opt/dependency-check
curl -sSfL \
  "https://github.com/jeremylong/DependencyCheck/releases/download/v${DEPCHECK_VERSION}/dependency-check-${DEPCHECK_VERSION}-release.zip" \
  -o /tmp/dependency-check.zip
sudo unzip -q /tmp/dependency-check.zip -d /opt/
sudo chmod +x /opt/dependency-check/bin/dependency-check.sh
echo 'export PATH="$PATH:/opt/dependency-check/bin"' | sudo tee /etc/profile.d/depcheck.sh
source /etc/profile.d/depcheck.sh
```

---

## 11. Checkov (IaC Security Scanner)

> **Installed automatically by cloud-init** via `pip3 install checkov`. Verify:

```bash
checkov --version
```

If missing: `pip3 install checkov`

---

## 12. SonarQube (Server — Docker)

> **Started automatically by cloud-init** as a Docker container. Verify:

```bash
docker ps --filter name=sonarqube
docker logs sonarqube --tail 30
```

SonarQube is available at `http://<VM_PRIVATE_IP>:9000` (accessible within the VNet).
Default credentials: `admin` / `admin` — **change immediately**.

Data is persisted to `/opt/sonarqube/` on the VM OS disk.

If the container is not running, start it manually:

```bash
sudo mkdir -p /opt/sonarqube/{data,logs,extensions}
sudo chown -R 1000:1000 /opt/sonarqube
echo 'vm.max_map_count=524288' | sudo tee -a /etc/sysctl.conf
sudo sysctl -w vm.max_map_count=524288

docker run -d \
  --name sonarqube \
  --restart unless-stopped \
  -p 9000:9000 \
  -v /opt/sonarqube/data:/opt/sonarqube/data \
  -v /opt/sonarqube/logs:/opt/sonarqube/logs \
  -v /opt/sonarqube/extensions:/opt/sonarqube/extensions \
  sonarqube:10-community
```

> **Accessing SonarQube UI from your local machine:**
> Use Azure Bastion SSH tunnel, or set up an SSH port-forward via your
> local machine if you have a tunnel to the VM's private IP.

### Post-Install SonarQube Configuration

```bash
# Wait for SonarQube to start (check logs)
docker logs -f sonarqube
```

Once running, configure via the UI at `http://<VM_PRIVATE_IP>:9000`:

1. **Change admin password** (required on first login)
2. **Create projects:**
   - Project key: `ecommerce-frontend`
   - Project key: `ecommerce-backend`
3. **Generate a token:**
   Administration → Security → Users → admin → Tokens → Generate
   Save as GitHub Secret: `SONAR_TOKEN`
4. **Quality Gate:** Sonar Way (default)

> **NSG note:** Port 9000 is already allowed within the VNet (`snet-vm` 10.0.2.0/24)
> by the Terraform NSG rule `AllowVnetInbound`. No manual NSG rule is needed.

---

## 13. Nexus Repository Manager (Docker)

> **Started automatically by cloud-init** as a Docker container. Verify:

```bash
docker ps --filter name=nexus
docker logs nexus --tail 30   # startup takes 2-3 minutes
```

Nexus is available at `http://<VM_PRIVATE_IP>:8081`.

```bash
# Retrieve the one-time initial admin password
docker exec nexus cat /nexus-data/admin.password && echo
```

If the container is not running, start it manually:

```bash
sudo mkdir -p /opt/nexus-data
sudo chown -R 200:200 /opt/nexus-data

docker run -d \
  --name nexus \
  --restart unless-stopped \
  -p 8081:8081 \
  -v /opt/nexus-data:/nexus-data \
  sonatype/nexus3:latest
```

> **NSG note:** Port 8081 is already allowed within the VNet by the Terraform
> NSG rule `AllowVnetInbound` (ports 8080/8081/9000). No manual NSG rule is needed.

### Nexus Repository Configuration

After logging in to `http://<VM_IP>:8081`:

1. **Change admin password** (prompted on first login)
2. **Disable anonymous access** (Security > Anonymous Access > uncheck)
3. **Create repositories:**

```
Repository Type     | Name                       | Format
--------------------|----------------------------|------------
hosted (release)    | ecommerce-releases         | raw
hosted (release)    | ecommerce-docker           | docker
hosted (release)    | ecommerce-npm-hosted       | npm
proxy               | ecommerce-npm-proxy        | npm (proxy → registry.npmjs.org)
proxy               | ecommerce-nuget-proxy      | nuget (proxy → api.nuget.org)
group               | ecommerce-npm-group        | npm (members: hosted + proxy)
```

4. **Create a CI user:**
   - Security → Users → Create user
   - Username: `ci-publisher`, password: strong secret
   - Roles: `nx-repository-view-*-*-*`
   - Save as GitHub Secrets: `NEXUS_USERNAME` / `NEXUS_PASSWORD`

5. Port 8081 is already open within the VNet via the Terraform-managed NSG — no additional rule needed.

---

## 14. Register GitHub Actions Self-Hosted Runner

```bash
# Create a dedicated runner user
sudo useradd -m -s /bin/bash github-runner
sudo usermod -aG docker github-runner

# Switch to runner user
sudo su - github-runner

# Download the latest runner package
# Get the latest version from https://github.com/actions/runner/releases
RUNNER_VERSION="2.316.1"
mkdir actions-runner && cd actions-runner
curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -L \
  "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
tar xzf actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# Configure the runner
# Go to GitHub: Settings → Actions → Runners → New self-hosted runner
# Copy the token shown there
./config.sh \
  --url https://github.com/YOUR_ORG/YOUR_REPO \
  --token YOUR_RUNNER_TOKEN \
  --name "azure-build-server" \
  --labels "self-hosted,linux,x64,azure,build-server" \
  --work "/opt/runner-work" \
  --unattended

# Exit back to azureuser
exit

# Install runner as a systemd service
cd /home/github-runner/actions-runner
sudo ./svc.sh install github-runner
sudo ./svc.sh start

# Verify runner is online
sudo ./svc.sh status
```

---

## 15. Configure GitHub Secrets

Go to your repository → **Settings → Secrets and variables → Actions → New repository secret**

| Secret Name               | Value / Where to Get                               |
|---------------------------|----------------------------------------------------|
| `ACR_LOGIN_SERVER`        | `terraform output -raw acr_login_server`           |
| `ACR_USERNAME`            | ACR admin username (Key Vault secret `acr-admin-username`) |
| `ACR_PASSWORD`            | ACR admin password (Key Vault secret `acr-admin-password`) |
| `AKS_RESOURCE_GROUP`      | `terraform output -raw resource_group_name`        |
| `AKS_CLUSTER_NAME`        | `terraform output -raw aks_cluster_name`           |
| `AZURE_CLIENT_ID`         | Service Principal App ID                           |
| `AZURE_CLIENT_SECRET`     | Service Principal secret                           |
| `AZURE_TENANT_ID`         | Azure AD Tenant ID                                 |
| `AZURE_SUBSCRIPTION_ID`   | Azure Subscription ID                              |
| `SONAR_TOKEN`             | Token generated in SonarQube admin                 |
| `SONAR_HOST_URL`          | `http://$(terraform output -raw vm_private_ip):9000` |
| `NEXUS_URL`               | `http://$(terraform output -raw vm_private_ip):8081` |
| `NEXUS_USERNAME`          | `ci-publisher`                                     |
| `NEXUS_PASSWORD`          | ci-publisher user's password                       |
| `SQL_CONNECTION_STRING`   | Azure SQL connection string (from Key Vault)       |
| `JWT_SECRET_KEY`          | Min 32-char random string                          |
| `SLACK_WEBHOOK_URL`       | Slack Incoming Webhook URL                         |
| `NVD_API_KEY`             | From https://nvd.nist.gov/developers               |

---

## 16. Azure Service Principal for AKS Deployment

```bash
# Create a service principal with contributor rights scoped to the resource group
az ad sp create-for-rbac \
  --name "sp-ecommerce-cicd" \
  --role Contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/YOUR_AKS_RG \
  --sdk-auth

# The JSON output — save each field as the corresponding GitHub Secret:
# clientId       → AZURE_CLIENT_ID
# clientSecret   → AZURE_CLIENT_SECRET
# tenantId       → AZURE_TENANT_ID
# subscriptionId → AZURE_SUBSCRIPTION_ID

# Grant AcrPush role to allow pushing images
ACR_RESOURCE_ID=$(az acr show --name YOUR_ACR_NAME --resource-group YOUR_RG --query id -o tsv)
az role assignment create \
  --assignee YOUR_SP_CLIENT_ID \
  --role AcrPush \
  --scope $ACR_RESOURCE_ID
```

---

## 17. Automated Maintenance (Cron Jobs)

Set up scheduled maintenance on the build server:

```bash
sudo crontab -e -u github-runner
```

Add these cron entries:

```cron
# Prune unused Docker images/containers weekly (Sunday 01:00)
0 1 * * 0 docker system prune -f --volumes

# Update Trivy DB daily (03:00)
0 3 * * * trivy image --download-db-only

# Update OWASP Dependency-Check NVD database daily (04:00)
0 4 * * * /opt/dependency-check/bin/dependency-check.sh --updateonly --nvdApiKey YOUR_NVD_API_KEY

# Rotate runner work directory (keep last 48h)
0 5 * * * find /opt/runner-work -maxdepth 1 -mtime +2 -exec rm -rf {} +
```

---

## 18. Security Hardening for the Build VM

> **SSH key-only auth and no public IP are already enforced by Terraform.**
> `disable_password_authentication = true` is set in the VM resource, and
> the VM has no public IP (Azure Bastion is the only access method).
> UFW and fail2ban are not required when there is no publicly reachable SSH port.

Additional hardening steps to run after connecting via Bastion:

```bash
# Confirm password auth is disabled
grep PasswordAuthentication /etc/ssh/sshd_config
# Expected: PasswordAuthentication no

# Enable automatic security updates
sudo apt-get install -y unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades

# Optional: Enable Azure Monitor Agent for VM insights
az vm extension set \
  --resource-group rg-ecommerce-dev \
  --vm-name vm-ecommerce-build \
  --name AzureMonitorLinuxAgent \
  --publisher Microsoft.Azure.Monitor \
  --version 1.0 \
  --enable-auto-upgrade true

# Enable Microsoft Defender for Servers (via Azure Portal or CLI)
# Portal: Defender for Cloud → Environment Settings → Subscription → Servers → On
```

---

## Summary: Tool Version Reference

All tools marked **cloud-init** are installed automatically on first VM boot
by the `custom_data` script in `terraform/modules/build_vm/main.tf`.

| Tool                     | Version   | Install Method  | Location                             |
|--------------------------|-----------|-----------------|--------------------------------------|
| Ubuntu                   | 22.04 LTS | Terraform image | OS                                   |
| Docker Engine            | latest    | cloud-init      | `/usr/bin/docker`                    |
| .NET SDK                 | 8.0       | cloud-init      | `/usr/bin/dotnet`                    |
| dotnet-sonarscanner      | latest    | cloud-init      | `~/.dotnet/tools/`                   |
| Node.js                  | 20 LTS    | cloud-init      | `/usr/bin/node`                      |
| Angular CLI              | 17        | cloud-init      | npm global                           |
| kubectl                  | stable    | cloud-init      | `/usr/local/bin/kubectl`             |
| Helm                     | 3.x       | cloud-init      | `/usr/local/bin/helm`                |
| Azure CLI                | latest    | cloud-init      | `/usr/bin/az`                        |
| Trivy                    | latest    | cloud-init      | `/usr/bin/trivy`                     |
| Gitleaks                 | 8.18.4    | cloud-init      | `/usr/local/bin/gitleaks`            |
| OWASP Dependency-Check   | 10.0.3    | cloud-init      | `/opt/dependency-check/`             |
| Checkov                  | latest    | cloud-init      | `/usr/local/bin/checkov`             |
| SonarQube (server)       | 10.x      | cloud-init      | Docker container, port 9000          |
| Nexus Repository         | latest    | cloud-init      | Docker container, port 8081          |
| GitHub Actions Runner    | 2.316.x   | Manual (Step 14)| `/home/github-runner/actions-runner/`|

---

## Terraform Infrastructure Reference

| Resource              | Name Pattern                     | SKU / Tier          |
|-----------------------|----------------------------------|---------------------|
| Resource Group        | `rg-ecommerce-dev`               | —                   |
| TF State RG           | `rg-tfstate-dev`                 | —                   |
| VNet                  | `vnet-ecommerce-dev`             | 10.0.0.0/16         |
| AKS Subnet            | `snet-aks` 10.0.1.0/24           | —                   |
| VM Subnet             | `snet-vm` 10.0.2.0/24            | —                   |
| Bastion Subnet        | `AzureBastionSubnet` 10.0.3.0/27 | —                   |
| SQL Subnet            | `snet-sql` 10.0.4.0/24           | —                   |
| Build VM              | `vm-ecommerce-build`             | Standard_D2ls_v5    |
| AKS Cluster           | `aks-ecommerce-dev`              | Free tier, 1 node   |
| Container Registry    | `acrecommercedev{suffix}`        | Basic SKU           |
| SQL Server            | `sql-ecommerce-dev-{suffix}`     | v12.0               |
| SQL Database          | `sqldb-ecommerce-dev`            | Basic (5 DTU, 2 GB) |
| Key Vault             | `kv-ecommerce-{suffix}`          | Standard            |
| Azure Bastion         | `bastion-ecommerce-dev`          | Basic SKU           |
| TF State Storage      | `st{project}tfstate{env}{hash}`  | Standard LRS        |
