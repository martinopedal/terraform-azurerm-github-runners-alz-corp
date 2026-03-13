resource "azurerm_container_app_environment" "this" {
  count = var.container_app_environment_creation_enabled ? 1 : 0

  location                           = var.location
  name                               = local.container_app_environment_name
  resource_group_name                = local.resource_group_name
  infrastructure_resource_group_name = local.resource_group_name_container_app_infrastructure
  infrastructure_subnet_id           = var.container_app_subnet_id
  internal_load_balancer_enabled     = true
  log_analytics_workspace_id         = local.log_analytics_workspace_id
  logs_destination                   = "log-analytics"
  tags                               = var.tags
  zone_redundancy_enabled            = var.use_zone_redundancy ? true : null

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
    maximum_count         = 0
    minimum_count         = 0
  }
}

resource "time_sleep" "delay_after_container_app_environment_creation" {
  create_duration = "${var.delays.delay_after_container_app_environment_creation}s"

  depends_on = [resource.azurerm_container_app_environment.this]
}
