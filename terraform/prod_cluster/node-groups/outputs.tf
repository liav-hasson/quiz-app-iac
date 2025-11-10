output "node_group_names" {
  description = "Names of the EKS node groups"
  value       = keys(module.eks_managed_node_groups)
}

output "node_groups_created" {
  description = "Map of created node groups"
  value       = length(keys(module.eks_managed_node_groups)) > 0
}

output "node_group_security_group_id" {
  description = "Security group ID attached to the EKS node groups"
  value       = try(values(module.eks_managed_node_groups)[0].security_group_id, null)
}