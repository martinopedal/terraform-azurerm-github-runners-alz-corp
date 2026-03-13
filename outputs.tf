output "container_app_environment_name" {
  description = "The name of the container app environment."
  value       = local.container_app_environment_name
}

output "container_app_environment_resource_id" {
  description = "The resource ID of the container app environment."
  value       = local.container_app_environment_id
}

output "container_app_job_name" {
  description = "The name of the container app job."
  value       = module.container_app_job.name
}

output "container_app_job_resource_id" {
  description = "The resource ID of the container app job."
  value       = module.container_app_job.resource_id
}

output "container_registry_login_server" {
  description = "The container registry login server."
  value       = var.container_registry_creation_enabled ? module.container_registry[0].login_server : var.custom_container_registry_login_server
}

output "container_registry_name" {
  description = "The container registry name."
  value       = var.container_registry_creation_enabled ? module.container_registry[0].name : null
}

output "container_registry_resource_id" {
  description = "The container registry resource ID."
  value       = var.container_registry_creation_enabled ? module.container_registry[0].resource_id : null
}

output "resource_group_name" {
  description = "The name of the resource group."
  value       = local.resource_group_name
}

output "user_assigned_managed_identity_client_id" {
  description = "The client ID of the user assigned managed identity."
  value       = var.user_assigned_managed_identity_creation_enabled ? module.user_assigned_managed_identity[0].client_id : null
}

output "user_assigned_managed_identity_id" {
  description = "The resource ID of the user assigned managed identity."
  value       = var.user_assigned_managed_identity_creation_enabled ? module.user_assigned_managed_identity[0].resource_id : var.user_assigned_managed_identity_id
}

output "user_assigned_managed_identity_principal_id" {
  description = "The principal ID of the user assigned managed identity."
  value       = var.user_assigned_managed_identity_creation_enabled ? module.user_assigned_managed_identity[0].principal_id : var.user_assigned_managed_identity_principal_id
}
