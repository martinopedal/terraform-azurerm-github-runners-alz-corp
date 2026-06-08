# Copilot Instructions: martinopedal/terraform-azurerm-github-runners-alz-corp

## Project Overview

ACA GitHub Runners module for corporate pools. Reusable Terraform module — consumed by alz-aca-runners.

## Tech Stack

- **Language/Framework**: Terraform module, Azure Container Apps, KEDA, AzAPI
- **Key Technologies**: Terraform, Azure SDK, GitHub Actions

## Directory Structure

**Key directories and files:**

- main.tf (runner job)
- variables.tf
- outputs.tf
- examples/

## Terraform Conventions

When editing Terraform in this repo:

1. **Provider discipline**: 
   - Use zapi for custom/direct ARM API resources
   - Use zurerm only when consuming AVM modules
   - Pin module versions to explicit semver (e.g., ersion = "1.0.0", not ~1.0 or main)

2. **State backend**: Terraform state is private with:
   - Public network access disabled
   - AAD-only authentication (no shared keys)
   - Private endpoint on platform VNet
   - Soft delete + versioning enabled

3. **Remote state**: Use 	erraform init to auto-configure remote state. Never commit .tfstate files.

4. **Module pattern** (if applicable): Reusable modules under modules/:
   - vm-*-fork for AVM forks (document why in module README)
   - Otherwise descriptive names

5. **AVM consumption**: All AVM instantiations must include nable_telemetry = var.enable_telemetry

## Testing & Validation

terraform validate, terraform fmt, terraform test, examples/ walkthrough

Common commands:

\\\ash
terraform init
terraform validate
terraform fmt -recursive
terraform plan -out=tfplan
terraform apply tfplan
\\\

## GitHub Actions & CI/CD

v1.0.1+. Consumers MUST use this module. alz-aca-runners hand-rolls; refactor needed.

- Workflows use OIDC federated credentials (no shared secrets)
- uns-on labels often delegate to reusable templates in **alz-avm-tf-demo/alz-prod-templates**
- Code changes flow through PR gates and testing before apply

## Key Files

- README.md — Documentation, prerequisites, deployment steps
- 	erraform/ — Infrastructure as code
- .github/workflows/ — CI/CD pipelines
- .squad/decisions.md — (in alz-prod) Governance decisions and ADRs

## ALZ Context (Personal)

This is a **personal** repo under the martinopedal account. When deploying to ALZ tenant resources (MngEnvMCAP464621), it is scoped to personal subscriptions (sub-5: runners/demos, or sub-9: shared demos). It operates within the same ALZ governance plane.

**Scope**: Read .squad/decisions.md from **alz-avm-tf-demo/alz-prod** for tenant-wide governance. This repo coordinates with org repos (firewall baseline, RBAC action, etc.).

## Before You Start

1. **Read the README** — Prerequisites, variable setup, runbook steps
2. **Check governance** — Read .squad/decisions.md in **alz-prod** for context
3. **Test locally** — Run 	erraform plan; use 	erraform fmt for formatting
4. **Authenticate** — Use z login or verify GitHub Actions OIDC is configured

## Common Tasks

### Terraform Plan & Apply

\\\ash
cd terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
\\\

### Create or Update a Resource

1. Add resource block to appropriate .tf file
2. Reference existing modules or AVM patterns
3. Run 	erraform fmt -recursive and 	erraform validate
4. Submit PR with plan output in description

### Add a New Module

1. Create modules/{module-name}/ directory
2. Add main.tf, ariables.tf, outputs.tf, README.md
3. Document module purpose and variable constraints
4. Include examples in modules/{module-name}/examples/

## Troubleshooting

- **Terraform init fails**: Check backend config, private endpoint connectivity
- **Apply times out**: Large deployments (AVNM, policy, firewall) can take 30+ minutes
- **OIDC rejected**: Verify federated credential (max 128 chars, matches only, * wildcards)

## Related Repos

- **alz-avm-tf-demo/alz-prod** — Central ALZ governance, decision ledger
- **alz-avm-tf-demo/alz-prod-templates** — Reusable CI/CD templates
- **alz-avm-tf-demo/alz-firewall-ops** — Firewall baseline (gates AVNM)
- **alz-avm-tf-demo/alz-rbac-action** — Production RBAC assignments

## Questions?

See the ALZ documentation in this repo or contact the team via GitHub issues.
