# ============================================================================
# 1. KUBERNETES PROVIDER CONFIGURATION (Dynamic Auth)
# ============================================================================
data "aws_eks_cluster" "cluster" {
  name = "FVKR-DEV"
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  
  # The EXEC block ensures Terraform always has a valid token to avoid "no client config" errors
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", "FVKR-DEV"]
    command     = "aws"
  }
}

# ============================================================================
# 2. SERVICE DEFINITIONS (Mapped from your screenshot)
# ============================================================================
locals {
  target_group_services = {
    "argo-cd-new"                  = { node_port = 30080, k8s_service = "argo-cd-new-server", k8s_port = 80 }
    "argocd"                       = { node_port = 30100, k8s_service = "argocd-server",       k8s_port = 80 }
    "document-page-classification" = { node_port = 30003, k8s_service = "doc-page-svc",         k8s_port = 80 }
    "document-classification"      = { node_port = 30006, k8s_service = "doc-class-svc",        k8s_port = 80 }
    "document-field-extraction"    = { node_port = 30004, k8s_service = "field-ext-svc",        k8s_port = 80 }
    "fvrk-dev-tg"                  = { node_port = 30080, k8s_service = "fvrk-dev-svc",        k8s_port = 80 }
    "jenkins-tg"                   = { node_port = 8080,  k8s_service = "jenkins",              k8s_port = 8080 }
    "rabbit-mq"                    = { node_port = 30044, k8s_service = "rabbitmq",             k8s_port = 15672 }
    "validus"                      = { node_port = 30020, k8s_service = "validus-svc",          k8s_port = 80 }
    "keycloak"                     = { node_port = 30102, k8s_service = "keycloak-service",     k8s_port = 8080 }
    "konga-service"                = { node_port = 30108, k8s_service = "konga-service",        k8s_port = 1337 }
    "text-extraction"              = { node_port = 30015, k8s_service = "text-ext-svc",         k8s_port = 80 }
  }
}

# ============================================================================
# 3. AWS TARGET GROUPS (Creation)
# ============================================================================
resource "aws_lb_target_group" "main" {
  for_each = local.target_group_services

  name        = "k8s-${each.key}" # Prefixing as requested
  port        = each.value.node_port
  protocol    = "HTTP"
  vpc_id      = data.aws_eks_cluster.cluster.vpc_config[0].vpc_id
  target_type = "instance"

  health_check {
    path                = "/"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-499" # Handles apps that might return 404 on the root path
  }
}

# ============================================================================
# 4. KUBERNETES TARGET GROUP BINDINGS (Link to EKS)
# ============================================================================
resource "kubernetes_manifest" "tg_bindings" {
  for_each = local.target_group_services

  manifest = {
    apiVersion = "elbv2.k8s.aws/v1beta1"
    kind       = "TargetGroupBinding"
    metadata = {
      name      = "${each.key}-binding"
      namespace = "dev"
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