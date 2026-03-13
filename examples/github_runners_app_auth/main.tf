module "github_runners" {
  source = "../.."

  postfix  = "ghapp"
  location = "swedencentral"

  # --- ALZ Corp networking (provided by ALZ Vending Module) ---
  container_app_subnet_id                       = var.container_app_subnet_id
  container_registry_private_endpoint_subnet_id = var.container_registry_private_endpoint_subnet_id
  container_registry_dns_zone_id                = var.container_registry_dns_zone_id

  # --- Resource Group (set false if provided by ALZ Vending) ---
  resource_group_creation_enabled = true

  # --- VCS Configuration ---
  version_control_system_type                               = "github"
  version_control_system_organization                       = var.github_organization
  version_control_system_repository                         = var.github_repository
  version_control_system_authentication_method              = "github_app"
  version_control_system_github_application_id              = var.github_app_id
  version_control_system_github_application_installation_id = var.github_app_installation_id
  version_control_system_github_application_key             = var.github_app_key

  tags = {
    environment = "production"
    managed_by  = "terraform"
  }
}
