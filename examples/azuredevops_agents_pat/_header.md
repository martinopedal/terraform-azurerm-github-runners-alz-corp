# Azure DevOps Agents with PAT authentication

Deploys self-hosted Azure DevOps agents on Azure Container Apps using a Personal Access Token (scope: `Agent Pools (Read & manage)`) for agent registration.

Networking inputs (VNet subnets and the private DNS zone for the registry) are expected from the ALZ Vending Module.
