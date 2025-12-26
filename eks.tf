# --- 1. The EKS Cluster ---
resource "aws_eks_cluster" "main" {
  name     = "FVKR-DEV"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.34"

  vpc_config {
    # Use PUBLIC subnets only (Cheapest option)
    subnet_ids             = aws_subnet.public[*].id
    endpoint_public_access = true
  }

  # Modern Authentication (Keeps access simple)
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

# 

# --- 2. The Managed Node Group (Standard Mode) ---
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "Fvrk-dev-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn

  subnet_ids = aws_subnet.public[*].id

  # --- LINK THE LAUNCH TEMPLATE HERE ---
  launch_template {
    id      = aws_launch_template.eks_node_lt.id
    version = "1"
  }
  # -------------------------------------

  scaling_config {
    desired_size = 4
    max_size     = 6
    min_size     = 0
  }

  instance_types = ["t3.medium"] 
  capacity_type  = "ON_DEMAND"

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ec2_container_registry_read_only,
    aws_iam_role_policy_attachment.eks_efs_csi_policy, # Ensure this is here
  ]

  tags = {
    Name = "Fvrk-dev-node"
  }
}

# --- 3. Essential Add-ons (Optional but recommended) ---
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"
}

# --- 4. Storage & Networking Add-ons (Enable EFS & ALB) ---

# 1. EFS CSI Driver (Allows using EFS as Persistent Volumes)
resource "aws_eks_addon" "efs_csi_driver" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "aws-efs-csi-driver"
  
  # This version auto-updates to the latest compatible version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

# # 2. AWS Load Balancer Controller (Manages ALBs/Target Groups automatically)
# resource "aws_eks_addon" "aws_load_balancer_controller" {
#   cluster_name = aws_eks_cluster.main.name
#   addon_name   = "aws-load-balancer-controller"
  
#   resolve_conflicts_on_create = "OVERWRITE"
#   resolve_conflicts_on_update = "OVERWRITE"
# }

# --- Launch Template to Fix Metadata Access (Hop Limit) ---
resource "aws_launch_template" "eks_node_lt" {
  name_prefix   = "eks-node-lt-"
  description   = "Launch template for EKS nodes with Hop Limit 2"

  # This allows Pods to access the Node's IAM Role
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2  # <--- THE CRITICAL FIX
    instance_metadata_tags      = "enabled"
  }
}