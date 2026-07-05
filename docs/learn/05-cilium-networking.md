# Lesson 5: Cilium Networking

## What you'll learn

What a CNI actually is, why this platform replaces the AWS default with Cilium, and what "default-deny" means for how apps must be built.

## What a CNI does, in one paragraph

When a pod starts, *something* must give it an IP address and wire it into the network so other pods can reach it. That something is the CNI (Container Network Interface) plugin. Every cluster has one; most people never think about theirs. Choosing it deliberately is one of the highest-leverage decisions in platform design, because the CNI decides how security policy, observability, and IP usage work.

## Why Cilium over the AWS default

The AWS VPC CNI is fine at connecting pods. It's limited at *controlling* them. Cilium (configured in `modules/cilium/main.tf`) adds three things:

### 1. eBPF instead of iptables

Traditional Kubernetes networking builds a giant chain of iptables rules — thousands of entries that every packet walks through linearly. It works, but degrades as clusters grow.

Cilium uses **eBPF**: small programs that run inside the Linux kernel and make forwarding/policy decisions right where the packet arrives. Practical consequences: near-constant performance as policy count grows, and visibility for free (below).

### 2. Default-deny policy mode

```yaml
policyEnforcementMode: default
```

The mindset shift: instead of "all pods can talk to all pods unless someone writes a deny rule" (the Kubernetes default), traffic is denied **unless a policy explicitly allows it**.

This changes how apps ship. Look at `apps/golden-path/manifests.yaml` — the app carries its own `CiliumNetworkPolicy` declaring exactly who may talk to it. In a default-deny platform, **the network policy is part of the app**, like its Dockerfile. A compromised pod can't scan the cluster or reach the database of the team next door, because nothing let it.

### 3. Hubble: seeing the traffic

Cilium ships with Hubble, which answers "what is actually talking to what?" from the kernel's own view — no sidecars, no code changes. When a developer says "my service can't reach X", Hubble shows whether the traffic arrived and precisely which policy dropped it. Without it, default-deny debugging is guesswork.

## The trade-off: ENI mode and the IP budget

This deployment runs Cilium in **ENI mode**: pod IPs are real VPC subnet IPs. Great for the network (pods are first-class VPC citizens, no encapsulation overhead) — but it's exactly why the ~600-pod ceiling from Lesson 3 exists. The alternative (overlay networking) gives you nearly unlimited pod IPs at the cost of an encapsulation layer and a less AWS-native setup. Choosing ENI mode is choosing simplicity now, IP planning later.

## The bootstrap catch

One operational quirk you'll hit when deploying: the VPC CNI addon is disabled (Lesson 4), so **nodes are not fully functional until Cilium installs**. This is why the platform needs the two-phase apply described in the README — cluster first, then Helm-installed components. Order of operations *is* platform engineering.

## Check yourself

1. What does default-deny protect against that "deny rules on top of allow-all" doesn't?
2. Why does every golden-path app ship with its own network policy?
3. You're asked to run 5,000 pods on this platform. What's the Cilium-related decision to revisit?

Next: [Lesson 6 — Karpenter Autoscaling](06-karpenter-autoscaling.md)
