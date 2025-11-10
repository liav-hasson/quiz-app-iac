# Jenkins Controller - CI/CD automation server
resource "aws_instance" "jenkins" {
  ami                    = var.jenkins_ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [var.security_group_id]
  subnet_id              = var.private_subnet_ids[1] # Second private subnet (AZ-1b)
  iam_instance_profile   = var.iam_instance_profile_name

  # Jenkins requires more storage for builds and artifacts
  root_block_device {
    volume_type = "gp3"
    volume_size = var.volume_size
    encrypted   = true
  }

  tags = {
    Name        = var.instance_name
    Type        = "DevOps Infrastructure"
    Service     = "Jenkins"
    Environment = "Development"
    Subnet      = "Private"
  }
}