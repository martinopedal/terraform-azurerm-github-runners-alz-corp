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
<!-- Auto-generated by terraform-docs. Run `terraform-docs markdown .` to regenerate. -->
<!-- END_TF_DOCS -->