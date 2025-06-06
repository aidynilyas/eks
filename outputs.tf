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

output "dashboard_service_account_name" {
  description = "The name of the ServiceAccount for the Kubernetes Dashboard admin user."
  value       = kubernetes_service_account_v1.dashboard_admin.metadata[0].name
}

output "dashboard_namespace" {
  description = "The namespace where the Kubernetes Dashboard is deployed."
  value       = helm_release.kubernetes_dashboard.namespace
}

output "get_dashboard_token_command" {
  description = "Command to retrieve the bearer token for Kubernetes Dashboard access."
  value       = "kubectl -n ${helm_release.kubernetes_dashboard.namespace} get secret $(kubectl -n ${helm_release.kubernetes_dashboard.namespace} get sa ${kubernetes_service_account_v1.dashboard_admin.metadata[0].name} -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 --decode"
}

output "kubectl_proxy_command" {
  description = "Command to start kubectl proxy to access the Kubernetes Dashboard."
  value       = "kubectl proxy"
}
