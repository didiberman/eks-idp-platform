output "release_name" {
  description = "Helm release name for Cilium"
  value       = helm_release.this.name
}

output "release_namespace" {
  description = "Namespace where Cilium is installed"
  value       = helm_release.this.namespace
}
