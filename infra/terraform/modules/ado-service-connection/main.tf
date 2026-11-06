# Workload identity federation service connection (no secrets): app registration + federated credential + ADO endpoint.
terraform {
  required_providers {
    azuredevops = { source = "microsoft/azuredevops", version = "~> 1.1" }
    azuread     = { source = "hashicorp/azuread",     version = "~> 3.0" }
  }
}
variable "name"            { type = string }
variable "project_id"      { type = string }
variable "subscription_id" { type = string }
variable "subscription_name" { type = string }
variable "tenant_id"       { type = string }

resource "azuread_application" "app" { display_name = "sp-${var.name}" }
resource "azuread_service_principal" "sp" { client_id = azuread_application.app.client_id }

resource "azuredevops_serviceendpoint_azurerm" "sc" {
  project_id                             = var.project_id
  service_endpoint_name                  = var.name
  service_endpoint_authentication_scheme = "WorkloadIdentityFederation"
  azurerm_spn_tenantid                   = var.tenant_id
  azurerm_subscription_id                = var.subscription_id
  azurerm_subscription_name              = var.subscription_name
  credentials { serviceprincipalid = azuread_application.app.client_id }
}

resource "azuread_application_federated_identity_credential" "fic" {
  application_id = azuread_application.app.id
  display_name   = var.name
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = azuredevops_serviceendpoint_azurerm.sc.workload_identity_federation_issuer
  subject        = azuredevops_serviceendpoint_azurerm.sc.workload_identity_federation_subject
}

resource "azurerm_role_assignment" "contrib" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.sp.object_id
}
