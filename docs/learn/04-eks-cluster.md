# Lesson 4: The EKS Cluster

## What you'll learn

What AWS manages vs what you manage, why platform pods get their own tainted nodes, and how pods get AWS permissions without anyone storing keys.

## The split: control plane vs data plane

EKS is Kubernetes where AWS runs the **control plane** — the API server, scheduler, and etcd database — across multiple AZs for you, for ~$73/month. You never see those machines.

You own the **data plane**: the EC2 nodes where pods actually run. Everything in `modules/eks/main.tf` is about setting up that ownership safely.

## The system node group: a small fixed island

The module creates one node group of 2× `t3.medium` with something unusual — a **taint**:

```hcl
taint {
  key    = "platform.eks-idp/role"
  value  = "system"
  effect = "NO_SCHEDULE"
}
```

A taint means "no pod may land here unless it explicitly tolerates this". Platform components (Karpenter, Kyverno, ArgoCD, the Cilium operator) carry the matching toleration; normal apps don't.

Why bother? Think about the alternative. Karpenter — the thing that *creates nodes* — runs as pods. If those pods ran on nodes that Karpenter itself manages, a scale-down decision could evict the autoscaler, and now nothing can create nodes. A deadlock you can only fix by hand at 3am.

The rule generalizes: **the machinery that manages capacity must not depend on the capacity it manages.** Fixed island for platform controllers; elastic ocean (Lesson 6) for everything else.

Consequence worth knowing: on a fresh cluster there are **zero workload nodes**. The first app pod sits `Pending` until Karpenter reacts. That's not a bug — it's the design.

## IRSA: AWS permissions without secrets

Pods often need AWS access (Karpenter must call EC2 to create instances). The old way: create an AWS key, paste it into a Kubernetes secret, hope nobody leaks it.

The way this repo does it — **IRSA** (IAM Roles for Service Accounts), set up in `modules/eks/irsa.tf`:

1. The cluster gets an **OIDC identity provider** — think of it as the cluster's passport office.
2. An IAM role says: "I trust tokens issued by this cluster, but only for the service account `karpenter` in the namespace `karpenter`."
3. The pod presents its token; AWS exchanges it for short-lived credentials.

No stored keys. Credentials expire in minutes. Each pod gets exactly its own permissions — Karpenter can create instances, but the golden-path app can't touch EC2 at all. Scoping in the trust condition (down to a single service account name) is the whole trick; you can read it in `modules/karpenter/main.tf`.

## The other security defaults

Each of these is one block of Terraform and one interview answer:

- **KMS encryption of secrets** — Kubernetes secrets are base64 by default, which is *encoding, not encryption*. The `encryption_config` block encrypts them with a customer KMS key inside etcd.
- **Control plane logs** — all five types (`api`, `audit`, `authenticator`, `controllerManager`, `scheduler`) go to CloudWatch. The audit log is how you answer "who deleted that deployment?"
- **Access entries** — the modern replacement for the infamous `aws-auth` ConfigMap, where a typo could lock everyone out of the cluster. Access is now proper AWS API resources.
- **VPC CNI conditionally disabled** — when Cilium is enabled, the default AWS CNI addon is skipped (`count = var.enable_cilium ? 0 : 1`). Two CNIs fighting over pod networking is a classic broken-cluster story; Lesson 5 explains what Cilium does instead.

## What breaks at scale

The system node group is **fixed at 2 nodes**. Every admission request (Lesson 7), every GitOps sync (Lesson 8), every autoscaling decision runs on those two small machines. Under heavy platform load they saturate *before* the workload capacity does — which surprises people, because the cluster looks half-empty while the platform crawls. The fix is boring and effective: bigger system nodes, more replicas.

## Check yourself

1. Explain the deadlock that tainted system nodes prevent.
2. Why is IRSA safer than a Kubernetes secret containing AWS keys — give two reasons.
3. A teammate says "Kubernetes secrets are encrypted by default." What's your correction?

Next: [Lesson 5 — Cilium Networking](05-cilium-networking.md)
