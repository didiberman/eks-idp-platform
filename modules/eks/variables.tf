variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.31"
}

variable "vpc_id" {
  description = "VPC ID where the cluster will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the EKS control plane and nodes"
  type        = list(string)
}

variable "cluster_endpoint_public_access" {
  description = "Whether the EKS API server endpoint is publicly accessible"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to access the public EKS API endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "system_node_instance_types" {
  description = "Instance types for the bootstrap system node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "system_node_desired_size" {
  description = "Desired number of nodes in the system node group"
  type        = number
  default     = 2
}

variable "system_node_min_size" {
  description = "Minimum number of nodes in the system node group"
  type        = number
  default     = 1
}

variable "system_node_max_size" {
  description = "Maximum number of nodes in the system node group"
  type        = number
  default     = 3
}

variable "enable_cilium" {
  description = "Whether to install Cilium as the cluster CNI"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to EKS resources"
  type        = map(string)
  default     = {}
}
