variable "aws_region" {
  description = "AWS region for the platform"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "eks-idp-platform"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.project_name))
    error_message = "Project name must start with a letter and contain only lowercase letters, numbers, and hyphens."
  }

  nullable = false
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }

  nullable = false
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "eks-idp-dev"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.31"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_cilium" {
  description = "Install Cilium as the cluster CNI (disables AWS VPC CNI)"
  type        = bool
  default     = true
}

variable "enable_karpenter" {
  description = "Install Karpenter for node autoscaling"
  type        = bool
  default     = true
}

variable "enable_kyverno" {
  description = "Install Kyverno policy engine"
  type        = bool
  default     = true
}

variable "enable_argocd" {
  description = "Install ArgoCD for GitOps"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to access the public EKS API endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
