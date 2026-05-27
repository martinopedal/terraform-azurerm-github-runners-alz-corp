# Firewall requirements

This module hosts corp Linux GitHub Actions runners and Azure DevOps agents in an ALZ landing zone spoke. The spoke egresses through the platform hub Azure Firewall via AVNM connectivity. Firewall rule implementation is tracked in `alz-avm-tf-demo/alz-firewall-ops`; this document is the module-owned requirement source.

See the detailed implementation list in [`../FIREWALL-RULES.md`](../FIREWALL-RULES.md). Keep both files aligned when runner images, package feeds, or VCS endpoints change.

## Required destinations

| Destination | Port | Protocol | Applies to | Purpose |
|---|---:|---|---|---|
| `mcr.microsoft.com` | 443 | HTTPS | ACA platform and image builds | Microsoft container images |
| `*.data.mcr.microsoft.com` | 443 | HTTPS | ACA platform and image builds | MCR image layers |
| `packages.aks.azure.com` | 443 | HTTPS | ACA platform | AKS and CNI packages used by ACA infrastructure |
| `acs-mirror.azureedge.net` | 443 | HTTPS | ACA platform | AKS binary mirror |
| `*.azurecontainerapps.dev` | 443 | HTTPS | ACA platform | ACA control plane and console access |
| `*.servicebus.windows.net` | 443 | HTTPS | ACA platform | KEDA platform operations |
| `login.microsoftonline.com` | 443 | HTTPS | Azure auth | Entra ID token issuance |
| `*.login.microsoftonline.com` | 443 | HTTPS | Azure auth | Regional Entra ID endpoints |
| `*.login.microsoft.com` | 443 | HTTPS | Azure auth | Entra ID fallback endpoints |
| `management.azure.com` | 443 | HTTPS | Azure control plane | ARM operations and identity flows |
| `*.identity.azure.net` | 443 | HTTPS | Managed identity | Managed identity token endpoint |
| `*.azurecr.io` | 443 | HTTPS | ACR | ACR login server and ACR Tasks |
| `*.blob.core.windows.net` | 443 | HTTPS | ACR and GitHub Actions | Image layers, logs, artifacts, caches |
| `*.cdn.mscr.io` | 443 | HTTPS | Image pulls | MCR CDN fallback |
| `packages.microsoft.com` | 443 | HTTPS | Image builds | Microsoft Linux package feeds |
| `*.ods.opinsights.azure.com` | 443 | HTTPS | Monitoring | Log Analytics ingestion |
| `*.oms.opinsights.azure.com` | 443 | HTTPS | Monitoring | Operations management data |
| `*.ingest.monitor.azure.com` | 443 | HTTPS | Monitoring | Azure Monitor ingestion |
| `*.monitor.azure.com` | 443 | HTTPS | Monitoring | Azure Monitor API |
| `github.com` | 443 | HTTPS | GitHub runners | GitHub web and API front door |
| `api.github.com` | 443 | HTTPS | GitHub runners | Runner registration and KEDA polling |
| `*.actions.githubusercontent.com` | 443 | HTTPS | GitHub runners | Actions service, OIDC, artifacts, logs |
| `codeload.github.com` | 443 | HTTPS | GitHub runners | Repository archive downloads |
| `results-receiver.actions.githubusercontent.com` | 443 | HTTPS | GitHub runners | Actions result upload |
| `pipelines.actions.githubusercontent.com` | 443 | HTTPS | GitHub runners | Actions pipeline orchestration |
| `objects.githubusercontent.com` | 443 | HTTPS | GitHub runners | Release asset downloads |
| `objects-origin.githubusercontent.com` | 443 | HTTPS | GitHub runners | Runner updates |
| `github-releases.githubusercontent.com` | 443 | HTTPS | GitHub runners | Runner updates |
| `github-registry-files.githubusercontent.com` | 443 | HTTPS | GitHub runners | Runner updates |
| `raw.githubusercontent.com` | 443 | HTTPS | GitHub runners | Raw file content |
| `release-assets.githubusercontent.com` | 443 | HTTPS | GitHub runners | Release assets |
| `*.pkg.github.com` | 443 | HTTPS | Optional GitHub packages | Package downloads |
| `pkg-containers.githubusercontent.com` | 443 | HTTPS | Optional GitHub packages | Container package layers |
| `ghcr.io` | 443 | HTTPS | Optional GHCR | Container image pulls |
| `dev.azure.com` | 443 | HTTPS | Azure DevOps agents | Azure DevOps API |
| `*.dev.azure.com` | 443 | HTTPS | Azure DevOps agents | Organization endpoints |
| `*.vsassets.io` | 443 | HTTPS | Azure DevOps agents | Static assets and agent downloads |
| `*.visualstudio.com` | 443 | HTTPS | Azure DevOps agents | Legacy Azure DevOps endpoints |
| `vstsagentpackage.azureedge.net` | 443 | HTTPS | Azure DevOps agents | Agent package downloads |
| `*.vstsmms.visualstudio.com` | 443 | HTTPS | Azure DevOps agents | Agent telemetry |

## Notes for alz-firewall-ops

- Corp runner spokes are in the network governance plane and use central firewall egress.
- The ACR private endpoint path stays private; the public ACR and blob destinations are still needed for ACR Tasks, GitHub Actions artifacts, caches, and logs.
- For GHEC data residency, replace the standard `github.com` destinations with the GHE.com set documented in `FIREWALL-RULES.md`.
