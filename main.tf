# Configure the AWS provider
provider "aws" {
  region = var.aws_region
}

# Configure the Kubernetes provider to connect to the EKS cluster
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token # See data block below
}

# Data source for EKS cluster authentication token
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}


# Configure the Helm provider to connect to the Kubernetes cluster
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

# Data source to fetch available AWS availability zones
data "aws_availability_zones" "available" {
  state = "available"
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
        AmazonEKSWorkerNodePolicy        = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      }
    }
  }

  tags = {
    Environment = "Dev"
    Project     = "KubernetesDashboard"
  }
}