output "namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "release_name" {
  description = "Helm release name for ArgoCD"
  value       = helm_release.argocd.name
}

output "server_service_name" {
  description = "Kubernetes service name for the ArgoCD API server"
  value       = "${helm_release.argocd.name}-server"
}
