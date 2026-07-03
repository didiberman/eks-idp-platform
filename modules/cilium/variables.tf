variable "cluster_name" {
  description = "EKS cluster name for Cilium ENI configuration"
  type        = string
}

variable "chart_version" {
  description = "Cilium Helm chart version"
  type        = string
  default     = "1.16.5"
}
