// ── Azure SQL Database Module ──────────────────────────────────
param location string
param projectName string
param environment string
param adminLogin string
@secure()
param adminPassword string
param keyVaultName string

var serverName = 'sql-${projectName}-${environment}'
var dbName = 'ecommerce-${environment}'

resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: serverName
  location: location
  properties: {
    administratorLogin: adminLogin
    administratorLoginPassword: adminPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'   // Restrict via firewall rules below
  }
  tags: {
    project: projectName
    environment: environment
  }
}

// Allow Azure services (AKS outbound) to connect
resource allowAzureServices 'Microsoft.Sql/servers/firewallRules@2023-05-01-preview' = {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource sqlDb 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  parent: sqlServer
  name: dbName
  location: location
  sku: {
    name: environment == 'prod' ? 'GP_Gen5' : 'GP_S_Gen5'
    tier: environment == 'prod' ? 'GeneralPurpose' : 'GeneralPurpose'
    capacity: environment == 'prod' ? 4 : 1
    family: 'Gen5'
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: environment == 'prod' ? 107374182400 : 34359738368  // 100GB prod / 32GB dev
    zoneRedundant: environment == 'prod'
    readScale: environment == 'prod' ? 'Enabled' : 'Disabled'
    requestedBackupStorageRedundancy: environment == 'prod' ? 'Geo' : 'Local'
    autoPauseDelay: environment == 'prod' ? -1 : 60  // Auto-pause non-prod after 60 min
  }
  tags: {
    project: projectName
    environment: environment
  }
}

// Store connection string in Key Vault
resource kv 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource sqlConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kv
  name: 'SqlConnectionString'
  properties: {
    value: 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${dbName};Persist Security Info=False;User ID=${adminLogin};Password=${adminPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
    attributes: {
      enabled: true
    }
  }
}

// Transparent Data Encryption
resource tde 'Microsoft.Sql/servers/databases/transparentDataEncryption@2023-05-01-preview' = {
  parent: sqlDb
  name: 'current'
  properties: {
    state: 'Enabled'
  }
}

// Enable SQL Auditing to storage
resource auditPolicy 'Microsoft.Sql/servers/auditingSettings@2023-05-01-preview' = {
  parent: sqlServer
  name: 'default'
  properties: {
    state: 'Enabled'
    isAzureMonitorTargetEnabled: true
    retentionDays: 90
    auditActionsAndGroups: [
      'SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP'
      'FAILED_DATABASE_AUTHENTICATION_GROUP'
      'BATCH_COMPLETED_GROUP'
    ]
  }
}

output serverFqdn string = sqlServer.properties.fullyQualifiedDomainName
output databaseName string = sqlDb.name
