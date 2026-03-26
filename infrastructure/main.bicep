// ================================================================
// Main Bicep Entrypoint — ShopMart E-Commerce Infrastructure
// Provisions: VNet, AKS, ACR, Azure SQL, Key Vault, App Insights
// ================================================================
targetScope = 'subscription'

@description('Azure region for all resources')
param location string = 'eastus'

@description('Environment: dev, staging, prod')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'prod'

@description('Project name prefix (lower-case, no spaces)')
param projectName string = 'shopmart'

@description('Azure SQL administrator login')
param sqlAdminLogin string

@description('Azure SQL administrator password')
@secure()
param sqlAdminPassword string

@description('AKS node count per zone')
param aksNodeCount int = 2

@description('AKS node VM size')
param aksNodeVmSize string = 'Standard_D4s_v5'

// ── Resource Group ────────────────────────────────────────────
resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'rg-${projectName}-${environment}'
  location: location
  tags: {
    project: projectName
    environment: environment
    managedBy: 'bicep'
  }
}

// ── Networking ────────────────────────────────────────────────
module networking 'modules/networking.bicep' = {
  name: 'networking'
  scope: rg
  params: {
    location: location
    projectName: projectName
    environment: environment
  }
}

// ── Container Registry ────────────────────────────────────────
module acr 'modules/acr.bicep' = {
  name: 'acr'
  scope: rg
  params: {
    location: location
    projectName: projectName
    environment: environment
  }
}

// ── Key Vault ─────────────────────────────────────────────────
module keyVault 'modules/keyvault.bicep' = {
  name: 'keyvault'
  scope: rg
  params: {
    location: location
    projectName: projectName
    environment: environment
  }
}

// ── Azure SQL ─────────────────────────────────────────────────
module sql 'modules/sql.bicep' = {
  name: 'sql'
  scope: rg
  params: {
    location: location
    projectName: projectName
    environment: environment
    adminLogin: sqlAdminLogin
    adminPassword: sqlAdminPassword
    keyVaultName: keyVault.outputs.keyVaultName
  }
}

// ── AKS ───────────────────────────────────────────────────────
module aks 'modules/aks.bicep' = {
  name: 'aks'
  scope: rg
  params: {
    location: location
    projectName: projectName
    environment: environment
    nodeCount: aksNodeCount
    nodeVmSize: aksNodeVmSize
    subnetId: networking.outputs.aksSubnetId
    acrId: acr.outputs.acrId
  }
}

// ── Application Insights ──────────────────────────────────────
module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    projectName: projectName
    environment: environment
    keyVaultName: keyVault.outputs.keyVaultName
  }
}

// ── Outputs ───────────────────────────────────────────────────
output resourceGroupName string = rg.name
output acrLoginServer string = acr.outputs.loginServer
output aksClusterName string = aks.outputs.clusterName
output keyVaultUri string = keyVault.outputs.keyVaultUri
output sqlServerFqdn string = sql.outputs.serverFqdn
