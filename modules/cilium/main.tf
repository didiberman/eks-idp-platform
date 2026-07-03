resource "helm_release" "this" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = var.chart_version
  namespace  = "kube-system"

  values = [
    yamlencode({
      eni = {
        enabled = true
      }
      ipam = {
        mode = "eni"
      }
      egressMasqueradeInterfaces = "eth0"
      nodeinit = {
        enabled = true
      }
      operator = {
        replicas = 2
      }
      hubble = {
        enabled = true
        relay = {
          enabled = true
        }
        ui = {
          enabled = false
        }
      }
      policyEnforcementMode = "default"
    })
  ]
}
