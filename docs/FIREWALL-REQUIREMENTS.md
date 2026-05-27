# Firewall requirements

This document lists the firewall egress required by the corp Linux ACA runner Terraform module. It is the upstream requirements source for `alz-avm-tf-demo/alz-firewall-ops` when this module is used in the ALZ corp topology.

## Source identity

| Item | Value |
|---|---|
| Owning repo | `martinopedal/terraform-azurerm-github-runners-alz-corp` |
| Consumer source | VNet-injected ACA subnet supplied by the consuming repo |
| Current ALZ consumer | `alz-avm-tf-demo/alz-aca-runners` |
| Target source group | `ipg-aca-org-sub10` in alz-firewall-ops |
| Current drift | ALZ live runner env is in sub-1 on `10.0.2.0/23`; target remains sub-10 until the lock ADR changes |
| Egress path | Consumer UDR to hub Azure Firewall |

## Destination requirements

| Purpose | FQDNs | Ports and protocol | Why | Implemented in alz-firewall-ops |
|---|---|---|---|---|
| GitHub runner control | `github.com`, `api.github.com`, `*.github.com`, `*.actions.githubusercontent.com`, `vstoken.actions.githubusercontent.com` | TCP 443 | KEDA queue polling, runner registration, token exchange, and workflow control. | `github-actions-endpoints` |
| GitHub content and packages | `codeload.github.com`, `objects.githubusercontent.com`, `objects-origin.githubusercontent.com`, `*.githubusercontent.com`, `*.blob.core.windows.net`, `ghcr.io`, `*.ghcr.io`, `pkg-containers.githubusercontent.com`, `*.pkg.github.com` | TCP 443 | Checkout, release assets, runner updates, artifacts/cache, GHCR images, and GitHub Packages. | `github-actions-endpoints`; TODO for `*.pkg.github.com` on main |
| Azure identity and ARM | `login.microsoftonline.com`, `login.windows.net`, `graph.microsoft.com`, `management.azure.com`, `*.management.azure.com` | TCP 443 | Managed identity, GitHub App/FIC operations, Terraform, and control-plane calls. | `azure-control-plane`, `azure-platform-endpoints` in PR #16 |
| Key Vault | `*.vault.azure.net`, `*.vaultcore.azure.net` | TCP 443 | Reads GitHub App private key, webhook secrets, and runner configuration. Private Endpoint is preferred where available. | `azure-platform-endpoints` in PR #16 |
| Container registries | `*.azurecr.io`, `*.data.azurecr.io`, `mcr.microsoft.com`, `*.data.mcr.microsoft.com` | TCP 443 | Pulls runner images, Microsoft base images, and ACR-hosted images if the consumer uses ACR. | `container-registries`, `azure-platform-endpoints` in PR #16 |
| ACA platform and KEDA | `*.servicebus.windows.net`, `*.azurecontainerapps.dev`, `packages.aks.azure.com`, `acs-mirror.azureedge.net` | TCP 443 | ACA environment platform dependencies and KEDA-backed scaling paths. | TODO for `*.azurecontainerapps.dev`, `packages.aks.azure.com`, `acs-mirror.azureedge.net` if routed through firewall |
| Monitoring | `*.monitor.azure.com`, `*.ingest.monitor.azure.com`, `*.handler.control.monitor.azure.com`, `*.ods.opinsights.azure.com`, `*.oms.opinsights.azure.com` | TCP 443 | Log Analytics ingestion, ACA diagnostics, and module alerting. | `azure-monitoring`, `azure-platform-endpoints` in PR #16 |
| OS and build packages | `archive.ubuntu.com`, `security.ubuntu.com`, `*.ubuntu.com`, `azure.archive.ubuntu.com`, `packages.microsoft.com`, `registry.npmjs.org`, `*.npmjs.org`, `*.npmjs.com`, `pypi.org`, `*.pypi.org`, `files.pythonhosted.org`, `*.nuget.org`, `api.nuget.org` | TCP 80, TCP 443 | Runner bootstrap and consumer workflow package restore. | `azure-and-update-fqdns`, `package-managers` |
| Terraform providers | `registry.terraform.io`, `releases.hashicorp.com`, `*.terraform.io`, `*.hashicorp.com` | TCP 443 | Terraform-based consumer workflows. | `terraform-providers` |
| DNS and NTP | Azure Firewall DNS proxy or Private DNS Resolver, `ntp.ubuntu.com` | UDP/TCP 53, UDP 123 | Name resolution and clock sync for TLS/OIDC. | TODO if routed through firewall |

## Change flow

1. Update this file before adding a new module egress dependency.
2. Consumers cite the commit SHA in their own firewall requirement docs.
3. `alz-firewall-ops` maps this requirement to RCG implementation and records the honored SHA.
