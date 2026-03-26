# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# modules/aks/main.tf
#
# Creates:
#   - AKS cluster (Free tier control plane)
#   - Single node pool: 1 × Standard_D2ls_v5
#   - System-assigned managed identity
#   - AcrPull role assignment → allows pulling images from ACR
#   - kubenet networking (lighter weight than Azure CNI, suitable for dev)
#
# COST NOTE: AKS Free tier = no charge for control plane.
#            Compute: ~$0.09/hour per Standard_D2ls_v5 node ≈ $65/month.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-${var.project}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  dns_prefix          = "${var.project}-${var.environment}"

  # Free tier: control plane is free (no SLA)
  sku_tier = "Free"

  # Kubernetes version: use stable default (Azure-managed)
  kubernetes_version = null   # null = use latest stable
  # automatic_channel_upgrade omitted — omitting disables auto-upgrade

  # ── Default node pool: 1 node, minimal specs ─────────────────────────────
  default_node_pool {
    name            = "system"
    node_count      = var.node_count
    vm_size         = var.node_vm_size
    os_disk_size_gb = var.os_disk_size_gb
    os_disk_type    = "Managed"
    vnet_subnet_id  = var.subnet_id

    # Enable auto-scaling off (free tier — manual control)
    enable_auto_scaling = false

    tags = var.tags
  }

  # ── Managed identity ──────────────────────────────────────────────────────
  identity {
    type = "SystemAssigned"
  }

  # ── Networking: kubenet keeps it simple and cost-effective ────────────────
  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
    pod_cidr          = "192.168.0.0/16"   # must not overlap VNet (10.0.0.0/16)
    service_cidr      = "172.16.0.0/16"    # must not overlap VNet or pod CIDR
    dns_service_ip    = "172.16.0.10"
  }

  # ── RBAC ───────────────────────────────────────────────────────────────────
  role_based_access_control_enabled = true
  local_account_disabled            = false

  # ── Disable unused add-ons to save costs ──────────────────────────────────
  # (HTTP Application Routing is deprecated; use ingress-nginx via Helm instead)

  tags = var.tags
}

# ── Grant AKS kubelet identity AcrPull on the ACR ────────────────────────────
# This allows AKS node to pull container images from ACR without credentials.
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = var.acr_id
  skip_service_principal_aad_check = true
}
