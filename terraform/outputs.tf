# =============================================================================
# Quiz App Infrastructure Outputs
# =============================================================================

# VPC Infrastructure
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.vpc.private_subnet_ids
}

# Compute Outputs
output "jenkins_instance_id" {
  description = "Jenkins instance ID for SSM access"
  value       = module.jenkins.instance_id
}

output "jenkins_private_ip" {
  description = "Jenkins private IP address"
  value       = module.jenkins.private_ip
}

# Security Groups
output "jenkins_security_group_id" {
  description = "Jenkins security group ID for EKS integration"
  value       = module.security_groups.jenkins_security_group_id
}

# Production EKS Cluster Outputs
output "prod_eks_cluster_id" {
  description = "ID of the production EKS cluster"
  value       = module.prod_cluster.cluster_id
}

output "prod_eks_cluster_endpoint" {
  description = "Endpoint URL of the production EKS cluster"
  value       = module.prod_cluster.cluster_endpoint
}

output "prod_eks_cluster_arn" {
  description = "ARN of the production EKS cluster"
  value       = module.prod_cluster.cluster_arn
}

output "prod_eks_kubectl_config_command" {
  description = "Command to configure kubectl for production EKS cluster"
  value       = module.prod_cluster.kubectl_config_command
}

output "prod_jenkins_integration" {
  description = "Jenkins integration information for production EKS"
  value = {
    kubectl_command = module.prod_cluster.kubectl_config_command
  }
}

# Removed kubespray IAM outputs - no longer needed with ArgoCD

# AWS Auth ConfigMap - now managed within prod_cluster
output "aws_auth_configmap" {
  description = "AWS Auth ConfigMap information"
  value = {
    configmap_name      = "aws-auth"
    configmap_namespace = "kube-system"
    managed_by          = "prod_cluster.kubernetes"
  }
}

# =============================================================================
# EKS Cluster & IRSA Outputs
# =============================================================================

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.prod_cluster.cluster_endpoint
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.prod_cluster.cluster_name
}

output "eks_cluster_ca_certificate" {
  description = "EKS cluster CA certificate (base64 encoded)"
  value       = module.prod_cluster.cluster_certificate_authority_data
  sensitive   = true
}

output "alb_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller IRSA"
  value       = module.iam.alb_controller_role_arn
}

output "external_secrets_role_arn" {
  description = "IAM role ARN for External Secrets Operator IRSA"
  value       = module.iam.external_secrets_role_arn
}

output "ebs_csi_driver_role_arn" {
  description = "IAM role ARN for EBS CSI Driver IRSA"
  value       = module.iam.ebs_csi_driver_role_arn
}

# =============================================================================
# NOTE: ALB outputs removed - migrated to Istio Service Mesh
# =============================================================================
# The NLB is now provisioned by the AWS Load Balancer Controller based on
# the Istio Ingress Gateway service annotations. DNS records are managed
# via the post-deployment script (update-dns.sh).
# =============================================================================

# =============================================================================
# DNS & Certificate Outputs
# =============================================================================

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS (if public zone enabled)"
  value       = module.route53.acm_certificate_arn
}

output "quiz_app_url" {
  description = "Public URL for quiz application"
  value       = module.route53.quiz_app_url
}

output "argocd_url" {
  description = "Public URL for ArgoCD"
  value       = module.route53.argocd_url
}

# =============================================================================
# Route53 DNS Outputs (for Istio NLB DNS update)
# =============================================================================

output "public_zone_id" {
  description = "ID of the public hosted zone for DNS updates"
  value       = module.route53.public_zone_id
}

output "public_domain" {
  description = "Public domain name (e.g., weatherlabs.org)"
  value       = module.route53.public_zone_name
}

# =============================================================================
# General Outputs
# =============================================================================

output "region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}