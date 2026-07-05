# ADR 003: Single-Cluster Scalability Limits

## Status

Accepted

## Context

The platform runs as a single EKS cluster with:

- 3-AZ VPC (`10.0.0.0/16`, `/24` private subnets)
- Tainted system node group (2× t3.medium)
- Karpenter NodePool (100 vCPU limit, 4 instance types)
- Cilium ENI mode for pod networking
- Kyverno, ArgoCD, and Cilium on system nodes

We need to understand where this architecture scales and where it stops.

## Decision

Accept single-cluster design for the **dev/portfolio** environment with **documented scalability ceilings** and a **repeatable benchmark suite** in `tests/load/`.

Do not prematurely optimize for multi-cluster or multi-tenant scale until benchmarks identify a real bottleneck.

## Scalability profile

### Scales well

- **Workload pods** — Karpenter provisions nodes in seconds; HPA scales golden-path replicas
- **Spot capacity** — NodePool allows spot + on-demand with consolidation
- **AZ failure** — 3-AZ networking and NAT per AZ

### Hits limits at

| Limit | Approximate ceiling | Mitigation |
|-------|---------------------|------------|
| Private subnet IPs | ~500–750 pods (ENI-dependent) | Secondary CIDR, larger subnets |
| Karpenter CPU cap | 100 vCPU (~25 nodes) | Raise `limits.cpu` in NodePool |
| System node group | 2 nodes, platform controllers | Larger instances or more replicas |
| NAT throughput | Per-AZ ~45 Gbps | VPC endpoints for ECR/S3/API |
| Single ArgoCD | ~100 apps before sync lag | ApplicationSets, sharding |

## Benchmark methodology

Run `tests/load/run-benchmark.sh` against a live cluster:

1. **Karpenter** — 40 pods @ 500m CPU → measure NodeClaim latency
2. **HPA** — HTTP load → golden-path scales 2→6
3. **Kyverno** — 100 pod admissions → measure job duration

Results recorded in `tests/load/results/` and `results-template.md`.

## Consequences

- Portfolio demonstrates measured limits, not assumed infinite scale
- Benchmark suite incurs real AWS cost (Karpenter provisions EC2) — cleanup required
- Production scaling path is documented but not implemented in v1

## Alternatives considered

1. **Multi-cluster from day one** — premature for dev; adds operational complexity without measured need
2. **Fargate-only** — no DaemonSets, incompatible with Cilium/Karpenter model
3. **Larger default VPC** — deferred; secondary CIDR is the standard AWS pattern when needed
