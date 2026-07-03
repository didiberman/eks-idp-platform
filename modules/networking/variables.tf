variable "name" {
  description = "Name prefix for networking resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones for subnet placement"
  type        = list(string)
}

variable "cluster_name" {
  description = "EKS cluster name used for discovery tags"
  type        = string
}

variable "enable_flow_logs" {
  description = "Whether to enable VPC flow logs"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to networking resources"
  type        = map(string)
  default     = {}
}
