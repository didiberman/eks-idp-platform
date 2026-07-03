output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "Kubernetes version"
  value       = module.eks.cluster_version
}

output "configure_kubectl" {
  description = "Command to configure kubectl for this cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "karpenter_namespace" {
  description = "Namespace where Karpenter is installed"
  value       = var.enable_karpenter ? module.karpenter[0].namespace : null
}

output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = var.enable_argocd ? module.argocd[0].namespace : null
}

output "argocd_admin_password_command" {
  description = "Command to retrieve the initial ArgoCD admin password"
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}
