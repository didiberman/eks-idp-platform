resource "kubernetes_namespace" "kyverno" {
  metadata {
    name = "kyverno"
    labels = {
      "platform.eks-idp/component" = "kyverno"
    }
  }
}

resource "helm_release" "kyverno" {
  name       = "kyverno"
  repository = "https://kyverno.github.io/kyverno/"
  chart      = "kyverno"
  version    = var.chart_version
  namespace  = kubernetes_namespace.kyverno.metadata[0].name

  values = [
    yamlencode({
      admissionController = {
        replicas = 2
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
      backgroundController = {
        replicas = 1
      }
      cleanupController = {
        replicas = 1
      }
      reportsController = {
        replicas = 1
      }
    })
  ]
}

resource "kubernetes_manifest" "require_labels" {
  count = var.enable_policies ? 1 : 0

  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "require-standard-labels"
      annotations = {
        "policies.kyverno.io/title"       = "Require Standard Labels"
        "policies.kyverno.io/category"    = "Best Practices"
        "policies.kyverno.io/severity"    = "medium"
        "policies.kyverno.io/description" = "Enforces platform standard labels on workloads"
      }
    }
    spec = {
      validationFailureAction = "Audit"
      background              = true
      rules = [
        {
          name = "check-labels"
          match = {
            any = [
              {
                resources = {
                  kinds = ["Deployment", "StatefulSet", "DaemonSet"]
                }
              }
            ]
          }
          validate = {
            message = "Workloads must include app, team, and environment labels"
            pattern = {
              metadata = {
                labels = {
                  app         = "?*"
                  "app.team"  = "?*"
                  environment = "?*"
                }
              }
            }
          }
        }
      ]
    }
  }

  depends_on = [helm_release.kyverno]
}

resource "kubernetes_manifest" "disallow_latest_tag" {
  count = var.enable_policies ? 1 : 0

  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "disallow-latest-tag"
      annotations = {
        "policies.kyverno.io/title"       = "Disallow Latest Tag"
        "policies.kyverno.io/category"    = "Supply Chain"
        "policies.kyverno.io/severity"    = "high"
        "policies.kyverno.io/description" = "Prevents use of mutable :latest image tags"
      }
    }
    spec = {
      validationFailureAction = "Audit"
      background              = true
      rules = [
        {
          name = "require-image-tag"
          match = {
            any = [
              {
                resources = {
                  kinds = ["Pod"]
                }
              }
            ]
          }
          validate = {
            message = "Using ':latest' tag is not allowed"
            pattern = {
              spec = {
                containers = [
                  {
                    image = "!*:latest"
                  }
                ]
              }
            }
          }
        }
      ]
    }
  }

  depends_on = [helm_release.kyverno]
}

resource "kubernetes_manifest" "require_resource_limits" {
  count = var.enable_policies ? 1 : 0

  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "require-resource-limits"
      annotations = {
        "policies.kyverno.io/title"       = "Require Resource Limits"
        "policies.kyverno.io/category"    = "Best Practices"
        "policies.kyverno.io/severity"    = "medium"
        "policies.kyverno.io/description" = "Requires CPU and memory limits on all containers"
      }
    }
    spec = {
      validationFailureAction = "Audit"
      background              = true
      rules = [
        {
          name = "validate-limits"
          match = {
            any = [
              {
                resources = {
                  kinds = ["Pod"]
                }
              }
            ]
          }
          validate = {
            message = "CPU and memory limits are required"
            pattern = {
              spec = {
                containers = [
                  {
                    resources = {
                      limits = {
                        memory = "?*"
                        cpu    = "?*"
                      }
                    }
                  }
                ]
              }
            }
          }
        }
      ]
    }
  }

  depends_on = [helm_release.kyverno]
}

resource "kubernetes_manifest" "require_non_root" {
  count = var.enable_policies ? 1 : 0

  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "require-non-root"
      annotations = {
        "policies.kyverno.io/title"       = "Require Non-Root Containers"
        "policies.kyverno.io/category"    = "Pod Security"
        "policies.kyverno.io/severity"    = "high"
        "policies.kyverno.io/description" = "Containers must not run as root"
      }
    }
    spec = {
      validationFailureAction = "Audit"
      background              = true
      rules = [
        {
          name = "check-run-as-non-root"
          match = {
            any = [
              {
                resources = {
                  kinds = ["Pod"]
                }
              }
            ]
          }
          validate = {
            message = "Containers must set runAsNonRoot to true"
            pattern = {
              spec = {
                securityContext = {
                  runAsNonRoot = true
                }
                containers = [
                  {
                    securityContext = {
                      runAsNonRoot             = true
                      allowPrivilegeEscalation = false
                    }
                  }
                ]
              }
            }
          }
        }
      ]
    }
  }

  depends_on = [helm_release.kyverno]
}
