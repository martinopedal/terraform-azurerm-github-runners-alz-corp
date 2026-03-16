# Firewall Rules for Self-Hosted Runners/Agents

This document lists all FQDN and network rules required on the **Azure Firewall** (or NVA) providing
central egress in an Azure Landing Zone Corp topology.

These rules must be in place **before** deploying this module, otherwise runner registration,
image builds, and job execution will fail.

> **Sources:** This list is compiled from the
> [GitHub self-hosted runners reference](https://docs.github.com/en/actions/reference/self-hosted-runners-reference),
> [GitHub GHEC data residency network details](https://docs.github.com/en/enterprise-cloud@latest/admin/data-residency/network-details-for-ghecom),
> [Azure Container Apps firewall integration](https://learn.microsoft.com/azure/container-apps/use-azure-firewall),
> [Azure Container Registry firewall rules](https://learn.microsoft.com/azure/container-registry/container-registry-firewall-access-rules),
> and [Azure Monitor network requirements](https://learn.microsoft.com/azure/azure-monitor/fundamentals/azure-monitor-network-access).

---

## Azure Container Apps Infrastructure

Required by the ACA platform itself (underlying AKS cluster, KEDA scaler, platform services).
See [Microsoft docs: Use Azure Firewall with Azure Container Apps](https://learn.microsoft.com/azure/container-apps/use-azure-firewall).

| FQDN / Endpoint | Port | Protocol | Why needed |
|---|---|---|---|
| `mcr.microsoft.com` | 443 | HTTPS | ACA pulls its own platform images from MCR during environment provisioning |
| `*.data.mcr.microsoft.com` | 443 | HTTPS | CDN-backed data endpoint for MCR image layer downloads |
| `packages.aks.azure.com` | 443 | HTTPS | Underlying AKS cluster downloads Kubernetes binaries and Azure CNI plugins |
| `acs-mirror.azureedge.net` | 443 | HTTPS | Mirror for AKS binaries (kubelet, containerd) used by ACA infrastructure |
| `*.azurecontainerapps.dev` | 443 | HTTPS | ACA control plane, Azure Portal log streaming, and console access |
| `*.servicebus.windows.net` | 443 | HTTPS | **CRITICAL** - KEDA uses Service Bus internally. Without this, KEDA cannot poll for queued jobs and runners never scale up |

---

## Azure Platform - Always Required

Required for Entra ID authentication, managed identity token acquisition, and Azure Resource Manager operations.
See [Microsoft docs: Managed Identity firewall rules](https://learn.microsoft.com/azure/container-apps/use-azure-firewall).

| FQDN / Endpoint | Port | Protocol | Why needed |
|---|---|---|---|
| `login.microsoftonline.com` | 443 | HTTPS | Primary Entra ID endpoint. UAMI token acquisition for ACR pull and KEDA auth |
| `*.login.microsoftonline.com` | 443 | HTTPS | Regional Entra ID endpoints. Token requests may route to region-specific servers |
| `*.login.microsoft.com` | 443 | HTTPS | Entra ID fallback. Some Azure SDKs use this domain for auth |
| `management.azure.com` | 443 | HTTPS | Azure Resource Manager. KEDA queries ARM for pool/job state; managed identity operations |
| `*.identity.azure.net` | 443 | HTTPS | IMDS managed identity token endpoint. Every container requests tokens via this on startup |

---

## Azure Container Registry (ACR) - Image Pull

Required for the Container App Job to pull runner/agent images from ACR, and for GitHub Actions
artifact/cache storage.

| FQDN / Endpoint | Port | Protocol | Why needed |
|---|---|---|---|
| `*.azurecr.io` | 443 | HTTPS | ACR login server. Needed for ACR Task image builds (tasks run on Azure infra, not in your VNet) |
| `*.blob.core.windows.net` | 443 | HTTPS | Azure Blob Storage. Used by ACR (image layers) and GitHub Actions (job summaries, logs, artifacts, caches) |
| `mcr.microsoft.com` | 443 | HTTPS | Base images (ubuntu, alpine, etc.) referenced in Dockerfile during ACR Task builds |
| `*.data.mcr.microsoft.com` | 443 | HTTPS | CDN endpoint for MCR base image layer downloads during builds |
| `*.cdn.mscr.io` | 443 | HTTPS | Legacy MCR CDN fallback. Some image pulls still resolve here |
| `packages.microsoft.com` | 443 | HTTPS | Microsoft apt/yum repos. Runner Dockerfiles install packages from here during ACR Task builds |

> **Note on ACR Tasks:** ACR Tasks run on **Microsoft-managed infrastructure**, not inside your VNet.
> The `networkRuleBypassAllowedForTasks = true` setting in this module allows tasks to bypass ACR network
> rules. The FQDNs above are needed because tasks make outbound calls to clone Dockerfile context and
> pull base images from their own network - your firewall rules don't directly affect ACR Task execution.
>
> **Note on private endpoint:** Image pulls from the Container App Job to ACR use the **private endpoint**
> and do not traverse the firewall. The `*.azurecr.io` and `*.blob.core.windows.net` rules are primarily
> needed for the `*.blob.core.windows.net` usage by GitHub Actions (artifacts, caches, logs).

---

## Log Analytics - Monitoring & Diagnostics

Required for the Container App Environment to send logs to the Log Analytics workspace.
The `AzureMonitor` service tag covers these, but if using FQDN-based rules:

| FQDN / Endpoint | Port | Protocol | Why needed |
|---|---|---|---|
| `*.ods.opinsights.azure.com` | 443 | HTTPS | Primary data ingestion endpoint. Container App Environment streams logs here |
| `*.oms.opinsights.azure.com` | 443 | HTTPS | Operations management. Agent health and configuration data |
| `*.ingest.monitor.azure.com` | 443 | HTTPS | Data Collection Endpoint (DCE). Newer ingestion path for Azure Monitor |
| `*.monitor.azure.com` | 443 | HTTPS | Azure Monitor control plane API. Workspace configuration and query operations |

> **Note:** If you prefer service tags, the `AzureMonitor` network rule (see below) covers all of these.
> Both approaches are valid - use whichever your firewall policy prefers.

---

## GitHub - Runner Registration & Job Execution (github.com)

Required when `version_control_system_type = "github"` with standard GitHub (`github.com`).
See [GitHub docs: Self-hosted runners reference - Communication requirements](https://docs.github.com/en/actions/reference/self-hosted-runners-reference#requirements-for-communication-with-github).

| FQDN / Endpoint | Port | Protocol | Purpose |
|---|---|---|---|
| `github.com` | 443 | HTTPS | GitHub API and web (runner registration) |
| `api.github.com` | 443 | HTTPS | GitHub REST API (KEDA scaler polling, runner ops) |
| `*.actions.githubusercontent.com` | 443 | HTTPS | GitHub Actions service, OIDC tokens, artifacts, logs |
| `codeload.github.com` | 443 | HTTPS | Git archive downloads (`actions/checkout`) |
| `results-receiver.actions.githubusercontent.com` | 443 | HTTPS | Actions results service |
| `pipelines.actions.githubusercontent.com` | 443 | HTTPS | Actions pipeline orchestration |
| `objects.githubusercontent.com` | 443 | HTTPS | GitHub release asset downloads |
| `objects-origin.githubusercontent.com` | 443 | HTTPS | Runner version updates |
| `github-releases.githubusercontent.com` | 443 | HTTPS | Runner version updates |
| `github-registry-files.githubusercontent.com` | 443 | HTTPS | Runner version updates |
| `raw.githubusercontent.com` | 443 | HTTPS | Raw file content |
| `release-assets.githubusercontent.com` | 443 | HTTPS | Release asset downloads |
| `*.pkg.github.com` | 443 | HTTPS | GitHub Packages (npm, NuGet, Maven, etc.) |
| `pkg-containers.githubusercontent.com` | 443 | HTTPS | GitHub Packages container images |
| `ghcr.io` | 443 | HTTPS | GitHub Container Registry |

Optional - only if your workflows use **Git LFS**:

| FQDN / Endpoint | Port | Protocol | Purpose |
|---|---|---|---|
| `github-cloud.githubusercontent.com` | 443 | HTTPS | Git LFS storage |
| `github-cloud.s3.amazonaws.com` | 443 | HTTPS | Git LFS storage (S3 backend) |

---

## GitHub - Runner Registration & Job Execution (GHEC with EU Data Residency)

Required when `version_control_system_type = "github"` with **GitHub Enterprise Cloud data residency**
(`version_control_system_github_url = "<subdomain>.ghe.com"`).
See [GitHub docs: Network details for GHE.com](https://docs.github.com/en/enterprise-cloud@latest/admin/data-residency/network-details-for-ghecom).

**Use this section INSTEAD of the github.com section above.** The standard `github.com`, `api.github.com`,
`codeload.github.com`, `*.pkg.github.com`, `ghcr.io`, and individual `*.githubusercontent.com` entries
are **not needed** - GHE.com consolidates these into a smaller set of hostnames.

| FQDN / Endpoint | Port | Protocol | Purpose | Replaces (from github.com section) |
|---|---|---|---|---|
| `<subdomain>.ghe.com` | 443 | HTTPS | Enterprise web | `github.com` |
| `*.<subdomain>.ghe.com` | 443 | HTTPS | API, Git, packages, GHCR | `api.github.com`, `codeload.github.com`, `*.pkg.github.com`, `ghcr.io` |
| `*.actions.<subdomain>.ghe.com` | 443 | HTTPS | Actions (jobs, artifacts, logs) | `*.actions.githubusercontent.com`, `results-receiver.*`, `pipelines.*` |
| `*.pages.<subdomain>.ghe.com` | 443 | HTTPS | GitHub Pages (if used) | N/A |
| `auth.ghe.com` | 443 | HTTPS | GHE.com authentication | N/A (new) |
| `*.githubassets.com` | 443 | HTTPS | Static assets (JS, CSS, images) | N/A (new) |
| `*.githubusercontent.com` | 443 | HTTPS | Raw content, runner updates, release assets | All individual `*.githubusercontent.com` entries |
| `*.blob.core.windows.net` | 443 | HTTPS | Job summaries, logs, artifacts, caches | Already in ACR section |

> **What you do NOT need with GHEC data residency** (compared to github.com):
> - `github.com`, `api.github.com`, `codeload.github.com` - replaced by `*.<subdomain>.ghe.com`
> - `*.pkg.github.com`, `ghcr.io`, `pkg-containers.githubusercontent.com` - replaced by `*.<subdomain>.ghe.com`
> - Individual `*.githubusercontent.com` subdomains - replaced by the `*.githubusercontent.com` wildcard
>
> **What is still needed:**
> - `*.githubusercontent.com` - runner updates and content delivery still use this domain
> - `*.blob.core.windows.net` - Azure Blob Storage is still used for artifacts/caches (already in ACR section)
> - `*.githubassets.com` - static assets still served from this domain
> - All Azure sections (Container Apps, Platform, ACR, Log Analytics) remain **unchanged**

> **Module behavior:** The KEDA scaler's `githubAPIURL` is automatically set to
> `https://api.<subdomain>.ghe.com` and the runner's `GITHUB_HOST` is set to
> `<subdomain>.ghe.com` by this module when `version_control_system_github_url` is configured.

### EU - IP Ranges (for IP-based rules)

If your firewall uses IP-based rules in addition to or instead of FQDNs, allow these ranges.
Use `gh api /meta --hostname <subdomain>.ghe.com` for the latest values.

| Direction | IP Ranges |
|---|---|
| **Egress** (GitHub → your network) | `108.143.221.96/28`, `20.61.46.32/28`, `20.224.62.160/28`, `51.12.252.16/28`, `74.241.131.48/28` |
| **Ingress** (your network → GitHub) | `108.143.197.176/28`, `20.123.213.96/28`, `20.224.46.144/28`, `20.240.194.240/28`, `20.240.220.192/28`, `20.240.211.208/28` |

### EU - Restrict `*.blob.core.windows.net` (optional tightening)

For tighter firewall rules, you can replace the GitHub-specific blob storage wildcard with
region-specific storage accounts. The ACR `*.blob.core.windows.net` rule is still needed separately
unless ACR is accessed exclusively via private endpoint.

```text
prodsdc01resultssa0.blob.core.windows.net
prodsdc01resultssa1.blob.core.windows.net
prodsdc01resultssa2.blob.core.windows.net
prodsdc01resultssa3.blob.core.windows.net
prodweu01resultssa0.blob.core.windows.net
prodweu01resultssa1.blob.core.windows.net
prodweu01resultssa2.blob.core.windows.net
prodweu01resultssa3.blob.core.windows.net
```

---

## Azure DevOps - Agent Registration & Job Execution

Required when `version_control_system_type = "azuredevops"`:

| FQDN / Endpoint | Port | Protocol | Purpose |
|---|---|---|---|
| `dev.azure.com` | 443 | HTTPS | Azure DevOps Services API |
| `*.dev.azure.com` | 443 | HTTPS | Organization-specific endpoints |
| `*.vsassets.io` | 443 | HTTPS | Azure DevOps static assets / agent download |
| `*.visualstudio.com` | 443 | HTTPS | Legacy Azure DevOps endpoints (still used by agent) |
| `vstsagentpackage.azureedge.net` | 443 | HTTPS | Agent package downloads |
| `*.vstsmms.visualstudio.com` | 443 | HTTPS | Azure DevOps telemetry |

> **Note on UAMI authentication:** When using `authentication_method = "uami"`, the agent uses
> Managed Identity to authenticate. The identity must be pre-configured in Azure DevOps as a
> service principal with Administrator role on the target agent pool. The Entra ID and managed
> identity endpoints in the "Azure Platform" section above are required for token acquisition.

---

## Network Rules (non-HTTP)

Service tag-based network rules. Use these when your firewall supports Azure service tags.
These can be used **instead of** (not in addition to) the equivalent FQDN rules above.

| Destination | Port | Protocol | Purpose |
|---|---|---|---|
| `MicrosoftContainerRegistry` (service tag) | 443 | TCP | MCR image pulls (required by ACA platform) |
| `AzureFrontDoorFirstParty` (service tag) | 443 | TCP | MCR CDN backend (required by ACA platform) |
| `AzureContainerRegistry` (service tag) | 443 | TCP | ACR connectivity |
| `AzureActiveDirectory` (service tag) | 443 | TCP | Entra ID authentication |
| `AzureMonitor` (service tag) | 443 | TCP | Log Analytics data ingestion |

> **Note:** The `MicrosoftContainerRegistry` and `AzureFrontDoorFirstParty` service tags are
> [required by Azure Container Apps](https://learn.microsoft.com/azure/container-apps/use-azure-firewall)
> for the underlying AKS infrastructure. If you use FQDN-based application rules for `mcr.microsoft.com`
> and `*.data.mcr.microsoft.com` instead, these network rules are not needed (and vice versa).

---

## Copy-Pasteable Rule Collections

Pick **one** of the two GitHub rule collections below based on your scenario. The Azure rules
are identical for both - only the GitHub section differs.

### Option A: GitHub Runners on github.com

```text
Rule Collection: rc-cicd-runners-application
Priority: 200
Action: Allow

Rules:
  - Name: container-apps-platform
    Source: <container-app-subnet-cidr>
    FQDNs: mcr.microsoft.com, *.data.mcr.microsoft.com,
           packages.aks.azure.com, acs-mirror.azureedge.net,
           *.azurecontainerapps.dev, *.servicebus.windows.net
    Protocol: Https:443

  - Name: azure-platform
    Source: <container-app-subnet-cidr>
    FQDNs: login.microsoftonline.com, *.login.microsoftonline.com,
           *.login.microsoft.com, management.azure.com,
           *.identity.azure.net
    Protocol: Https:443

  - Name: container-registry
    Source: <container-app-subnet-cidr>
    FQDNs: *.azurecr.io, *.blob.core.windows.net,
           mcr.microsoft.com, *.data.mcr.microsoft.com,
           *.cdn.mscr.io, packages.microsoft.com
    Protocol: Https:443

  - Name: log-analytics
    Source: <container-app-subnet-cidr>
    FQDNs: *.ods.opinsights.azure.com, *.oms.opinsights.azure.com,
           *.ingest.monitor.azure.com, *.monitor.azure.com
    Protocol: Https:443

  - Name: github-runners
    Source: <container-app-subnet-cidr>
    FQDNs: github.com, api.github.com, *.actions.githubusercontent.com,
           codeload.github.com, *.pkg.github.com, ghcr.io,
           pkg-containers.githubusercontent.com,
           results-receiver.actions.githubusercontent.com,
           pipelines.actions.githubusercontent.com,
           objects.githubusercontent.com,
           objects-origin.githubusercontent.com,
           github-releases.githubusercontent.com,
           github-registry-files.githubusercontent.com,
           raw.githubusercontent.com, release-assets.githubusercontent.com
    Protocol: Https:443
```

```text
Rule Collection: rc-cicd-runners-network
Priority: 200
Action: Allow

Rules:
  - Name: azure-services
    Source: <container-app-subnet-cidr>
    Service Tags: MicrosoftContainerRegistry, AzureFrontDoorFirstParty,
                  AzureContainerRegistry, AzureActiveDirectory, AzureMonitor
    Protocol: TCP
    Port: 443
```

### Option B: GitHub Runners on GHEC with EU Data Residency (ghe.com)

Replace `<subdomain>` with your enterprise's GHE.com subdomain.

```text
Rule Collection: rc-cicd-runners-application
Priority: 200
Action: Allow

Rules:
  - Name: container-apps-platform
    Source: <container-app-subnet-cidr>
    FQDNs: mcr.microsoft.com, *.data.mcr.microsoft.com,
           packages.aks.azure.com, acs-mirror.azureedge.net,
           *.azurecontainerapps.dev, *.servicebus.windows.net
    Protocol: Https:443

  - Name: azure-platform
    Source: <container-app-subnet-cidr>
    FQDNs: login.microsoftonline.com, *.login.microsoftonline.com,
           *.login.microsoft.com, management.azure.com,
           *.identity.azure.net
    Protocol: Https:443

  - Name: container-registry
    Source: <container-app-subnet-cidr>
    FQDNs: *.azurecr.io, *.blob.core.windows.net,
           mcr.microsoft.com, *.data.mcr.microsoft.com,
           *.cdn.mscr.io, packages.microsoft.com
    Protocol: Https:443

  - Name: log-analytics
    Source: <container-app-subnet-cidr>
    FQDNs: *.ods.opinsights.azure.com, *.oms.opinsights.azure.com,
           *.ingest.monitor.azure.com, *.monitor.azure.com
    Protocol: Https:443

  - Name: github-runners-ghecom
    Source: <container-app-subnet-cidr>
    FQDNs: <subdomain>.ghe.com, *.<subdomain>.ghe.com,
           *.actions.<subdomain>.ghe.com, auth.ghe.com,
           *.githubassets.com, *.githubusercontent.com
    Protocol: Https:443
```

```text
Rule Collection: rc-cicd-runners-network
Priority: 200
Action: Allow

Rules:
  - Name: azure-services
    Source: <container-app-subnet-cidr>
    Service Tags: MicrosoftContainerRegistry, AzureFrontDoorFirstParty,
                  AzureContainerRegistry, AzureActiveDirectory, AzureMonitor
    Protocol: TCP
    Port: 443
```

> **Note:** The Azure rules (container-apps-platform, azure-platform, container-registry,
> log-analytics, azure-services) are **identical** in both options. Only the GitHub rule differs.

---

## DNS Requirements

This module requires DNS resolution for the private endpoint it creates. This is **not** a firewall
rule - it is a prerequisite handled by the landing zone platform:

| DNS Zone | Purpose | Managed By |
|---|---|---|
| `privatelink.azurecr.io` | ACR private endpoint resolution | Central DNS infrastructure or Azure Policy (platform team) |

The VNet's DNS settings (which DNS server to use) are configured by the **ALZ Vending Module**.
If your Azure Firewall has DNS Proxy enabled, the VNet should point to the firewall's private IP for DNS.
FQDN-based application rules need DNS queries routed through the firewall to work.

---

## Validation

After configuring firewall rules, you can validate connectivity by running a test workflow:

**GitHub Actions:**
```yaml
jobs:
  test:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      - run: |
          curl -s https://api.github.com/zen
          echo "Connectivity OK"
```

**Azure DevOps:**
```yaml
pool: <your-pool-name>
steps:
  - script: |
      curl -s https://dev.azure.com
      echo "Connectivity OK"
```

### Troubleshooting - Job Stuck in "Queued"

If the workflow job stays in "Queued" and no runner picks it up:

1. **Check if KEDA triggered any Container App Job executions:**
   ```bash
   az containerapp job execution list --name <job-name> --resource-group <rg-name> --output table
   ```
   If zero executions, KEDA cannot poll the VCS API - check firewall rules for `api.github.com`
   (or `dev.azure.com`) and `*.servicebus.windows.net`.

2. **Check firewall deny logs:**
   ```kusto
   AZFWApplicationRule
   | union AZFWNetworkRule
   | where Action in ("Deny", "Drop")
   | order by TimeGenerated desc
   ```

3. **Check DNS proxy logs** (traffic may fail before reaching the firewall if DNS doesn't resolve):
   ```kusto
   AZFWDnsQuery
   | order by TimeGenerated desc
   | take 100
   ```

4. **Check Container App logs:**
   ```kusto
   ContainerAppSystemLogs_CL
   | order by TimeGenerated desc
   | take 50
   ```

> **Common pitfall:** GitHub's own [self-hosted runner docs](https://docs.github.com/en/actions/reference/self-hosted-runners-reference)
> only list the FQDNs needed by the runner itself. They do **not** include the Azure-specific
> endpoints (ACA platform, KEDA, Entra ID, ACR, Log Analytics) that are also required when
> running on Azure Container Apps behind a firewall.
