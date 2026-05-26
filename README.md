# Self-Hosted CI/CD Runners for Azure Landing Zone Corp

ALZ Corp subscriptions route all traffic through a central Azure Firewall and have no public IPs. The upstream [AVM CI/CD pattern module](https://github.com/Azure/terraform-azurerm-avm-ptn-cicd-agents-and-runners) creates its own VNet, NAT Gateway, and Public IP, which conflicts with that setup.

This module removes those networking components and deploys self-hosted **GitHub Actions Runners** or **Azure DevOps Agents** on **Azure Container Apps**, using the VNet and subnets your landing zone already provides.

Works with:

- [ALZ Terraform Modules](https://github.com/Azure/terraform-azurerm-caf-enterprise-scale) for platform landing zone
- [ALZ Vending Module](https://github.com/Azure/terraform-azurerm-lz-vending) for subscription vending (provides Resource Group, VNet, subnets)
- [Azure Virtual Network Manager (AVNM)](https://learn.microsoft.com/azure/virtual-network-manager/overview) for hub-spoke connectivity
- Azure Firewall for central egress (see [FIREWALL-RULES.md](./FIREWALL-RULES.md))

> Forked from [Azure/terraform-azurerm-avm-ptn-cicd-agents-and-runners](https://github.com/Azure/terraform-azurerm-avm-ptn-cicd-agents-and-runners) and adapted for ALZ Corp.

---

## Quick Start

Minimal example: GitHub runners with PAT auth in an ALZ Corp subscription.

```hcl
module "github_runners" {
  source  = "martinopedal/github-runners-alz-corp/azurerm"

  postfix  = "ghrun"
  location = "swedencentral"

  # Subnets from ALZ Vending Module
  container_app_subnet_id                      = module.lz_vending.subnets["aca"].id
  container_registry_private_endpoint_subnet_id = module.lz_vending.subnets["pe"].id

  # GitHub
  version_control_system_type                  = "github"
  version_control_system_organization          = "my-org"
  version_control_system_repository            = "my-repo"
  version_control_system_personal_access_token = var.github_pat
}
```

Then reference the runner in your workflow:

```yaml
jobs:
  deploy:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      - run: terraform plan
```

See [Usage examples](#usage---github-runners-with-pat) below for GitHub App auth, Azure DevOps PAT, and Azure DevOps UAMI.

---

## ALZ Provides vs. This Module Creates

| Resource | ALZ / Platform team | This module |
|---|---|---|
| Virtual Network + Subnets | Yes (Vending Module) | No |
| Hub-spoke connectivity | Yes (AVNM) | No |
| Azure Firewall + egress rules | Yes (Platform team, see [FIREWALL-RULES.md](./FIREWALL-RULES.md)) | No |
| Private DNS for `privatelink.azurecr.io` | Yes (central DNS or Azure Policy) | No |
| NAT Gateway / Public IP | Not needed | Not created |
| Resource Group | Optional (Vending Module can provide) | Yes (optional) |
| Azure Container Registry (Premium, private) | N/A | Yes |
| Container App Environment (internal) | N/A | Yes |
| Container App Job (KEDA-scaled) | N/A | Yes |
| User Assigned Managed Identity | N/A | Yes |
| Log Analytics Workspace | N/A | Yes |

---

## Authentication

This module involves **two separate authentication layers** that serve different purposes.
These are frequently confused, so this section explains each one.

### Layer 1: Terraform to Azure (Infrastructure Deployment)

**"How does Terraform authenticate to Azure to create the resources?"**

This is handled **outside this module** - in your CI/CD pipeline or local environment:

| Method | When to Use | How |
|---|---|---|
| **Workload Identity Federation (OIDC)** | CI/CD pipelines (recommended) | `ARM_CLIENT_ID` + `ARM_TENANT_ID` + `ARM_SUBSCRIPTION_ID` + `ARM_OIDC_TOKEN`/`ARM_OIDC_REQUEST_*` |
| **Service Principal + Client Secret** | CI/CD pipelines (legacy) | `ARM_CLIENT_ID` + `ARM_CLIENT_SECRET` + `ARM_TENANT_ID` + `ARM_SUBSCRIPTION_ID` |
| **Managed Identity** | Azure-hosted deployment agents | `ARM_USE_MSI = true` |
| **Azure CLI** | Local development | `az login` before `terraform apply` |

> **This module does NOT configure Terraform authentication.** That's your pipeline's responsibility.

### Layer 2: Runner/Agent to VCS Platform (Runtime Registration)

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

### Layer 3: Runner/Agent UAMI to Azure Resources (Workload Access)

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

```mermaid
flowchart TB
    subgraph Platform["ALZ Platform (Connectivity Subscription)"]
        FW["Azure Firewall\negress"]
        AVNM["AVNM\nHub-Spoke"]
        DNS["Central DNS\nprivatelink.azurecr.io"]
    end

    subgraph Corp["ALZ Corp Subscription (from Vending Module)"]
        subgraph VNet["VNet (from Vending, connected via AVNM)"]
            subgraph ACASnet["Subnet: ACA\nDelegated: Microsoft.App/environments"]
                CAE["Container App Environment\n(internal/private)"]
                CAJ["Container App Job\n(KEDA-scaled runner/agent)"]
                UAMI["User Assigned\nManaged Identity"]
            end
            subgraph PESnet["Subnet: Private Endpoints"]
                ACRPE["ACR Private Endpoint"]
            end
        end
        ACR["Azure Container Registry\n(Premium, private)"]
        LA["Log Analytics\nWorkspace"]
    end

    VCS(("GitHub / Azure DevOps"))

    CAJ -->|"Pull image\n(UAMI + AcrPull)"| ACR
    ACR --- ACRPE
    ACRPE -.->|"privatelink.azurecr.io"| DNS
    CAJ -.->|"Egress via UDR"| FW
    FW -->|"FQDN filtered"| VCS
    VCS -->|"KEDA polls\nfor queued jobs"| CAJ
    CAJ -->|"Logs"| LA
    AVNM ---|"Hub-Spoke\npeering"| VNet
```

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

## Usage - GitHub Runners with PAT

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

## Usage - Azure DevOps Agents with UAMI

```hcl
module "azuredevops_agents" {
  source  = "martinopedal/github-runners-alz-corp/azurerm"

  postfix  = "adoagt"
  location = "swedencentral"

  # ALZ Corp networking
  container_app_subnet_id                    = module.lz_vending.subnets["aca"].id
  container_registry_private_endpoint_subnet_id = module.lz_vending.subnets["pe"].id

  # Azure DevOps configuration - UAMI (no PAT needed)
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

## Usage - GitHub Runners with GitHub App Auth

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

1. **Image Build** - ACR Task builds the runner/agent image from
   [Azure/avm-container-images-cicd-agents-and-runners](https://github.com/Azure/avm-container-images-cicd-agents-and-runners)
   (or your custom image)
2. **Idle** - Container App Job scales to zero. No runners running, no compute cost.
3. **Job Queued** - A workflow/pipeline is triggered in GitHub or Azure DevOps
4. **KEDA Scales Up** - The KEDA scaler starts an ephemeral Container App Job execution. By default this is the `github-runner` / `azure-pipelines` scaler **polling** the VCS API every `container_app_polling_interval_seconds`. For sub-second scale-up with no API polling, enable [webhook-driven scaling](./WEBHOOKS.md) (`webhook_scaling_enabled = true`) — KEDA then scales on a private Storage Queue fed by your webhook receiver.
5. **Runner Registers** - The container registers as a runner/agent, picks up the job, runs it
6. **Runner Terminates** - After the job completes, the ephemeral container terminates
7. **Scale to Zero** - If no more jobs are queued, KEDA scales back down

---

## Scaling modes

| Mode | Trigger | Latency | API load | Extra moving parts |
|---|---|---|---|---|
| **Polling** (default) | KEDA polls GitHub/AzDO every 30s | 0-30s | Each runner counts against API rate limit | None |
| **Webhook** (`webhook_scaling_enabled = true`) | GitHub/AzDO webhook → your receiver → Storage Queue → KEDA `azure-queue` scaler | ~queue poll interval | Zero polling against VCS | Storage Account + Queue (this module) + a webhook receiver you host (Function/Logic App/APIM — out of module) |

Full details, receiver contract, and a sample Function in [WEBHOOKS.md](./WEBHOOKS.md).

---

## Runner Image - What's Included (and What's Not)

The default image is **not** the same as GitHub's `ubuntu-latest` hosted runner. GitHub-hosted `ubuntu-latest` is ~80 GB with Docker, Node, Python, .NET, Java, Buildah, Chrome and dozens of other tools preinstalled. Self-hosted runners on Azure Container Apps use a minimal image instead.

The default image is built from [`Azure/avm-container-images-cicd-agents-and-runners`](https://github.com/Azure/avm-container-images-cicd-agents-and-runners) (`github-runner-aca` / `azure-devops-agent-aca`) and contains:

| Included | Not included |
|---|---|
| Base: `mcr.microsoft.com/azure-powershell:ubuntu-22.04` (at the pinned commit `221742d`) | ❌ Docker / `docker-ce-cli` |
| `git`, `curl`, `jq`, `unzip`, `ca-certificates` | ❌ Buildah, Kaniko, Podman |
| `nodejs`, `ruby` | ❌ Python, .NET SDK, Java, Go |
| `azure-cli`, PowerShell (`pwsh`) | ❌ Chrome, Firefox, browsers |
| GitHub Actions runner / Azure Pipelines agent binaries | ❌ Most things `ubuntu-latest` ships |

> The default image is pinned via `default_image_repository_commit`. If you bump the commit, also update `default_image_registry_dockerfile_path` — upstream renamed the file from `dockerfile` to `Dockerfile` after `221742d`, and ACR Tasks run on a case-sensitive filesystem.

### Base image choice — why not Alpine?

Don't. The GitHub Actions runner and Azure Pipelines agent are built against **glibc**; Alpine uses **musl**. `actions/setup-node`, `setup-python`, `setup-dotnet` all ship glibc binaries and fail on Alpine with cryptic loader errors. Most Marketplace actions are Node-based and also break. The size win is fake once the runner payload is in. If you maintain a custom image, the sensible bases are Ubuntu 24.04, Debian 12-slim, or **Azure Linux 3.0** (`mcr.microsoft.com/azurelinux/base/core:3.0`) — Microsoft-published, hardened, glibc, ~110 MB.

### Why no Docker?

Azure Container Apps Jobs run in a sandboxed environment that does not allow privileged containers, so traditional Docker-in-Docker (DinD) does not work. Workflow steps cannot `apt-get install docker.io` and then `docker build` — the daemon will not start.

### What to do instead

1. **Build a custom runner image** — extend the default image with the tools you need (Docker CLI talking to a remote daemon, Buildah, Python, etc.) and pass it via `custom_container_registry_images` + `use_default_container_image = false`. See [`variables.container.registry.tf`](./variables.container.registry.tf).
2. **Delegate container image builds to ACR Tasks** — instead of `docker build` in the workflow, call `az acr build` from the runner. The build runs in ACR, not in the runner. Recommended for most "I just want to build a container image" cases.
3. **Use rootless Buildah or Kaniko** — add either to a custom runner image for OCI image builds without a Docker daemon.

If your customer needs `ubuntu-latest`-equivalent tooling, point them at GitHub-hosted runners — not self-hosted. Self-hosted is for jobs that need network access into the landing zone or specific tooling, not for replicating the full hosted-runner toolbox.

---

## Using the runners — workflow examples

Drop-in workflow files live under [`docs/workflow-examples/`](./docs/workflow-examples/):

- [`container-build.yml`](./docs/workflow-examples/container-build.yml) — build & push to ACR via `az acr build` (no Docker daemon needed)
- [`terraform-apply.yml`](./docs/workflow-examples/terraform-apply.yml) — Terraform plan/apply using `ARM_USE_MSI=true` and the runner UAMI for Azure auth

Both authenticate to Azure via the runner's managed identity — no PATs or client secrets to manage.

---

## Examples

| Example | Description |
|---|---|
| [github_runners_pat](./examples/github_runners_pat/) | GitHub runners with PAT authentication |
| [github_runners_app_auth](./examples/github_runners_app_auth/) | GitHub runners with GitHub App authentication |
| [github_runners_webhook](./examples/github_runners_webhook/) | GitHub runners with webhook-driven scaling (Storage Queue + receiver) |
| [azuredevops_agents_pat](./examples/azuredevops_agents_pat/) | Azure DevOps agents with PAT authentication |
| [azuredevops_agents_uami](./examples/azuredevops_agents_uami/) | Azure DevOps agents with UAMI (no secrets) |

---

<!-- BEGIN_TF_DOCS -->
<!-- Code generated by terraform-docs. DO NOT EDIT. -->

<!-- markdownlint-disable MD033 -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_azapi"></a> [azapi](#requirement\_azapi) | ~> 2.8 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 4.20 |
| <a name="requirement_modtm"></a> [modtm](#requirement\_modtm) | ~> 0.3 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.5 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.12 |

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_container_app_environment.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_app_environment) | resource |
| [azurerm_management_lock.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_lock) | resource |
| [azurerm_resource_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_role_assignment.custom_container_registry_pull](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [modtm_telemetry.telemetry](https://registry.terraform.io/providers/azure/modtm/latest/docs/resources/telemetry) | resource |
| [random_uuid.telemetry](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/uuid) | resource |
| [time_sleep.delay_after_container_app_environment_creation](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [time_sleep.delay_after_container_image_build](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [azapi_client_config.telemetry](https://registry.terraform.io/providers/Azure/azapi/latest/docs/data-sources/client_config) | data source |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |
| [modtm_module_source.telemetry](https://registry.terraform.io/providers/azure/modtm/latest/docs/data-sources/module_source) | data source |

<!-- markdownlint-disable MD013 -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_container_app_subnet_id"></a> [container\_app\_subnet\_id](#input\_container\_app\_subnet\_id) | The resource ID of the subnet for the Container App Environment. Must have delegation for `Microsoft.App/environments`. Provided by ALZ Vending Module. | `string` | n/a | yes |
| <a name="input_container_registry_private_endpoint_subnet_id"></a> [container\_registry\_private\_endpoint\_subnet\_id](#input\_container\_registry\_private\_endpoint\_subnet\_id) | The resource ID of the subnet for the Container Registry private endpoint. Provided by ALZ Vending Module. | `string` | n/a | yes |
| <a name="input_location"></a> [location](#input\_location) | Azure region where the resource should be deployed. | `string` | n/a | yes |
| <a name="input_postfix"></a> [postfix](#input\_postfix) | A postfix used to build default names if no name has been supplied for a specific resource type. | `string` | n/a | yes |
| <a name="input_version_control_system_organization"></a> [version\_control\_system\_organization](#input\_version\_control\_system\_organization) | The organization for the version control system. For Azure DevOps: the full URL (e.g. `https://dev.azure.com/my-org`). For GitHub: the organization name. | `string` | n/a | yes |
| <a name="input_version_control_system_type"></a> [version\_control\_system\_type](#input\_version\_control\_system\_type) | The type of the version control system. Allowed values are `azuredevops` or `github`. | `string` | n/a | yes |
| <a name="input_container_app_container_cpu"></a> [container\_app\_container\_cpu](#input\_container\_app\_container\_cpu) | Required CPU in cores, e.g. 0.5 | `number` | `1` | no |
| <a name="input_container_app_container_memory"></a> [container\_app\_container\_memory](#input\_container\_app\_container\_memory) | Required memory, e.g. '250Mb' | `string` | `"2Gi"` | no |
| <a name="input_container_app_environment_creation_enabled"></a> [container\_app\_environment\_creation\_enabled](#input\_container\_app\_environment\_creation\_enabled) | Whether or not to create a Container App Environment. | `bool` | `true` | no |
| <a name="input_container_app_environment_id"></a> [container\_app\_environment\_id](#input\_container\_app\_environment\_id) | The resource id of the Container App Environment. Only required if `container_app_environment_creation_enabled` is `false`. | `string` | `null` | no |
| <a name="input_container_app_environment_name"></a> [container\_app\_environment\_name](#input\_container\_app\_environment\_name) | The name of the Container App Environment. Only required if `container_app_environment_creation_enabled` is `true`. | `string` | `null` | no |
| <a name="input_container_app_environment_variables"></a> [container\_app\_environment\_variables](#input\_container\_app\_environment\_variables) | List of additional environment variables to pass to the container. | <pre>set(object({<br/>    name  = string<br/>    value = string<br/>  }))</pre> | `[]` | no |
| <a name="input_container_app_infrastructure_resource_group_name"></a> [container\_app\_infrastructure\_resource\_group\_name](#input\_container\_app\_infrastructure\_resource\_group\_name) | The name of the resource group where the Container Apps infrastructure is deployed. | `string` | `null` | no |
| <a name="input_container_app_job_container_name"></a> [container\_app\_job\_container\_name](#input\_container\_app\_job\_container\_name) | The name of the container for the runner Container Apps job. | `string` | `null` | no |
| <a name="input_container_app_job_name"></a> [container\_app\_job\_name](#input\_container\_app\_job\_name) | The name of the Container App runner job. | `string` | `null` | no |
| <a name="input_container_app_max_execution_count"></a> [container\_app\_max\_execution\_count](#input\_container\_app\_max\_execution\_count) | The maximum number of executions (ADO jobs) to spawn per polling interval. | `number` | `100` | no |
| <a name="input_container_app_min_execution_count"></a> [container\_app\_min\_execution\_count](#input\_container\_app\_min\_execution\_count) | The minimum number of executions (ADO jobs) to spawn per polling interval. | `number` | `0` | no |
| <a name="input_container_app_placeholder_container_name"></a> [container\_app\_placeholder\_container\_name](#input\_container\_app\_placeholder\_container\_name) | The name of the container for the placeholder Container Apps job. | `string` | `null` | no |
| <a name="input_container_app_placeholder_job_name"></a> [container\_app\_placeholder\_job\_name](#input\_container\_app\_placeholder\_job\_name) | The name of the Container App placeholder job. | `string` | `null` | no |
| <a name="input_container_app_placeholder_replica_retry_limit"></a> [container\_app\_placeholder\_replica\_retry\_limit](#input\_container\_app\_placeholder\_replica\_retry\_limit) | The number of times to retry the placeholder Container Apps job. | `number` | `0` | no |
| <a name="input_container_app_placeholder_replica_timeout"></a> [container\_app\_placeholder\_replica\_timeout](#input\_container\_app\_placeholder\_replica\_timeout) | The timeout in seconds for the placeholder Container Apps job. | `number` | `300` | no |
| <a name="input_container_app_polling_interval_seconds"></a> [container\_app\_polling\_interval\_seconds](#input\_container\_app\_polling\_interval\_seconds) | How often should the pipeline queue be checked for new events, in seconds. | `number` | `30` | no |
| <a name="input_container_app_replica_retry_limit"></a> [container\_app\_replica\_retry\_limit](#input\_container\_app\_replica\_retry\_limit) | The number of times to retry the runner Container Apps job. | `number` | `3` | no |
| <a name="input_container_app_replica_timeout"></a> [container\_app\_replica\_timeout](#input\_container\_app\_replica\_timeout) | The timeout in seconds for the runner Container Apps job. | `number` | `1800` | no |
| <a name="input_container_app_sensitive_environment_variables"></a> [container\_app\_sensitive\_environment\_variables](#input\_container\_app\_sensitive\_environment\_variables) | List of additional sensitive environment variables to pass to the container. | <pre>set(object({<br/>    name                      = string<br/>    value                     = string<br/>    container_app_secret_name = string<br/>    keda_auth_name            = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_container_registry_creation_enabled"></a> [container\_registry\_creation\_enabled](#input\_container\_registry\_creation\_enabled) | Whether or not to create a container registry. | `bool` | `true` | no |
| <a name="input_container_registry_dns_zone_id"></a> [container\_registry\_dns\_zone\_id](#input\_container\_registry\_dns\_zone\_id) | The ID of the private DNS zone for the container registry (`privatelink.azurecr.io`). If null, DNS resolution is assumed to be handled by Azure Policy or central DNS infrastructure. | `string` | `null` | no |
| <a name="input_container_registry_name"></a> [container\_registry\_name](#input\_container\_registry\_name) | The name of the container registry. If null, defaults to `acr<postfix>`. | `string` | `null` | no |
| <a name="input_custom_container_registry_id"></a> [custom\_container\_registry\_id](#input\_custom\_container\_registry\_id) | The ID of an existing container registry. Only used if `container_registry_creation_enabled` is `false`. | `string` | `null` | no |
| <a name="input_custom_container_registry_images"></a> [custom\_container\_registry\_images](#input\_custom\_container\_registry\_images) | Custom images to build in the container registry. Only relevant if `container_registry_creation_enabled` is `true` and `use_default_container_image` is `false`.<br/><br/>- `task_name` - Name of the ACR build task<br/>- `dockerfile_path` - Path to the Dockerfile (e.g. `dockerfile`)<br/>- `context_path` - Context in format `<repository-url>#<commit>:<folder-path>`<br/>- `context_access_token` - Access token for the context repository<br/>- `image_names` - List of image names to build (e.g. `["image-name:tag"]`) | <pre>map(object({<br/>    task_name            = string<br/>    dockerfile_path      = string<br/>    context_path         = string<br/>    context_access_token = optional(string, "a")<br/>    image_names          = list(string)<br/>  }))</pre> | `null` | no |
| <a name="input_custom_container_registry_login_server"></a> [custom\_container\_registry\_login\_server](#input\_custom\_container\_registry\_login\_server) | The login server of an existing container registry. Required if `container_registry_creation_enabled` is `false`. | `string` | `null` | no |
| <a name="input_custom_container_registry_password"></a> [custom\_container\_registry\_password](#input\_custom\_container\_registry\_password) | The password for an existing container registry. | `string` | `null` | no |
| <a name="input_custom_container_registry_username"></a> [custom\_container\_registry\_username](#input\_custom\_container\_registry\_username) | The username for an existing container registry. | `string` | `null` | no |
| <a name="input_default_image_name"></a> [default\_image\_name](#input\_default\_image\_name) | The default image name. If null, auto-detected from `version_control_system_type`. | `string` | `null` | no |
| <a name="input_default_image_registry_dockerfile_path"></a> [default\_image\_registry\_dockerfile\_path](#input\_default\_image\_registry\_dockerfile\_path) | The Dockerfile path for the default image build. | `string` | `"dockerfile"` | no |
| <a name="input_default_image_repository_commit"></a> [default\_image\_repository\_commit](#input\_default\_image\_repository\_commit) | The commit SHA of the default image repository. | `string` | `"221742d"` | no |
| <a name="input_default_image_repository_folder_paths"></a> [default\_image\_repository\_folder\_paths](#input\_default\_image\_repository\_folder\_paths) | Map of image type to folder path in the default image repository. | `map(string)` | <pre>{<br/>  "azuredevops-container-app": "azure-devops-agent-aca",<br/>  "github-container-app": "github-runner-aca"<br/>}</pre> | no |
| <a name="input_default_image_repository_url"></a> [default\_image\_repository\_url](#input\_default\_image\_repository\_url) | The URL of the default image repository. | `string` | `"https://github.com/Azure/avm-container-images-cicd-agents-and-runners"` | no |
| <a name="input_delays"></a> [delays](#input\_delays) | Delays (in seconds) to apply to the module operations. | <pre>object({<br/>    delay_after_container_image_build              = optional(number, 60)<br/>    delay_after_container_app_environment_creation = optional(number, 120)<br/>  })</pre> | `{}` | no |
| <a name="input_enable_telemetry"></a> [enable\_telemetry](#input\_enable\_telemetry) | This variable controls whether or not telemetry is enabled for the module.<br/>For more information see <https://aka.ms/avm/telemetryinfo>.<br/>If it is set to false, then no telemetry will be collected. | `bool` | `true` | no |
| <a name="input_lock"></a> [lock](#input\_lock) | Controls the Resource Lock configuration for this resource. The following properties can be specified:<br/><br/>- `kind` - (Required) The type of lock. Possible values are `"CanNotDelete"` and `"ReadOnly"`.<br/>- `name` - (Optional) The name of the lock. If not specified, a name will be generated based on the `kind` value. | <pre>object({<br/>    kind = string<br/>    name = optional(string, null)<br/>  })</pre> | `null` | no |
| <a name="input_log_analytics_workspace_creation_enabled"></a> [log\_analytics\_workspace\_creation\_enabled](#input\_log\_analytics\_workspace\_creation\_enabled) | Whether or not to create a log analytics workspace. | `bool` | `true` | no |
| <a name="input_log_analytics_workspace_id"></a> [log\_analytics\_workspace\_id](#input\_log\_analytics\_workspace\_id) | The resource Id of the Log Analytics Workspace. | `string` | `null` | no |
| <a name="input_log_analytics_workspace_internet_ingestion_enabled"></a> [log\_analytics\_workspace\_internet\_ingestion\_enabled](#input\_log\_analytics\_workspace\_internet\_ingestion\_enabled) | Whether or not to enable internet ingestion for the Log Analytics workspace. If null, the module defaults this to `false`. | `bool` | `null` | no |
| <a name="input_log_analytics_workspace_internet_query_enabled"></a> [log\_analytics\_workspace\_internet\_query\_enabled](#input\_log\_analytics\_workspace\_internet\_query\_enabled) | Whether or not to enable internet query for the Log Analytics workspace. If null, the module defaults this to `false`. | `bool` | `null` | no |
| <a name="input_log_analytics_workspace_name"></a> [log\_analytics\_workspace\_name](#input\_log\_analytics\_workspace\_name) | The name of the log analytics workspace. Only required if `log_analytics_workspace_creation_enabled == false`. | `string` | `null` | no |
| <a name="input_log_analytics_workspace_retention_in_days"></a> [log\_analytics\_workspace\_retention\_in\_days](#input\_log\_analytics\_workspace\_retention\_in\_days) | The retention period for the Log Analytics Workspace. | `number` | `30` | no |
| <a name="input_log_analytics_workspace_sku"></a> [log\_analytics\_workspace\_sku](#input\_log\_analytics\_workspace\_sku) | The SKU of the Log Analytics Workspace. | `string` | `"PerGB2018"` | no |
| <a name="input_resource_group_creation_enabled"></a> [resource\_group\_creation\_enabled](#input\_resource\_group\_creation\_enabled) | Whether or not to create a resource group. Set to `false` if the resource group is provided by ALZ Vending Module. | `bool` | `true` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | The resource group where the resources will be deployed. Must be specified if `resource_group_creation_enabled == false`. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | (Optional) Tags of the resource. | `map(string)` | `null` | no |
| <a name="input_use_default_container_image"></a> [use\_default\_container\_image](#input\_use\_default\_container\_image) | Whether to use the default container image provided by the module. | `bool` | `true` | no |
| <a name="input_use_zone_redundancy"></a> [use\_zone\_redundancy](#input\_use\_zone\_redundancy) | Enable zone redundancy for the deployment. | `bool` | `true` | no |
| <a name="input_user_assigned_managed_identity_client_id"></a> [user\_assigned\_managed\_identity\_client\_id](#input\_user\_assigned\_managed\_identity\_client\_id) | The client ID of an existing user assigned managed identity.<br/>Only required if `user_assigned_managed_identity_creation_enabled` is `false`.<br/><br/>For Azure DevOps with UAMI authentication, this identity must also be configured<br/>as a service principal in your Azure DevOps organization. | `string` | `null` | no |
| <a name="input_user_assigned_managed_identity_creation_enabled"></a> [user\_assigned\_managed\_identity\_creation\_enabled](#input\_user\_assigned\_managed\_identity\_creation\_enabled) | Whether or not to create a user assigned managed identity. | `bool` | `true` | no |
| <a name="input_user_assigned_managed_identity_id"></a> [user\_assigned\_managed\_identity\_id](#input\_user\_assigned\_managed\_identity\_id) | The resource ID of an existing user assigned managed identity. Only required if `user_assigned_managed_identity_creation_enabled` is `false`. | `string` | `null` | no |
| <a name="input_user_assigned_managed_identity_name"></a> [user\_assigned\_managed\_identity\_name](#input\_user\_assigned\_managed\_identity\_name) | The name of the user assigned managed identity. If null, defaults to `uami-<postfix>`. | `string` | `null` | no |
| <a name="input_user_assigned_managed_identity_principal_id"></a> [user\_assigned\_managed\_identity\_principal\_id](#input\_user\_assigned\_managed\_identity\_principal\_id) | The principal ID of an existing user assigned managed identity. Only required if<br/>`user_assigned_managed_identity_creation_enabled` is `false` AND the module needs<br/>to assign RBAC to that identity (currently: when `webhook_scaling_enabled = true`,<br/>the identity is granted `Storage Queue Data Reader` on the webhook Storage Account). | `string` | `null` | no |
| <a name="input_version_control_system_agent_name_prefix"></a> [version\_control\_system\_agent\_name\_prefix](#input\_version\_control\_system\_agent\_name\_prefix) | The prefix for agent/runner names. | `string` | `null` | no |
| <a name="input_version_control_system_agent_target_queue_length"></a> [version\_control\_system\_agent\_target\_queue\_length](#input\_version\_control\_system\_agent\_target\_queue\_length) | The target value for the amount of pending jobs to trigger scaling. | `number` | `1` | no |
| <a name="input_version_control_system_authentication_method"></a> [version\_control\_system\_authentication\_method](#input\_version\_control\_system\_authentication\_method) | The authentication method for the version control system.<br/><br/>For Azure DevOps: `pat` or `uami`<br/>For GitHub: `pat` or `github_app`<br/><br/>**Important:** This controls how the *runner/agent registers and communicates with GitHub/Azure DevOps*.<br/>This is separate from how the *Terraform deployment authenticates to Azure* (which uses a Service Principal<br/>or Managed Identity with Workload Identity Federation via your CI/CD pipeline). | `string` | `"pat"` | no |
| <a name="input_version_control_system_enterprise"></a> [version\_control\_system\_enterprise](#input\_version\_control\_system\_enterprise) | The enterprise name. Required for GitHub when `runner_scope` is `ent`. | `string` | `null` | no |
| <a name="input_version_control_system_github_application_id"></a> [version\_control\_system\_github\_application\_id](#input\_version\_control\_system\_github\_application\_id) | The GitHub App ID. Required when `authentication_method` is `github_app`.<br/><br/>The GitHub App is used by the **runner at runtime** to obtain registration tokens from GitHub.<br/>This is NOT the same as the Azure AD App Registration used for Terraform/Azure authentication. | `string` | `""` | no |
| <a name="input_version_control_system_github_application_installation_id"></a> [version\_control\_system\_github\_application\_installation\_id](#input\_version\_control\_system\_github\_application\_installation\_id) | The GitHub App installation ID. Required when `authentication_method` is `github_app`. | `string` | `""` | no |
| <a name="input_version_control_system_github_application_key"></a> [version\_control\_system\_github\_application\_key](#input\_version\_control\_system\_github\_application\_key) | The GitHub App private key. Required when `authentication_method` is `github_app`. | `string` | `null` | no |
| <a name="input_version_control_system_github_url"></a> [version\_control\_system\_github\_url](#input\_version\_control\_system\_github\_url) | The base URL for GitHub. Use `github.com` for standard GitHub, or `<subdomain>.ghe.com` for GitHub Enterprise Cloud with data residency. | `string` | `"github.com"` | no |
| <a name="input_version_control_system_personal_access_token"></a> [version\_control\_system\_personal\_access\_token](#input\_version\_control\_system\_personal\_access\_token) | The personal access token for the version control system. Required when `authentication_method` is `pat`.<br/><br/>For **Azure DevOps**: a PAT with `Agent Pools (Read & manage)` scope.<br/>For **GitHub**: a classic PAT with `repo` and `admin:org` scopes (or fine-grained with equivalent).<br/><br/>This token is used by the **runner/agent at runtime** to register with and poll for jobs from the VCS platform.<br/>It is NOT used for Terraform authentication to Azure. | `string` | `null` | no |
| <a name="input_version_control_system_placeholder_agent_name"></a> [version\_control\_system\_placeholder\_agent\_name](#input\_version\_control\_system\_placeholder\_agent\_name) | The placeholder agent name. | `string` | `null` | no |
| <a name="input_version_control_system_pool_name"></a> [version\_control\_system\_pool\_name](#input\_version\_control\_system\_pool\_name) | The name of the agent pool. Required for Azure DevOps. | `string` | `null` | no |
| <a name="input_version_control_system_repository"></a> [version\_control\_system\_repository](#input\_version\_control\_system\_repository) | The repository name. Required for GitHub when `runner_scope` is `repo`. | `string` | `null` | no |
| <a name="input_version_control_system_runner_group"></a> [version\_control\_system\_runner\_group](#input\_version\_control\_system\_runner\_group) | The runner group to add the runner to. GitHub only. | `string` | `null` | no |
| <a name="input_version_control_system_runner_scope"></a> [version\_control\_system\_runner\_scope](#input\_version\_control\_system\_runner\_scope) | The scope of the GitHub runner. Must be `ent`, `org`, or `repo`. Ignored for Azure DevOps. | `string` | `"repo"` | no |
| <a name="input_webhook_queue_length_per_runner"></a> [webhook\_queue\_length\_per\_runner](#input\_webhook\_queue\_length\_per\_runner) | KEDA `queueLength` metadata - how many messages in the queue trigger one additional runner. Default `1` means one runner per queued job. Only used when `webhook_scaling_enabled` is `true`. | `number` | `1` | no |
| <a name="input_webhook_queue_name"></a> [webhook\_queue\_name](#input\_webhook\_queue\_name) | Name of the Storage Queue used to trigger runner scale-up. Only used when `webhook_scaling_enabled` is `true`. | `string` | `"runner-jobs"` | no |
| <a name="input_webhook_receiver_principal_ids"></a> [webhook\_receiver\_principal\_ids](#input\_webhook\_receiver\_principal\_ids) | Principal IDs (object IDs) of identities that should be granted `Storage Queue Data Message Sender`<br/>on the webhook queue. Typically the managed identity of the Azure Function / Logic App that receives<br/>webhooks and writes to the queue. Only used when `webhook_scaling_enabled` is `true`. | `set(string)` | `[]` | no |
| <a name="input_webhook_scaling_enabled"></a> [webhook\_scaling\_enabled](#input\_webhook\_scaling\_enabled) | Whether to enable webhook-driven scaling instead of the default polling scaler.<br/><br/>When `false` (default), KEDA polls the GitHub/Azure DevOps API every `container_app_polling_interval_seconds`<br/>to detect queued jobs. This is simple but adds 0-30s of latency per job and consumes API rate limit.<br/><br/>When `true`, this module provisions a private Storage Account + Storage Queue, and KEDA scales on<br/>queue length instead. A webhook receiver (out of scope for this module - typically an Azure Function,<br/>Logic App, or APIM policy) must translate GitHub `workflow_job` / Azure DevOps service hook events<br/>into queue messages. See [WEBHOOKS.md](./WEBHOOKS.md) for the receiver contract and a sample Function.<br/><br/>Webhook mode gives sub-second scale-up latency and removes API polling load, at the cost of<br/>operating an additional receiver component. | `bool` | `false` | no |
| <a name="input_webhook_storage_account_name"></a> [webhook\_storage\_account\_name](#input\_webhook\_storage\_account\_name) | Name of the Storage Account that hosts the webhook queue. If null, defaults to `stwh<postfix>` (with hyphens removed). Only used when `webhook_scaling_enabled` is `true`. | `string` | `null` | no |
| <a name="input_webhook_storage_private_endpoint_subnet_id"></a> [webhook\_storage\_private\_endpoint\_subnet\_id](#input\_webhook\_storage\_private\_endpoint\_subnet\_id) | Resource ID of the subnet for the webhook Storage Account private endpoint. If null, falls back to `container_registry_private_endpoint_subnet_id`. Only used when `webhook_scaling_enabled` is `true`. | `string` | `null` | no |
| <a name="input_webhook_storage_queue_dns_zone_id"></a> [webhook\_storage\_queue\_dns\_zone\_id](#input\_webhook\_storage\_queue\_dns\_zone\_id) | ID of the private DNS zone for Storage Queue (`privatelink.queue.core.windows.net`). If null, DNS is assumed to be handled by Azure Policy or central DNS. Only used when `webhook_scaling_enabled` is `true`. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_container_app_environment_name"></a> [container\_app\_environment\_name](#output\_container\_app\_environment\_name) | The name of the container app environment. |
| <a name="output_container_app_environment_resource_id"></a> [container\_app\_environment\_resource\_id](#output\_container\_app\_environment\_resource\_id) | The resource ID of the container app environment. |
| <a name="output_container_app_job_name"></a> [container\_app\_job\_name](#output\_container\_app\_job\_name) | The name of the container app job. |
| <a name="output_container_app_job_resource_id"></a> [container\_app\_job\_resource\_id](#output\_container\_app\_job\_resource\_id) | The resource ID of the container app job. |
| <a name="output_container_registry_login_server"></a> [container\_registry\_login\_server](#output\_container\_registry\_login\_server) | The container registry login server. |
| <a name="output_container_registry_name"></a> [container\_registry\_name](#output\_container\_registry\_name) | The container registry name. |
| <a name="output_container_registry_resource_id"></a> [container\_registry\_resource\_id](#output\_container\_registry\_resource\_id) | The container registry resource ID. |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | The name of the resource group. |
| <a name="output_user_assigned_managed_identity_client_id"></a> [user\_assigned\_managed\_identity\_client\_id](#output\_user\_assigned\_managed\_identity\_client\_id) | The client ID of the user assigned managed identity. |
| <a name="output_user_assigned_managed_identity_id"></a> [user\_assigned\_managed\_identity\_id](#output\_user\_assigned\_managed\_identity\_id) | The resource ID of the user assigned managed identity. |
| <a name="output_user_assigned_managed_identity_principal_id"></a> [user\_assigned\_managed\_identity\_principal\_id](#output\_user\_assigned\_managed\_identity\_principal\_id) | The principal ID of the user assigned managed identity. |
| <a name="output_webhook_queue_messages_endpoint"></a> [webhook\_queue\_messages\_endpoint](#output\_webhook\_queue\_messages\_endpoint) | REST endpoint for the Put Message operation (queue URL + `/messages`). Use this if you are calling the Storage REST API directly rather than via an SDK. `null` when `webhook_scaling_enabled` is `false`. |
| <a name="output_webhook_queue_name"></a> [webhook\_queue\_name](#output\_webhook\_queue\_name) | Name of the Storage Queue used for webhook-driven scaling. `null` when `webhook_scaling_enabled` is `false`. |
| <a name="output_webhook_queue_url"></a> [webhook\_queue\_url](#output\_webhook\_queue\_url) | Queue URL (without `/messages` suffix). Use this with Azure Storage SDKs, e.g. `QueueClient.from_queue_url(...)`. `null` when `webhook_scaling_enabled` is `false`. |
| <a name="output_webhook_storage_account_name"></a> [webhook\_storage\_account\_name](#output\_webhook\_storage\_account\_name) | Name of the Storage Account hosting the webhook queue. `null` when `webhook_scaling_enabled` is `false`. |
| <a name="output_webhook_storage_account_resource_id"></a> [webhook\_storage\_account\_resource\_id](#output\_webhook\_storage\_account\_resource\_id) | Resource ID of the Storage Account hosting the webhook queue. `null` when `webhook_scaling_enabled` is `false`. |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_container_app_job"></a> [container\_app\_job](#module\_container\_app\_job) | ./modules/container-app-job | n/a |
| <a name="module_container_registry"></a> [container\_registry](#module\_container\_registry) | ./modules/container-registry | n/a |
| <a name="module_log_analytics_workspace"></a> [log\_analytics\_workspace](#module\_log\_analytics\_workspace) | Azure/avm-res-operationalinsights-workspace/azurerm | 0.4.2 |
| <a name="module_user_assigned_managed_identity"></a> [user\_assigned\_managed\_identity](#module\_user\_assigned\_managed\_identity) | Azure/avm-res-managedidentity-userassignedidentity/azurerm | 0.3.3 |
| <a name="module_webhook_storage"></a> [webhook\_storage](#module\_webhook\_storage) | Azure/avm-res-storage-storageaccount/azurerm | 0.7.0 |

<!-- markdownlint-disable-next-line MD041 -->
## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at <https://go.microsoft.com/fwlink/?LinkID=824704>. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.

## Built with Azure Verified Modules

This module follows the [Azure Verified Modules (AVM)](https://aka.ms/avm) specification.
AVM modules are open-source, MIT-licensed, and maintained by Microsoft and community contributors.

See [THIRD_PARTY_NOTICES.md](./THIRD_PARTY_NOTICES.md) for full license details of all
incorporated components.
<!-- END_TF_DOCS -->