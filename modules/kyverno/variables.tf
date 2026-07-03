variable "chart_version" {
  description = "Kyverno Helm chart version"
  type        = string
  default     = "3.3.4"
}

variable "enable_policies" {
  description = "Whether to install baseline cluster policies"
  type        = bool
  default     = true
}
