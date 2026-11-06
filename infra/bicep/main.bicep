targetScope = 'subscription'
param env string
param location string = 'westeurope'
param tags object = { env: env, managedBy: 'bicep' }

resource rgApp 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'rg-acme-${env}'
  location: location
  tags: tags
}
resource rgNet 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'rg-acme-net-${env}'
  location: location
  tags: tags
}
output appRg string = rgApp.name
