variable "env"       { type = string }
variable "location"  { type = string }
variable "tags"      { type = map(string) }
variable "aks_node_count" { type = number }
variable "aks_vm_size"    { type = string }
variable "sql_sku"        { type = string }

resource "azurerm_resource_group" "rg" {
  name     = "rg-acme-${var.env}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-acme-${var.env}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = var.env == "prod" ? 90 : 30
}

resource "azurerm_key_vault" "kv" {
  name                       = "kv-acme-${var.env}-001"
  location                   = var.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.cur.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true
  purge_protection_enabled   = true
  soft_delete_retention_days = 90
}
data "azurerm_client_config" "cur" {}

resource "azurerm_storage_account" "sa" {
  name                            = "stacme${var.env}001"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = var.env == "prod" ? "GZRS" : "LRS"
  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"
  static_website { index_document = "index.html" }
}

resource "azurerm_service_plan" "plan" {
  name                = "plan-${var.env}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = var.env == "prod" ? "P1v3" : "B1"
}

resource "azurerm_linux_web_app" "api" {
  name                = "app-acme-orders-${var.env}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan.id
  https_only          = true
  identity { type = "SystemAssigned" }
  site_config { always_on = var.env == "prod" }
}

resource "azurerm_role_assignment" "app_kv" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.api.identity[0].principal_id
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-acme-${var.env}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "acme-${var.env}"
  oidc_issuer_enabled       = true
  workload_identity_enabled = true
  azure_active_directory_role_based_access_control { azure_rbac_enabled = true }
  default_node_pool {
    name       = "system"
    node_count = var.aks_node_count
    vm_size    = var.aks_vm_size
  }
  identity { type = "SystemAssigned" }
  oms_agent { log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id }
  key_vault_secrets_provider { secret_rotation_enabled = true }
}

resource "azurerm_mssql_server" "sql" {
  name                         = "sql-acme-${var.env}"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = var.location
  version                      = "12.0"
  minimum_tls_version          = "1.2"
  azuread_administrator {
    login_username              = "sql-admins"
    object_id                   = data.azurerm_client_config.cur.object_id
    azuread_authentication_only = true
  }
}
resource "azurerm_mssql_database" "db" {
  name      = "ordersdb"
  server_id = azurerm_mssql_server.sql.id
  sku_name  = var.sql_sku
}

output "resource_group" { value = azurerm_resource_group.rg.name }
output "key_vault"      { value = azurerm_key_vault.kv.name }
output "aks_name"       { value = azurerm_kubernetes_cluster.aks.name }
