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
    resource_group_name  = "rg-tfstate-dev"
    storage_account_name = "stecommercetfstatedebb82"
    container_name       = "tfstate"
    key                  = "ecommerce/dev/terraform.tfstate"
    # access_key is injected at init time via -backend-config=.backend-config
    # (keeps the key out of source control)
  }
}
