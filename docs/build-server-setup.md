# Build Server Setup Guide — Azure VM (GitHub Actions Self-Hosted Runner)

This guide covers provisioning and configuring an Azure VM as a **deployment-only**
GitHub Actions self-hosted runner.

## Runner Strategy — Hosted vs Self-Hosted

The VM is a **Standard_D2ls_v5 (2 vCPU / 4 GB RAM)** free-trial instance.
Running SonarQube + Nexus + full CI toolchain on it exhausts memory and causes
latency. The workload is split as follows:

| Job type | Runner | Why |
|---|---|---|
| Build (.NET, Angular) | `ubuntu-latest` (hosted) | CPU-intensive; hosted runners are free and ephemeral |
| Unit tests | `ubuntu-latest` (hosted) | Same |
| Lint / format checks | `ubuntu-latest` (hosted) | Same |
| Trivy container scan | `ubuntu-latest` (hosted) | Reaches public ACR endpoint directly |
| Gitleaks secret scan | `ubuntu-latest` (hosted) | No VNet access needed |
| Checkov IaC scan | `ubuntu-latest` (hosted) | No VNet access needed |
| SonarQube analysis | `ubuntu-latest` (hosted) | Connects to SonarCloud (cloud-hosted) |
| OWASP Dependency-Check | `ubuntu-latest` (hosted) | **Scheduled pipelines only** (daily/weekly) — NVD DB does not change per-PR |
| Docker build + ACR push | `ubuntu-latest` (hosted) | ACR has a public endpoint |
| Deploy to AKS | **self-hosted** (this VM) | Needs private VNet access to AKS API server |
| Helm release | **self-hosted** (this VM) | Same |
| `az aks get-credentials` | **self-hosted** (this VM) | Uses VM managed identity |

The self-hosted runner installs **only**: Docker Engine, kubectl, Helm, Azure CLI.
All other tools are installed on-demand by hosted runner job steps.

---

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
> **Docker Engine, kubectl, Helm, and Azure CLI only**.
> First-boot provisioning takes approximately 5 minutes.
> Monitor progress: `sudo tail -f /var/log/cloud-init-output.log`
>
> Tools NOT installed on this VM (run on GitHub Actions hosted runners): .NET SDK,
> Node.js, Angular CLI, Trivy, Gitleaks, OWASP Dependency-Check, Checkov,
> SonarQube, Nexus, dotnet-sonarscanner.

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
# Cloud-init log (follow until 'Build VM setup complete (deployment-only runner)' appears)
sudo tail -f /var/log/cloud-init-output.log

# Confirm deployment tools are present
docker --version
kubectl version --client
helm version
az --version
```

If cloud-init is still in progress, wait for it to complete before proceeding.
The steps below cover any additional manual configuration needed after first boot.

> **No data disk needed.** The Terraform module provisions a 64 GB OS disk
> (Standard LRS). The disk is now ample — no SonarQube or Nexus data directories
> are written by cloud-init.

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

## 4. .NET 8 SDK — Hosted Runner Only

> **Not installed on this VM.** .NET builds, tests, and SonarScanner analysis
> run on GitHub Actions **hosted runners** (`ubuntu-latest`).

In your GitHub Actions workflow, use the standard setup action:

```yaml
- uses: actions/setup-dotnet@v4
  with:
    dotnet-version: '8.0.x'
```

---

## 5. Node.js 20 LTS — Hosted Runner Only

> **Not installed on this VM.** Angular builds, `npm install`, and lint steps
> run on GitHub Actions **hosted runners** (`ubuntu-latest`).

In your GitHub Actions workflow:

```yaml
- uses: actions/setup-node@v4
  with:
    node-version: '20'
    cache: 'npm'
    cache-dependency-path: frontend/package-lock.json
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

## 8. Trivy — Hosted Runner Only

> **Not installed on this VM.** Trivy container and filesystem scans run on
> GitHub Actions **hosted runners** using the official action:

```yaml
- uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.IMAGE_TAG }}
    format: 'sarif'
    output: 'trivy-results.sarif'
```

ACR has a public endpoint so hosted runners can scan images directly.

---

## 9. Gitleaks — Hosted Runner Only

> **Not installed on this VM.** Secret scanning runs on GitHub Actions
> **hosted runners**:

```yaml
- uses: gitleaks/gitleaks-action@v2
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## 10. OWASP Dependency-Check — Hosted Runner, Scheduled Only

> **Not installed on this VM.** Dependency-Check runs on GitHub Actions
> **hosted runners** and is pinned to **scheduled pipelines only** (see below).
> Running it on every PR is wasteful — the NVD database does not change
> minute-to-minute and the Java process blocks 2 vCPUs for 10–20 minutes.

In your GitHub Actions workflow, gate this job on a schedule:

```yaml
on:
  schedule:
    - cron: '0 2 * * 1'   # Every Monday at 02:00 UTC
  workflow_dispatch:       # Allow manual trigger

jobs:
  dependency-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dependency-check/Dependency-Check_Action@main
        with:
          project: 'ecommerce'
          path: '.'
          format: 'HTML'
          args: --nvdApiKey ${{ secrets.NVD_API_KEY }}
```

---

## 11. Checkov — Hosted Runner Only

> **Not installed on this VM.** IaC security scanning runs on GitHub Actions
> **hosted runners**:

```yaml
- uses: bridgecrewio/checkov-action@master
  with:
    directory: terraform/
    framework: terraform
```

---

## 12. SonarQube Analysis — Hosted Runner / SonarCloud

> **SonarQube server is NOT hosted on this VM.** Use **SonarCloud** (free for
> public repos, no self-hosted server required) so that GitHub-hosted runners
> can reach it directly without VNet access.
>
> 1. Create a project at [sonarcloud.io](https://sonarcloud.io)
> 2. Generate a token → save as GitHub Secret `SONAR_TOKEN`
> 3. Set `SONAR_HOST_URL` to `https://sonarcloud.io`

Remove `SONAR_HOST_URL` GitHub Secret pointing to the old VM IP and replace:

| Secret | Value |
|---|---|
| `SONAR_TOKEN` | Token from sonarcloud.io |
| `SONAR_HOST_URL` | `https://sonarcloud.io` |

---

## 13. Nexus Repository — Replaced by GitHub Packages

> **Nexus is NOT hosted on this VM.** Use **GitHub Packages** (built into your
> repository) as the artifact and Docker registry. This eliminates ~1–2 GB of
> resident memory on the VM.
>
> - npm packages → `https://npm.pkg.github.com`
> - NuGet packages → `https://nuget.pkg.github.com`
> - Docker images → `ghcr.io/<org>/<repo>`
>
> Alternatively, keep pushing Docker images directly to **Azure Container
> Registry** (ACR), which already has a public endpoint.

Remove the `NEXUS_URL`, `NEXUS_USERNAME`, `NEXUS_PASSWORD` GitHub Secrets.

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

Set up scheduled maintenance on the build server (Docker cleanup only —
Trivy and OWASP database updates now run on hosted runners via the scheduled
pipeline):

```bash
sudo crontab -e -u github-runner
```

Add these cron entries:

```cron
# Prune unused Docker images/containers weekly (Sunday 01:00)
0 1 * * 0 docker system prune -f --volumes

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

## 19. Recreating the VM with the Updated Cloud-Init Script

Because `custom_data` (cloud-init) on an Azure VM cannot be changed in-place—
it only runs once at first boot—recreating the VM is the only way to apply a
new cloud-init script.

> **Before you start:** The runner will be offline during this procedure.
> Make sure no CI jobs are running or queue them to another runner first.

### Step 1 — Deregister the old runner from GitHub

Connect via Azure Bastion (see [Step 0c](#0c-connect-to-the-vm-via-azure-bastion)),
then:

```bash
sudo su - github-runner
cd ~/actions-runner

# Remove the runner registration from GitHub
./config.sh remove --token YOUR_RUNNER_REMOVAL_TOKEN
# Get the removal token from: GitHub → Settings → Actions → Runners → (runner) → Remove

# Stop and disable the systemd service
exit   # back to azureuser
cd /home/github-runner/actions-runner
sudo ./svc.sh stop
sudo ./svc.sh uninstall github-runner
```

### Step 2 — Destroy only the VM (preserve AKS, ACR, SQL, Key Vault)

From your local machine (where Terraform is initialised):

```bash
cd terraform

# Target only the VM module resources to avoid touching AKS / SQL / ACR
terraform destroy \
  -target="module.build_vm.azurerm_linux_virtual_machine.main" \
  -target="module.build_vm.azurerm_network_interface.main" \
  -target="module.build_vm.azurerm_public_ip.vm" \
  -var-file=terraform.tfvars
```

Confirm with `yes` when prompted. This deletes only:
- The VM and its OS disk
- The NIC
- The public IP

AKS, ACR, SQL, Key Vault, and the VNet are **not touched**.

### Step 3 — Recreate the VM

```bash
# Apply only the build_vm module — Terraform regenerates the SSH key and
# runs the new slim cloud-init on first boot
terraform apply \
  -target="module.build_vm" \
  -var-file=terraform.tfvars
```

Terraform will create a new VM, NIC, and public IP and print the new private IP.

### Step 4 — Wait for cloud-init to finish

Connect via Azure Bastion to the new VM and monitor boot progress:

```bash
sudo tail -f /var/log/cloud-init-output.log
# Wait for: "Build VM setup complete (deployment-only runner)"

# Verify tools
docker --version
kubectl version --client
helm version
az --version
```

Cloud-init now takes approximately **5 minutes** (down from 10–15 minutes).

### Step 5 — Register the runner

Follow [Step 14](#14-register-github-actions-self-hosted-runner) to re-register
the runner with GitHub using a fresh token.

### Step 6 — Verify the runner is online

```bash
sudo ./svc.sh status
```

Then in GitHub: **Settings → Actions → Runners** — the runner should show
as **Idle** (green).

---

## Summary: Tool Version Reference

Tools on the **self-hosted runner VM** (installed by cloud-init):

| Tool                   | Version  | Install Method | Location                   |
|------------------------|----------|----------------|----------------------------|
| Ubuntu                 | 22.04 LTS| Terraform image| OS                         |
| Docker Engine          | latest   | cloud-init     | `/usr/bin/docker`          |
| kubectl                | stable   | cloud-init     | `/usr/local/bin/kubectl`   |
| Helm                   | 3.x      | cloud-init     | `/usr/local/bin/helm`      |
| Azure CLI              | latest   | cloud-init     | `/usr/bin/az`              |
| GitHub Actions Runner  | 2.316.x  | Manual (Step 14)| `/home/github-runner/actions-runner/` |

Tools on **GitHub Actions hosted runners** (`ubuntu-latest`):

| Tool                   | Version  | How it arrives                            |
|------------------------|----------|-------------------------------------------|
| .NET SDK               | 8.0      | `actions/setup-dotnet@v4`                 |
| dotnet-sonarscanner    | latest   | `dotnet tool install` step in workflow    |
| Node.js                | 20 LTS   | `actions/setup-node@v4`                   |
| Angular CLI            | 17       | `npm install -g @angular/cli` step        |
| Trivy                  | latest   | `aquasecurity/trivy-action`               |
| Gitleaks               | latest   | `gitleaks/gitleaks-action@v2`             |
| Checkov                | latest   | `bridgecrewio/checkov-action`             |
| OWASP Dependency-Check | 10.x     | `dependency-check/Dependency-Check_Action` (scheduled only) |
| SonarQube analysis     | latest   | `sonarsource/sonarqube-scan-action` via SonarCloud |

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
