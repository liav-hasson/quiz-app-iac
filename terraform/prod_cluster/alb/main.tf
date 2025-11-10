# =============================================================================
# Application Load Balancer for Jenkins and ArgoCD
# =============================================================================
# This ALB will be used by both Jenkins (ExternalName service) and ArgoCD (Ingress)
# ArgoCD will reference this ALB by its name via annotations

# Security Group for ALB
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  # HTTP access from anywhere
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access from anywhere
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound to EKS and Jenkins
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-alb-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.cluster_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection
  enable_http2              = true
  enable_cross_zone_load_balancing = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.cluster_name}-alb"
      # Required tag for AWS Load Balancer Controller to manage this ALB
      "elbv2.k8s.aws/cluster" = var.cluster_name
    }
  )
}

# Default Target Group (required for ALB, will be overridden by ArgoCD)
resource "aws_lb_target_group" "default" {
  name     = "${var.project_name}-default-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-default-tg"
    }
  )
}

# Quiz App Target Group (managed via TargetGroupBinding)
resource "aws_lb_target_group" "quiz_app" {
  name        = "${var.project_name}-quiz-app-tg"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"  # Required for EKS with IP mode

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    port                = "traffic-port"
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-quiz-app-tg"
      # Required for TargetGroupBinding to discover this target group
      "elbv2.k8s.aws/cluster" = var.cluster_name
    }
  )
}

# ArgoCD Target Group (managed via TargetGroupBinding)
# ArgoCD runs HTTP on port 8080, ALB terminates TLS
resource "aws_lb_target_group" "argocd" {
  name        = "${var.project_name}-argocd-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"  # Required for EKS with IP mode

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/healthz"
    protocol            = "HTTP"
    matcher             = "200-399"  # Accept redirects (ArgoCD returns 307)
    port                = "traffic-port"
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-argocd-tg"
      # Required for TargetGroupBinding to discover this target group
      "elbv2.k8s.aws/cluster" = var.cluster_name
    }
  )
}

# Jenkins Target Group (EC2 instance)
# Jenkins runs HTTP on port 8080
resource "aws_lb_target_group" "jenkins" {
  name        = "${var.project_name}-jenkins-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"  # EC2 instance

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/login"
    protocol            = "HTTP"
    matcher             = "200"
    port                = "traffic-port"
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-jenkins-tg"
    }
  )
}

# Register Jenkins EC2 instance to target group
resource "aws_lb_target_group_attachment" "jenkins" {
  target_group_arn = aws_lb_target_group.jenkins.arn
  target_id        = var.jenkins_instance_id
  port             = 8080
}

# HTTP Listener (redirects to HTTPS)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.certificate_arn

  # Default action (return 404 for unknown hosts)
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

# HTTPS Listener Rule for Quiz App
resource "aws_lb_listener_rule" "quiz_app" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.quiz_app.arn
  }

  condition {
    host_header {
      values = ["quiz.weatherlabs.org"]
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-quiz-app-rule"
    }
  )
}

# HTTPS Listener Rule for ArgoCD
resource "aws_lb_listener_rule" "argocd" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.argocd.arn
  }

  condition {
    host_header {
      values = ["argocd.weatherlabs.org"]
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-argocd-rule"
    }
  )
}

# HTTPS Listener Rule for Jenkins
resource "aws_lb_listener_rule" "jenkins" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 300

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins.arn
  }

  condition {
    host_header {
      values = ["jenkins.weatherlabs.org"]
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-jenkins-rule"
    }
  )
}