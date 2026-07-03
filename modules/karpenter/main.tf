data "aws_region" "current" {}
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  karpenter_namespace = "karpenter"
  account_id          = data.aws_caller_identity.current.account_id
  partition           = data.aws_partition.current.partition
  region              = data.aws_region.current.name
}

resource "aws_sqs_queue" "interruption" {
  name                      = "${var.cluster_name}-karpenter-interruption"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-karpenter-interruption"
  })
}

resource "aws_sqs_queue_policy" "interruption" {
  queue_url = aws_sqs_queue.interruption.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowEventBridge"
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.interruption.arn
      },
      {
        Sid       = "AllowSqs"
        Effect    = "Allow"
        Principal = { Service = "sqs.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.interruption.arn
      },
    ]
  })
}

resource "aws_cloudwatch_event_rule" "spot_interruption" {
  name        = "${var.cluster_name}-karpenter-spot-interruption"
  description = "Forward EC2 spot interruption warnings to Karpenter"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "spot_interruption" {
  rule      = aws_cloudwatch_event_rule.spot_interruption.name
  target_id = "karpenter-interruption-queue"
  arn       = aws_sqs_queue.interruption.arn
}

resource "aws_iam_role" "controller" {
  name = "${var.cluster_name}-karpenter-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:${local.karpenter_namespace}:karpenter"
            "${replace(var.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "controller" {
  name = "${var.cluster_name}-karpenter-controller"
  role = aws_iam_role.controller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KarpenterCore"
        Effect = "Allow"
        Action = [
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateTags",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstances",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets",
          "ec2:DeleteLaunchTemplate",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "pricing:GetProducts",
          "ssm:GetParameter",
        ]
        Resource = "*"
      },
      {
        Sid      = "KarpenterPassRole"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = "arn:${local.partition}:iam::${local.account_id}:role/${var.node_role_name}"
      },
      {
        Sid    = "KarpenterInterruptionQueue"
        Effect = "Allow"
        Action = [
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage",
        ]
        Resource = aws_sqs_queue.interruption.arn
      },
      {
        Sid      = "KarpenterEKS"
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = "arn:${local.partition}:eks:${local.region}:${local.account_id}:cluster/${var.cluster_name}"
      },
    ]
  })
}

resource "kubernetes_namespace" "karpenter" {
  metadata {
    name = local.karpenter_namespace
    labels = {
      "platform.eks-idp/component" = "karpenter"
    }
  }
}

resource "helm_release" "karpenter" {
  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = var.chart_version
  namespace  = kubernetes_namespace.karpenter.metadata[0].name

  values = [
    yamlencode({
      settings = {
        clusterName       = var.cluster_name
        clusterEndpoint   = var.cluster_endpoint
        interruptionQueue = aws_sqs_queue.interruption.name
      }
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.controller.arn
        }
      }
      controller = {
        resources = {
          requests = {
            cpu    = "250m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "1"
            memory = "1Gi"
          }
        }
      }
      tolerations = [
        {
          key      = "platform.eks-idp/role"
          operator = "Equal"
          value    = "system"
          effect   = "NoSchedule"
        }
      ]
      nodeSelector = {
        "platform.eks-idp/role" = "system"
      }
    })
  ]

  depends_on = [aws_iam_role_policy.controller]
}

resource "kubernetes_manifest" "ec2_node_class" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "default"
    }
    spec = {
      amiSelectorTerms = [
        {
          alias = "al2023@latest"
        }
      ]
      role = var.node_role_name
      subnetSelectorTerms = [
        for subnet_id in var.subnet_ids : {
          id = subnet_id
        }
      ]
      securityGroupSelectorTerms = [
        {
          id = var.node_security_group_id
        }
      ]
      tags = merge(var.tags, {
        "karpenter.sh/discovery" = var.cluster_name
      })
    }
  }

  depends_on = [helm_release.karpenter]
}

resource "kubernetes_manifest" "node_pool" {
  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "default"
    }
    spec = {
      template = {
        spec = {
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "default"
          }
          requirements = [
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["amd64"]
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["on-demand", "spot"]
            },
            {
              key      = "node.kubernetes.io/instance-type"
              operator = "In"
              values   = ["t3.medium", "t3.large", "m6i.large", "m6i.xlarge"]
            },
          ]
        }
      }
      limits = {
        cpu = "100"
      }
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "1m"
      }
    }
  }

  depends_on = [kubernetes_manifest.ec2_node_class]
}
