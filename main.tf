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

resource "aws_iam_role" "ebs_csi_driver" {
  name_prefix = "${var.cluster_name}-ebs-csi-role" # Or simply "ebs-csi-driver-role"
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Condition = {
        StringEquals = {
          "${replace(module.eks.oidc_provider, "https://", "")}:sub" : "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          "${replace(module.eks.oidc_provider, "https://", "")}:aud" : "sts.amazonaws.com"
        }
      }
    }]
    Version = "2012-10-17"
  })

  tags = {
    Name = "${var.cluster_name}-ebs-csi-role"
  }
}

# 2. Attach the necessary IAM Policy to the role
resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver.name
}

# 3. Deploy the EBS CSI Addon using the aws_eks_addon resource
resource "aws_eks_addon" "ebs_csi_driver_addon" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  # This version should match your EKS cluster version.
  # For EKS 1.28, "v1.28.0-eksbuild.1" is common. Check AWS EKS Add-ons documentation for your exact K8s version.
  # https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html
  # Or use a data source to get the latest compatible version:
  addon_version            = "v1.28.0-eksbuild.1" # Adjust based on your `var.kubernetes_version`

  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn # Link to the IAM role created above

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # Ensure this add-on is deployed after the cluster and node groups are stable
  depends_on = [
    module.eks.eks_managed_node_groups,
    aws_iam_role_policy_attachment.ebs_csi_driver_policy # Ensure role is attached
  ]
}