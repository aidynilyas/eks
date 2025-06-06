# variables.tf

variable "aws_region" {
  description = "The AWS region to deploy the EKS cluster."
  type        = string
  default     = "us-east-1" # Change to your desired AWS region
}

variable "cluster_name" {
  description = "The name of the EKS cluster."
  type        = string
  default     = "my-eks-dashboard-cluster"
}

variable "instance_type" {
  description = "The EC2 instance type for the EKS worker nodes."
  type        = string
  default     = "t3.small" # Consider t3.small for cost savings if testing
}

variable "desired_size" {
  description = "The desired number of worker nodes in the EKS node group."
  type        = number
  default     = 2
}

variable "max_size" {
  description = "The maximum number of worker nodes in the EKS node group."
  type        = number
  default     = 3
}

variable "min_size" {
  description = "The minimum number of worker nodes in the EKS node group."
  type        = number
  default     = 1
}

variable "kubernetes_version" {
  description = "The Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.29" # Use a supported EKS version
}
