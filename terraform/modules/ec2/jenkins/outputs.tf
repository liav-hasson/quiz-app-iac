output "instance_id" {
  description = "ID of the Jenkins instance"
  value       = aws_instance.jenkins.id
}

output "private_ip" {
  description = "Private IP address of Jenkins instance"
  value       = aws_instance.jenkins.private_ip
}