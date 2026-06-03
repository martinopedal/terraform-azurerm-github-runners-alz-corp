output "azure_firewall_private_ip" {
  description = "Firewall private IP consumed by the surrounding UDR configuration."
  value       = local.azure_firewall_private_ip
}

output "connectivity_subscription_id" {
  description = "Connectivity subscription containing the hub and Azure Firewall."
  value       = local.connectivity_subscription_id
}

output "hub_vnet_id" {
  description = "Hub virtual network consumed by the surrounding AVNM and UDR configuration."
  value       = local.hub_vnet_id
}

output "runner_identity_principal_id" {
  description = "Managed identity principal ID for granting runner workload RBAC."
  value       = module.corp_runners.user_assigned_managed_identity_principal_id
}
