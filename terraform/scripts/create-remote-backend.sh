#!/usr/bin/env bash
# =============================================================================
# create-remote-backend.sh
#
# PURPOSE:
#   Provisions an Azure Storage Account + Blob Container to securely store
#   Terraform remote state, then patches backend.tf to activate the remote
#   backend and runs `terraform init -reconfigure` to migrate state.
#
# PREREQUISITES:
#   - Azure CLI installed and logged in  (az login)
#   - Terraform CLI installed
#   - Run from the repo root OR the terraform/ directory
#   - jq installed (optional — used for JSON parsing only if needed)
#
# USAGE:
#   chmod +x terraform/scripts/create-remote-backend.sh
#   ./terraform/scripts/create-remote-backend.sh
#
#   Override defaults with environment variables:
#   LOCATION=eastus ENVIRONMENT=prod ./terraform/scripts/create-remote-backend.sh
#
# WHAT IT DOES:
#   1.  Validates prereqs (az, terraform)
#   2.  Creates a dedicated resource group for TF state (rg-tfstate-<env>)
#   3.  Creates a Storage Account with:
#         - TLS 1.2 minimum
#         - Blob versioning enabled   (point-in-time recovery)
#         - Soft delete (7 days)      (accidental delete protection)
#         - Public blob access denied (tfstate must never be public)
#         - HTTPS-only traffic
#   4.  Creates a blob container named "tfstate"
#   5.  Locks the RG to prevent accidental deletion
#   6.  Stores the Storage Account key in a local .backend-config file
#       (gitignored — never commit this file)
#   7.  Patches terraform/backend.tf to activate the azurerm backend
#   8.  Runs terraform init -reconfigure to migrate existing local state
#   9.  Prints a summary with all relevant values
# =============================================================================

set -euo pipefail

# ── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
heading() { echo -e "\n${BOLD}━━━ $* ━━━${NC}"; }

# ── Configuration (override via environment variables) ───────────────────────
PROJECT="${PROJECT:-ecommerce}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
LOCATION="${LOCATION:-centralindia}"

# Resource group exclusively for Terraform state
STATE_RG="rg-tfstate-${ENVIRONMENT}"

# Storage account name: must be 3-24 chars, lowercase alphanumeric, globally unique
# We append a short hash of the subscription ID to ensure uniqueness
SA_NAME_BASE="st${PROJECT}tfstate${ENVIRONMENT}"
# Trim to 20 chars to leave room for the 4-char suffix
SA_NAME_BASE="${SA_NAME_BASE:0:20}"

CONTAINER_NAME="tfstate"
STATE_KEY="${PROJECT}/${ENVIRONMENT}/terraform.tfstate"

# Path to backend.tf (resolved relative to this script's location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKEND_TF="${TERRAFORM_DIR}/backend.tf"
BACKEND_CONFIG_FILE="${TERRAFORM_DIR}/.backend-config"

# ── Step 0: Prerequisites check ───────────────────────────────────────────────
heading "Step 0 — Checking prerequisites"

command -v az        &>/dev/null || error "Azure CLI (az) not found. Install from https://aka.ms/InstallAzureCLIDeb"
command -v terraform &>/dev/null || error "Terraform CLI not found. Install from https://developer.hashicorp.com/terraform/downloads"

# Verify az is logged in
SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>/dev/null) \
  || error "Not logged in to Azure. Run: az login"
TENANT_ID=$(az account show --query tenantId -o tsv)
ACCOUNT_NAME=$(az account show --query user.name -o tsv)

success "Logged in as: ${ACCOUNT_NAME}"
success "Subscription:  ${SUBSCRIPTION_ID}"
success "Tenant:        ${TENANT_ID}"

# ── Generate a unique 4-char suffix from the subscription ID ─────────────────
# Uses the first 4 hex chars of an MD5 hash — deterministic, no extra tools needed
SUFFIX=$(echo -n "${SUBSCRIPTION_ID}" | md5sum 2>/dev/null | cut -c1-4 \
         || echo -n "${SUBSCRIPTION_ID}" | md5 2>/dev/null | cut -c1-4 \
         || echo "tfst")
STORAGE_ACCOUNT_NAME="${SA_NAME_BASE}${SUFFIX}"

info "Storage account name will be: ${STORAGE_ACCOUNT_NAME}"

# ── Step 1: Create resource group for TF state ───────────────────────────────
heading "Step 1 — Resource group: ${STATE_RG}"

if az group show --name "${STATE_RG}" &>/dev/null; then
  warn "Resource group '${STATE_RG}' already exists — skipping creation"
else
  az group create \
    --name     "${STATE_RG}" \
    --location "${LOCATION}" \
    --tags     "purpose=terraform-state" "project=${PROJECT}" "environment=${ENVIRONMENT}" \
    --output none
  success "Created resource group: ${STATE_RG}"
fi

# ── Step 2: Create Storage Account ───────────────────────────────────────────
heading "Step 2 — Storage account: ${STORAGE_ACCOUNT_NAME}"

if az storage account show --name "${STORAGE_ACCOUNT_NAME}" --resource-group "${STATE_RG}" &>/dev/null; then
  warn "Storage account '${STORAGE_ACCOUNT_NAME}' already exists — skipping creation"
else
  az storage account create \
    --name                   "${STORAGE_ACCOUNT_NAME}" \
    --resource-group         "${STATE_RG}" \
    --location               "${LOCATION}" \
    --sku                    Standard_LRS \
    --kind                   StorageV2 \
    --access-tier            Hot \
    --min-tls-version        TLS1_2 \
    --https-only             true \
    --allow-blob-public-access false \
    --tags                   "purpose=terraform-state" "project=${PROJECT}" "environment=${ENVIRONMENT}" \
    --output none
  success "Created storage account: ${STORAGE_ACCOUNT_NAME}"
fi

# ── Step 3: Enable blob versioning + soft delete ──────────────────────────────
heading "Step 3 — Enabling versioning & soft delete"

az storage account blob-service-properties update \
  --account-name          "${STORAGE_ACCOUNT_NAME}" \
  --resource-group        "${STATE_RG}" \
  --enable-versioning     true \
  --enable-delete-retention true \
  --delete-retention-days 7 \
  --output none
success "Blob versioning enabled (7-day soft delete)"

# ── Step 4: Create blob container ────────────────────────────────────────────
heading "Step 4 — Blob container: ${CONTAINER_NAME}"

# Retrieve storage account key for container creation
ACCOUNT_KEY=$(az storage account keys list \
  --resource-group "${STATE_RG}" \
  --account-name   "${STORAGE_ACCOUNT_NAME}" \
  --query          "[0].value" \
  --output tsv)

if az storage container show \
     --name         "${CONTAINER_NAME}" \
     --account-name "${STORAGE_ACCOUNT_NAME}" \
     --account-key  "${ACCOUNT_KEY}" &>/dev/null; then
  warn "Container '${CONTAINER_NAME}' already exists — skipping creation"
else
  az storage container create \
    --name         "${CONTAINER_NAME}" \
    --account-name "${STORAGE_ACCOUNT_NAME}" \
    --account-key  "${ACCOUNT_KEY}" \
    --public-access off \
    --output none
  success "Created private blob container: ${CONTAINER_NAME}"
fi

# ── Step 5: Lock the RG to prevent accidental deletion ───────────────────────
heading "Step 5 — Resource group lock"

LOCK_EXISTS=$(az lock list --resource-group "${STATE_RG}" --query "[?name=='tfstate-lock'].name" -o tsv)
if [[ -n "${LOCK_EXISTS}" ]]; then
  warn "Delete lock already exists on '${STATE_RG}'"
else
  az lock create \
    --name           "tfstate-lock" \
    --resource-group "${STATE_RG}" \
    --lock-type      CanNotDelete \
    --notes          "Terraform remote state — do not delete" \
    --output none
  success "CanNotDelete lock applied to resource group"
fi

# ── Step 6: Write .backend-config (gitignored) ───────────────────────────────
heading "Step 6 — Writing .backend-config"

# Ensure .backend-config is in .gitignore
GITIGNORE_ROOT="$(cd "${TERRAFORM_DIR}/.." && pwd)/.gitignore"
if [[ -f "${GITIGNORE_ROOT}" ]]; then
  if ! grep -q "\.backend-config" "${GITIGNORE_ROOT}"; then
    echo "terraform/.backend-config" >> "${GITIGNORE_ROOT}"
    info "Added terraform/.backend-config to .gitignore"
  fi
fi

cat > "${BACKEND_CONFIG_FILE}" <<EOF
# ─────────────────────────────────────────────────────────────────────────────
# Terraform Remote Backend Configuration
# Generated by create-remote-backend.sh on $(date -u +"%Y-%m-%dT%H:%M:%SZ")
#
# This file contains the Storage Account key — NEVER commit to source control.
# It is already listed in .gitignore.
#
# Usage:
#   terraform init -backend-config=.backend-config
# ─────────────────────────────────────────────────────────────────────────────
resource_group_name  = "${STATE_RG}"
storage_account_name = "${STORAGE_ACCOUNT_NAME}"
container_name       = "${CONTAINER_NAME}"
key                  = "${STATE_KEY}"
access_key           = "${ACCOUNT_KEY}"
EOF

chmod 600 "${BACKEND_CONFIG_FILE}"
success "Wrote ${BACKEND_CONFIG_FILE} (mode 600)"

# ── Step 7: Patch backend.tf to activate the azurerm backend ─────────────────
heading "Step 7 — Activating remote backend in backend.tf"

# Check if backend is already activated (not commented out)
if grep -q '^\s*backend "azurerm"' "${BACKEND_TF}"; then
  warn "backend.tf already has an active azurerm backend block — skipping patch"
else
  # Replace the entire terraform{} block with an activated backend
  # We write the new file from scratch to avoid fragile sed multiline edits
  cat > "${BACKEND_TF}" <<EOF
# ── Remote state on Azure Blob Storage ───────────────────────────────────────
# Provisioned by terraform/scripts/create-remote-backend.sh
#
# The storage account key is stored in .backend-config (gitignored).
# Initialize with:
#   terraform init -backend-config=.backend-config
#
# To switch BACK to local state:
#   Comment out the backend block below, then: terraform init -migrate-state

terraform {
  backend "azurerm" {
    resource_group_name  = "${STATE_RG}"
    storage_account_name = "${STORAGE_ACCOUNT_NAME}"
    container_name       = "${CONTAINER_NAME}"
    key                  = "${STATE_KEY}"
    # access_key is injected at init time via -backend-config=.backend-config
    # (keeps the key out of source control)
  }
}
EOF
  success "Patched backend.tf with remote backend configuration"
fi

# ── Step 8: terraform init -reconfigure ──────────────────────────────────────
heading "Step 8 — Running terraform init -reconfigure"

cd "${TERRAFORM_DIR}"

# If a local terraform.tfstate exists, offer to migrate it
if [[ -f "terraform.tfstate" ]]; then
  warn "Found existing local terraform.tfstate"
  info "Running init with -migrate-state to copy existing state to the remote backend..."
  terraform init \
    -backend-config=".backend-config" \
    -migrate-state \
    -force-copy
else
  terraform init \
    -backend-config=".backend-config" \
    -reconfigure
fi

success "Terraform initialised with remote backend"

# ── Step 9: Verify state is in Blob Storage ───────────────────────────────────
heading "Step 9 — Verifying remote state"

# After init/apply, a tfstate blob should exist; if it's a fresh init it may not yet
BLOB_COUNT=$(az storage blob list \
  --container-name "${CONTAINER_NAME}" \
  --account-name   "${STORAGE_ACCOUNT_NAME}" \
  --account-key    "${ACCOUNT_KEY}" \
  --prefix         "${PROJECT}/${ENVIRONMENT}" \
  --query          "length(@)" \
  --output tsv 2>/dev/null || echo "0")

if [[ "${BLOB_COUNT}" -gt 0 ]]; then
  success "Found ${BLOB_COUNT} blob(s) in container — state is remote"
else
  info "No state blob yet (expected for a fresh workspace — run terraform apply to create one)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  Remote Backend Ready${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${CYAN}Resource Group    :${NC} ${STATE_RG}"
echo -e "  ${CYAN}Storage Account   :${NC} ${STORAGE_ACCOUNT_NAME}"
echo -e "  ${CYAN}Container         :${NC} ${CONTAINER_NAME}"
echo -e "  ${CYAN}State Key         :${NC} ${STATE_KEY}"
echo -e "  ${CYAN}Location          :${NC} ${LOCATION}"
echo -e "  ${CYAN}Backend Config    :${NC} ${BACKEND_CONFIG_FILE}"
echo ""
echo -e "  ${YELLOW}Next steps:${NC}"
echo -e "  1. terraform plan  -var-file=terraform.tfvars"
echo -e "  2. terraform apply -var-file=terraform.tfvars"
echo ""
echo -e "  ${YELLOW}On another machine / CI/CD runner:${NC}"
echo -e "  Retrieve the storage key from Key Vault or Azure CLI, then:"
echo -e "  terraform init -backend-config=.backend-config"
echo ""
echo -e "  ${YELLOW}GitHub Actions — add these secrets:${NC}"
echo -e "  TF_BACKEND_RESOURCE_GROUP  = ${STATE_RG}"
echo -e "  TF_BACKEND_STORAGE_ACCOUNT = ${STORAGE_ACCOUNT_NAME}"
echo -e "  TF_BACKEND_CONTAINER       = ${CONTAINER_NAME}"
echo -e "  TF_BACKEND_KEY             = ${STATE_KEY}"
echo -e "  TF_BACKEND_ACCESS_KEY      = \$(az storage account keys list ...)"
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
