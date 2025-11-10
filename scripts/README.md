# Core Project Scripts  

Management utilities for Quiz App infrastructure deployment and operations. These scripts streamline the workflow for provisioning, monitoring, and accessing AWS resources.

- The scripts are structured to be moveable, so they can run on any machine that pulls the source code. 
* they are dependent on the project architecture and relative paths.
  
## How To Use

### Add add the scripts to your .bashrc file

```bash
# Go to the script directory
cd ~/github/Leumi-project/quiz-app/iac/scripts/management

# Get absolute path
SCRIPTS_DIR="$(pwd)"

# Append to ~/.bashrc
{
  echo ""
  echo "# === Leumi Project Management Scripts ==="
  echo "alias manage-project='bash \"$SCRIPTS_DIR/manage-project.sh\"'"
  echo "alias monitor-deployment='bash \"$SCRIPTS_DIR/monitor-deployment.sh\"'"
  echo "alias project-utils='bash \"$SCRIPTS_DIR/project-utils.sh\"'"
  echo "# ========================================"
} >> ~/.bashrc

# Reload bashrc immediately
source ~/.bashrc
```

## 1. manage-project

- **This command is the main entry point for infrustructure provisioning and destruction**
- It starts by verifying dependencies, allows the user to commit changes to Git, then begins terraform apply.
- After terraform finishes, it injects values from terraform outputs into the helm charts and pushes the changes to GitHub.
- It then deploys the root argocd App-of-apps, which then takes over and configures the cluster.
- The script then sends a slack status report of the operation. 

```bash
$ manage-project -h

Usage: manage-project {apply|destroy|validate}

Commands:
  --apply,    -a     - Deploy infrastructure and configure GitOps
  --destroy,  -d     - Tear down all infrastructure
  --validate, -v     - Validate Helm chart structure and configuration

Infrastructure: EKS cluster, Jenkins, ALB, Route53, ArgoCD, Quiz App
```

## 2. monitor-deploy

- **Real-time log monitoring and analysis for deployment operations**
- Tracks and displays logs from terraform, helm, argocd, and bootstrap operations.
- Can follow logs in real-time with filtering, summarize recent events, or tail last N lines.
- Helps debug issues by providing organized views of multi-stage deployment processes.

```bash
$ monitor-deploy -h

🖥️  Quiz-App Deployment Monitor
=================================

Usage: monitor-deployment.sh [options]

Options:
  -h, --help          Show this help and exit
  -s, --status        Summarise log files for the current bundle
  -t, --tail <N>      Display the last N lines from each log (default 20)
  -f, --filter        Follow logs in real time and highlight key events only
  -c, --clear         Remove all log files for the current bundle

Notes:
  • Logs are stored under /tmp/quiz-app-deploy
  • Use --filter during deployments for a concise view

```

## 3. project-utils

- **Quick access to cluster information, credentials, and application URLs**
- Displays access information for Quiz App, ArgoCD, and Jenkins endpoints.
- Retrieves Jenkins EKS credentials for configuring the Kubernetes Cloud plugin.
- Can open web UIs directly in the browser and show ArgoCD application sync status.

```bash
$ project-utils -h

=================================
Quiz App DevOps - Project Utilities
=================================

Usage: project-utils [OPTIONS]

Options:
  --access,   -a       Show access information (cluster + apps)
  --argocd,   -r       Show ArgoCD status
  --jenkins,  -j       Get Jenkins EKS credentials for Kubernetes Cloud
  --open,     -o       Open web UIs in browser
  --help,     -h       Show this help


```
