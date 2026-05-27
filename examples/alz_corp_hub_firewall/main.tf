locals {
  connectivity_subscription_id = var.connectivity_subscription_id
  hub_vnet_id                  = var.hub_vnet_id
  azure_firewall_private_ip    = var.azure_firewall_private_ip
}

module "corp_runners" {
  source = "../.."

  postfix  = "corpaca"
  location = var.location

  resource_group_creation_enabled = true
  resource_group_name             = var.runner_resource_group_name

  container_app_subnet_id                       = var.container_app_subnet_id
  container_registry_private_endpoint_subnet_id = var.container_registry_private_endpoint_subnet_id
  container_registry_dns_zone_id                = var.container_registry_dns_zone_id

  version_control_system_type                  = "github"
  version_control_system_organization          = var.github_organization
  version_control_system_repository            = var.github_repository
  version_control_system_authentication_method = "pat"
  version_control_system_personal_access_token = var.github_personal_access_token

  tags = var.tags
}

output "connectivity_subscription_id" {
  description = "Connectivity subscription containing the hub and Azure Firewall."
  value       = local.connectivity_subscription_id
}

output "hub_vnet_id" {
  description = "Hub virtual network consumed by the surrounding AVNM and UDR configuration."
  value       = local.hub_vnet_id
}

output "azure_firewall_private_ip" {
  description = "Firewall private IP consumed by the surrounding UDR configuration."
  value       = local.azure_firewall_private_ip
}

output "runner_identity_principal_id" {
  description = "Managed identity principal ID for granting runner workload RBAC."
  value       = module.corp_runners.user_assigned_managed_identity_principal_id
}
