# Lesson 1: The Big Picture

## What you'll learn

What an Internal Developer Platform (IDP) is, and why this repo has six Terraform modules instead of one.

## The problem in simple words

Imagine a company with 20 development teams. Each team needs to run their apps on Kubernetes. You have two options:

1. **Every team builds their own infrastructure.** 20 teams make 20 different clusters with 20 different security setups. Most of them get something wrong, and nobody can help anyone else because everything is different.
2. **One platform team builds a paved road.** Developers get a well-lit path: "push your code here, label it like this, and the platform handles networking, scaling, security, and deployment."

Option 2 is an Internal Developer Platform. This repo is a small but real version of one.

## The stack, layer by layer

Think of the platform as a building:

```
  ┌──────────────────────────────────────────┐
  │  Apps (what developers care about)       │   apps/golden-path/
  ├──────────────────────────────────────────┤
  │  Delivery: how apps reach the cluster    │   modules/argocd
  │  Rules: what apps are allowed to do      │   modules/kyverno
  ├──────────────────────────────────────────┤
  │  Compute: machines appear on demand      │   modules/karpenter
  │  Network inside: pod-to-pod traffic      │   modules/cilium
  ├──────────────────────────────────────────┤
  │  The cluster itself                      │   modules/eks
  │  Network outside: VPC, subnets, NAT      │   modules/networking
  ├──────────────────────────────────────────┤
  │  Foundation: where Terraform remembers   │   bootstrap/state-backend
  └──────────────────────────────────────────┘
```

Each layer only depends on the layers below it. That is not an accident — it's the reason the repo has separate modules. You can swap Kyverno for another policy engine without touching networking. You can raise Karpenter's limits without redeploying the cluster.

## Why "scalable design" is the theme

Every layer above has a built-in limit, and production design is mostly about knowing them:

| Layer | Its hidden limit |
|-------|------------------|
| Network | Runs out of IP addresses (Lesson 3) |
| Cluster | Platform pods compete with app pods for space (Lesson 4) |
| Compute | Autoscaler has a configured ceiling (Lesson 6) |
| Rules | Policy checks add latency to every pod start (Lesson 7) |
| Delivery | One GitOps controller can only sync so many apps (Lesson 8) |

A junior engineer says "Kubernetes scales automatically." A platform engineer says "it scales until the private subnets run out of IPs at roughly 600 pods, and here's the benchmark that proves it." This course gets you to the second sentence.

## Key files to skim now

- `environments/dev/main.tf` — the whole platform wired together in ~70 lines. Read it top to bottom; notice the order: networking → eks → cilium → karpenter → kyverno → argocd.
- `docs/scalability.md` — the limits we'll spend Lesson 10 on.

## Check yourself

1. Why is the platform split into six modules instead of one big Terraform file?
2. If a team asks for GPU workloads, which layer changes — and which layers should *not* change?
3. What does "paved road" mean, and what's the trade-off for developers using one?

Next: [Lesson 2 — Terraform State](02-terraform-state.md)
