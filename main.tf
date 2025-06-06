# main.tf

# Configure the AWS provider
provider "aws" {
  region = var.aws_region
}

# --- VPC and Subnets Module ---
# This module creates a new VPC, public and private subnets, NAT Gateway,
# and other necessary networking components for the EKS cluster.
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = data.aws_availability_zones.available.names
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

# --- EKS Cluster Module ---
# This module creates the EKS control plane and an associated managed node group.
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Enable Public and Private API server endpoint access
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # Add current user as admin to the cluster via cluster access entry
  # This makes it easier to connect to the cluster with kubectl after creation
  enable_cluster_creator_admin_permissions = true

  # Define EKS Managed Node Groups
  eks_managed_node_groups = {
    # Name of the node group
    default = {
      # Instance type for worker nodes
      instance_types = [var.instance_type]
      # Desired, min, and max size for the autoscaling group
      desired_size = var.desired_size
      max_size     = var.max_size
      min_size     = var.min_size

      # Optional: Enable IAM roles for Service Accounts (IRSA)
      # This is crucial for Kubernetes services to securely access AWS resources
      iam_role_additional_policies = {
        AmazonEKSWorkerNodePolicy = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      }
    }
  }

  tags = {
    Environment = "Dev"
    Project     = "KubernetesDashboard"
  }
}

# --- Kubernetes Provider Configuration ---
# The Kubernetes provider needs to authenticate with the EKS cluster.
# We retrieve the cluster details from the EKS module outputs.
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

# Data source to retrieve EKS cluster authentication token
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

# --- Helm Provider Configuration ---
# The Helm provider also needs to authenticate with the EKS cluster.
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

# --- Kubernetes Dashboard Deployment ---
# Deploy the Kubernetes Dashboard using its official Helm chart.
resource "helm_release" "kubernetes_dashboard" {
  name       = "kubernetes-dashboard"
  repository = "https://kubernetes.github.io/dashboard/"
  chart      = "kubernetes-dashboard"
  namespace  = "kubernetes-dashboard"
  # Create the namespace if it doesn't exist
  create_namespace = true

  # Increase the timeout for the Helm release to allow more time for resources to become ready
  timeout = "600" # Increased from default 300s (5 minutes) to 10 minutes

  # Set specific values for the Helm chart.
  # This makes the dashboard accessible via a LoadBalancer and configures RBAC.
  values = [
    # Expose the dashboard via a LoadBalancer for easier external access (e.g., from your machine).
    # In a production environment, you might use an Ingress controller.
    # We are setting up http as the protocol here, for easier access using kubectl proxy later.
    # For production, always use https.
    yamlencode({
      service = {
        type     = "LoadBalancer"
        externalPort = 80
        targetPort = 80
      }
      # Configure RBAC to allow an admin user to access the dashboard.
      # This is a broad permission for demonstration purposes.
      # For production, define more granular permissions.
      rbac = {
        create = true
        clusterAdminRole = true # Grants cluster-admin permissions
      }
      ingress = {
        enabled = false # We'll use kubectl proxy for access in this guide
      }
    })
  ]
}

# --- Kubernetes Dashboard Admin User Setup ---
# Create a ServiceAccount and ClusterRoleBinding for an admin user
# to authenticate with the Kubernetes Dashboard.
resource "kubernetes_service_account_v1" "dashboard_admin" {
  metadata {
    name      = "dashboard-admin-user"
    namespace = helm_release.kubernetes_dashboard.namespace # Use the namespace created by helm_release
  }
}

resource "kubernetes_cluster_role_binding_v1" "dashboard_admin_binding" {
  metadata {
    name = "dashboard-admin-user-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin" # Bind to cluster-admin for full access
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.dashboard_admin.metadata[0].name
    namespace = kubernetes_service_account_v1.dashboard_admin.metadata[0].namespace
  }
}

# Data source to fetch available AWS availability zones
data "aws_availability_zones" "available" {
  state = "available"
}
