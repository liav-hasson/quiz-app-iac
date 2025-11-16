# Get current AWS caller identity
data "aws_caller_identity" "current" {}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.28"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  enable_irsa = true

  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access

  # Kubernetes service IPv4 CIDR block
  cluster_service_ipv4_cidr = var.cluster_service_ipv4_cidr

  create_cluster_security_group = true

  # Disable control-plane CloudWatch logging by default to avoid automatic
  # creation of CloudWatch log groups and ingestion (cost). If you want
  # control-plane logs enabled later, set `cluster_enabled_log_types` to a
  # non-empty list (eg. ["api", "audit"]).
  cluster_enabled_log_types   = []
  create_cloudwatch_log_group = false

  cluster_security_group_additional_rules = {
    ingress_nodes_443 = {
      description                = "Node groups to cluster API"
      protocol                   = "tcp"
      from_port                  = 443
      to_port                    = 443
      type                       = "ingress"
      source_node_security_group = true
    }
  }

  # EKS access entries to ensure proper authentication
  access_entries = {
    # Root user access for Terraform and emergency admin access
    root_user = {
      kubernetes_groups = []
      principal_arn     = data.aws_caller_identity.current.arn

      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  tags = var.tags
}