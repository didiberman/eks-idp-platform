# Load Testing

Scalability benchmarks for the EKS IDP platform. Run against a **live cluster** after `terraform apply`.

## Prerequisites

```bash
aws eks update-kubeconfig --region eu-west-1 --name eks-idp-dev
kubectl get nodes
```

## Quick start

```bash
cd tests/load
chmod +x run-benchmark.sh capacity-calculator.sh

# Theoretical limits (no cluster required)
./capacity-calculator.sh

# Full benchmark suite (~6 min)
./run-benchmark.sh all

# Clean up when done
./run-benchmark.sh cleanup
```

## Individual tests

| Command | What it measures |
|---------|------------------|
| `./run-benchmark.sh karpenter` | Node provisioning latency under pod pressure |
| `./run-benchmark.sh hpa` | golden-path HPA scale-out (2 → 6) |
| `./run-benchmark.sh kyverno` | Admission webhook throughput (100 pods) |
| `./run-benchmark.sh snapshot` | Point-in-time cluster state |
| `./run-benchmark.sh capacity` | VPC IP / ENI theoretical limits |

## Manual apply

```bash
kubectl apply -k tests/load
kubectl apply -f tests/load/kyverno-admission/job.yaml
```

## Recording results

1. Results are auto-written to `tests/load/results/<timestamp>-benchmark.txt`
2. Copy `results-template.md` and fill in measured values for your portfolio / ADR

## Cost warning

Karpenter scale-up provisions real EC2 instances. Run `cleanup` promptly to avoid unnecessary spend.

## See also

- [docs/scalability.md](../../docs/scalability.md) — full scalability analysis
- [docs/adr/003-single-cluster-scalability-limits.md](../../docs/adr/003-single-cluster-scalability-limits.md)
