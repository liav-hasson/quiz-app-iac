# CI Pipeline

Jenkins pipeline configuration for infrastructure provisioning.

---
## Contents
- `Jenkinsfile` - Pipeline definition for terraform plan/apply workflows
- `jenkins-agent/` - Docker agent configuration for running Terraform

---
## Pipeline Stages
1. Checkout - Pull latest IaC repository
2. Validate - Run `terraform validate`
3. Plan - Generate execution plan
4. Approve - Manual approval gate (production)
5. Apply - Apply infrastructure changes

---
## Related
- See [../scripts/README.md](../scripts/README.md) for local management scripts
- See [../terraform/README.md](../terraform/README.md) for Terraform configuration
