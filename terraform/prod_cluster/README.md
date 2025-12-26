# EKS Production Cluster

Terraform configuration for the production EKS cluster.

---
## Contents

| Directory | Description |
|-----------|-------------|
| `eks-cluster/` | EKS control plane configuration |
| `node-groups/` | Managed node group definitions |
| `addons/` | EKS addons (CoreDNS, kube-proxy, VPC CNI) |
| `security-groups/` | Cluster-specific security groups |

---
## Entry Points
- `main.tf` - Orchestrates cluster module calls
- `variables.tf` - Cluster configuration inputs
- `outputs.tf` - Cluster endpoint, certificate, and OIDC provider outputs

---
## Related
- See [../modules/README.md](../modules/README.md) for foundational infrastructure modules
- See [../../README.md](../../README.md) for repository overview
