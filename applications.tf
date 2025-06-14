# # --- Deploy MySQL Helm Chart ---
# resource "helm_release" "mysql" {
#   name       = "nodejs-mysql"            # Release name for your MySQL deployment
#   repository = "."                     # This tells Helm to look for the chart locally
#   chart      = "./mysql"               # Path to your local MySQL chart directory
#   namespace  = "default"               # Or a dedicated namespace like "database"
#   create_namespace = true              # Ensures the namespace exists if it's not "default"
#   timeout = 600

#   # Values to override in your values.yaml for MySQL
#   # These should reflect your ClusterIP strategy, resource limits, etc.
#   values = [
#     # file("${path.module}/mysql/values.yaml"), # Load default values from chart
#     # You can add specific overrides here, e.g.:
#     # "image.tag=8.0",
#     # "service.type=ClusterIP", # Ensure this is explicitly set if not default in your chart
#     # "persistence.enabled=true",
#     # "persistence.size=10Gi",
#   ]

#   # Ensure EKS cluster is ready before deploying Helm charts
#   depends_on = [
#     module.eks.cluster_id,
#     module.eks.eks_managed_node_groups # Wait for node groups to be ready
#   ]
# }

# # --- Deploy API Helm Chart ---
# resource "helm_release" "api" {
#   name       = "nodejs-api"              # Release name for your API deployment
#   repository = "."
#   chart      = "./api"                 # Path to your local API chart directory
#   namespace  = "default"               # Or a dedicated namespace like "backend"
#   create_namespace = true

#   # Values to override for your API
#   values = [
#     # file("${path.module}/api/values.yaml"), # Load default values from chart
#     # "service.type=ClusterIP", # Ensure this is explicitly set if not default
#     # "image.repository=your-ecr-repo/your-api-image",
#     # "image.tag=latest",
#     # "replicaCount=3",
#   ]

#   # API depends on MySQL, so ensure MySQL is deployed first
#   depends_on = [
#     helm_release.mysql
#   ]
# }

# # --- Deploy Web Helm Chart ---
# resource "helm_release" "web" {
#   name       = "nodejs-web"              # Release name for your Web deployment
#   repository = "."
#   chart      = "./web"                 # Path to your local Web chart directory
#   namespace  = "default"               # Or a dedicated namespace like "frontend"
#   create_namespace = true

#   # Values to override for your Web frontend
#   values = [
#     # file("${path.module}/web/values.yaml"), # Load default values from chart
#     # "service.type=LoadBalancer", # Ensure this is explicitly set if not default
#     # "image.repository=your-ecr-repo/your-web-image",
#     # "image.tag=latest",
#     # "replicaCount=2",
#     # Pass API service endpoint if needed (example)
#     # "apiEndpoint=http://${helm_release.api.name}.${helm_release.api.namespace}.svc.cluster.local",
#   ]

#   # Web depends on API, so ensure API is deployed first
#   depends_on = [
#     helm_release.api
#   ]
# }