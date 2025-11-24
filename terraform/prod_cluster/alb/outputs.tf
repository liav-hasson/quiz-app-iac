output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "alb_name" {
  description = "Name of the ALB (used in ArgoCD annotations)"
  value       = aws_lb.main.name
}

output "alb_security_group_id" {
  description = "Security group ID of the ALB"
  value       = aws_security_group.alb.id
}

output "quiz_backend_target_group_arn" {
  description = "ARN of the quiz backend target group for TargetGroupBinding"
  value       = aws_lb_target_group.quiz_backend.arn
}

output "quiz_frontend_target_group_arn" {
  description = "ARN of the quiz frontend target group for TargetGroupBinding"
  value       = aws_lb_target_group.quiz_frontend.arn
}

output "quiz_app_target_group_arn" {
  description = "(Deprecated) ARN of the quiz app target group"
  value       = aws_lb_target_group.quiz_backend.arn
}

output "argocd_target_group_arn" {
  description = "ARN of the ArgoCD target group for TargetGroupBinding"
  value       = aws_lb_target_group.argocd.arn
}

output "jenkins_target_group_arn" {
  description = "ARN of the Jenkins target group"
  value       = aws_lb_target_group.jenkins.arn
}

output "grafana_target_group_arn" {
  description = "ARN of the Grafana target group for TargetGroupBinding"
  value       = aws_lb_target_group.grafana.arn
}

output "loki_target_group_arn" {
  description = "ARN of the Loki target group for TargetGroupBinding"
  value       = aws_lb_target_group.loki.arn
}

output "quiz_backend_dev_target_group_arn" {
  description = "ARN of the quiz backend DEV target group for TargetGroupBinding"
  value       = aws_lb_target_group.quiz_backend_dev.arn
}

output "quiz_frontend_dev_target_group_arn" {
  description = "ARN of the quiz frontend DEV target group for TargetGroupBinding"
  value       = aws_lb_target_group.quiz_frontend_dev.arn
}
