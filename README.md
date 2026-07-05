# EKS IDP Platform

> Production IDP on AWS EKS

[![Terraform](https://img.shields.io/badge/Terraform-1.9+-623CE4?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.31-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![AWS](https://img.shields.io/badge/AWS-EKS-FF9900?logo=amazonaws&logoColor=white)](https://aws.amazon.com/eks/)
[![Trivy](https://img.shields.io/badge/Security-Trivy%20Scanned-1904DA?logo=aquasecurity&logoColor=white)](https://trivy.dev/)
[![harden-runner](https://img.shields.io/badge/Supply%20Chain-Harden--Runner-00A651?logo=githubactions&logoColor=white)](https://github.com/step-security/harden-runner)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A security-first EKS platform with Terraform modules, ArgoCD, Kyverno, Cilium, Karpenter, and hardened GitHub Actions CI.

---

## What It Does

| Area | Description |
|------|-------------|
| Infrastructure as Code | Provisions VPC, EKS, and platform services through modular Terraform |
| Security | Enforces default-deny networking with Cilium, admission policies with Kyverno, IRSA, and KMS encryption |
| Autoscaling | Scales nodes with Karpenter (spot and on-demand) and scales pods with HPA |
| GitOps | Deploys applications from Git with ArgoCD and automated sync |
| Observability | Exposes network flows via Cilium Hubble, EKS control plane logs, and VPC flow logs |
| CI/CD | SHA-pinned actions, `harden-runner` egress auditing, Trivy v0.35.0, Checkov, tflint, and `terraform test` |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Developer / GitOps                         │
│                    GitHub → ArgoCD → Workloads                    │
└──────────────────────────────┬──────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────┐
│                         EKS Cluster                              │
│  ┌──────────┐  ┌───────────┐  ┌─────────┐  ┌─────────────────┐ │
│  │  Cilium  │  │ Karpenter │  │ Kyverno │  │     ArgoCD      │ │
│  │   CNI    │  │ Autoscale │  │ Policies│  │     GitOps      │ │
│  └──────────┘  └───────────┘  └─────────┘  └─────────────────┘ │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  System Node Group (tainted) │  Karpenter-provisioned nodes │ │
│  └─────────────────────────────────────────────────────────────┘ │
└──────────────────────────────┬──────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────┐
│  VPC (3 AZs) · Private Subnets · NAT · Flow Logs · IRSA/OIDC    │
└─────────────────────────────────────────────────────────────────┘
```

---

## Repository Structure

```
eks-idp-platform/
├── bootstrap/state-backend/     # S3 + DynamoDB for remote state
├── environments/
│   └── dev/                     # Dev environment composition
├── modules/
│   ├── networking/              # VPC, subnets, NAT, flow logs
│   ├── eks/                     # EKS cluster, IRSA, system node group
│   ├── cilium/                  # Cilium CNI (ENI mode)
│   ├── karpenter/               # Karpenter controller + NodePool
│   ├── kyverno/                 # Policy engine + baseline policies
│   └── argocd/                  # GitOps controller
├── apps/golden-path/            # Sample secure workload (ArgoCD target)
├── tests/
│   ├── networking_test.tftest.hcl
│   └── load/                    # Scalability benchmarks
├── docs/
│   ├── scalability.md           # Scalability analysis
│   └── adr/                     # Architecture Decision Records
└── .github/workflows/           # CI pipeline
```

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) `>= 1.9`
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) v2
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [helm](https://helm.sh/docs/intro/install/) (optional, for manual debugging)
- AWS account with permissions for EKS, EC2, IAM, S3, DynamoDB

---

## Quick Start

### 1. Bootstrap Remote State

```bash
cd bootstrap/state-backend
cp terraform.tfvars.example terraform.tfvars
# Edit state_bucket_name to be globally unique

terraform init
terraform apply
```

Copy the `backend_config` output into `environments/dev/versions.tf`.

### 2. Deploy the Platform

```bash
cd environments/dev
cp terraform.tfvars.example terraform.tfvars

terraform init
```

**First apply** — create AWS infrastructure (cluster + nodes):

```bash
terraform apply \
  -target=module.networking \
  -target=module.eks
```

**Second apply** — install platform services (Cilium, Karpenter, Kyverno, ArgoCD):

```bash
terraform apply
```

> Two-phase apply is required because Kubernetes/Helm providers depend on the EKS cluster endpoint.

### 3. Configure kubectl

```bash
aws eks update-kubeconfig --region eu-west-1 --name eks-idp-dev
kubectl get nodes
```

### 4. Access ArgoCD

```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d && echo

# Port-forward UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open [https://localhost:8080](https://localhost:8080) — login: `admin` / `<password>`

---

## Platform Components

### Networking (`modules/networking`)

- 3-AZ VPC with public/private subnet layout
- NAT gateways per AZ for high availability
- VPC flow logs to CloudWatch
- Karpenter discovery tags on subnets

### EKS (`modules/eks`)

- Kubernetes 1.31 with KMS secrets encryption
- IRSA via OIDC provider
- Tainted system node group for platform controllers
- Control plane logging (api, audit, authenticator, scheduler, controllerManager)
- EKS access entries (modern auth model)

### Cilium (`modules/cilium`)

- eBPF-based CNI in AWS ENI mode
- Default-deny policy enforcement mode
- Hubble relay for network flow visibility

### Karpenter (`modules/karpenter`)

- Spot + on-demand capacity
- Consolidation for cost optimization
- Spot interruption handling via SQS + EventBridge
- AL2023 AMI via EC2NodeClass

### Kyverno (`modules/kyverno`)

Baseline policies (audit mode):

- Require standard labels (`app`, `app.team`, `environment`)
- Disallow `:latest` image tags
- Require CPU/memory limits
- Require non-root containers

### ArgoCD (`modules/argocd`)

- GitOps controller with automated sync
- Pre-configured Application for `apps/golden-path`

---

## Golden Path Application

The sample app in `apps/golden-path/` is a reference workload shipped with:

- Required labels for Kyverno compliance
- Non-root security context with dropped capabilities
- Resource requests and limits
- HorizontalPodAutoscaler (2–6 replicas)
- CiliumNetworkPolicy + Kubernetes NetworkPolicy

---

## CI Pipeline

Every push and PR runs with supply chain hardening:

1. `step-security/harden-runner` on every job (egress audit)
2. `terraform fmt -check`
3. `terraform validate`
4. `tflint`
5. Checkov (security)
6. Trivy v0.35.0 config scan (SHA-pinned)
7. `terraform test`

All third-party GitHub Actions are pinned to full commit SHAs. Trivy is pinned to `v0.35.0`, which internally SHA-pins `setup-trivy` and avoids mutable tag references compromised in the [March 2026 supply chain attack](https://thehackernews.com/2026/03/trivy-security-scanner-github-actions.html).

---

## Cost Estimate (Dev)

| Resource | Approx. Monthly Cost |
|----------|---------------------|
| EKS control plane | ~$73 |
| 2× t3.medium system nodes | ~$60 |
| 3× NAT gateways | ~$100 |
| Karpenter workload nodes | Variable (spot: ~$15/node) |
| **Total baseline** | **~$230–280/mo** |

> Tear down when not in use: `terraform destroy` in `environments/dev`

---

## Security Considerations

- Restrict `cluster_endpoint_public_access_cidrs` to your IP in production
- Kyverno policies start in **audit** mode — switch to `Enforce` when ready
- Remote state bucket enforces encryption and TLS-only access
- No secrets stored in Terraform variables — use AWS Secrets Manager for app secrets

---

## Architecture Decision Records

| ADR | Decision |
|-----|----------|
| [001](docs/adr/001-karpenter-over-cluster-autoscaler.md) | Karpenter over Cluster Autoscaler |
| [002](docs/adr/002-cilium-as-cni.md) | Cilium as cluster CNI |
| [003](docs/adr/003-single-cluster-scalability-limits.md) | Single-cluster scalability limits |

---

## Scalability

Benchmark suite and documented ceilings for the platform:

```bash
cd tests/load
./capacity-calculator.sh    # theoretical VPC / ENI limits
./run-benchmark.sh all      # live cluster benchmarks
./run-benchmark.sh cleanup  # tear down test workloads
```

See [docs/scalability.md](docs/scalability.md) for bottleneck analysis and production scaling path.

---

## Roadmap

- [ ] External Secrets Operator + AWS Secrets Manager
- [ ] Prometheus + Grafana observability stack
- [ ] Istio service mesh with mTLS
- [ ] Backstage developer portal
- [ ] Multi-environment (staging/prod) with Atlantis

---

## License

MIT
