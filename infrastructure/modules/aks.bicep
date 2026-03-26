// ── AKS Module ────────────────────────────────────────────────
param location string
param projectName string
param environment string
param nodeCount int
param nodeVmSize string
param subnetId string
param acrId string

var clusterName = 'aks-${projectName}-${environment}'
var nodePoolName = 'system'

resource aks 'Microsoft.ContainerService/managedClusters@2024-01-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Base'
    tier: environment == 'prod' ? 'Standard' : 'Free'
  }
  properties: {
    kubernetesVersion: '1.29'
    dnsPrefix: '${projectName}-${environment}'
    enableRBAC: true

    // ── System node pool ──
    agentPoolProfiles: [
      {
        name: nodePoolName
        count: nodeCount
        vmSize: nodeVmSize
        osType: 'Linux'
        osDiskSizeGB: 128
        osDiskType: 'Managed'
        mode: 'System'
        type: 'VirtualMachineScaleSets'
        availabilityZones: ['1', '2', '3']
        enableAutoScaling: true
        minCount: 2
        maxCount: 10
        vnetSubnetID: subnetId
        upgradeSettings: {
          maxSurge: '33%'
        }
        nodeTaints: []
        nodeLabels: {
          'nodepool-type': 'system'
          environment: environment
        }
      }
    ]

    // ── Networking ──
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      loadBalancerSku: 'standard'
      serviceCidr: '10.100.0.0/16'
      dnsServiceIP: '10.100.0.10'
      outboundType: 'loadBalancer'
    }

    // ── Add-ons ──
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspace.id
        }
      }
      azurepolicy: {
        enabled: true
      }
      azureKeyVaultSecretsProvider: {
        enabled: true
        config: {
          enableSecretRotation: 'true'
          rotationPollInterval: '2m'
        }
      }
    }

    // ── Security ──
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
      imageCleaner: {
        enabled: true
        intervalHours: 48
      }
    }

    // ── Auto upgrade ──
    autoUpgradeProfile: {
      upgradeChannel: 'patch'
    }

    apiServerAccessProfile: {
      enablePrivateCluster: false  // Set to true for production zero-trust
      authorizedIPRanges: []       // Restrict to build server IPs in production
    }

    disableLocalAccounts: false
  }

  tags: {
    project: projectName
    environment: environment
  }
}

// ── Log Analytics Workspace ───────────────────────────────────
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'law-${projectName}-${environment}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// ── Grant AKS pull access to ACR ──────────────────────────────
resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aks.id, acrId, 'acrpull')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: aks.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
}

output clusterName string = aks.name
output kubeletIdentityObjectId string = aks.properties.identityProfile.kubeletidentity.objectId
output oidcIssuerUrl string = aks.properties.oidcIssuerProfile.issuerURL
