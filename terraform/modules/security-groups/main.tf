# Jenkins Security Group
resource "aws_security_group" "jenkins" {
  name                   = var.jenkins_security_group_name
  description            = "Security group for Jenkins controller"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  # Dynamic ingress rules using loops
  dynamic "ingress" {
    for_each = var.jenkins_ingress_rules
    content {
      description = ingress.value.description
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks[0] == "10.0.0.0/16" ? [var.vpc_cidr] : ingress.value.cidr_blocks
    }
  }

  # Allow inbound from ALB security group (if provided)
  dynamic "ingress" {
    for_each = var.alb_security_group_id != null ? [1] : []
    content {
      description     = "HTTP from ALB"
      from_port       = 8080
      to_port         = 8080
      protocol        = "tcp"
      security_groups = [var.alb_security_group_id]
    }
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "Jenkins Security Group"
    Service     = "Jenkins"
    Environment = var.environment
  }
}

# Kubernetes Security Group (Dedicated for K8s cluster)
resource "aws_security_group" "kubernetes" {
  name                   = var.kubernetes_security_group_name
  description            = "Security group for Kubernetes cluster nodes"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  # Dynamic ingress rules using loops
  dynamic "ingress" {
    for_each = var.kubernetes_ingress_rules
    content {
      description = ingress.value.description
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks[0] == "10.0.0.0/16" ? [var.vpc_cidr] : ingress.value.cidr_blocks
    }
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "Kubernetes Security Group"
    Service     = "Kubernetes"
    Type        = "Cluster"
    Environment = var.environment
  }
}

# Separate security group rule for inter-cluster communication
# This prevents circular dependency issues during terraform destroy
resource "aws_security_group_rule" "kubernetes_inter_cluster" {
  description              = "Inter-cluster communication - All Traffic"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.kubernetes.id
  security_group_id        = aws_security_group.kubernetes.id

  # Explicit dependency to ensure proper destruction order
  depends_on = [aws_security_group.kubernetes]
}