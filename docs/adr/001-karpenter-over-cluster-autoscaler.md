# ADR 001: Karpenter over Cluster Autoscaler

## Status

Accepted

## Context

The platform needs node autoscaling for developer workloads. EKS offers two primary approaches:

- **Cluster Autoscaler (CAS)** — scales existing Auto Scaling Groups
- **Karpenter** — provisions nodes directly via EC2 Fleet API

## Decision

We use **Karpenter** for workload node autoscaling.

## Rationale

| Factor | Karpenter | Cluster Autoscaler |
|--------|-----------|-------------------|
| Provisioning speed | Seconds (no ASG warm-up) | Minutes |
| Instance selection | Flexible per-pod requirements | Fixed ASG instance types |
| Bin-packing | Native consolidation | Limited |
| Spot integration | First-class | Supported but less granular |
| Industry adoption | Growing standard for new platforms | Legacy default |

Karpenter aligns with modern platform engineering practices and is used by companies like idealo, Datadog, and Netflix.

## Consequences

- Requires a bootstrap system node group (tainted) for platform controllers
- Karpenter controller needs IRSA with EC2 permissions
- SQS queue required for spot interruption handling
- Team must understand NodePool / EC2NodeClass CRDs

## Alternatives Considered

1. **Cluster Autoscaler** — simpler but slower and less flexible
2. **Fargate-only** — no node management but limited for platform workloads needing DaemonSets
