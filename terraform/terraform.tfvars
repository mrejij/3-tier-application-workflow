# ── Free-tier minimal configuration ──────────────────────────────────────────
# Edit these values to match your environment.
# Run: terraform init && terraform plan -var-file=terraform.tfvars

project     = "ecommerce"
environment = "dev"
location    = "centralindia"

# AKS node + build VM SKU
# NOTE: If Standard_D2ls_v5 is not available in centralindia, change to:
#   vm_sku = "Standard_B2s"
vm_sku = "Standard_D2ls_v5"

# AKS: 1 node (free-tier constraint)
aks_node_count      = 1
aks_os_disk_size_gb = 32

# Build VM
vm_admin_username = "azureuser"
vm_os_disk_size_gb = 64

# SQL — Basic tier: 5 DTUs, 2 GB storage (~$5/month)
sql_admin_username = "sqladmin"
sql_db_sku         = "Basic"
sql_db_max_size_gb = 2
