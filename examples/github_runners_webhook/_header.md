# GitHub Runners with webhook-driven scaling

Deploys self-hosted GitHub Actions runners on Azure Container Apps, scaled by KEDA against a private Storage Queue fed by a webhook receiver you host. Sub-second scale-up, no GitHub API polling.

Networking inputs (VNet subnets and the private DNS zones for the registry and storage queue) are expected from the ALZ Vending Module. The receiver itself is out of scope for this module. See [`WEBHOOKS.md`](../../WEBHOOKS.md) for the receiver contract and a reference Azure Function.
