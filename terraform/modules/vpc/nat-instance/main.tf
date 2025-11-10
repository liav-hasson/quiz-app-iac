# Security Group for NAT Instance
resource "aws_security_group" "nat_instance" {
  name_prefix = "${var.project_name}-nat-instance-${var.environment}-"
  vpc_id      = var.vpc_id

  # Allow traffic from private subnets - SSH access via SSM only

  ingress {
    description = "HTTP from private subnets"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidrs
  }

  ingress {
    description = "HTTPS from private subnets"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidrs
  }

  ingress {
    description = "All TCP from private subnets"
    from_port   = 1024
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidrs
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-nat-security-group-${var.environment}"
    Environment = var.environment
    Type        = "NAT"
    Project     = var.project_name
  }
}

# NAT Instance
resource "aws_instance" "nat" {
  ami                         = var.nat_ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.nat_instance.id]
  associate_public_ip_address = true
  source_dest_check           = false # Critical for NAT functionality
  # key_name removed - using SSM Session Manager for access

  root_block_device {
    volume_type = "gp3"
    volume_size = var.volume_size
    encrypted   = true
  }

  tags = {
    Name        = "NAT Instance"
    Type        = "Network Infrastructure"
    Service     = "NAT"
    Environment = var.environment
    Subnet      = "Public"
    Purpose     = "Cost-optimized NAT Gateway replacement"
  }
}

# Elastic IP for NAT Instance
resource "aws_eip" "nat" {
  domain   = "vpc"
  instance = aws_instance.nat.id

  tags = {
    Name        = "NAT Instance EIP"
    Environment = var.environment
  }

  depends_on = [aws_instance.nat]
}
