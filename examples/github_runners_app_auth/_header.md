# GitHub Runners with GitHub App authentication

Deploys self-hosted GitHub Actions runners on Azure Container Apps and registers them using a GitHub App installation. Preferred over PAT for production: short-lived tokens, scoped permissions, no human-owned secret.

Networking inputs (VNet subnets and the private DNS zone for the registry) are expected from the ALZ Vending Module.
