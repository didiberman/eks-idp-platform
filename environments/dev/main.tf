locals {
  name               = "${var.project_name}-${var.environment}"
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 3)

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

module "networking" {
  source = "../../modules/networking"

  name               = local.name
  vpc_cidr           = var.vpc_cidr
  availability_zones = local.availability_zones
  cluster_name       = var.cluster_name
  tags               = local.common_tags
}

module "eks" {
  source = "../../modules/eks"

  cluster_name                         = var.cluster_name
  cluster_version                      = var.cluster_version
  vpc_id                               = module.networking.vpc_id
  subnet_ids                           = module.networking.private_subnet_ids
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  enable_cilium                        = var.enable_cilium
  tags                                 = local.common_tags
}

module "cilium" {
  count  = var.enable_cilium ? 1 : 0
  source = "../../modules/cilium"

  cluster_name = var.cluster_name

  depends_on = [module.eks]
}

module "karpenter" {
  count  = var.enable_karpenter ? 1 : 0
  source = "../../modules/karpenter"

  cluster_name           = module.eks.cluster_name
  cluster_endpoint       = module.eks.cluster_endpoint
  oidc_provider_arn      = module.eks.oidc_provider_arn
  oidc_provider_url      = module.eks.oidc_provider_url
  node_role_name         = module.eks.node_role_name
  subnet_ids             = module.networking.private_subnet_ids
  node_security_group_id = module.eks.node_security_group_id
  tags                   = local.common_tags

  depends_on = [module.eks]
}

module "kyverno" {
  count  = var.enable_kyverno ? 1 : 0
  source = "../../modules/kyverno"

  depends_on = [module.eks]
}

module "argocd" {
  count  = var.enable_argocd ? 1 : 0
  source = "../../modules/argocd"

  depends_on = [module.eks]
}
