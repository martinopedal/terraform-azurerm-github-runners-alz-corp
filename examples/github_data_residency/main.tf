locals {
  tags = {
    scenario = "github_data_residency"
  }
}

terraform {
  required_version = ">= 1.9"

  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.20"
    }
  }
}

provider "azurerm" {
  features {}
}

# This is the module call - configured for GHEC with data residency and BYO VNet/DNS
module "github_runners" {
  source = "../.."

  location = var.location
  postfix  = var.postfix

  # GitHub data residency configuration
  version_control_system_type                               = "github"
  version_control_system_github_url                         = var.github_url
  version_control_system_organization                       = var.github_organization_name
  version_control_system_repository                         = var.github_repository_name
  version_control_system_authentication_method              = var.github_authentication_method
  version_control_system_personal_access_token              = var.github_personal_access_token
  version_control_system_github_application_id              = var.github_app_id
  version_control_system_github_application_installation_id = var.github_app_installation_id
  version_control_system_github_application_key             = var.github_app_private_key

  # Private networking (default, but explicit for clarity)
  use_private_networking = true

  # BYO resource group
  resource_group_creation_enabled = false
  resource_group_name             = var.resource_group_name

  # BYO VNet — module will not create networking resources
  virtual_network_creation_enabled              = false
  virtual_network_id                            = var.virtual_network_id
  container_app_subnet_id                       = var.container_app_subnet_id
  container_registry_private_endpoint_subnet_id = var.container_registry_private_endpoint_subnet_id

  # BYO private DNS zone for ACR
  container_registry_private_dns_zone_creation_enabled = false
  container_registry_dns_zone_id                       = var.container_registry_dns_zone_id

  tags = local.tags
}
