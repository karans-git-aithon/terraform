# --- 1. Security Group for ALB ---
resource "aws_security_group" "alb_sg" {
  name        = "Fvrk-dev-alb-sg"
  description = "Allow HTTP and HTTPS from anywhere"
  vpc_id      = aws_vpc.main.id

  # HTTP (Port 80)
  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS (Port 443)
  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound (Allow all)
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

# --- 2. Application Load Balancer ---
resource "aws_lb" "main" {
  name               = "Fvrk-dev-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  
  # FIX: Use 'slice' to pick only the first 3 subnets.
  # This ensures we pick [Zone A, Zone B, Zone C] and ignore the duplicate Zone A.
  subnets = slice(aws_subnet.public[*].id, 0, 3)

  tags = {
    Name = "Fvrk-dev-alb"
  }
}

# --- 3. Target Group ---
# We point this to Port 30080 (The standard NodePort range for K8s)
resource "aws_lb_target_group" "app_tg" {
  name     = "Fvrk-dev-tg"
  port     = 30080 
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# --- 4. HTTP Listener (Port 80) ---
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# --- 5. HTTPS Listener (Port 443) ---
# NOTE: This will fail if you do not have a valid SSL Certificate ARN.
# I have commented it out. To use it, uncomment and add your Certificate ARN.

/*
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:ap-south-1:YOUR_ACCOUNT_ID:certificate/YOUR_CERT_ID"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}
*/