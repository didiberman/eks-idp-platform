variable "domain" {
  description = "Base domain for ArgoCD ingress (optional)"
  type        = string
  default     = ""
}

variable "chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "7.7.10"
}

variable "enable_ingress" {
  description = "Whether to expose ArgoCD via a LoadBalancer service"
  type        = bool
  default     = true
}
