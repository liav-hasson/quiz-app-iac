output "iam_instance_profile_name" {
  description = "Name of the IAM instance profile for EC2 instances"
  value       = aws_iam_instance_profile.ec2_instance_profile.name
}

output "iam_role_arn" {
  description = "ARN of the IAM role for EC2 instances"
  value       = aws_iam_role.ec2_instance_role.arn
}

output "iam_role_name" {
  description = "Name of the IAM role for EC2 instances"
  value       = aws_iam_role.ec2_instance_role.name
}

output "alb_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller IRSA"
  value       = aws_iam_role.alb_controller.arn
}

output "external_secrets_role_arn" {
  description = "IAM role ARN for External Secrets Operator IRSA"
  value       = aws_iam_role.eso.arn
}
