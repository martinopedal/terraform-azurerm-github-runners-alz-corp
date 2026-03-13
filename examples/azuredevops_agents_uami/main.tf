module "azuredevops_agents" {
  source = "../.."

  postfix  = "adouami"
  location = "swedencentral"

  # --- ALZ Corp networking (provided by ALZ Vending Module) ---
  container_app_subnet_id                       = var.container_app_subnet_id
  container_registry_private_endpoint_subnet_id = var.container_registry_private_endpoint_subnet_id
  container_registry_dns_zone_id                = var.container_registry_dns_zone_id

  # --- Resource Group (set false if provided by ALZ Vending) ---
  resource_group_creation_enabled = true

  # --- VCS Configuration ---
  version_control_system_type                  = "azuredevops"
  version_control_system_organization          = var.azuredevops_organization_url
  version_control_system_pool_name             = var.azuredevops_pool_name
  version_control_system_authentication_method = "uami"

  # --- Use existing UAMI (pre-configured in Azure DevOps) ---
  user_assigned_managed_identity_creation_enabled = false
  user_assigned_managed_identity_id               = var.user_assigned_managed_identity_id
  user_assigned_managed_identity_client_id        = var.user_assigned_managed_identity_client_id
  user_assigned_managed_identity_principal_id     = var.user_assigned_managed_identity_principal_id

  tags = {
    environment = "production"
    managed_by  = "terraform"
  }
}
