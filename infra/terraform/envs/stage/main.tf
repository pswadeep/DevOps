terraform {
  required_version = ">= 1.9"
  required_providers { azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" } }
  backend "azurerm" {}
}
provider "azurerm" {
  features {}
  use_oidc = true
}
variable "env"            { type = string }
variable "location"       { type = string }
variable "aks_node_count" { type = number }
variable "aks_vm_size"    { type = string }
variable "sql_sku"        { type = string }
module "baseline" {
  source         = "../../modules/baseline"
  env            = var.env
  location       = var.location
  aks_node_count = var.aks_node_count
  aks_vm_size    = var.aks_vm_size
  sql_sku        = var.sql_sku
  tags           = { env = var.env, owner = "platform", managedBy = "terraform" }
}
