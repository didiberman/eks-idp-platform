# Lesson 3: Networking

## What you'll learn

What the VPC layer actually provides, why there are six subnets and three NAT gateways, and the single most underrated fact in EKS design: **pods consume real IP addresses, and you will run out.**

## The problem in simple words

Kubernetes needs a network to live in. On AWS that's a VPC — a private slice of the cloud with its own IP range. Every design choice in `modules/networking/main.tf` answers one of three questions:

1. Who can reach the internet, and how?
2. What happens when one datacenter has a bad day?
3. How many IP addresses do we have — really?

## The layout

```
VPC 10.0.0.0/16  (65,536 addresses on paper)
│
├── AZ eu-west-1a ── public subnet 10.0.0.0/24 ── private subnet 10.0.3.0/24
├── AZ eu-west-1b ── public subnet 10.0.1.0/24 ── private subnet 10.0.4.0/24
└── AZ eu-west-1c ── public subnet 10.0.2.0/24 ── private subnet 10.0.5.0/24
```

**Public subnets** have a route to the Internet Gateway. Only load balancers and NAT gateways live here.

**Private subnets** hold everything that matters — the nodes and pods. Nothing on the internet can open a connection *to* them.

**Three availability zones** because an AZ is a physical datacenter, and datacenters fail. Spread across three, and losing one means losing a third of capacity, not everything.

## NAT: the expensive doorman

Private nodes still need to reach *out* — to pull container images, call APIs. A NAT gateway is a one-way door: traffic gets out, nothing gets in uninvited.

This repo puts **one NAT gateway in each AZ** (see `aws_nat_gateway.this` with `count = local.az_count`). Why not one for all three? Because if the AZ holding the single NAT dies, nodes in the other two AZs lose internet even though they're healthy. ~$100/month for three is the price of not having that failure mode.

Production refinement: NAT charges per GB processed. Heavy image pulling through NAT gets expensive — real platforms add **VPC endpoints** so traffic to ECR and S3 bypasses NAT entirely.

## The IP math — the part everyone skips

A `/24` subnet sounds like 256 addresses, but AWS reserves 5, so you get **251 per subnet, ~753 private IPs total**.

Here's the trap: with a VPC-native CNI (like Cilium in ENI mode — Lesson 5), **every pod takes a real subnet IP**. Not a virtual one. So:

- 753 IPs total
- minus nodes themselves, load balancer interfaces, and per-node overhead
- **≈ 600 pods, ceiling, ever** — no matter how many nodes Karpenter can add

Run the math yourself:

```bash
./tests/load/capacity-calculator.sh
```

This is almost always the first hard wall a growing EKS platform hits, and it's decided by a single line — `vpc_cidr = "10.0.0.0/16"` with `/24` carving — written on day one. The fixes (secondary CIDR blocks, bigger subnets, prefix delegation) all exist, but they're much easier before the cluster is full.

## Two small details worth noticing

- **Discovery tags**: subnets carry `karpenter.sh/discovery = <cluster-name>`. Karpenter finds where to place nodes by tag, not by hardcoded IDs (Lesson 6).
- **Flow logs**: every accepted/rejected connection is logged to CloudWatch. When something "can't connect", flow logs are how you find out whether the network even saw the attempt.

## Check yourself

1. Why do NAT gateways cost triple here, and what failure justifies it?
2. Your cluster has plenty of CPU but new pods hang in `Pending` with network errors. What do you check first?
3. Why is changing the VPC CIDR later so much harder than getting it right on day one?

Next: [Lesson 4 — The EKS Cluster](04-eks-cluster.md)
