resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      "platform.eks-idp/component" = "argocd"
    }
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [
    yamlencode({
      global = {
        domain = var.domain != "" ? var.domain : "argocd.local"
      }
      configs = {
        params = {
          "server.insecure" = true
        }
      }
      server = {
        service = {
          type = var.enable_ingress ? "LoadBalancer" : "ClusterIP"
        }
        ingress = {
          enabled = false
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
      }
      controller = {
        replicas = 1
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
      }
      repoServer = {
        replicas = 1
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
      }
      applicationSet = {
        enabled = true
      }
      notifications = {
        enabled = true
      }
    })
  ]
}

resource "kubernetes_manifest" "golden_path_app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "golden-path"
      namespace = kubernetes_namespace.argocd.metadata[0].name
      labels = {
        "platform.eks-idp/component" = "golden-path"
      }
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://github.com/didiberman/eks-idp-platform.git"
        targetRevision = "main"
        path           = "apps/golden-path"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "golden-path"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }

  depends_on = [helm_release.argocd]
}
