# ADR 002: Cilium as Cluster CNI

## Status

Accepted

## Context

EKS ships with the AWS VPC CNI by default. For a security-focused IDP, we need:

- Network policy enforcement (default-deny capable)
- eBPF-based observability (Hubble)
- Identity-aware networking for future service mesh integration

## Decision

Use **Cilium** in ENI mode as the cluster CNI, replacing the AWS VPC CNI addon.

## Rationale

- **Default-deny policies** — `policyEnforcementMode: default` enforces zero-trust networking
- **Hubble** — built-in flow visibility without sidecar injection
- **eBPF performance** — lower latency than iptables-based CNIs at scale
- **Industry alignment** — used by cloud-native platform teams (Isovalent/Cilium is CNCF graduated)

## Consequences

- VPC CNI addon is disabled when Cilium is enabled
- Cilium must be installed immediately after node group creation
- Golden-path apps include both CiliumNetworkPolicy and Kubernetes NetworkPolicy examples
- Team needs familiarity with Cilium policy CRDs

## Alternatives Considered

1. **AWS VPC CNI + Calico** — policy enforcement via add-on, more complex
2. **Default VPC CNI only** — no L3/L4 policy enforcement without additional tooling
