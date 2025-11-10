variable "environment" {
  description = "Environment tag for IAM resources"
  type        = string
  default     = "shared"
}

variable "eks_cluster_name" {
  description = "EKS cluster name (for OIDC discovery)"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "eks_cluster_arn" {
  description = "EKS cluster ARN for IAM policy references"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider (passed from prod_cluster module)"
  type        = string
}

variable "alb_service_account_name" {
  description = "ServiceAccount name for AWS Load Balancer Controller"
  type        = string
}

variable "alb_service_account_namespace" {
  description = "Namespace for AWS Load Balancer Controller ServiceAccount"
  type        = string
}

variable "eso_service_account_name" {
  description = "ServiceAccount name for External Secrets Operator"
  type        = string
}

variable "eso_service_account_namespace" {
  description = "Namespace for External Secrets Operator ServiceAccount"
  type        = string
}

variable "ssm_parameter_prefix" {
  description = "Prefix for SSM Parameter Store paths"
  type        = string
  default     = "/fibi-quiz"
}
