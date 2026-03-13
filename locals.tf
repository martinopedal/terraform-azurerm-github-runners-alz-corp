locals {
  container_app_environment_id                     = var.container_app_environment_creation_enabled ? azurerm_container_app_environment.this[0].id : var.container_app_environment_id
  container_registry_dns_zone_id                   = var.container_registry_dns_zone_id
  container_registry_private_endpoint_subnet_id    = var.container_registry_private_endpoint_subnet_id
  log_analytics_workspace_id                       = var.log_analytics_workspace_creation_enabled ? module.log_analytics_workspace[0].resource_id : var.log_analytics_workspace_id
  registry_login_server                            = var.container_registry_creation_enabled ? module.container_registry[0].login_server : var.custom_container_registry_login_server
  resource_group_id                                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${local.resource_group_name}"
  resource_group_name                              = var.resource_group_creation_enabled ? azurerm_resource_group.this[0].name : var.resource_group_name
  resource_group_name_container_app_infrastructure = var.container_app_infrastructure_resource_group_name == null ? "rg-${var.postfix}-container-apps-infrastructure" : var.container_app_infrastructure_resource_group_name
  user_assigned_managed_identity_client_id         = var.user_assigned_managed_identity_creation_enabled ? module.user_assigned_managed_identity[0].client_id : var.user_assigned_managed_identity_client_id
  user_assigned_managed_identity_principal_id      = var.user_assigned_managed_identity_creation_enabled ? module.user_assigned_managed_identity[0].principal_id : var.user_assigned_managed_identity_principal_id
}

locals {
  container_app_environment_name                = var.container_app_environment_creation_enabled ? (var.container_app_environment_name != null ? var.container_app_environment_name : "cae-${var.postfix}") : ""
  container_registry_name                       = replace(var.container_registry_name != null ? var.container_registry_name : "acr${var.postfix}", "-", "")
  default_image_name                            = var.default_image_name != null ? var.default_image_name : (var.version_control_system_type == "azuredevops" ? "azure-devops-agent" : "github-runner")
  github_repository_url                         = var.version_control_system_repository != null ? (startswith(var.version_control_system_repository, "https") ? var.version_control_system_repository : "https://${var.version_control_system_github_url}/${var.version_control_system_organization}/${var.version_control_system_repository}") : ""
  log_analytics_workspace_name                  = var.log_analytics_workspace_name != null ? var.log_analytics_workspace_name : "laws-${var.postfix}"
  user_assigned_managed_identity_id             = var.user_assigned_managed_identity_id != null ? var.user_assigned_managed_identity_id : module.user_assigned_managed_identity[0].resource_id
  user_assigned_managed_identity_name           = var.user_assigned_managed_identity_name != null ? var.user_assigned_managed_identity_name : "uami-${var.postfix}"
  version_control_system_agent_name_prefix      = var.version_control_system_agent_name_prefix != null ? var.version_control_system_agent_name_prefix : (var.version_control_system_type == "azuredevops" ? "agent-${var.postfix}" : "runner-${var.postfix}")
  version_control_system_placeholder_agent_name = var.version_control_system_placeholder_agent_name != null ? var.version_control_system_placeholder_agent_name : "placeholder-${var.postfix}"
}

locals {
  container_images = var.use_default_container_image ? {
    container_app = {
      task_name            = "${var.version_control_system_type}-container-app-image-build-task"
      dockerfile_path      = var.default_image_registry_dockerfile_path
      context_path         = "${var.default_image_repository_url}#${var.default_image_repository_commit}:${var.default_image_repository_folder_paths["${var.version_control_system_type}-container-app"]}"
      context_access_token = "a"
      image_names          = ["${local.default_image_name}:${var.default_image_repository_commit}"]
    }
  } : var.custom_container_registry_images
}
