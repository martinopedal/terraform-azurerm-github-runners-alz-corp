# GitHub Enterprise Cloud with Data Residency — BYO VNet and DNS

This example deploys GitHub self-hosted runners configured for GitHub
Enterprise Cloud (GHEC) with data residency (`<subdomain>.ghe.com`),
using a **Bring Your Own** (BYO) VNet, DNS zone, and resource group.

Only the runner infrastructure is created by this module — you supply
the networking and DNS resources that already exist in your environment.

## Prerequisites

Before deploying, you need:

1. A resource group
2. A VNet with the following subnets:
   - Container App subnet (min /27, delegated to `Microsoft.App/environments`)
   - Container Registry private endpoint subnet (min /29)
3. A private DNS zone for `privatelink.azurecr.io`, linked to the VNet

## Key Variables

| Variable | Description |
|----------|-------------|
| `github_url` | Your GHEC data residency domain (e.g., `mycompany.ghe.com`) |
| `resource_group_name` | Existing resource group name |
| `virtual_network_id` | Existing VNet resource ID |
| `container_app_subnet_id` | Subnet ID for Container App environment |
| `container_registry_private_endpoint_subnet_id` | Subnet ID for ACR private endpoint |
| `container_registry_dns_zone_id` | Private DNS zone ID for `privatelink.azurecr.io` |

## Usage

### GitHub App authentication with BYO VNet (recommended)

```hcl
module "github_runners" {
  source = "git::https://github.com/<your-org>/terraform-azurerm-avm-ptn-cicd-agents-and-runners.git?ref=main"

  location = "westeurope"
  postfix  = "dr-runners"

  # GitHub data residency with App auth
  version_control_system_type                               = "github"
  version_control_system_github_url                         = "mycompany.ghe.com"
  version_control_system_organization                       = "my-org"
  version_control_system_repository                         = "my-repo"
  version_control_system_authentication_method              = "github_app"
  version_control_system_github_application_id              = var.github_app_id
  version_control_system_github_application_installation_id = var.github_app_installation_id
  version_control_system_github_application_key             = var.github_app_private_key

  # Private networking (default, but explicit for clarity)
  use_private_networking = true

  # BYO resource group
  resource_group_creation_enabled = false
  resource_group_name             = "rg-runners-prod"

  # BYO VNet
  virtual_network_creation_enabled              = false
  virtual_network_id                            = data.azurerm_virtual_network.runners.id
  container_app_subnet_id                       = data.azurerm_subnet.container_app.id
  container_registry_private_endpoint_subnet_id = data.azurerm_subnet.acr_pe.id

  # BYO private DNS for ACR
  container_registry_private_dns_zone_creation_enabled = false
  container_registry_dns_zone_id                       = data.azurerm_private_dns_zone.acr.id
}
```

### PAT authentication with BYO VNet

```hcl
module "github_runners" {
  source = "git::https://github.com/<your-org>/terraform-azurerm-avm-ptn-cicd-agents-and-runners.git?ref=main"

  location = "westeurope"
  postfix  = "dr-runners"

  version_control_system_type                  = "github"
  version_control_system_github_url            = "mycompany.ghe.com"
  version_control_system_organization          = "my-org"
  version_control_system_repository            = "my-repo"
  version_control_system_personal_access_token = var.github_personal_access_token

  # BYO infrastructure
  resource_group_creation_enabled                      = false
  resource_group_name                                  = "rg-runners"
  virtual_network_creation_enabled                     = false
  virtual_network_id                                   = "/subscriptions/.../virtualNetworks/vnet-runners"
  container_app_subnet_id                              = "/subscriptions/.../subnets/snet-container-app"
  container_registry_private_endpoint_subnet_id        = "/subscriptions/.../subnets/snet-acr-pe"
  container_registry_private_dns_zone_creation_enabled = false
  container_registry_dns_zone_id                       = "/subscriptions/.../privateDnsZones/privatelink.azurecr.io"
}
```

