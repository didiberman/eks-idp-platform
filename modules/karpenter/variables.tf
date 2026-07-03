variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider for IRSA"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the EKS OIDC provider (without https:// prefix)"
  type        = string
}

variable "node_role_name" {
  description = "IAM role name attached to EKS worker nodes"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs available to Karpenter-provisioned nodes"
  type        = list(string)
}

variable "node_security_group_id" {
  description = "Security group ID for Karpenter-provisioned nodes"
  type        = string
}

variable "chart_version" {
  description = "Karpenter Helm chart version"
  type        = string
  default     = "1.1.1"
}

variable "tags" {
  description = "Tags applied to Karpenter AWS resources"
  type        = map(string)
  default     = {}
}
