# --- 1. Configure Helm Provider ---
# This block is REQUIRED to tell Terraform how to talk to your EKS cluster.
provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.main.name]
      command     = "aws"
    }
  }
}

# --- 2. Install Load Balancer Controller ---
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  # Prevent timeout errors
  wait    = false
  timeout = 600

  set {
    name  = "clusterName"
    value = aws_eks_cluster.main.name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  # --- CRITICAL FIXES FOR CRASHLOOP ---
  set {
    name  = "region"
    value = "ap-south-1" 
  }

  set {
    name  = "vpcId"
    # Robustly get VPC ID from the cluster config itself
    value = aws_eks_cluster.main.vpc_config[0].vpc_id
  }
}