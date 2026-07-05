# Scalability

How the EKS IDP platform scales, where it hits limits, and how to measure both.

---

## Architecture at a glance

```
                    ┌─────────────────────────────────────┐
                    │           Developer traffic          │
                    └──────────────────┬──────────────────┘
                                       │
         ┌─────────────────────────────▼─────────────────────────────┐
         │                     EKS Control Plane                      │
         │              (AWS-managed, multi-AZ by default)            │
         └─────────────────────────────┬─────────────────────────────┘
                                       │
    ┌──────────────────────────────────┼──────────────────────────────────┐
    │                                  │                                  │
    ▼                                  ▼                                  ▼
┌─────────┐                    ┌───────────────┐                  ┌─────────────┐
│ System  │                    │   Karpenter   │                  │   ArgoCD    │
│ nodes   │                    │   NodePool    │                  │   Kyverno   │
│ (fixed) │                    │  (elastic)    │                  │   Cilium    │
│ tainted │                    │ spot+on-demand│                  │ (platform)  │
└─────────┘                    └───────┬───────┘                  └─────────────┘
                                       │
                              Workload pods scale
                              horizontally via HPA
```

---

## What scales automatically

| Component | Mechanism | Current limit |
|-----------|-----------|---------------|
| **Workload pods** | HPA on golden-path (2–6 replicas) | CPU target 70% |
| **Worker nodes** | Karpenter NodePool + consolidation | 100 vCPU pool limit |
| **Instance selection** | Karpenter requirements | t3/m6i, amd64, spot+on-demand |
| **AZ resilience** | 3-AZ VPC + subnets | Survives single AZ loss |

---

## Known ceilings

### 1. VPC IP space

Default config uses `10.0.0.0/16` with `/24` private subnets across 3 AZs (~750 usable IPs total).

Cilium ENI mode assigns pod IPs from the VPC subnet. This is typically the **first hard limit**.

```bash
./tests/load/capacity-calculator.sh
```

### 2. Karpenter NodePool CPU cap

```hcl
limits = { cpu = "100" }
```

Caps total worker capacity at ~25× `t3.large` nodes regardless of subnet size.

### 3. System node group

2× `t3.medium` nodes (tainted `platform.eks-idp/role=system`) run:

- Karpenter controller
- Cilium operator
- Kyverno admission webhooks
- ArgoCD

Platform controllers do **not** scale with Karpenter. Heavy admission load or many ArgoCD syncs saturate here first.

### 4. NAT gateway throughput

3 NAT gateways (one per AZ) handle all private subnet egress. Egress-heavy workloads (image pulls, external APIs) hit NAT bandwidth before compute limits.

### 5. Single cluster design

One EKS cluster, one NodePool, one ArgoCD instance. Multi-tenant production IDPs typically shard by:

- NodePool per workload class (system / general / GPU)
- Cluster per environment or team
- ApplicationSet for bulk GitOps

---

## Bottleneck order (typical)

```
1. VPC private subnet IPs     ← most common first limit
2. Karpenter limits.cpu       ← configured cap
3. System node group CPU      ← platform controllers
4. NAT gateway throughput     ← egress-heavy apps
5. Kyverno admission latency  ← at Enforce + high churn
6. ArgoCD sync queue          ← many applications
```

---

## Running benchmarks

Full instructions: [tests/load/README.md](../tests/load/README.md)

```bash
cd tests/load
./run-benchmark.sh all      # ~6 minutes, provisions real nodes
./run-benchmark.sh cleanup  # tear down test workloads
```

### Test suite

| Test | Manifest | Measures |
|------|----------|----------|
| Karpenter scale-up | `karpenter-scale-up/deployment.yaml` | NodeClaim latency, scheduling throughput |
| HPA stress | `hpa-stress/load-generator.yaml` | Pod autoscaler response time |
| Kyverno admission | `kyverno-admission/job.yaml` | Webhook throughput (100 pods) |
| Cilium policies | `cilium-policies/policy-template.yaml` | Policy evaluation overhead (manual) |

Record results in [tests/load/results-template.md](../tests/load/results-template.md).

---

## Scaling levers (production path)

| Change | Module | Impact |
|--------|--------|--------|
| Secondary VPC CIDR | `modules/networking` | More pod IPs |
| Multiple NodePools | `modules/karpenter` | Isolate workload classes |
| Graviton instances | `modules/karpenter` | Lower cost, more capacity per $ |
| Larger system node group | `modules/eks` | More platform controller headroom |
| Kyverno `Enforce` + replicas | `modules/kyverno` | Policy compliance at scale |
| Prometheus + Grafana | new module | Data-driven capacity planning |
| VPC endpoints | `modules/networking` | Reduce NAT load |

---

## Interview talking points

1. **"How do you know it scales?"** — Karpenter handles node elasticity; I benchmarked X pods → Y nodes in Z seconds. VPC IP space is the first ceiling at ~N pods.

2. **"What breaks first?"** — Private subnet IPs, then Karpenter CPU limit, then system node group under heavy platform load.

3. **"How would you scale this for 50 teams?"** — Separate NodePools, secondary CIDR, Prometheus-based capacity alerts, ApplicationSets for GitOps, consider cluster-per-tenant with vCluster.

---

## Related

- [ADR 003: Single-cluster scalability limits](adr/003-single-cluster-scalability-limits.md)
- [ADR 001: Karpenter over Cluster Autoscaler](adr/001-karpenter-over-cluster-autoscaler.md)
