param location string = resourceGroup().location
param environment string = 'dev'
param sqlAdminLogin string
@secure()
param sqlAdminPassword string

var suffix = uniqueString(resourceGroup().id)

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'onboard${environment}${suffix}'
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    isHnsEnabled: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
  }
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  name: '${storage.name}/default/data'
  properties: {
    publicAccess: 'None'
  }
}

resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: 'onboard-sql-${environment}-${suffix}'
  location: location
  properties: {
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    publicNetworkAccess: 'Enabled'
  }
}

resource sqlDb 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  name: '${sqlServer.name}/onboarding'
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'onboard-kv-${environment}-${suffix}'
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: { family: 'A', name: 'standard' }
    enableRbacAuthorization: true
    publicNetworkAccess: 'Enabled'
  }
}

resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: 'onboard-adf-${environment}-${suffix}'
  location: location
  identity: { type: 'SystemAssigned' }
}

output storageAccountName string = storage.name
output sqlServerName string = sqlServer.name
output sqlDatabaseName string = sqlDb.name
output keyVaultName string = keyVault.name
output dataFactoryName string = dataFactory.name
