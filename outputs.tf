# outputs.tf

output "cluster_name" {
  description = "The name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "The endpoint for the EKS cluster API."
  value       = module.eks.cluster_endpoint
}

output "kubeconfig_command" {
  description = "Command to update your kubeconfig to connect to the EKS cluster."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
