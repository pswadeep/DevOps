param env string
param location string = resourceGroup().location
param sbSku string = 'Standard'

resource sb 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: 'sb-acme-${env}'
  location: location
  sku: { name: sbSku, tier: sbSku }
  properties: { disableLocalAuth: true, minimumTlsVersion: '1.2', zoneRedundant: sbSku == 'Premium' }
}
resource queue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: sb
  name: 'orders'
  properties: { maxDeliveryCount: 10, deadLetteringOnMessageExpiration: true, lockDuration: 'PT1M' }
}
resource topic 'Microsoft.ServiceBus/namespaces/topics@2022-10-01-preview' = { parent: sb, name: 'order-events' }
resource sub 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: topic
  name: 'billing'
  properties: { maxDeliveryCount: 10 }
}
resource eh 'Microsoft.EventHub/namespaces@2024-01-01' = {
  name: 'eh-acme-${env}'
  location: location
  sku: { name: 'Standard', tier: 'Standard', capacity: 1 }
  properties: { disableLocalAuth: true }
}
resource hub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' = {
  parent: eh
  name: 'telemetry'
  properties: { partitionCount: env == 'prod' ? 8 : 2, messageRetentionInDays: env == 'prod' ? 7 : 1 }
}
resource cg 'Microsoft.EventHub/namespaces/eventhubs/consumergroups@2024-01-01' = { parent: hub, name: 'analytics' }
