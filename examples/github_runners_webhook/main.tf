module "github_runners" {
  source = "../.."

  # --- ALZ Corp networking ---
  container_app_subnet_id                       = var.container_app_subnet_id
  container_registry_private_endpoint_subnet_id = var.container_registry_private_endpoint_subnet_id
  location                                      = "swedencentral"
  postfix                                       = "ghrun-wh"
  version_control_system_organization           = var.github_organization
  # --- VCS Configuration ---
  version_control_system_type    = "github"
  container_registry_dns_zone_id = var.container_registry_dns_zone_id
  tags = {
    environment = "production"
    managed_by  = "terraform"
    scaling     = "webhook"
  }
  version_control_system_authentication_method = "pat"
  version_control_system_personal_access_token = var.github_personal_access_token
  version_control_system_repository            = var.github_repository
  # Grant the receiver Function's managed identity permission to send to the queue.
  # The receiver itself is deployed separately - see WEBHOOKS.md for the contract
  # and a sample Function implementation.
  webhook_receiver_principal_ids = var.webhook_receiver_principal_ids
  # --- Webhook-driven scaling ---
  webhook_scaling_enabled                    = true
  webhook_storage_private_endpoint_subnet_id = var.webhook_storage_private_endpoint_subnet_id
  webhook_storage_queue_dns_zone_id          = var.webhook_storage_queue_dns_zone_id
}
