AWS EKS Cluster and Kubernetes Dashboard Deployment with Terraform
This repository contains Terraform configurations to automate the deployment of an Amazon Elastic Kubernetes Service (EKS) cluster and the Kubernetes Dashboard on AWS.

Table of Contents
Features

Prerequisites

Project Structure

Deployment Steps

Accessing the Kubernetes Dashboard

Updating Kubeconfig

Retrieving Dashboard Access Token

Starting Kubectl Proxy

Accessing in Browser

Troubleshooting Common Issues

Helm Release Timeout / "context deadline exceeded"

"services kubernetes-dashboard not found"

"SECRETS: 0" for Service Account / Token Generation Error

Cleanup

Important Security Notes

Features
Automated EKS Cluster Creation: Provisions a fully functional EKS cluster using the terraform-aws-modules/eks/aws module.

VPC and Networking Setup: Automatically sets up a dedicated VPC, public/private subnets, and NAT Gateway for the EKS cluster.

Managed Node Groups: Deploys EKS Managed Node Groups with configurable instance types and desired capacities.

Kubernetes Dashboard Deployment: Installs the official Kubernetes Dashboard using the Helm provider.

Dashboard Access Configuration: Sets up a dedicated Service Account and ClusterRoleBinding for secure dashboard access.

Prerequisites
Before you begin, ensure you have the following installed and configured on your local machine:

AWS CLI: Configured with credentials that have sufficient permissions to create EKS clusters, VPCs, IAM roles, etc.

Terraform (>= 1.0.0): Download and Install Terraform

kubectl: Install Kubectl

Helm: Install Helm

Project Structure
The project is organized into the following files:

eks-dashboard-automation/
├── main.tf             # Main Terraform configuration for EKS cluster and Dashboard
├── variables.tf        # Input variables for customization (e.g., region, instance types)
├── outputs.tf          # Outputs displaying cluster info and access commands
└── versions.tf         # Specifies required Terraform and provider versions

Deployment Steps
Clone the Repository:

git clone <your-repository-url>
cd eks-dashboard-automation

Initialize Terraform:
This command initializes the working directory, downloads the necessary providers and modules specified in versions.tf.

terraform init

Review the Plan:
Always review the execution plan before applying changes. This command shows you exactly what Terraform will create, modify, or destroy.

terraform plan

Apply the Changes:
This command applies the changes defined in your Terraform configuration. You will be prompted to confirm by typing yes. This process can take 15-25 minutes as AWS provisions the EKS cluster and its nodes.

terraform apply

Upon successful completion, Terraform will output important information needed to access your cluster and the Kubernetes Dashboard.

Accessing the Kubernetes Dashboard
Once terraform apply completes, follow these steps to securely access the Kubernetes Dashboard.

Updating Kubeconfig
First, configure kubectl to communicate with your new EKS cluster. Use the kubeconfig_command output from your terraform apply.

# Example command from outputs.tf (replace with your actual output):
aws eks update-kubeconfig --region us-east-1 --name my-eks-dashboard-cluster

Verify kubectl connectivity:

kubectl get nodes
kubectl get svc -n kubernetes-dashboard

Retrieving Dashboard Access Token
The Kubernetes Dashboard requires a bearer token for authentication. Use the following command to retrieve it.

For Linux/macOS (or Git Bash on Windows):

kubectl -n kubernetes-dashboard get secret $(kubectl -n kubernetes-dashboard get sa dashboard-admin-user -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 --decode

For PowerShell on Windows:

# Get the base64 encoded token
$token = kubectl -n kubernetes-dashboard get secret $(kubectl -n kubernetes-dashboard get sa dashboard-admin-user -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}'

# Decode the base64 token using PowerShell
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($token))

Note: Copy the entire string that is outputted. This is your bearer token.

Starting Kubectl Proxy
Open a new terminal window and run the kubectl proxy command. Keep this terminal window open as long as you want to access the dashboard.

kubectl proxy

This command makes the Kubernetes API, and thus the Dashboard, accessible via http://localhost:8001.

Accessing in Browser
Open your web browser and navigate to the following URL:

http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/http:kubernetes-dashboard:/proxy/

On the Kubernetes Dashboard login page, select the "Token" option, paste the bearer token you copied earlier, and click "Sign in."

Troubleshooting Common Issues
Helm Release Timeout / "context deadline exceeded"
If terraform apply times out during the helm_release.kubernetes_dashboard step with a "context deadline exceeded" error, it means the dashboard resources did not become ready within the default timeframe.

Solution:
The main.tf has been updated to include a timeout = "600s" (10 minutes) for the helm_release resource, which often resolves this. If you still encounter this, try increasing the timeout further, or check the status of Kubernetes resources directly:

helm status kubernetes-dashboard --namespace kubernetes-dashboard
kubectl get pods -n kubernetes-dashboard
kubectl get svc -n kubernetes-dashboard
kubectl get events -n kubernetes-dashboard

Look for pods that are not Running or services with pending external IPs.

"services kubernetes-dashboard not found"
This error indicates kubectl cannot locate the Kubernetes service for the dashboard.

Solution:
This often happens if the Helm release is still provisioning or failed. Follow the troubleshooting steps for "Helm Release Timeout" above to verify the status of the pods and services. Wait for the kubernetes-dashboard service to show a public IP (if LoadBalancer type) or for all dashboard pods to be in a Running state.

"SECRETS: 0" for Service Account / Token Generation Error
If kubectl get sa dashboard-admin-user -n kubernetes-dashboard shows SECRETS: 0, it means Kubernetes (versions 1.24+) no longer automatically creates long-lived secret tokens for service accounts by default.

Solution:
Manually generate a token for the dashboard-admin-user ServiceAccount using the kubectl create token command, as described in the Retrieving Dashboard Access Token section.

Cleanup
To destroy all AWS resources created by this Terraform configuration and avoid unnecessary charges, run the following command. You will be prompted to confirm by typing yes.

terraform destroy

Important Security Notes
Dashboard Access: Granting cluster-admin permissions to the dashboard-admin-user is convenient for demonstration purposes but is not recommended for production environments. In production, implement more granular Role-Based Access Control (RBAC) permissions.

Public Endpoint: The EKS cluster public endpoint and the LoadBalancer for the Kubernetes Dashboard are enabled for ease of access in this example. For production, consider restricting public access to the EKS API endpoint and using more secure ingress methods (e.g., Ingress controller with authenticated access, VPN, or private links).

Bearer Tokens: Treat bearer tokens as sensitive credentials. Do not share them publicly.

AWS Credentials: Ensure your AWS CLI credentials used for Terraform have the principle of least privilege applied.
