output "namespace" {
  description = "Namespace where Kyverno is installed"
  value       = kubernetes_namespace.kyverno.metadata[0].name
}

output "release_name" {
  description = "Helm release name for Kyverno"
  value       = helm_release.kyverno.name
}
