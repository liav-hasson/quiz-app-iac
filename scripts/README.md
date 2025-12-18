# Quiz App Infrastructure Scripts

Utility scripts for infrastructure provisioning, GitOps bootstrap, and day-to-day operations for the quiz-app stack on AWS EKS.

## Quick Setup

Add the `bin/` directory to your PATH:

```bash
# Add to ~/.bashrc or ~/.zshrc
export PATH="$PATH:$HOME/github/quiz-app/iac/scripts/management/bin"
```

Then reload your shell or run:
```bash
source ~/.bashrc
```

## Commands

### manage-project

Main entry point for infrastructure provisioning and teardown.

```bash
# Deploy infrastructure
manage-project --apply

# Tear down infrastructure  
manage-project --destroy

# Validate configuration
manage-project --validate
```

### monitor-deployment

Monitor deployment logs in real-time.

```bash
# Follow logs in real-time
monitor-deployment --follow

# Show last 50 lines
monitor-deployment --tail 50

# Show log file status
monitor-deployment --status

# Clear log file
monitor-deployment --clear
```

### project-utils

Utility commands for cluster access and management.

```bash
# Show cluster access information
project-utils --access

# Show ArgoCD status and applications
project-utils --argocd

# Get Jenkins EKS credentials for Kubernetes Cloud
project-utils --jenkins

# Open web UIs in browser
project-utils --open
```

## Directory Structure

```
scripts/
├── bin/                        # Entry points (add to PATH)
│   ├── manage-project         
│   ├── monitor-deployment     
│   └── project-utils          
│
├── management/lib/
│   ├── core/                   # Foundation (loaded by all scripts)
│   │   ├── init.sh            # Main initializer
│   │   ├── paths.sh           # Path resolution
│   │   ├── colors.sh          # Terminal colors
│   │   └── logging.sh         # Unified logging
│   │
│   ├── helpers/                # Reusable utilities
│   │   └── notification.sh    # Slack notifications
│   │
│   ├── workflows/              # High-level orchestration
│   │   ├── apply.sh           
│   │   ├── destroy.sh         
│   │   └── validate.sh        
│   │
│   ├── tasks/                  # Individual operations
│   │   ├── terraform.sh       
│   │   ├── argocd.sh          
│   │   ├── dns.sh             
│   │   ├── git-sync.sh        
│   │   ├── inject-values.sh   
│   │   ├── eks-cleanup.sh     
│   │   └── jenkins-backup.sh  
│   │
│   └── tools/                  # Standalone utilities
│       ├── preflight-check.sh
│       ├── verify-dns.sh
│       └── mongodb-tools.sh
│
└── README.md
```

## Logging

All operations log to a single file: `/tmp/quiz-app-deploy/deploy.log`

Log format:
```
[2025-12-18 13:22:59] [function_name] [LEVEL] Message
```

Console output is clean (no timestamps):
```
[INFO] Starting terraform apply
[OK] Terraform init completed
[ERROR] Failed to connect to cluster
```

## Infrastructure Components

- **EKS Cluster**: Kubernetes cluster for application workloads
- **Jenkins EC2**: CI/CD server with golden AMI backup
- **Istio**: Service mesh with NLB for ingress
- **ArgoCD**: GitOps continuous delivery
- **External Secrets**: AWS Secrets Manager integration
- **Route53**: DNS management

## Workflow: Apply

1. Preflight dependency checks
2. Terraform apply (VPC, EKS, Jenkins, IAM)
3. Configure kubectl for EKS
4. Inject Terraform outputs into GitOps manifests
5. Commit and push GitOps changes
6. Deploy ArgoCD to cluster
7. Deploy ArgoCD root application
8. Update DNS records to Istio NLB

## Workflow: Destroy

1. Backup Jenkins AMI
2. Cleanup EKS resources (finalizers, NLB, namespaces)
3. Terraform destroy
4. Cleanup kubectl configuration

