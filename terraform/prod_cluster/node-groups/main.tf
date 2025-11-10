module "eks_managed_node_groups" {
  source  = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = "20.24.0"

  for_each = var.node_groups

  cluster_name         = var.cluster_name
  cluster_version      = var.cluster_version
  cluster_service_cidr = var.cluster_service_cidr

  name         = each.key
  min_size     = each.value.min_size
  max_size     = each.value.max_size
  desired_size = each.value.desired_size

  instance_types = each.value.instance_types
  capacity_type  = each.value.capacity_type
  subnet_ids     = var.subnet_ids

  iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = var.tags
}