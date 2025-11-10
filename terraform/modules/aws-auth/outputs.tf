output "configmap_name" {
  description = "Name of the aws-auth ConfigMap"
  value       = kubernetes_config_map_v1.aws_auth.metadata[0].name
}

output "configmap_namespace" {
  description = "Namespace of the aws-auth ConfigMap"
  value       = kubernetes_config_map_v1.aws_auth.metadata[0].namespace
}

output "mapped_role_arn" {
  description = "ARN of the IAM role mapped in aws-auth"
  value       = var.kubespray_iam_role_arn
}

output "authentication_summary" {
  description = "Summary of the authentication configuration"
  value = {
    configmap_created = "${kubernetes_config_map_v1.aws_auth.metadata[0].namespace}/${kubernetes_config_map_v1.aws_auth.metadata[0].name}"
    iam_role_mapped   = var.kubespray_iam_role_arn
    kubernetes_user   = "kubespray-user"
    kubernetes_groups = ["system:masters"]
    access_level      = "cluster-admin"
  }
}