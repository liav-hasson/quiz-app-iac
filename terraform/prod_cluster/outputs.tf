# EKS Cluster Outputs
output "cluster_id" {
  description = "ID of the EKS cluster"
  value       = module.eks_cluster.cluster_name
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks_cluster.cluster_name
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = module.eks_cluster.cluster_arn
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks_cluster.cluster_endpoint
}

output "cluster_version" {
  description = "The Kubernetes version of the cluster"
  value       = module.eks_cluster.cluster_version
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks_cluster.cluster_certificate_authority_data
  sensitive   = true
}

# OIDC Provider
output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = module.eks_cluster.oidc_provider_arn
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider"
  value       = module.eks_cluster.oidc_provider_arn
}

# Node Groups
output "node_group_names" {
  description = "Names of the EKS node groups"
  value       = module.node_groups.node_group_names
}

output "node_groups_created" {
  description = "Whether node groups were successfully created"
  value       = module.node_groups.node_groups_created
}

# Removed kubernetes module outputs - authentication now handled by ArgoCD

# Kubectl Commands
output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks_cluster.cluster_name}"
}

# Security & Networking
output "security_rules_created" {
  description = "Security rules created for Jenkins-EKS integration"
  value       = module.security_groups.security_rules_created
}

# ALB Outputs
output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.alb.alb_arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = module.alb.alb_zone_id
}

output "alb_name" {
  description = "Name of the Application Load Balancer (for ArgoCD annotations)"
  value       = module.alb.alb_name
}

output "alb_security_group_id" {
  description = "Security group ID of the ALB"
  value       = module.alb.alb_security_group_id
}

output "quiz_app_target_group_arn" {
  description = "ARN of the quiz app target group for TargetGroupBinding"
  value       = module.alb.quiz_app_target_group_arn
}

output "argocd_target_group_arn" {
  description = "ARN of the ArgoCD target group for TargetGroupBinding"
  value       = module.alb.argocd_target_group_arn
}