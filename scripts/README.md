# Scripts Overview

Utility scripts that orchestrate infrastructure provisioning, GitOps bootstrap, and day-to-day operations for the quiz-app stack.

- `management/` – entry points (`manage-project.sh`, `monitor-deployment.sh`, `project-utils.sh`) plus shared libraries.
- `lib/`        – helper functions (logging, git, Kubernetes, bootstrap checks) used by the management scripts.

## Quick Setup

```bash
cd ~/github/quiz-app/iac/scripts/management
export PATH="$PATH:$(pwd)"
# or create aliases in ~/.bashrc if you prefer
```

## Key Commands

- `manage-project` – runs Terraform apply/destroy, injects outputs into GitOps, and boots ArgoCD.
- `monitor-deployment` – tails orchestration logs with filtering options for troubleshooting.
- `project-utils` – fetches cluster access details, ArgoCD status, and Jenkins integration values.
