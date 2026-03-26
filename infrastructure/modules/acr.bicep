// ── Azure Container Registry Module ──────────────────────────
param location string
param projectName string
param environment string

var acrName = replace('acr${projectName}${environment}', '-', '')

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: environment == 'prod' ? 'Premium' : 'Standard'
  }
  properties: {
    adminUserEnabled: false           // Use managed identity, not admin creds
    anonymousPullEnabled: false
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
    policies: {
      retentionPolicy: {
        status: 'enabled'
        days: 30
      }
      quarantinePolicy: {
        status: 'enabled'
      }
      trustPolicy: {
        status: 'disabled'
        type: 'Notary'
      }
    }
    encryption: {
      status: 'disabled'
    }
  }
  tags: {
    project: projectName
    environment: environment
  }
}

output acrId string = acr.id
output loginServer string = acr.properties.loginServer
output acrName string = acr.name
