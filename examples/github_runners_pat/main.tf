module "github_runners" {
  source = "../.."

  postfix  = "ghrun"
  location = "swedencentral"

  # --- ALZ Corp networking (provided by ALZ Vending Module) ---
  container_app_subnet_id                       = var.container_app_subnet_id
  container_registry_private_endpoint_subnet_id = var.container_registry_private_endpoint_subnet_id
  container_registry_dns_zone_id                = var.container_registry_dns_zone_id

  # --- Resource Group (set false if provided by ALZ Vending) ---
  resource_group_creation_enabled = true

  # --- VCS Configuration ---
  version_control_system_type                  = "github"
  version_control_system_organization          = var.github_organization
  version_control_system_repository            = var.github_repository
  version_control_system_authentication_method = "pat"
  version_control_system_personal_access_token = var.github_personal_access_token

  tags = {
    environment = "production"
    managed_by  = "terraform"
  }
}
