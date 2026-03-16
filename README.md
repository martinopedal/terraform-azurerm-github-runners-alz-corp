# Self-Hosted CI/CD Runners for Azure Landing Zone Corp

This Terraform module deploys self-hosted **GitHub Actions Runners** and **Azure DevOps Agents**
on **Azure Container Apps** — purpose-built for **Azure Landing Zone (ALZ) Corp** subscriptions
with central firewall egress and no public IPs.

It is designed to work with:

- [**ALZ Terraform Modules**](https://github.com/Azure/terraform-azurerm-caf-enterprise-scale) — for platform landing zone
- [**ALZ Vending Module**](https://github.com/Azure/terraform-azurerm-lz-vending) — for subscription vending (provides Resource Group, VNet, subnets)
- [**Azure Virtual Network Manager (AVNM)**](https://learn.microsoft.com/azure/virtual-network-manager/overview) — for hub-spoke connectivity
- **Azure Firewall** — for central egress (see [FIREWALL-RULES.md](./FIREWALL-RULES.md))

> **Forked from** [Azure/terraform-azurerm-avm-ptn-cicd-agents-and-runners](https://github.com/Azure/terraform-azurerm-avm-ptn-cicd-agents-and-runners)
> and streamlined for ALZ Corp. Networking components (VNet, NAT Gateway, Public IP) are removed —
> those are delivered by your landing zone platform.

---

## Authentication

This module involves **two separate authentication layers** that serve different purposes.
These are frequently confused, so this section explains each one.

### Layer 1: Terraform → Azure (Infrastructure Deployment)

**"How does Terraform authenticate to Azure to create the resources?"**

This is handled **outside this module** — in your CI/CD pipeline or local environment:

| Method | When to Use | How |
|---|---|---|
| **Workload Identity Federation (OIDC)** | CI/CD pipelines (recommended) | `ARM_CLIENT_ID` + `ARM_TENANT_ID` + `ARM_SUBSCRIPTION_ID` + `ARM_OIDC_TOKEN`/`ARM_OIDC_REQUEST_*` |
| **Service Principal + Client Secret** | CI/CD pipelines (legacy) | `ARM_CLIENT_ID` + `ARM_CLIENT_SECRET` + `ARM_TENANT_ID` + `ARM_SUBSCRIPTION_ID` |
| **Managed Identity** | Azure-hosted deployment agents | `ARM_USE_MSI = true` |
| **Azure CLI** | Local development | `az login` before `terraform apply` |

> **This module does NOT configure Terraform authentication.** That's your pipeline's responsibility.

### Layer 2: Runner/Agent → VCS Platform (Runtime Registration)

**"How does the self-hosted runner authenticate to GitHub/Azure DevOps to pick up jobs?"**

This is what `version_control_system_authentication_method` configures. The runner container
uses these credentials **at runtime** to register itself and poll for jobs:

#### GitHub Options

| Method | Variable | How It Works |
|---|---|---|
| **PAT** | `version_control_system_personal_access_token` | A GitHub Personal Access Token (classic with `repo` + `admin:org` scopes, or fine-grained equivalent). Stored as a Container App secret. The KEDA scaler also uses it to poll for queued workflows. |
| **GitHub App** | `version_control_system_github_application_id` + `_installation_id` + `_key` | A GitHub App installed on your org/repo. The runner uses the App's private key to generate short-lived tokens. No long-lived token, scoped permissions, audit trail. Preferred for production. |

#### Azure DevOps Options

| Method | Variable | How It Works |
|---|---|---|
| **PAT** | `version_control_system_personal_access_token` | An Azure DevOps PAT with `Agent Pools (Read & manage)` scope. Stored as a Container App secret. Used by both the agent and the KEDA scaler. |
| **UAMI** | (No token needed) | A User Assigned Managed Identity registered as a service principal in Azure DevOps with Administrator role on the target agent pool. No secrets to manage or rotate. The agent uses the managed identity to obtain tokens from Entra ID. |

### Layer 3: Runner/Agent UAMI → Azure Resources (Workload Access)

**"How does the runner access Azure resources (Storage, Key Vault, etc.) during job execution?"**

The User Assigned Managed Identity (UAMI) created by this module is attached to the Container App Job.
Your workflow steps can use this identity to authenticate to Azure resources without secrets:

```yaml
# GitHub Actions example
- uses: azure/login@v2
  with:
    client-id: ${{ secrets.UAMI_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

Grant the UAMI appropriate RBAC roles on the resources your pipelines need to access.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  ALZ Platform (Management/Connectivity Subscription)            │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────────────┐ │
│  │ Azure        │  │ AVNM         │  │ Central DNS           │ │
│  │ Firewall     │  │ Hub-Spoke    │  │ (privatelink.azurecr  │ │
│  │ (egress)     │  │ Connectivity │  │  .io, etc.)           │ │
│  └──────┬───────┘  └──────┬───────┘  └───────────┬───────────┘ │
└─────────┼─────────────────┼──────────────────────┼─────────────┘
          │                 │                      │
┌─────────┼─────────────────┼──────────────────────┼─────────────┐
│  ALZ Corp Subscription (from LZ Vending Module)                 │
│         │                 │                      │              │
│  ┌──────┴─────────────────┴──────────────────────┴───────────┐ │
│  │  VNet (from Vending Module, connected via AVNM)           │ │
│  │  ┌────────────────────┐  ┌──────────────────────────────┐ │ │
│  │  │ Subnet: ACA        │  │ Subnet: Private Endpoints    │ │ │
│  │  │ (delegated to      │  │ (ACR PE)                     │ │ │
│  │  │  Microsoft.App/    │  │                              │ │ │
│  │  │  environments)     │  │                              │ │ │
│  │  └────────┬───────────┘  └──────────────┬───────────────┘ │ │
│  └───────────┼─────────────────────────────┼─────────────────┘ │
│              │                             │                    │
│  ┌───────────┴──────────┐  ┌───────────────┴─────────────────┐ │
│  │ Container App Env    │  │ Azure Container Registry        │ │
│  │  ├ Runner/Agent Job  │  │  (Premium, Private Endpoint)    │ │
│  │  │  (KEDA-scaled)    │  │  ├ github-runner image          │ │
│  │  │                   │  │  └ azure-devops-agent image     │ │
│  │  └ UAMI attached     │  └─────────────────────────────────┘ │
│  └──────────────────────┘                                       │
│  ┌──────────────────────┐  ┌─────────────────────────────────┐ │
│  │ Log Analytics        │  │ User Assigned Managed Identity  │ │
│  │ Workspace            │  │  (ACR pull + optional workload  │ │
│  └──────────────────────┘  │   access)                       │ │
│                             └─────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## What This Module Creates

| Resource | Purpose |
|---|---|
| Resource Group | (optional) Container for all resources |
| Azure Container Registry | Builds and stores the runner/agent container image |
| Container App Environment | Serverless hosting for runner jobs (always internal/private) |
| Container App Job | KEDA-scaled event-driven job that spins up runners on demand |
| User Assigned Managed Identity | ACR pull access + runner identity for Azure resource access |
| Log Analytics Workspace | Logs and monitoring for the Container App Environment |

## What This Module Does NOT Create (ALZ Provides These)

| Resource | Provided By |
|---|---|
| Virtual Network + Subnets | ALZ Vending Module |
| Hub-Spoke Connectivity | AVNM |
| NAT Gateway / Public IP | Not needed — central Azure Firewall egress |
| Azure Firewall Rules | Platform team ([see required rules](./FIREWALL-RULES.md)) |
| Private DNS Zones | Central DNS infrastructure or Azure Policy |

---

## Prerequisites

1. **ALZ Vending Module** must have provisioned:
   - A subscription with a VNet connected to the hub via AVNM
   - A subnet delegated to `Microsoft.App/environments` (min /27 recommended)
   - A subnet for private endpoints (ACR)

2. **Azure Firewall** must allow the FQDNs listed in [FIREWALL-RULES.md](./FIREWALL-RULES.md)

3. **Private DNS** for `privatelink.azurecr.io` must resolve (via central DNS or Azure Policy)

4. **`Microsoft.App` resource provider** must be registered on the subscription

---

## Usage — GitHub Runners with PAT

```hcl
module "github_runners" {
  source  = "martinopedal/github-runners-alz-corp/azurerm"

  postfix  = "ghrun"
  location = "swedencentral"

  # ALZ Corp networking (from Vending Module outputs)
  container_app_subnet_id                    = module.lz_vending.subnets["aca"].id
  container_registry_private_endpoint_subnet_id = module.lz_vending.subnets["pe"].id
  container_registry_dns_zone_id             = data.azurerm_private_dns_zone.acr.id  # or null if policy-managed

  # GitHub configuration
  version_control_system_type                  = "github"
  version_control_system_organization          = "my-org"
  version_control_system_repository            = "my-repo"
  version_control_system_authentication_method = "pat"
  version_control_system_personal_access_token = var.github_pat  # from Key Vault or pipeline secret

  tags = var.tags
}
```

Then in your GitHub Actions workflow:

```yaml
jobs:
  deploy:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      - run: echo "Running on self-hosted runner"
```

## Usage — Azure DevOps Agents with UAMI

```hcl
module "azuredevops_agents" {
  source  = "martinopedal/github-runners-alz-corp/azurerm"

  postfix  = "adoagt"
  location = "swedencentral"

  # ALZ Corp networking
  container_app_subnet_id                    = module.lz_vending.subnets["aca"].id
  container_registry_private_endpoint_subnet_id = module.lz_vending.subnets["pe"].id

  # Azure DevOps configuration — UAMI (no PAT needed)
  version_control_system_type                  = "azuredevops"
  version_control_system_organization          = "https://dev.azure.com/my-org"
  version_control_system_pool_name             = "alz-corp-pool"
  version_control_system_authentication_method = "uami"

  # Pre-configured UAMI (must be registered in Azure DevOps first)
  user_assigned_managed_identity_creation_enabled = false
  user_assigned_managed_identity_id               = azurerm_user_assigned_identity.ado.id
  user_assigned_managed_identity_client_id        = azurerm_user_assigned_identity.ado.client_id
  user_assigned_managed_identity_principal_id     = azurerm_user_assigned_identity.ado.principal_id

  tags = var.tags
}
```

## Usage — GitHub Runners with GitHub App Auth

```hcl
module "github_runners" {
  source  = "martinopedal/github-runners-alz-corp/azurerm"

  postfix  = "ghapp"
  location = "swedencentral"

  # ALZ Corp networking
  container_app_subnet_id                    = module.lz_vending.subnets["aca"].id
  container_registry_private_endpoint_subnet_id = module.lz_vending.subnets["pe"].id

  # GitHub App authentication (no long-lived PAT)
  version_control_system_type                               = "github"
  version_control_system_organization                       = "my-org"
  version_control_system_repository                         = "my-repo"
  version_control_system_authentication_method              = "github_app"
  version_control_system_github_application_id              = var.github_app_id
  version_control_system_github_application_installation_id = var.github_app_installation_id
  version_control_system_github_application_key             = var.github_app_private_key

  tags = var.tags
}
```

---

## How It Works

1. **Image Build** — ACR Task builds the runner/agent image from
   [Azure/avm-container-images-cicd-agents-and-runners](https://github.com/Azure/avm-container-images-cicd-agents-and-runners)
   (or your custom image)
2. **Idle** — Container App Job scales to zero. No runners running, no compute cost.
3. **Job Queued** — A workflow/pipeline is triggered in GitHub or Azure DevOps
4. **KEDA Scales Up** — The KEDA scaler (`github-runner` or `azure-pipelines`) polls the VCS API,
   detects the queued job, and starts an ephemeral Container App Job execution
5. **Runner Registers** — The container registers as a runner/agent, picks up the job, runs it
6. **Runner Terminates** — After the job completes, the ephemeral container terminates
7. **Scale to Zero** — If no more jobs are queued, KEDA scales back down

---

## Examples

| Example | Description |
|---|---|
| [github_runners_pat](./examples/github_runners_pat/) | GitHub runners with PAT authentication |
| [github_runners_app_auth](./examples/github_runners_app_auth/) | GitHub runners with GitHub App authentication |
| [azuredevops_agents_pat](./examples/azuredevops_agents_pat/) | Azure DevOps agents with PAT authentication |
| [azuredevops_agents_uami](./examples/azuredevops_agents_uami/) | Azure DevOps agents with UAMI (no secrets) |

---

<!-- BEGIN_TF_DOCS -->
<!-- Code generated by terraform-docs. DO NOT EDIT. -->

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.9.0)

- <a name="requirement_azapi"></a> [azapi](#requirement\_azapi) (~> 2.4)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (~> 4.20)

- <a name="requirement_modtm"></a> [modtm](#requirement\_modtm) (~> 0.3)

- <a name="requirement_random"></a> [random](#requirement\_random) (~> 3.5)

- <a name="requirement_time"></a> [time](#requirement\_time) (~> 0.12)

## Resources

The following resources are used by this module:

- [azurerm_container_app_environment.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_app_environment) (resource)
- [azurerm_management_lock.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_lock) (resource)
- [azurerm_resource_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_role_assignment.custom_container_registry_pull](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) (resource)
- [modtm_telemetry.telemetry](https://registry.terraform.io/providers/azure/modtm/latest/docs/resources/telemetry) (resource)
- [random_uuid.telemetry](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/uuid) (resource)
- [time_sleep.delay_after_container_app_environment_creation](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) (resource)
- [time_sleep.delay_after_container_image_build](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) (resource)
- [azapi_client_config.telemetry](https://registry.terraform.io/providers/Azure/azapi/latest/docs/data-sources/client_config) (data source)
- [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) (data source)
- [modtm_module_source.telemetry](https://registry.terraform.io/providers/azure/modtm/latest/docs/data-sources/module_source) (data source)

<!-- markdownlint-disable MD013 -->
## Required Inputs

The following input variables are required:

### <a name="input_container_app_subnet_id"></a> [container\_app\_subnet\_id](#input\_container\_app\_subnet\_id)

Description: The resource ID of the subnet for the Container App Environment. Must have delegation for `Microsoft.App/environments`. Provided by ALZ Vending Module.

Type: `string`

### <a name="input_container_registry_private_endpoint_subnet_id"></a> [container\_registry\_private\_endpoint\_subnet\_id](#input\_container\_registry\_private\_endpoint\_subnet\_id)

Description: The resource ID of the subnet for the Container Registry private endpoint. Provided by ALZ Vending Module.

Type: `string`

### <a name="input_location"></a> [location](#input\_location)

Description: Azure region where the resource should be deployed.

Type: `string`

### <a name="input_postfix"></a> [postfix](#input\_postfix)

Description: A postfix used to build default names if no name has been supplied for a specific resource type.

Type: `string`

### <a name="input_version_control_system_organization"></a> [version\_control\_system\_organization](#input\_version\_control\_system\_organization)

Description: The organization for the version control system. For Azure DevOps: the full URL (e.g. `https://dev.azure.com/my-org`). For GitHub: the organization name.

Type: `string`

### <a name="input_version_control_system_type"></a> [version\_control\_system\_type](#input\_version\_control\_system\_type)

Description: The type of the version control system. Allowed values are `azuredevops` or `github`.

Type: `string`

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_container_app_container_cpu"></a> [container\_app\_container\_cpu](#input\_container\_app\_container\_cpu)

Description: Required CPU in cores, e.g. 0.5

Type: `number`

Default: `1`

### <a name="input_container_app_container_memory"></a> [container\_app\_container\_memory](#input\_container\_app\_container\_memory)

Description: Required memory, e.g. '250Mb'

Type: `string`

Default: `"2Gi"`

### <a name="input_container_app_environment_creation_enabled"></a> [container\_app\_environment\_creation\_enabled](#input\_container\_app\_environment\_creation\_enabled)

Description: Whether or not to create a Container App Environment.

Type: `bool`

Default: `true`

### <a name="input_container_app_environment_id"></a> [container\_app\_environment\_id](#input\_container\_app\_environment\_id)

Description: The resource id of the Container App Environment. Only required if `container_app_environment_creation_enabled` is `false`.

Type: `string`

Default: `null`

### <a name="input_container_app_environment_name"></a> [container\_app\_environment\_name](#input\_container\_app\_environment\_name)

Description: The name of the Container App Environment. Only required if `container_app_environment_creation_enabled` is `true`.

Type: `string`

Default: `null`

### <a name="input_container_app_environment_variables"></a> [container\_app\_environment\_variables](#input\_container\_app\_environment\_variables)

Description: List of additional environment variables to pass to the container.

Type:

```hcl
set(object({
    name  = string
    value = string
  }))
```

Default: `[]`

### <a name="input_container_app_infrastructure_resource_group_name"></a> [container\_app\_infrastructure\_resource\_group\_name](#input\_container\_app\_infrastructure\_resource\_group\_name)

Description: The name of the resource group where the Container Apps infrastructure is deployed.

Type: `string`

Default: `null`

### <a name="input_container_app_job_container_name"></a> [container\_app\_job\_container\_name](#input\_container\_app\_job\_container\_name)

Description: The name of the container for the runner Container Apps job.

Type: `string`

Default: `null`

### <a name="input_container_app_job_name"></a> [container\_app\_job\_name](#input\_container\_app\_job\_name)

Description: The name of the Container App runner job.

Type: `string`

Default: `null`

### <a name="input_container_app_max_execution_count"></a> [container\_app\_max\_execution\_count](#input\_container\_app\_max\_execution\_count)

Description: The maximum number of executions (ADO jobs) to spawn per polling interval.

Type: `number`

Default: `100`

### <a name="input_container_app_min_execution_count"></a> [container\_app\_min\_execution\_count](#input\_container\_app\_min\_execution\_count)

Description: The minimum number of executions (ADO jobs) to spawn per polling interval.

Type: `number`

Default: `0`

### <a name="input_container_app_placeholder_container_name"></a> [container\_app\_placeholder\_container\_name](#input\_container\_app\_placeholder\_container\_name)

Description: The name of the container for the placeholder Container Apps job.

Type: `string`

Default: `null`

### <a name="input_container_app_placeholder_job_name"></a> [container\_app\_placeholder\_job\_name](#input\_container\_app\_placeholder\_job\_name)

Description: The name of the Container App placeholder job.

Type: `string`

Default: `null`

### <a name="input_container_app_placeholder_replica_retry_limit"></a> [container\_app\_placeholder\_replica\_retry\_limit](#input\_container\_app\_placeholder\_replica\_retry\_limit)

Description: The number of times to retry the placeholder Container Apps job.

Type: `number`

Default: `0`

### <a name="input_container_app_placeholder_replica_timeout"></a> [container\_app\_placeholder\_replica\_timeout](#input\_container\_app\_placeholder\_replica\_timeout)

Description: The timeout in seconds for the placeholder Container Apps job.

Type: `number`

Default: `300`

### <a name="input_container_app_polling_interval_seconds"></a> [container\_app\_polling\_interval\_seconds](#input\_container\_app\_polling\_interval\_seconds)

Description: How often should the pipeline queue be checked for new events, in seconds.

Type: `number`

Default: `30`

### <a name="input_container_app_replica_retry_limit"></a> [container\_app\_replica\_retry\_limit](#input\_container\_app\_replica\_retry\_limit)

Description: The number of times to retry the runner Container Apps job.

Type: `number`

Default: `3`

### <a name="input_container_app_replica_timeout"></a> [container\_app\_replica\_timeout](#input\_container\_app\_replica\_timeout)

Description: The timeout in seconds for the runner Container Apps job.

Type: `number`

Default: `1800`

### <a name="input_container_app_sensitive_environment_variables"></a> [container\_app\_sensitive\_environment\_variables](#input\_container\_app\_sensitive\_environment\_variables)

Description: List of additional sensitive environment variables to pass to the container.

Type:

```hcl
set(object({
    name                      = string
    value                     = string
    container_app_secret_name = string
    keda_auth_name            = optional(string)
  }))
```

Default: `[]`

### <a name="input_container_registry_creation_enabled"></a> [container\_registry\_creation\_enabled](#input\_container\_registry\_creation\_enabled)

Description: Whether or not to create a container registry.

Type: `bool`

Default: `true`

### <a name="input_container_registry_dns_zone_id"></a> [container\_registry\_dns\_zone\_id](#input\_container\_registry\_dns\_zone\_id)

Description: The ID of the private DNS zone for the container registry (`privatelink.azurecr.io`). If null, DNS resolution is assumed to be handled by Azure Policy or central DNS infrastructure.

Type: `string`

Default: `null`

### <a name="input_container_registry_name"></a> [container\_registry\_name](#input\_container\_registry\_name)

Description: The name of the container registry. If null, defaults to `acr<postfix>`.

Type: `string`

Default: `null`

### <a name="input_custom_container_registry_id"></a> [custom\_container\_registry\_id](#input\_custom\_container\_registry\_id)

Description: The ID of an existing container registry. Only used if `container_registry_creation_enabled` is `false`.

Type: `string`

Default: `null`

### <a name="input_custom_container_registry_images"></a> [custom\_container\_registry\_images](#input\_custom\_container\_registry\_images)

Description: Custom images to build in the container registry. Only relevant if `container_registry_creation_enabled` is `true` and `use_default_container_image` is `false`.

- `task_name` - Name of the ACR build task
- `dockerfile_path` - Path to the Dockerfile (e.g. `dockerfile`)
- `context_path` - Context in format `<repository-url>#<commit>:<folder-path>`
- `context_access_token` - Access token for the context repository
- `image_names` - List of image names to build (e.g. `["image-name:tag"]`)

Type:

```hcl
map(object({
    task_name            = string
    dockerfile_path      = string
    context_path         = string
    context_access_token = optional(string, "a")
    image_names          = list(string)
  }))
```

Default: `null`

### <a name="input_custom_container_registry_login_server"></a> [custom\_container\_registry\_login\_server](#input\_custom\_container\_registry\_login\_server)

Description: The login server of an existing container registry. Required if `container_registry_creation_enabled` is `false`.

Type: `string`

Default: `null`

### <a name="input_custom_container_registry_password"></a> [custom\_container\_registry\_password](#input\_custom\_container\_registry\_password)

Description: The password for an existing container registry.

Type: `string`

Default: `null`

### <a name="input_custom_container_registry_username"></a> [custom\_container\_registry\_username](#input\_custom\_container\_registry\_username)

Description: The username for an existing container registry.

Type: `string`

Default: `null`

### <a name="input_default_image_name"></a> [default\_image\_name](#input\_default\_image\_name)

Description: The default image name. If null, auto-detected from `version_control_system_type`.

Type: `string`

Default: `null`

### <a name="input_default_image_registry_dockerfile_path"></a> [default\_image\_registry\_dockerfile\_path](#input\_default\_image\_registry\_dockerfile\_path)

Description: The Dockerfile path for the default image build.

Type: `string`

Default: `"dockerfile"`

### <a name="input_default_image_repository_commit"></a> [default\_image\_repository\_commit](#input\_default\_image\_repository\_commit)

Description: The commit SHA of the default image repository.

Type: `string`

Default: `"221742d"`

### <a name="input_default_image_repository_folder_paths"></a> [default\_image\_repository\_folder\_paths](#input\_default\_image\_repository\_folder\_paths)

Description: Map of image type to folder path in the default image repository.

Type: `map(string)`

Default:

```json
{
  "azuredevops-container-app": "azure-devops-agent-aca",
  "github-container-app": "github-runner-aca"
}
```

### <a name="input_default_image_repository_url"></a> [default\_image\_repository\_url](#input\_default\_image\_repository\_url)

Description: The URL of the default image repository.

Type: `string`

Default: `"https://github.com/Azure/avm-container-images-cicd-agents-and-runners"`

### <a name="input_delays"></a> [delays](#input\_delays)

Description: Delays (in seconds) to apply to the module operations.

Type:

```hcl
object({
    delay_after_container_image_build              = optional(number, 60)
    delay_after_container_app_environment_creation = optional(number, 120)
  })
```

Default: `{}`

### <a name="input_enable_telemetry"></a> [enable\_telemetry](#input\_enable\_telemetry)

Description: This variable controls whether or not telemetry is enabled for the module.  
For more information see <https://aka.ms/avm/telemetryinfo>.  
If it is set to false, then no telemetry will be collected.

Type: `bool`

Default: `true`

### <a name="input_lock"></a> [lock](#input\_lock)

Description: Controls the Resource Lock configuration for this resource. The following properties can be specified:

- `kind` - (Required) The type of lock. Possible values are `"CanNotDelete"` and `"ReadOnly"`.
- `name` - (Optional) The name of the lock. If not specified, a name will be generated based on the `kind` value.

Type:

```hcl
object({
    kind = string
    name = optional(string, null)
  })
```

Default: `null`

### <a name="input_log_analytics_workspace_creation_enabled"></a> [log\_analytics\_workspace\_creation\_enabled](#input\_log\_analytics\_workspace\_creation\_enabled)

Description: Whether or not to create a log analytics workspace.

Type: `bool`

Default: `true`

### <a name="input_log_analytics_workspace_id"></a> [log\_analytics\_workspace\_id](#input\_log\_analytics\_workspace\_id)

Description: The resource Id of the Log Analytics Workspace.

Type: `string`

Default: `null`

### <a name="input_log_analytics_workspace_internet_ingestion_enabled"></a> [log\_analytics\_workspace\_internet\_ingestion\_enabled](#input\_log\_analytics\_workspace\_internet\_ingestion\_enabled)

Description: Whether or not to enable internet ingestion for the Log Analytics workspace. If null, the module defaults this to `false`.

Type: `bool`

Default: `null`

### <a name="input_log_analytics_workspace_internet_query_enabled"></a> [log\_analytics\_workspace\_internet\_query\_enabled](#input\_log\_analytics\_workspace\_internet\_query\_enabled)

Description: Whether or not to enable internet query for the Log Analytics workspace. If null, the module defaults this to `false`.

Type: `bool`

Default: `null`

### <a name="input_log_analytics_workspace_name"></a> [log\_analytics\_workspace\_name](#input\_log\_analytics\_workspace\_name)

Description: The name of the log analytics workspace. Only required if `log_analytics_workspace_creation_enabled == false`.

Type: `string`

Default: `null`

### <a name="input_log_analytics_workspace_retention_in_days"></a> [log\_analytics\_workspace\_retention\_in\_days](#input\_log\_analytics\_workspace\_retention\_in\_days)

Description: The retention period for the Log Analytics Workspace.

Type: `number`

Default: `30`

### <a name="input_log_analytics_workspace_sku"></a> [log\_analytics\_workspace\_sku](#input\_log\_analytics\_workspace\_sku)

Description: The SKU of the Log Analytics Workspace.

Type: `string`

Default: `"PerGB2018"`

### <a name="input_resource_group_creation_enabled"></a> [resource\_group\_creation\_enabled](#input\_resource\_group\_creation\_enabled)

Description: Whether or not to create a resource group. Set to `false` if the resource group is provided by ALZ Vending Module.

Type: `bool`

Default: `true`

### <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name)

Description: The resource group where the resources will be deployed. Must be specified if `resource_group_creation_enabled == false`.

Type: `string`

Default: `null`

### <a name="input_tags"></a> [tags](#input\_tags)

Description: (Optional) Tags of the resource.

Type: `map(string)`

Default: `null`

### <a name="input_use_default_container_image"></a> [use\_default\_container\_image](#input\_use\_default\_container\_image)

Description: Whether to use the default container image provided by the module.

Type: `bool`

Default: `true`

### <a name="input_use_zone_redundancy"></a> [use\_zone\_redundancy](#input\_use\_zone\_redundancy)

Description: Enable zone redundancy for the deployment.

Type: `bool`

Default: `true`

### <a name="input_user_assigned_managed_identity_client_id"></a> [user\_assigned\_managed\_identity\_client\_id](#input\_user\_assigned\_managed\_identity\_client\_id)

Description: The client ID of an existing user assigned managed identity.  
Only required if `user_assigned_managed_identity_creation_enabled` is `false`.

For Azure DevOps with UAMI authentication, this identity must also be configured  
as a service principal in your Azure DevOps organization.

Type: `string`

Default: `null`

### <a name="input_user_assigned_managed_identity_creation_enabled"></a> [user\_assigned\_managed\_identity\_creation\_enabled](#input\_user\_assigned\_managed\_identity\_creation\_enabled)

Description: Whether or not to create a user assigned managed identity.

Type: `bool`

Default: `true`

### <a name="input_user_assigned_managed_identity_id"></a> [user\_assigned\_managed\_identity\_id](#input\_user\_assigned\_managed\_identity\_id)

Description: The resource ID of an existing user assigned managed identity. Only required if `user_assigned_managed_identity_creation_enabled` is `false`.

Type: `string`

Default: `null`

### <a name="input_user_assigned_managed_identity_name"></a> [user\_assigned\_managed\_identity\_name](#input\_user\_assigned\_managed\_identity\_name)

Description: The name of the user assigned managed identity. If null, defaults to `uami-<postfix>`.

Type: `string`

Default: `null`

### <a name="input_user_assigned_managed_identity_principal_id"></a> [user\_assigned\_managed\_identity\_principal\_id](#input\_user\_assigned\_managed\_identity\_principal\_id)

Description: The principal ID of an existing user assigned managed identity. Only required if `user_assigned_managed_identity_creation_enabled` is `false`.

Type: `string`

Default: `null`

### <a name="input_version_control_system_agent_name_prefix"></a> [version\_control\_system\_agent\_name\_prefix](#input\_version\_control\_system\_agent\_name\_prefix)

Description: The prefix for agent/runner names.

Type: `string`

Default: `null`

### <a name="input_version_control_system_agent_target_queue_length"></a> [version\_control\_system\_agent\_target\_queue\_length](#input\_version\_control\_system\_agent\_target\_queue\_length)

Description: The target value for the amount of pending jobs to trigger scaling.

Type: `number`

Default: `1`

### <a name="input_version_control_system_authentication_method"></a> [version\_control\_system\_authentication\_method](#input\_version\_control\_system\_authentication\_method)

Description: The authentication method for the version control system.

For Azure DevOps: `pat` or `uami`  
For GitHub: `pat` or `github_app`

**Important:** This controls how the *runner/agent registers and communicates with GitHub/Azure DevOps*.  
This is separate from how the *Terraform deployment authenticates to Azure* (which uses a Service Principal  
or Managed Identity with Workload Identity Federation via your CI/CD pipeline).

Type: `string`

Default: `"pat"`

### <a name="input_version_control_system_enterprise"></a> [version\_control\_system\_enterprise](#input\_version\_control\_system\_enterprise)

Description: The enterprise name. Required for GitHub when `runner_scope` is `ent`.

Type: `string`

Default: `null`

### <a name="input_version_control_system_github_application_id"></a> [version\_control\_system\_github\_application\_id](#input\_version\_control\_system\_github\_application\_id)

Description: The GitHub App ID. Required when `authentication_method` is `github_app`.

The GitHub App is used by the **runner at runtime** to obtain registration tokens from GitHub.  
This is NOT the same as the Azure AD App Registration used for Terraform/Azure authentication.

Type: `string`

Default: `""`

### <a name="input_version_control_system_github_application_installation_id"></a> [version\_control\_system\_github\_application\_installation\_id](#input\_version\_control\_system\_github\_application\_installation\_id)

Description: The GitHub App installation ID. Required when `authentication_method` is `github_app`.

Type: `string`

Default: `""`

### <a name="input_version_control_system_github_application_key"></a> [version\_control\_system\_github\_application\_key](#input\_version\_control\_system\_github\_application\_key)

Description: The GitHub App private key. Required when `authentication_method` is `github_app`.

Type: `string`

Default: `null`

### <a name="input_version_control_system_github_url"></a> [version\_control\_system\_github\_url](#input\_version\_control\_system\_github\_url)

Description: The base URL for GitHub. Use `github.com` for standard GitHub, or `<subdomain>.ghe.com` for GitHub Enterprise Cloud with data residency.

Type: `string`

Default: `"github.com"`

### <a name="input_version_control_system_personal_access_token"></a> [version\_control\_system\_personal\_access\_token](#input\_version\_control\_system\_personal\_access\_token)

Description: The personal access token for the version control system. Required when `authentication_method` is `pat`.

For **Azure DevOps**: a PAT with `Agent Pools (Read & manage)` scope.  
For **GitHub**: a classic PAT with `repo` and `admin:org` scopes (or fine-grained with equivalent).

This token is used by the **runner/agent at runtime** to register with and poll for jobs from the VCS platform.  
It is NOT used for Terraform authentication to Azure.

Type: `string`

Default: `null`

### <a name="input_version_control_system_placeholder_agent_name"></a> [version\_control\_system\_placeholder\_agent\_name](#input\_version\_control\_system\_placeholder\_agent\_name)

Description: The placeholder agent name.

Type: `string`

Default: `null`

### <a name="input_version_control_system_pool_name"></a> [version\_control\_system\_pool\_name](#input\_version\_control\_system\_pool\_name)

Description: The name of the agent pool. Required for Azure DevOps.

Type: `string`

Default: `null`

### <a name="input_version_control_system_repository"></a> [version\_control\_system\_repository](#input\_version\_control\_system\_repository)

Description: The repository name. Required for GitHub when `runner_scope` is `repo`.

Type: `string`

Default: `null`

### <a name="input_version_control_system_runner_group"></a> [version\_control\_system\_runner\_group](#input\_version\_control\_system\_runner\_group)

Description: The runner group to add the runner to. GitHub only.

Type: `string`

Default: `null`

### <a name="input_version_control_system_runner_scope"></a> [version\_control\_system\_runner\_scope](#input\_version\_control\_system\_runner\_scope)

Description: The scope of the GitHub runner. Must be `ent`, `org`, or `repo`. Ignored for Azure DevOps.

Type: `string`

Default: `"repo"`

## Outputs

The following outputs are exported:

### <a name="output_container_app_environment_name"></a> [container\_app\_environment\_name](#output\_container\_app\_environment\_name)

Description: The name of the container app environment.

### <a name="output_container_app_environment_resource_id"></a> [container\_app\_environment\_resource\_id](#output\_container\_app\_environment\_resource\_id)

Description: The resource ID of the container app environment.

### <a name="output_container_app_job_name"></a> [container\_app\_job\_name](#output\_container\_app\_job\_name)

Description: The name of the container app job.

### <a name="output_container_app_job_resource_id"></a> [container\_app\_job\_resource\_id](#output\_container\_app\_job\_resource\_id)

Description: The resource ID of the container app job.

### <a name="output_container_registry_login_server"></a> [container\_registry\_login\_server](#output\_container\_registry\_login\_server)

Description: The container registry login server.

### <a name="output_container_registry_name"></a> [container\_registry\_name](#output\_container\_registry\_name)

Description: The container registry name.

### <a name="output_container_registry_resource_id"></a> [container\_registry\_resource\_id](#output\_container\_registry\_resource\_id)

Description: The container registry resource ID.

### <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name)

Description: The name of the resource group.

### <a name="output_user_assigned_managed_identity_client_id"></a> [user\_assigned\_managed\_identity\_client\_id](#output\_user\_assigned\_managed\_identity\_client\_id)

Description: The client ID of the user assigned managed identity.

### <a name="output_user_assigned_managed_identity_id"></a> [user\_assigned\_managed\_identity\_id](#output\_user\_assigned\_managed\_identity\_id)

Description: The resource ID of the user assigned managed identity.

### <a name="output_user_assigned_managed_identity_principal_id"></a> [user\_assigned\_managed\_identity\_principal\_id](#output\_user\_assigned\_managed\_identity\_principal\_id)

Description: The principal ID of the user assigned managed identity.

## Modules

The following Modules are called:

### <a name="module_container_app_job"></a> [container\_app\_job](#module\_container\_app\_job)

Source: ./modules/container-app-job

Version:

### <a name="module_container_registry"></a> [container\_registry](#module\_container\_registry)

Source: ./modules/container-registry

Version:

### <a name="module_log_analytics_workspace"></a> [log\_analytics\_workspace](#module\_log\_analytics\_workspace)

Source: Azure/avm-res-operationalinsights-workspace/azurerm

Version: 0.4.2

### <a name="module_user_assigned_managed_identity"></a> [user\_assigned\_managed\_identity](#module\_user\_assigned\_managed\_identity)

Source: Azure/avm-res-managedidentity-userassignedidentity/azurerm

Version: 0.3.3

<!-- markdownlint-disable-next-line MD041 -->
## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at <https://go.microsoft.com/fwlink/?LinkID=824704>. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.
<!-- END_TF_DOCS -->