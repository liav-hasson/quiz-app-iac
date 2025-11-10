output "nat_instance_id" {
  description = "ID of the NAT instance"
  value       = aws_instance.nat.id
}

output "nat_network_interface_id" {
  description = "Primary network interface ID of the NAT instance"
  value       = aws_instance.nat.primary_network_interface_id
}

output "nat_instance_private_ip" {
  description = "Private IP of the NAT instance"
  value       = aws_instance.nat.private_ip
}

output "nat_elastic_ip" {
  description = "Elastic IP of the NAT instance"
  value       = aws_eip.nat.public_ip
}

output "nat_security_group_id" {
  description = "Security group ID of the NAT instance"
  value       = aws_security_group.nat_instance.id
}