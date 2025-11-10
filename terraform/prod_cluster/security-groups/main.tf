# Additional security group rules for EKS cluster
# These complement the security groups created by the terraform-aws-modules/eks module

# Security group references received as variables from root module
# This eliminates data source dependencies and uses centralized configuration

# Security Group Rule: Allow Jenkins to communicate with EKS API Server
resource "aws_security_group_rule" "jenkins_to_eks_api" {
  description              = "Allow Jenkins to communicate with EKS API Server"
  type                     = "ingress"
  from_port                = var.kubernetes_api_port
  to_port                  = var.kubernetes_api_port
  protocol                 = "tcp"
  source_security_group_id = var.jenkins_security_group_id
  security_group_id        = var.cluster_security_group_id
}

# Security Group Rule: Allow Jenkins to access worker nodes for deployments
resource "aws_security_group_rule" "jenkins_to_worker_nodes" {
  description              = "Allow Jenkins to access worker nodes"
  type                     = "ingress"
  from_port                = var.worker_node_port_range_start
  to_port                  = var.worker_node_port_range_end
  protocol                 = "tcp"
  source_security_group_id = var.jenkins_security_group_id
  security_group_id        = var.node_security_group_id
}

# Security Group Rule: Allow Jenkins outbound to EKS cluster
resource "aws_security_group_rule" "jenkins_egress_to_eks" {
  description              = "Allow Jenkins outbound to EKS cluster"
  type                     = "egress"
  from_port                = var.kubernetes_api_port
  to_port                  = var.kubernetes_api_port
  protocol                 = "tcp"
  source_security_group_id = var.cluster_security_group_id
  security_group_id        = var.jenkins_security_group_id
}