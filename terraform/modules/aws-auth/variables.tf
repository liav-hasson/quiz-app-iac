variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubespray_iam_role_arn" {
  description = "ARN of the Kubespray IAM role to map to system:masters"
  type        = string
}