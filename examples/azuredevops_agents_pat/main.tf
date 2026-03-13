module "azuredevops_agents" {
  source = "../.."

  postfix  = "adoagt"
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
  version_control_system_authentication_method = "pat"
  version_control_system_personal_access_token = var.azuredevops_personal_access_token

  tags = {
    environment = "production"
    managed_by  = "terraform"
  }
}
