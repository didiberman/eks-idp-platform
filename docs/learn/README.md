# Learn Production EKS Design

This repository is a **working platform and a course at the same time**. Every module in `modules/` is real, deployable Terraform — and every lesson below explains, in simple words, *why* it is built the way it is and *what breaks* when you scale it.

You can read the lessons without an AWS account. Deploying is optional (and costs ~$230–280/month while running).

## How to use this course

1. Read the lessons in order — each builds on the previous one.
2. Open the referenced Terraform files side by side. The code is the textbook.
3. If you have an AWS account, deploy after Lesson 8 and run the benchmarks in Lesson 10.
4. Answer the "Check yourself" questions at the end of each lesson — they're the kind of questions platform engineering interviews actually ask.

## Curriculum

| # | Lesson | You will understand |
|---|--------|--------------------|
| 1 | [The Big Picture](01-big-picture.md) | What an Internal Developer Platform is, and what problem each component solves |
| 2 | [Terraform State](02-terraform-state.md) | Why state is the most dangerous file in your infrastructure |
| 3 | [Networking](03-networking.md) | VPCs, subnets, NAT — and why IP addresses are the first thing that runs out |
| 4 | [The EKS Cluster](04-eks-cluster.md) | Control plane vs nodes, IRSA, and why platform pods get their own tainted nodes |
| 5 | [Cilium Networking](05-cilium-networking.md) | What a CNI actually does, and why default-deny is the production standard |
| 6 | [Karpenter Autoscaling](06-karpenter-autoscaling.md) | How nodes appear in seconds when pods need them, and what limits that |
| 7 | [Kyverno Policies](07-kyverno-policies.md) | Guardrails as code: how a cluster says "no" politely, then firmly |
| 8 | [GitOps with ArgoCD](08-argocd-gitops.md) | Why production clusters pull changes from Git instead of receiving pushes |
| 9 | [Supply Chain Security](09-supply-chain-security.md) | How a CI pipeline gets hacked, and the three layers that stop it |
| 10 | [Scalability and Limits](10-scalability-and-limits.md) | Where this platform stops scaling, how we measured it, and the production fix for each ceiling |

## The one-paragraph summary of the whole course

A production Kubernetes platform is not "a cluster". It is a **stack of scaling decisions**: how many IPs the network can hand out (Lesson 3), how fast new machines appear under load (Lesson 6), which workloads are allowed to run at all (Lesson 7), how changes reach the cluster safely (Lesson 8), and how you know any of it is true (Lesson 10). Each lesson takes one of those decisions apart.

## Prerequisites

- Basic Kubernetes: you know what a pod, deployment, and service are
- Basic Terraform: you know what `terraform apply` does
- No AWS expertise required — Lesson 3 and 4 explain the AWS pieces as they appear
