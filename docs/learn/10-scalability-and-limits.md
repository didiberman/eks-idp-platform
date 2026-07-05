# Lesson 10: Scalability and Limits

## What you'll learn

The complete map of where this platform stops scaling, how to measure each ceiling instead of guessing, and the production fix for each one. This lesson ties every previous lesson together.

## The core idea of the whole course

"Does it scale?" is an amateur question. The professional questions are:

1. **What breaks first?**
2. **At what number?**
3. **How do I know — did I measure or guess?**
4. **What's the fix, and when do I need it?**

Everything below answers those four questions for this platform.

## The ceiling map

In the order you'd actually hit them:

```
          load grows →

1. VPC IP space          ~600 pods        (Lesson 3 — the /16 + /24 decision)
2. Karpenter CPU cap     100 vCPU         (Lesson 6 — the deliberate circuit breaker)
3. System node group     2× t3.medium     (Lesson 4 — platform controllers saturate)
4. NAT throughput        per-AZ gateway   (Lesson 3 — egress-heavy workloads)
5. Kyverno admission     webhook latency  (Lesson 7 — at high pod churn)
6. ArgoCD sync queue     ~100 apps        (Lesson 8 — one controller instance)
```

Two observations worth internalizing:

- **The first ceiling is a networking decision made on day one**, before any workload existed. The most expensive-to-change limits are set earliest. This is why senior engineers obsess over VPC design in week one.
- **Ceilings hide behind each other.** You won't notice the NAT limit until you've raised the IP limit. Capacity planning is peeling an onion, which is why the ceiling *order* matters as much as the numbers.

## Measuring instead of guessing

The repo ships a benchmark suite (`tests/load/`) so every number above can be verified:

| Test | Ceiling it probes | Command |
|------|-------------------|---------|
| Capacity calculator | IP math, no cluster needed | `./capacity-calculator.sh` |
| Karpenter scale-up (40 pods) | Node provisioning speed + CPU cap | `./run-benchmark.sh karpenter` |
| HPA stress | Pod-level autoscaling response | `./run-benchmark.sh hpa` |
| Kyverno admission (100 pods) | Webhook throughput | `./run-benchmark.sh kyverno` |

Results land in `tests/load/results/`, with `results-template.md` for recording them properly. [ADR 003](../adr/003-single-cluster-scalability-limits.md) documents the accepted limits.

The habit this teaches: **never state a capacity number you can't back with a test you can re-run.** That habit, more than any tool, is what production experience means.

## The production fix for each ceiling

| Ceiling | The fix | Effort |
|---------|---------|--------|
| VPC IPs | Secondary CIDR block; prefix delegation; bigger subnets on day one | Medium (painful later) |
| Karpenter cap | Raise `limits.cpu`; add NodePools per workload class (general/GPU/arm64) | Trivial |
| System nodes | Larger instances, more replicas of controllers | Easy |
| NAT | VPC endpoints for ECR/S3 — most "internet" traffic is actually AWS traffic | Easy, saves money too |
| Kyverno | More admission replicas; keep policies simple; measure before enforce | Easy |
| ArgoCD | ApplicationSets; sharded controllers | Medium |

And the ceiling *behind* all of these: **one cluster is one blast radius.** Past a certain size, the answer stops being "bigger cluster" and becomes "more clusters" — per environment, per region, or per tenant (vCluster-style). That's the graduation point from cluster admin to platform architect.

## What's deliberately missing

An honest limits list includes the tooling gaps ([README roadmap](../../README.md)):

- **No Prometheus/Grafana** — right now, saturation is discovered by benchmark or by incident. A metrics stack turns ceilings into dashboards and alerts *before* users notice.
- **One environment** — a real platform proves changes in staging before prod.
- **Secrets management** — External Secrets Operator + AWS Secrets Manager is the next security layer.

Knowing what you *don't* have is as much a part of scalable design as building what you do.

## Final check — the whole course in five questions

1. A pod is `Pending`. Walk the diagnosis path across Lessons 3, 6, and 7 (IPs? CPU cap? admission?).
2. Why must the platform's own controllers (Karpenter, Kyverno, ArgoCD) never run on the capacity they manage?
3. Which day-one decision in this repo is hardest to change later, and what would you choose differently for a 5,000-pod target?
4. Your CI passed and the security scan was green — give one reason (Lesson 9) that isn't sufficient evidence of a safe pipeline.
5. Design interview closer: "How do you know your platform scales?" Answer in three sentences using numbers from this repo.

---

That's the course. The next step is the best one: **deploy it, run the benchmarks, fill in `results-template.md` with your own numbers, and break something on purpose.** The platform is small enough to understand and real enough to teach you what documents can't.
