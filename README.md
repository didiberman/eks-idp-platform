# EKS IDP Platform

> Production IDP on AWS EKS

[![Terraform](https://img.shields.io/badge/Terraform-1.9+-623CE4?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.31-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![AWS](https://img.shields.io/badge/AWS-EKS-FF9900?logo=amazonaws&logoColor=white)](https://aws.amazon.com/eks/)
[![Trivy](https://img.shields.io/badge/Security-Trivy%20Scanned-1904DA?logo=aquasecurity&logoColor=white)](https://trivy.dev/)
[![harden-runner](https://img.shields.io/badge/Supply%20Chain-Harden--Runner-00A651?logo=githubactions&logoColor=white)](https://github.com/step-security/harden-runner)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A security-first EKS platform with Terraform modules, ArgoCD, Kyverno, Cilium, Karpenter, hardened GitHub Actions CI, and scalability benchmarks.

---

## What It Does

| Area | Description |
|------|-------------|
| Infrastructure as Code | Provisions VPC, EKS, and platform services through modular Terraform (`environments/dev`) |
| Security | Cilium default-deny networking, Kyverno admission policies (audit), IRSA, KMS encryption, VPC flow logs |
| Autoscaling | Karpenter NodePool (spot + on-demand, 100 vCPU cap) and HPA on the golden-path app |
| GitOps | ArgoCD with automated sync of `apps/golden-path` from this repository |
| Observability | Cilium Hubble relay, EKS control plane logs, VPC flow logs — no metrics stack yet |
| CI/CD | SHA-pinned actions, `harden-runner` egress audit, Trivy v0.35.0, Checkov, tflint, `terraform test` |
| Scalability | Load test suite in `tests/load/` with documented ceilings (~600 pods, ~25 nodes) |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     GitHub (this repo)                           │
│              Terraform CI · apps/golden-path manifests           │
└──────────────────────────────┬──────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────┐
│                         EKS Cluster                              │
│  ┌──────────┐  ┌───────────┐  ┌─────────┐  ┌─────────────────┐ │
│  │  Cilium  │  │ Karpenter │  │ Kyverno │  │     ArgoCD      │ │
│  │ ENI CNI  │  │ NodePool  │  │ (audit) │  │  golden-path    │ │
│  └──────────┘  └───────────┘  └─────────┘  └─────────────────┘ │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  System nodes (tainted)      │  Karpenter workload nodes    │ │
│  │  platform controllers only   │  spot + on-demand            │ │
│  └─────────────────────────────────────────────────────────────┘ │
└──────────────────────────────┬──────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────┐
│  VPC · 3 AZs · private subnets · NAT/AZ · IRSA/OIDC · S3 state  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Current State

| Layer | Status | Notes |
|-------|--------|-------|
| Remote state bootstrap | Ready | `bootstrap/state-backend` — S3, DynamoDB, KMS |
| Dev environment | Ready | `environments/dev` — sole environment today |
| Networking | Implemented | `10.0.0.0/16`, 3 AZs, NAT per AZ |
| EKS 1.31 | Implemented | KMS encryption, access entries, system node group |
| Cilium | Implemented | Replaces AWS VPC CNI when `enable_cilium = true` |
| Karpenter | Implemented | IRSA, SQS interruption queue, default NodePool |
| Kyverno | Implemented | 4 cluster policies in **audit** mode |
| ArgoCD | Implemented | Syncs `apps/golden-path` from `main` |
| Golden-path app | Implemented | nginx, HPA, NetworkPolicies |
| CI pipeline | Implemented | validate · test · plan (PR) |
| Scalability benchmarks | Implemented | `tests/load/` |
| Staging / prod | Not yet | Roadmap |
| Prometheus / Grafana | Not yet | Roadmap |
| External Secrets | Not yet | Roadmap |

---

## Known Challenges

These are intentional trade-offs or gaps in the current design — not bugs.

### Deployment

| Challenge | Why | Mitigation |
|-----------|-----|------------|
| **Two-phase `terraform apply`** | Kubernetes/Helm providers need a live cluster endpoint | Apply `networking` + `eks` first, then full apply |
| **CNI bootstrap window** | VPC CNI is skipped when Cilium is enabled; nodes need Cilium before they're Ready | Second apply installs Cilium immediately after system nodes |
| **Destroy order** | Helm/K8s resources must be removed before the cluster | `terraform destroy` may need a targeted destroy of platform modules first |

### Runtime

| Challenge | Why | Mitigation |
|-----------|-----|------------|
| **Tainted system nodes** | Platform controllers run on dedicated nodes (`platform.eks-idp/role=system:NoSchedule`) | Workloads schedule on Karpenter nodes only — first pod triggers node provisioning |
| **Karpenter cold start** | No workload nodes exist until first schedulable pod | Expect 30–90s for first NodeClaim; see `tests/load/karpenter-scale-up/` |
| **Kyverno in audit** | Policies log violations but do not block | Switch `validationFailureAction` to `Enforce` when ready |
| **Single NodePool** | One pool, amd64 only, 4 instance types, 100 vCPU cap | See [docs/scalability.md](docs/scalability.md) for ceilings and scaling path |
| **VPC IP exhaustion** | Cilium ENI mode consumes subnet IPs per pod | ~600 pod ceiling on default `/16` — run `./tests/load/capacity-calculator.sh` |

### Operations

| Challenge | Why | Mitigation |
|-----------|-----|------------|
| **NAT gateway cost** | 3 NAT gateways for AZ HA | ~$100/mo baseline; add VPC endpoints for ECR/S3 in prod |
| **Public EKS endpoint** | Default `0.0.0.0/0` for dev convenience | Restrict `cluster_endpoint_public_access_cidrs` in `terraform.tfvars` |
| **ArgoCD insecure mode** | `server.insecure = true` for port-forward dev access | Enable TLS + ingress for production |
| **CI plan job** | PR plan step needs `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` secrets | Configure repo secrets or accept plan-only validation without AWS |
| **`harden-runner` audit only** | Egress policy not yet baselined to `block` | Run pipeline, review StepSecurity dashboard, add `allowed-endpoints` |

---

## Repository Structure

```
eks-idp-platform/
├── bootstrap/state-backend/     # S3 + DynamoDB + KMS (one-time)
├── environments/dev/              # Composition: all modules wired together
├── modules/
│   ├── networking/                # VPC, subnets, NAT, flow logs
│   ├── eks/                       # Cluster, IRSA, system node group, addons
│   ├── cilium/                    # Cilium Helm (ENI mode, default-deny)
│   ├── karpenter/                 # Controller, NodePool, EC2NodeClass, SQS
│   ├── kyverno/                   # Policy engine + 4 cluster policies
│   └── argocd/                    # GitOps + golden-path Application
├── apps/golden-path/              # Reference workload (ArgoCD target)
├── tests/
│   ├── networking_test.tftest.hcl # Terraform native tests
│   └── load/                      # Karpenter, HPA, Kyverno benchmarks
├── docs/
│   ├── scalability.md
│   └── adr/                       # Architecture Decision Records
└── .github/workflows/terraform.yml
```

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) `>= 1.9`
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) v2
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- AWS account with permissions for EKS, EC2, IAM, S3, DynamoDB

---

## Quick Start

### 1. Bootstrap remote state (one-time)

```bash
cd bootstrap/state-backend
cp terraform.tfvars.example terraform.tfvars
# Set a globally unique state_bucket_name

terraform init && terraform apply
```

Copy the `backend_config` output into `environments/dev/versions.tf`, then re-init.

### 2. Deploy the platform

```bash
cd environments/dev
cp terraform.tfvars.example terraform.tfvars
terraform init
```

**Phase 1** — AWS infrastructure:

```bash
terraform apply -target=module.networking -target=module.eks
```

**Phase 2** — platform services (Cilium, Karpenter, Kyverno, ArgoCD):

```bash
terraform apply
```

All platform components can be toggled via `enable_cilium`, `enable_karpenter`, `enable_kyverno`, `enable_argocd` in `terraform.tfvars`.

### 3. Configure kubectl

```bash
aws eks update-kubeconfig --region eu-west-1 --name eks-idp-dev
kubectl get nodes
# Expect: 2 system nodes (tainted) — workload nodes appear after first pod schedules
```

### 4. Access ArgoCD

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d && echo

kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open `https://localhost:8080` — login: `admin` / `<password>`

---

## Platform Components

### Networking (`modules/networking`)

- 3-AZ VPC (`10.0.0.0/16` default) with `/24` public and private subnets
- NAT gateway per AZ
- VPC flow logs to CloudWatch (30-day retention)
- `karpenter.sh/discovery` tags on subnets

### EKS (`modules/eks`)

- Kubernetes 1.31, KMS secrets encryption
- OIDC provider for IRSA, EKS Pod Identity agent addon
- System node group: 2× `t3.medium`, tainted `platform.eks-idp/role=system:NoSchedule`
- Control plane logging: api, audit, authenticator, scheduler, controllerManager
- EKS access entries (cluster admin for deployer principal)
- Disables VPC CNI addon when Cilium is enabled

### Cilium (`modules/cilium`)

- Helm chart in ENI mode with `policyEnforcementMode: default`
- Hubble relay enabled (UI disabled)
- Replaces AWS VPC CNI — required before workload pods become Ready

### Karpenter (`modules/karpenter`)

- IRSA controller, SQS + EventBridge for spot interruption
- `EC2NodeClass` with AL2023 AMI
- Default `NodePool`: amd64, spot + on-demand, t3/m6i instances, 100 vCPU limit
- Controller runs on tainted system nodes

### Kyverno (`modules/kyverno`)

Four cluster policies in **audit** mode:

- `require-standard-labels` — `app`, `app.team`, `environment`
- `disallow-latest-tag`
- `require-resource-limits`
- `require-non-root`

### ArgoCD (`modules/argocd`)

- Automated sync with prune and self-heal
- Pre-configured `Application` targeting `apps/golden-path` on `main`
- Server exposed via `LoadBalancer` (or port-forward for dev)

---

## Golden Path Application

Reference workload in `apps/golden-path/`:

- Kyverno-compliant labels and non-root security context
- Resource requests/limits, read-only root filesystem
- HPA: 2–6 replicas at 70% CPU
- CiliumNetworkPolicy + Kubernetes NetworkPolicy

Deployed by ArgoCD after the platform is up. If ArgoCD is disabled, apply manually:

```bash
kubectl apply -k apps/golden-path
```

---

## CI Pipeline

Three jobs on every push/PR:

| Job | Runs | Requires AWS secrets |
|-----|------|----------------------|
| `validate` | fmt, validate, tflint, Checkov, Trivy v0.35.0 | No |
| `test` | `terraform test` | No |
| `plan` | `terraform plan` on PRs | Yes (optional) |

Supply chain controls:

- `step-security/harden-runner` on every job (egress audit)
- All actions pinned to full commit SHAs
- Trivy `v0.35.0` SHA-pins `setup-trivy` internally ([March 2026 attack](https://thehackernews.com/2026/03/trivy-security-scanner-github-actions.html))

---

## Scalability

Theoretical ceilings on default config:

| Limit | Approximate value |
|-------|-------------------|
| Pod capacity | ~600 (VPC IP space) |
| Worker nodes | ~25 (Karpenter 100 vCPU cap) |
| Platform controllers | 2 system nodes (fixed) |

```bash
cd tests/load
./capacity-calculator.sh       # no cluster needed
./run-benchmark.sh all         # live benchmarks (~6 min, provisions EC2)
./run-benchmark.sh cleanup     # tear down test workloads
```

Details: [docs/scalability.md](docs/scalability.md) · ADR [003](docs/adr/003-single-cluster-scalability-limits.md)

---

## Cost Estimate (Dev)

| Resource | Approx. monthly |
|----------|-----------------|
| EKS control plane | ~$73 |
| 2× t3.medium system nodes | ~$60 |
| 3× NAT gateways | ~$100 |
| Karpenter workload nodes | Variable (~$15/node spot) |
| **Baseline** | **~$230–280** |

Tear down when not in use: `terraform destroy` in `environments/dev`

---

## Security Considerations

- Restrict `cluster_endpoint_public_access_cidrs` before any real workloads
- Kyverno policies are in audit — switch to `Enforce` incrementally
- Remote state: KMS encryption, TLS-only bucket policy, DynamoDB locking
- No secrets in Terraform variables — use AWS Secrets Manager (roadmap: External Secrets Operator)
- ArgoCD runs insecure HTTP internally — use port-forward or add TLS for production

---

## Architecture Decision Records

| ADR | Decision |
|-----|----------|
| [001](docs/adr/001-karpenter-over-cluster-autoscaler.md) | Karpenter over Cluster Autoscaler |
| [002](docs/adr/002-cilium-as-cni.md) | Cilium as cluster CNI |
| [003](docs/adr/003-single-cluster-scalability-limits.md) | Single-cluster scalability limits |

---

## Roadmap

- [x] Scalability benchmark suite (`tests/load/`)
- [ ] `harden-runner` egress block mode with allowlist
- [ ] External Secrets Operator + AWS Secrets Manager
- [ ] Prometheus + Grafana observability stack
- [ ] Istio service mesh with mTLS
- [ ] Backstage developer portal
- [ ] Staging/prod environments with Atlantis

---

## License

MIT
