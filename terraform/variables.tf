# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# variables.tf — Root module input variables
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

variable "project" {
  type        = string
  default     = "ecommerce"
  description = "Short project name used as prefix for all resource names."
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Deployment environment (dev | staging | prod)."
}

variable "location" {
  type        = string
  default     = "centralindia"
  description = "Azure region for all resources."
}

# ── VM / AKS node SKU ─────────────────────────────────────────────────────────
# NOTE: Standard_D2ls_v5 (2 vCPU, 4 GiB RAM, no temp disk) is requested.
# If the SKU is unavailable in Central India, fall back to Standard_B2s.
variable "vm_sku" {
  type        = string
  default     = "Standard_D2ls_v5"
  description = "VM size used for both the AKS node pool and the build VM."
}

# ── SQL admin ─────────────────────────────────────────────────────────────────
variable "sql_admin_username" {
  type        = string
  default     = "sqladmin"
  description = "SQL Server administrator login name."
}

# ── AKS ───────────────────────────────────────────────────────────────────────
variable "aks_node_count" {
  type        = number
  default     = 1
  description = "Number of nodes in the AKS default node pool (free-tier: 1)."
}

variable "aks_os_disk_size_gb" {
  type        = number
  default     = 32
  description = "OS disk size for AKS nodes in GB. Minimum required is 30."
}

# ── Build VM ──────────────────────────────────────────────────────────────────
variable "vm_os_disk_size_gb" {
  type        = number
  default     = 64
  description = "OS disk size for the build VM in GB."
}

variable "vm_admin_username" {
  type        = string
  default     = "azureuser"
  description = "Admin username for the Linux build VM."
}

# ── SQL DB ────────────────────────────────────────────────────────────────────
variable "sql_db_sku" {
  type        = string
  default     = "Basic"
  description = "Azure SQL Database SKU. Basic = 5 DTUs, 2 GB — cheapest option."
}

variable "sql_db_max_size_gb" {
  type        = number
  default     = 2
  description = "Max storage size for the SQL Database in GB."
}
