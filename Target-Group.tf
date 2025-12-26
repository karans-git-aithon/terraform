# ============================================================================
# TARGET-GROUP.TF - Integrated EKS App Logic
# ============================================================================

# 1. KUBERNETES PROVIDER
data "aws_eks_cluster" "cluster" {
  name = "FVKR-DEV"
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", "FVKR-DEV"]
    command     = "aws"
  }
}

# 2. LOCALS (Service Definitions)
locals {
  target_group_services = {
    # --- DOCUMENT SERVICES (Namespace: dev) ---
    "document-page-classification" = { node_port = 30003, k8s_service = "doc-page-classification-service", k8s_port = 8003, health_path = "/health", namespace = "dev" }
    "document-classification"      = { node_port = 30006, k8s_service = "doc-classification-service", k8s_port = 8006, health_path = "/api/document-embedding-classification/health", namespace = "dev" }
    "document-field-extraction"    = { node_port = 30004, k8s_service = "doc-field-extraction-service", k8s_port = 8004, health_path = "/api/field-extraction/health", namespace = "dev" }
    "text-extraction"              = { node_port = 30015, k8s_service = "text-extraction-service", k8s_port = 8015, health_path = "/api/document-text-extraction/health", namespace = "dev" }
    
    # --- APP SERVICES (Namespace: dev) ---
    "validus"                      = { node_port = 30020, k8s_service = "validus-service", k8s_port = 8020, health_path = "/health", namespace = "dev" }
    "rabbit-mq"                    = { node_port = 30044, k8s_service = "rabbitmq-service", k8s_port = 15672, health_path = "/api/health/checks/virtual-hosts", namespace = "dev" }
    "fvrk-dev-tg"                  = { node_port = 30080, k8s_service = "frame-validus-service", k8s_port = 80, health_path = "/", namespace = "dev" }
    "frame"                        = { node_port = 30040, k8s_service = "frame-service", k8s_port = 8040, health_path = "/health", namespace = "dev" }   
    
    # --- INFRA SERVICES (Namespace: dev) ---
    "keycloak"                     = { node_port = 30102, k8s_service = "keycloak-service", k8s_port = 8080, health_path = "/health/live", namespace = "dev" }
    "konga-service"                = { node_port = 30108, k8s_service = "konga-service", k8s_port = 1337, health_path = "/status", namespace = "dev" }
    
    # UPDATED: Jenkins configuration matching your K8s NodePort and Service Name
    "jenkins-tg"                   = { node_port = 30088, k8s_service = "jenkins-service", k8s_port = 8080, health_path = "/login", namespace = "dev" }
    
    # --- ARGO CD (Namespace: argocd) ---
    "argocd" = { 
       node_port   = 30100, 
       k8s_service = "argocd-server-nodeport", 
       k8s_port    = 80, 
       health_path = "/healthz", 
       namespace   = "argocd" 
    } 
  }
}

# 3. AWS TARGET GROUPS
resource "aws_lb_target_group" "main" {
  for_each = local.target_group_services

  name        = "k8s-${each.key}"
  port        = each.value.node_port
  protocol    = "HTTP"
  vpc_id      = data.aws_eks_cluster.cluster.vpc_config[0].vpc_id
  target_type = "instance"

  health_check {
    path                = each.value.health_path
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-499"
  }

  tags = {
    ManagedBy = "Terraform"
  }
}

# 4. KUBERNETES BINDINGS (This automatically registers K8s pods into the AWS TGs)
resource "kubernetes_manifest" "tg_bindings" {
  for_each = local.target_group_services

  manifest = {
    apiVersion = "elbv2.k8s.aws/v1beta1"
    kind       = "TargetGroupBinding"
    metadata = {
      name      = "${each.key}-binding"
      namespace = each.value.namespace
    }
    spec = {
      serviceRef = {
        name = each.value.k8s_service
        port = each.value.k8s_port
      }
      targetGroupARN = aws_lb_target_group.main[each.key].arn
      targetType     = "instance"
    }
  }
}

# 5. LISTENER RULES (Routing Logic)

# Rule 1: Document Classification (Path-based)
resource "aws_lb_listener_rule" "rule_1" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 1
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["document-classification"].arn
  }
  condition {
    path_pattern {
      values = ["/api/document-embedding-classification/*"]
    }
  }
}

# Rule 2: Validus (Host-based)
resource "aws_lb_listener_rule" "rule_2" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 2
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["validus"].arn
  }
  condition {
    host_header {
      values = ["validus.aithondev.com"]
    }
  }
}

# Rule 3: Jenkins (Host-based)
resource "aws_lb_listener_rule" "rule_3" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 3
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["jenkins-tg"].arn
  }
  condition {
    host_header {
      values = ["jenkins.aithondev.com"]
    }
  }
}

# Rule 4: ArgoCD (Host-based)
resource "aws_lb_listener_rule" "rule_4" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 4
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["argocd"].arn
  }
  condition {
    host_header {
      values = ["argocd.aithondev.com"]
    }
  }
}

# Rule 5: Page Classification (Path-based)
resource "aws_lb_listener_rule" "rule_5" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 5
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["document-page-classification"].arn
  }
  condition {
    path_pattern {
      values = ["/api/page-classification/*"]
    }
  }
}

# Rule 6: Field Extraction (Path-based)
resource "aws_lb_listener_rule" "rule_6" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 6
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["document-field-extraction"].arn
  }
  condition {
    path_pattern {
      values = ["/api/field-extraction/*"]
    }
  }
}

# Rule 7: Konga (Host-based)
resource "aws_lb_listener_rule" "rule_7" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 7
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["konga-service"].arn
  }
  condition {
    host_header {
      values = ["konga.aithondev.com"]
    }
  }
}

# Rule 8: Keycloak (Host-based)
resource "aws_lb_listener_rule" "rule_8" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 8
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["keycloak"].arn
  }
  condition {
    host_header {
      values = ["keycloak.aithondev.com"]
    }
  }
}

# Rule 9: RabbitMQ (Host-based)
resource "aws_lb_listener_rule" "rule_9" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 9
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["rabbit-mq"].arn
  }
  condition {
    host_header {
      values = ["rabbitmq.aithondev.com"]
    }
  }
}

# Rule 10: Text Extraction (Path-based)
resource "aws_lb_listener_rule" "rule_10" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["text-extraction"].arn
  }
  condition {
    path_pattern {
      values = ["/api/document-text-extraction/*"]
    }
  }
}

# Rule 12: Frame (Host-based)
resource "aws_lb_listener_rule" "rule_12" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 12
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["frame"].arn
  }
  condition {
    host_header {
      values = ["frame.aithondev.com"]
    }
  }
}