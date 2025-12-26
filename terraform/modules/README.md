# Terraform Modules

Reusable Terraform modules for AWS infrastructure provisioning.

---
## Modules

| Module | Description |
|--------|-------------|
| `vpc/` | VPC with public/private subnets, NAT, and route tables |
| `security-groups/` | Security group definitions for cluster and Jenkins |
| `route53/` | DNS zone and record management |
| `iam/` | IAM roles and policies (EKS OIDC, ALB IRSA, External Secrets IRSA) |
| `ec2/` | EC2 instances (Jenkins host) |

---
## Usage

Modules are called from the root `terraform/main.tf`. Each module has its own `variables.tf` and `outputs.tf`.

---
## Related
- See [../README.md](../README.md) for root Terraform configuration
- See [../prod_cluster/README.md](../prod_cluster/README.md) for EKS cluster modules
