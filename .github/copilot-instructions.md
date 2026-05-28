---
description: 'Self-Hosted CI/CD Runners for ALZ Corp - Terraform Module'
applyTo: '**/*.tf, **/*.tfvars, **/*.md'
---

# Copilot Instructions - terraform-azurerm-github-runners-alz-corp

## CANONICAL MODULES - DIRECTIVE (2026-05-28)

**Runner infrastructure is deployed by consuming a canonical module. Raw `resource` declarations for runner Jobs / VMSS in consumer repos are forbidden.** Forks are allowed where they carry features not yet upstream - they are documented below with the exact upstream gap.

### Canonical modules

| # | Module | Use for | Pin |
|---|---|---|---|
| 1 | `github.com/martinopedal/terraform-azurerm-vmss-github-runners-windows` | Windows VMSS runners (sub-1 pool-w-org, sub-5 personal Windows) | `?ref=vX.Y.Z` |
| 2 | `github.com/martinopedal/terraform-azurerm-github-runners-alz-corp` | Linux ACA runners in ALZ Corp subscriptions (sub-1 pool-a1, pool-b-pub) | `?ref=vX.Y.Z` |
| 3 | `Azure/avm-ptn-cicd-agents-and-runners/azurerm` v0.5.1+ | Linux ACA runners - vanilla case (no fork features needed) | `version = "0.6.0"` |
| 4 | `github.com/martinopedal/terraform-azurerm-avm-ptn-cicd-agents-and-runners-personal` | Linux ACA runners in personal estate (sub-5) - fork of #3 with NAT GW retention, BYO LAW for CAE, KEDA label parity | `?ref=v0.6.0-personal.N` |

**Why #4 exists (so future-you doesn't ask again):**
- The personal estate (sub-5) needs NAT Gateway + public IP egress, which upstream #3 supports but personal-runners-infra leans on heavily.
- Personal fork adds: `log_analytics_workspace_resource_id` BYO input for CAE appLogsConfiguration (upstream creates LAW internally with fragile sharedKeys ordering), and 3 KEDA inputs (`version_control_system_keda_labels`, `_no_default_labels`, `_enable_etags`) for label-aware scaling.
- **Forks are permanent canonicals.** Upstream PR branches exist (`feat/byo-log-analytics-workspace-resource-id`, `feat/keda-parity-inputs` on `martinopedal/terraform-azurerm-avm-ptn-cicd-agents-and-runners`) and may be opened later, but #4 is not on a retirement path. If upstream ever catches up, migration is optional, not required.

### Estate → module quick-lookup

| Estate | Linux ACA runners | Windows VMSS runners |
|---|---|---|
| **Personal (sub-5)** | **#4** (personal fork) | **#1** |
| **ALZ Corp (sub-1)** | **#2** (alz-corp module) | **#1** |
| **Any vanilla future consumer** | **#3** (public AVM) | **#1** |

One Windows module covers all estates. Three Linux modules because the shape differs (vanilla / ALZ-corp / personal-with-NAT).

### Consumer rules

**A consumer repo consumes a canonical module - it does not redeclare what the module owns.** Consumer repos legitimately need: `main.tf` (module block + provider/backend), `variables.tf`, `terraform.tfvars`, `data.tf` (BYO lookups), `outputs.tf`, plus workflows, READMEs, scripts. They do NOT need raw runner Job / VMSS resources.

- ✅ `module "runners" { source = "<one-of-the-four>"; ... }`
- ✅ `data` blocks for BYO RG/CAE/UAMI/LAW/ACR/KV/subnets
- ✅ `terraform`, `provider`, `backend` blocks
- ✅ Supporting infra the module is intentionally NOT responsible for (spoke networking before ALZ Vending, custom monitoring, KV with App secrets, ACR-specific config)
- ❌ No `resource "azurerm_container_app_job"` / `azapi_resource "job"` / `azurerm_linux_virtual_machine_scale_set` for the runner Job/VMSS itself
- ❌ No `azapi_update_resource` patches against live module-owned resources - if the module is missing a field, PR the module (or its fork)
- ❌ No `null_resource` / `local-exec` workarounds against the runner Job/VMSS - same rule
- ❌ No orchestration scripts that mutate runner state out-of-band
- ❌ No raw `Azure/avm-res-compute-virtualmachinescaleset/azurerm` for runner VMSS - use canonical #1; it wraps the AVM compute module with runner-specific glue (DSC bootstrap, KV, RBAC, GitHub registration)

### Compliance status (audited 2026-05-28)

| Pool | Repo | Status | Action |
|---|---|---|---|
| `caj-a1-runner` | alz-prod/infra/pool-a1 | ❌ raw `azurerm_container_app_job` | Refactor to #2 (HIGH risk - azurerm→azapi provider mismatch, needs state surgery) |
| `caj-b-pub-*` | alz-prod/infra/pool-b-pub | ❌ raw `azurerm_container_app_job` | Refactor to #2 OR archive if unused |
| `pool-w-org` | alz-prod/pool-w-org | ❌ uses raw `Azure/avm-res-compute-virtualmachinescaleset` | Refactor to #1 |
| `caj-personal-runner` | personal-runners-infra (Linux) | ✅ consumes #4 | None - compliant via fork (justified above) |
| `vmss_pool_w_pub` | personal-runners-infra (Windows) | ❌ raw `azapi_resource` | Refactor to #1 |
| `runner_job` | alz-avm-tf-demo/alz-aca-runners | ✅ repo deleted from GitHub 2026-05-28 | Done |

### Archived / retired

- `alz-avm-tf-demo/terraform-azurerm-github-runners-alz-corp` - archived 2026-05-28 (zero consumers - see `martinopedal/terraform-azurerm-github-runners-alz-corp` instead)
- `alz-avm-tf-demo/alz-aca-runners` - deleted 2026-05-28 (never deployed; sub-10 holds only orphan state SA + VNet pending cleanup)

### Pinning

Pin versions explicitly. No `?ref=main`. No `version = "~> 0"`. Fork pins use the suffixed tag (e.g. `v0.6.0-personal.2`) and the corresponding upstream tag MUST be referenced in the fork's release notes so the diff is always inspectable.

## What This Module Is

This is a Terraform module that deploys self-hosted **GitHub Actions Runners** and **Azure DevOps Agents** on **Azure Container Apps (ACA)** in an **Azure Landing Zone Corp** subscription.

It is a fork of [Azure/terraform-azurerm-avm-ptn-cicd-agents-and-runners](https://github.com/Azure/terraform-azurerm-avm-ptn-cicd-agents-and-runners), stripped down for ALZ Corp:

- No VNet, NAT Gateway, or Public IP creation - networking is provided by the ALZ Vending Module and AVNM
- No Container Instances - ACA only
- Always private networking with central Azure Firewall egress
- Subnets are required inputs (`container_app_subnet_id`, `container_registry_private_endpoint_subnet_id`)

## Module Structure

```
.
├── modules/
│   ├── container-app-job/    # ACA Job definition (KEDA-scaled runner/agent)
│   └── container-registry/   # ACR + image build tasks
├── examples/
│   ├── github_runners_pat/
│   ├── github_runners_app_auth/
│   ├── azuredevops_agents_pat/
│   └── azuredevops_agents_uami/
├── locals.tf                          # Core locals
├── locals.container.app.job.tf        # KEDA + env var config for GitHub/AzDO
├── main.tf                            # Resource group + lock
├── main.container.app.environment.tf  # ACA Environment (always internal)
├── main.container.app.job.tf          # Wires root → container-app-job submodule
├── main.container.registry.tf         # Wires root → container-registry submodule
├── main.log.analytics.workspace.tf    # Log Analytics (AVM module)
├── main.user.assigned.managed.identity.tf  # UAMI (AVM module)
├── main.telemetry.tf                  # AVM telemetry
├── variables.tf                       # Core variables (location, postfix, subnets, etc.)
├── variables.version.control.system.tf    # GitHub/AzDO auth config
├── variables.container.app.tf         # ACA job sizing, scaling, timeouts
├── variables.container.registry.tf    # ACR + image build config
├── variables.log.analytics.workspace.tf
├── variables.user.assigned.managed.identity.tf
├── outputs.tf
├── FIREWALL-RULES.md                  # Required Azure Firewall FQDN openings
└── README.md
```

## Rules for Modifying This Repo

### Do NOT modify these submodules

- `modules/container-app-job/` - shared with upstream, changes here break compatibility
- `modules/container-registry/` - shared with upstream, changes here break compatibility

If submodule behavior needs changing, do it through the root module's variable pass-throughs in `main.container.app.job.tf` or `main.container.registry.tf`.

### Do NOT reintroduce networking resources

This module does not create VNets, NAT Gateways, Public IPs, or subnets. Those come from the ALZ Vending Module. Do not add them back. The following variables/resources must NOT exist in this module:

- `virtual_network_creation_enabled`, `virtual_network_address_space`, `virtual_network_id`
- `nat_gateway_creation_enabled`, `nat_gateway_id`, `nat_gateway_name`
- `public_ip_creation_enabled`, `public_ip_id`, `public_ip_name`
- `use_private_networking` (always private, hardcoded)

### Do NOT reintroduce Container Instance support

No ACI module, no ACI variables, no `compute_types` variable. ACA is the only compute type.

### Both GitHub and Azure DevOps must be supported

The `version_control_system_type` variable accepts `github` or `azuredevops`. Both code paths must remain functional. When making changes to environment variables, KEDA metadata, or sensitive variables in `locals.container.app.job.tf`, test both paths.

## Authentication - Three Layers

When working on auth-related code, keep these three layers distinct:

1. **Terraform to Azure** - handled outside this module (pipeline identity, `ARM_*` env vars). This module does not configure it.

2. **Runner/Agent to VCS** - configured by `version_control_system_authentication_method`:
   - GitHub: `pat` (PAT token) or `github_app` (App ID + installation ID + private key)
   - Azure DevOps: `pat` (PAT token) or `uami` (Managed Identity registered in AzDO)
   - These credentials are stored as Container App secrets and used by the runner at runtime to register and poll for jobs.

3. **Runner UAMI to Azure resources** - the UAMI attached to the Container App Job can be used by workflow steps to access Azure resources (Storage, Key Vault, etc.) via RBAC.

## Validation Before Committing

```bash
terraform fmt -recursive
terraform validate
```

The `avm.ps1` / `avm.bat` dev tooling from upstream has been removed. Standard `terraform fmt` and `terraform validate` are sufficient.

## File Naming Convention

Follow the AVM pattern with dot-separated descriptive filenames:

- `variables.{concern}.tf` - e.g. `variables.container.app.tf`
- `main.{concern}.tf` - e.g. `main.container.registry.tf`
- `locals.{concern}.tf` - e.g. `locals.container.app.job.tf`

## Key Design Decisions

- `main.container.registry.tf` hardcodes `use_private_networking = true` - this is intentional for ALZ Corp
- `main.container.app.environment.tf` hardcodes `internal_load_balancer_enabled = true` - no public ingress
- Log Analytics defaults `internet_ingestion_enabled` and `internet_query_enabled` to `false`
- The Container App Environment always requires `infrastructure_subnet_id`
- Private DNS for ACR (`privatelink.azurecr.io`) is expected to be managed centrally (Azure Policy or platform team) - the `container_registry_dns_zone_id` variable is optional

## FIREWALL-RULES.md

When adding new external dependencies (new container images, new API endpoints), update `FIREWALL-RULES.md` with the required FQDNs. This file is referenced by platform teams configuring Azure Firewall rules.

## README Conventions

- No AI-generated language patterns
- Only ✅ and ❌ emojis are permitted - no others
- Code examples must be functional `main.tf` snippets that work with this module's current interface
- The `<!-- BEGIN_TF_DOCS -->` / `<!-- END_TF_DOCS -->` markers are for terraform-docs auto-generation

## Security rules
- No secrets in code - use environment variables or GitHub Secrets
- SHA-pin all GitHub Actions to commit SHAs
- Use actions/checkout@v6 and actions/setup-python@v6 (Node.js 24 compatible)
- No enforce_admins on branch protection
- CodeQL enabled for code scanning

## GitHub-first principle
Validate changes in GitHub Actions, not locally. Push, trigger workflow, check logs, iterate.
