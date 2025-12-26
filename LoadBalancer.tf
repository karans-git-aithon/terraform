# ============================================================================
# LOADBALANCER.TF - Infrastructure Only (SG, ALB, Listeners)
# ============================================================================

# 1. SECURITY GROUP
resource "aws_security_group" "alb_sg" {
  name        = "Fvrk-dev-alb-sg"
  description = "Allow HTTP and HTTPS from anywhere"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Fvrk-dev-alb-sg"
  }
}

# 2. LOAD BALANCER
resource "aws_lb" "main" {
  name               = "Fvrk-dev-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = slice(aws_subnet.public[*].id, 0, 3) 
  idle_timeout       = 300 

  tags = {
    Name = "Fvrk-dev-alb"
  }
}

# 3. HTTP LISTENER (Redirect 80 -> 443)
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

# 4. HTTPS LISTENER (Port 443)
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  
  # YOUR CERTIFICATE
  certificate_arn   = "arn:aws:acm:ap-south-1:010438478476:certificate/027daaa8-4c47-41d3-ad8c-b7828d332752"

  # Default Action: Forward to Frontend (Target Group defined in other file)
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["fvrk-dev-tg"].arn
  }
}