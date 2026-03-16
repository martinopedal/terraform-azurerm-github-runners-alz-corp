# Firewall Rules for Self-Hosted Runners/Agents

This document lists all FQDN and network rules required on the **Azure Firewall** (or NVA) providing
central egress in an Azure Landing Zone Corp topology.

These rules must be in place **before** deploying this module, otherwise runner registration,
image builds, and job execution will fail.

> **Sources:** This list is compiled from the
> [GitHub self-hosted runners reference](https://docs.github.com/en/actions/reference/self-hosted-runners-reference),
> [Azure Container Apps firewall integration](https://learn.microsoft.com/azure/container-apps/use-azure-firewall),
> [Azure Container Registry firewall rules](https://learn.microsoft.com/azure/container-registry/container-registry-firewall-access-rules),
> and [Azure Monitor network requirements](https://learn.microsoft.com/azure/azure-monitor/fundamentals/azure-monitor-network-access).

---

## Azure Container Apps Infrastructure

Required by the ACA platform itself (underlying AKS cluster, KEDA scaler, platform services).
See [Microsoft docs: Use Azure Firewall with Azure Container Apps](https://learn.microsoft.com/azure/container-apps/use-azure-firewall).

| FQDN / Endpoint | Port | Protocol | Purpose |
|---|---|---|---|
| `mcr.microsoft.com` | 443 | HTTPS | Microsoft Container Registry (ACA platform images) |
| `*.data.mcr.microsoft.com` | 443 | HTTPS | MCR data endpoint (CDN-backed) |
| `packages.aks.azure.com` | 443 | HTTPS | AKS package downloads (underlying ACA infrastructure) |
| `acs-mirror.azureedge.net` | 443 | HTTPS | AKS binary mirror (Kubernetes + Azure CNI binaries) |
| `*.azurecontainerapps.dev` | 443 | HTTPS | Container Apps platform (portal, log streaming) |
| `*.servicebus.windows.net` | 443 | HTTPS | KEDA scaler connectivity (essential for autoscaling) |

> **Critical:** Without `*.servicebus.windows.net`, KEDA cannot function and will never scale up
> runners in response to queued jobs. This is the most common cause of jobs stuck in "Queued".

---

## Azure Platform — Always Required

Required for Entra ID authentication, managed identity token acquisition, and Azure Resource Manager operations.
See [Microsoft docs: Managed Identity firewall rules](https://learn.microsoft.com/azure/container-apps/use-azure-firewall).

| FQDN / Endpoint | Port | Protocol | Purpose |
|---|---|---|---|
| `login.microsoftonline.com` | 443 | HTTPS | Entra ID / Azure AD authentication |
| `*.login.microsoftonline.com` | 443 | HTTPS | Entra ID regional endpoints |
| `*.login.microsoft.com` | 443 | HTTPS | Entra ID authentication (fallback) |
| `management.azure.com` | 443 | HTTPS | Azure Resource Manager (KEDA scaler, identity) |
| `*.identity.azure.net` | 443 | HTTPS | Managed Identity token endpoint (IMDS) |

---

## Azure Container Registry (ACR) — Image Build & Pull

Required for building the runner/agent container image via ACR Tasks and pulling it into the Container App Job.
See [Microsoft docs: ACR firewall access rules](https://learn.microsoft.com/azure/container-registry/container-registry-firewall-access-rules).

| FQDN / Endpoint | Port | Protocol | Purpose |
|---|---|---|---|
| `*.azurecr.io` | 443 | HTTPS | ACR login server, image pull/push |
| `*.blob.core.windows.net` | 443 | HTTPS | ACR blob storage layer (image layers), also used by GitHub Actions for job summaries, logs, artifacts, and caches |
| `mcr.microsoft.com` | 443 | HTTPS | Microsoft Container Registry (base images in Dockerfile) |
| `*.data.mcr.microsoft.com` | 443 | HTTPS | MCR data endpoint (CDN-backed) |
| `*.cdn.mscr.io` | 443 | HTTPS | MCR CDN fallback |
| `packages.microsoft.com` | 443 | HTTPS | Microsoft package repos (used in Dockerfiles) |

> **Note:** If using private endpoint for ACR, the `*.azurecr.io` and `*.blob.core.windows.net` rules
> are only needed for the **ACR Task** image build (which runs on ACR infrastructure, not inside your VNet).
> Image pull from the Container App Job uses the private endpoint.

---

## Log Analytics — Monitoring & Diagnostics

Required for the Container App Environment to send logs to the Log Analytics workspace.
The `AzureMonitor` service tag covers these, but if using FQDN-based rules:

| FQDN / Endpoint | Port | Protocol | Purpose |
|---|---|---|---|
| `*.ods.opinsights.azure.com` | 443 | HTTPS | Log Analytics data ingestion (ODS) |
| `*.oms.opinsights.azure.com` | 443 | HTTPS | Log Analytics operations (OMS) |
| `*.ingest.monitor.azure.com` | 443 | HTTPS | Data collection endpoint (DCE) |
| `*.monitor.azure.com` | 443 | HTTPS | Azure Monitor control API |

> **Note:** If you prefer service tags, the `AzureMonitor` network rule (see below) covers all of these.
> Both approaches are valid — use whichever your firewall policy prefers.

---

## GitHub — Runner Registration & Job Execution

Required when `version_control_system_type = "github"`.
See [GitHub docs: Self-hosted runners reference — Communication requirements](https://docs.github.com/en/actions/reference/self-hosted-runners-reference#requirements-for-communication-with-github).

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
| `raw.githubusercontent.com` | 443 | HTTPS | Raw file content (used by ACR Task for default image build) |
| `release-assets.githubusercontent.com` | 443 | HTTPS | Release asset downloads |
| `*.pkg.github.com` | 443 | HTTPS | GitHub Packages (npm, NuGet, Maven, etc.) |
| `pkg-containers.githubusercontent.com` | 443 | HTTPS | GitHub Packages container images |
| `ghcr.io` | 443 | HTTPS | GitHub Container Registry |

### Optional — Git LFS

Only required if your workflows use Git Large File Storage:

| FQDN / Endpoint | Port | Protocol | Purpose |
|---|---|---|---|
| `github-cloud.githubusercontent.com` | 443 | HTTPS | Git LFS storage |
| `github-cloud.s3.amazonaws.com` | 443 | HTTPS | Git LFS storage (S3 backend) |

### GitHub Enterprise Cloud with Data Residency

If using `version_control_system_github_url = "<subdomain>.ghe.com"` (e.g., for EU data residency),
the GitHub FQDNs above must be **replaced** with the GHE.com equivalents.
See [GitHub docs: Network details for GHE.com](https://docs.github.com/en/enterprise-cloud@latest/admin/data-residency/network-details-for-ghecom).

| FQDN / Endpoint | Port | Protocol | Purpose |
|---|---|---|---|
| `<subdomain>.ghe.com` | 443 | HTTPS | Enterprise web and API |
| `*.<subdomain>.ghe.com` | 443 | HTTPS | Enterprise services (API, Git, etc.) |
| `*.actions.<subdomain>.ghe.com` | 443 | HTTPS | GitHub Actions service |
| `*.pages.<subdomain>.ghe.com` | 443 | HTTPS | GitHub Pages (if used) |
| `auth.ghe.com` | 443 | HTTPS | GHE.com authentication service |
| `*.githubassets.com` | 443 | HTTPS | Static assets (JS, CSS, images) |
| `*.githubusercontent.com` | 443 | HTTPS | Raw content, avatars, release assets, runner updates |
| `*.blob.core.windows.net` | 443 | HTTPS | Job summaries, logs, artifacts, caches |

> **Note:** With GHEC data residency, the KEDA scaler's `githubAPIURL` is automatically set to
> `https://api.<subdomain>.ghe.com` by this module when `version_control_system_github_url` is configured.

#### EU Data Residency — IP Ranges (for IP-based rules)

If your firewall uses IP-based rules in addition to or instead of FQDNs, allow these ranges
for the EU region. Use `gh api /meta --hostname <subdomain>.ghe.com` for the latest values.

| Direction | IP Ranges |
|---|---|
| **Egress** (GitHub → your runners) | `108.143.221.96/28`, `20.61.46.32/28`, `20.224.62.160/28`, `51.12.252.16/28`, `74.241.131.48/28` |
| **Ingress** (your runners → GitHub) | `108.143.197.176/28`, `20.123.213.96/28`, `20.224.46.144/28`, `20.240.194.240/28`, `20.240.220.192/28`, `20.240.211.208/28` |

---

## Azure DevOps — Agent Registration & Job Execution

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

## Recommended Azure Firewall Application Rule Collection

```text
Rule Collection: rc-cicd-runners
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

  # Use this rule INSTEAD of github-runners when using GHEC with data residency:
  # - Name: github-runners-ghecom
  #   Source: <container-app-subnet-cidr>
  #   FQDNs: <subdomain>.ghe.com, *.<subdomain>.ghe.com,
  #          *.actions.<subdomain>.ghe.com, auth.ghe.com,
  #          *.githubassets.com, *.githubusercontent.com,
  #          *.blob.core.windows.net
  #   Protocol: Https:443

  - Name: azuredevops-agents
    Source: <container-app-subnet-cidr>
    FQDNs: dev.azure.com, *.dev.azure.com, *.vsassets.io,
           *.visualstudio.com, vstsagentpackage.azureedge.net,
           *.vstsmms.visualstudio.com
    Protocol: Https:443
```

### Recommended Network Rule Collection

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

---

## DNS Requirements

This module requires DNS resolution for the private endpoint it creates. This is **not** a firewall
rule — it is a prerequisite handled by the landing zone platform:

| DNS Zone | Purpose | Managed By |
|---|---|---|
| `privatelink.azurecr.io` | ACR private endpoint resolution | Central DNS infrastructure or Azure Policy (platform team) |

The VNet's DNS settings (which DNS server to use) are configured by the **ALZ Vending Module**.
If your Azure Firewall has DNS Proxy enabled, the VNet should point to the firewall's private IP for DNS.
This ensures all DNS queries go through the firewall, which is required for FQDN-based application rules to work.

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

### Troubleshooting — Job Stuck in "Queued"

If the workflow job stays in "Queued" and no runner picks it up:

1. **Check if KEDA triggered any Container App Job executions:**
   ```bash
   az containerapp job execution list --name <job-name> --resource-group <rg-name> --output table
   ```
   If zero executions, KEDA cannot poll the VCS API — check firewall rules for `api.github.com`
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
