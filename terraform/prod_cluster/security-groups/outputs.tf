output "jenkins_security_group_id" {
  description = "ID of the Jenkins security group (passthrough)"
  value       = var.jenkins_security_group_id
}

# Kubernetes security group output removed - no longer needed with ArgoCD

output "security_rules_created" {
  description = "List of security rules created for Jenkins-EKS integration"
  value = {
    jenkins_to_eks_api      = aws_security_group_rule.jenkins_to_eks_api.id
    jenkins_to_worker_nodes = aws_security_group_rule.jenkins_to_worker_nodes.id
    jenkins_egress_to_eks   = aws_security_group_rule.jenkins_egress_to_eks.id
    # Removed kubespray_to_eks_api - no longer needed with ArgoCD
  }
}