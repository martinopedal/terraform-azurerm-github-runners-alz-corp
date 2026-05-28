---
description: 'Self-Hosted CI/CD Runners for ALZ Corp - Terraform Module'
applyTo: '**/*.tf, **/*.tfvars, **/*.md'
---

# Copilot Instructions - terraform-azurerm-github-runners-alz-corp

## CANONICAL MODULES - DIRECTIVE (2026-05-28)

**Only THREE modules are consumed to deploy runner infrastructure across the alz-avm-tf-demo + martinopedal ecosystem.** Any other source URL in a consumer repo is a bug that must be migrated to one of these:

| Module | Use for | Pin format |
|---|---|---|
| `github.com/martinopedal/terraform-azurerm-vmss-github-runners-windows` | Windows VMSS runners (alz-prod pool-w-org) | `?ref=vX.Y.Z` (tag) |
| `github.com/martinopedal/terraform-azurerm-github-runners-alz-corp` | Linux ACA runners in ALZ Corp subscriptions (alz-prod pool-a1) | `?ref=vX.Y.Z` (tag) |
| `Azure/avm-ptn-cicd-agents-and-runners/azurerm` v0.5.1+ | Linux ACA runners in non-ALZ subscriptions (personal-runners-infra) | `version = "0.5.1"` (registry pin) |

**No raw `azurerm_container_app_job` / `azurerm_linux_virtual_machine_scale_set` declarations in consumer repos** - everything goes through a module. The canonical module accepts BYO RG / CAE / UAMI / LAW / ACR / subnets via the documented escape hatches.

**Forks that exist purely to consume must be archived.** As of 2026-05-28 the following are deprecated and slated for archival:
- `martinopedal/terraform-azurerm-avm-ptn-cicd-agents-and-runners-personal` - replaced by public AVM v0.5.1
- `alz-avm-tf-demo/terraform-azurerm-github-runners-alz-corp` (already archived 2026-05-28 - zero consumers)
- `alz-avm-tf-demo/alz-aca-runners` - replaced by direct module consumption from alz-prod

**Consumer mapping (authoritative as of 2026-05-28):**
- `alz-avm-tf-demo/alz-prod/infra/pool-a1` → `martinopedal/terraform-azurerm-github-runners-alz-corp` (Linux ACA)
- `alz-avm-tf-demo/alz-prod/infra/pool-w-org` → `martinopedal/terraform-azurerm-vmss-github-runners-windows` (Windows VMSS)
- `martinopedal/personal-runners-infra` → `Azure/avm-ptn-cicd-agents-and-runners/azurerm` (public registry)

Pin versions explicitly. No `?ref=main`. No `version = "~> 0"`.

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
