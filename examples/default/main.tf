module "corp_runners" {
  source = "../.."

  container_app_subnet_id                       = var.container_app_subnet_id
  container_registry_private_endpoint_subnet_id = var.container_registry_private_endpoint_subnet_id
  location                                      = var.location
  postfix                                       = "corpaca"
  version_control_system_organization           = var.github_organization
  version_control_system_type                   = "github"
  container_registry_dns_zone_id                = var.container_registry_dns_zone_id
  tags = {
    workload   = "corp-aca-runners"
    managed-by = "terraform"
  }
  version_control_system_authentication_method = "pat"
  version_control_system_personal_access_token = var.github_personal_access_token
  version_control_system_repository            = var.github_repository
}
