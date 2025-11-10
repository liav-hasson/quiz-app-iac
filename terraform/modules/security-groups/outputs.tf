output "jenkins_security_group_id" {
  description = "ID of Jenkins security group"
  value       = aws_security_group.jenkins.id
}

output "kubernetes_security_group_id" {
  description = "ID of Kubernetes security group"
  value       = aws_security_group.kubernetes.id
}