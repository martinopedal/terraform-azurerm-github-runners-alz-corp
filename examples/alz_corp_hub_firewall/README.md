# ALZ corp hub firewall example

This example shows the corp ACA runner module in the alz-prod pattern: the runner spoke is already connected to the hub through AVNM, and egress is routed to the central Azure Firewall.

The module does not create AVNM, UDRs, hub networking, or firewall rules. The consumer passes the hub VNet ID and firewall private IP so the surrounding stack can keep those dependencies explicit.

Copy `terraform.tfvars.example` to `terraform.tfvars`, replace IDs and the GitHub token, then run:

```powershell
terraform init
terraform plan
```
