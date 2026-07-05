# Lesson 6: Karpenter Autoscaling

## What you'll learn

How the cluster grows and shrinks by itself, why Karpenter replaced the older Cluster Autoscaler pattern, and where the deliberate limits are.

## The problem in simple words

Pods request CPU and memory. When no node has room, pods sit `Pending`. Someone — or something — must add a machine. When load drops, someone must remove machines, or you pay for air.

The old tool (Cluster Autoscaler) worked by resizing pre-defined groups of identical machines. It was slow (minutes) and rigid: you had to guess instance sizes upfront.

Karpenter's approach: watch for pending pods, then **create exactly the right machine directly** — usually in under a minute. No pre-defined groups. See [ADR 001](../adr/001-karpenter-over-cluster-autoscaler.md) for the full comparison.

## The three objects that matter

Open `modules/karpenter/main.tf` and find:

### NodePool — the rules of growth

```
requirements:
  arch:          amd64
  capacity-type: [on-demand, spot]
  instance-type: [t3.medium, t3.large, m6i.large, m6i.xlarge]
limits:
  cpu: 100
disruption:
  consolidationPolicy: WhenEmptyOrUnderutilized
```

In words: "Grow using these instance types, prefer whatever's cheapest including spot, never exceed 100 vCPUs total, and continuously repack pods onto fewer nodes when possible."

That `cpu: 100` limit is a **circuit breaker**. A bad deployment requesting a thousand replicas will not bankrupt you — it will hit the cap and stay pending. A limit you chose is infinitely better than a surprise bill.

### EC2NodeClass — what the machines look like

AMI family (AL2023), which subnets to join (found by the discovery tags from Lesson 3), which security group. The *how*, while NodePool is the *how much*.

### The interruption queue — living with spot

Spot instances are ~70% cheaper because AWS can reclaim them with **2 minutes' warning**. The module wires an SQS queue + EventBridge rule so the warning reaches Karpenter, which drains the node gracefully and starts a replacement before the machine disappears. That plumbing is the difference between "spot is a risk" and "spot is a discount".

## Consolidation: the money feature

`WhenEmptyOrUnderutilized` means Karpenter doesn't just add nodes — it notices when pods would fit on fewer machines, and actively replaces three half-empty nodes with one full one. Over months, this quiet repacking is often the single biggest cost saving on the platform.

The flip side: nodes get replaced *routinely*, not just during incidents. Apps must tolerate eviction — correct `PodDisruptionBudgets`, graceful shutdown, no "pet" pods. Platform design pushes discipline back onto app design.

## What breaks at scale

Measured and documented in Lesson 10, but the summary:

| Ceiling | Value | Where it's set |
|---------|-------|----------------|
| Total compute | 100 vCPU (~25 nodes) | NodePool `limits.cpu` |
| Pod IPs | ~600 | VPC subnets (Lesson 3) — Karpenter cannot help |
| Instance variety | 4 types, amd64 only | NodePool requirements |

The production path: multiple NodePools (general / GPU / Graviton-arm64), raised limits, and wider instance choice so spot has more markets to shop in.

## Try it

With a deployed cluster:

```bash
cd tests/load && ./run-benchmark.sh karpenter
```

Watch 40 pending pods trigger real node creation, timed. Clean up after: `./run-benchmark.sh cleanup`.

## Check yourself

1. Why is the 100 vCPU limit a feature and not a bug?
2. What happens, step by step, when AWS reclaims a spot node?
3. Karpenter is healthy but pods stay `Pending` forever. Name two ceilings from this course that could be the cause.

Next: [Lesson 7 — Kyverno Policies](07-kyverno-policies.md)
