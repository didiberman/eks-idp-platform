# Scalability Benchmark Results

Copy this template for each test run and fill in measured values.

## Run metadata

| Field | Value |
|-------|-------|
| Date | YYYY-MM-DD |
| Cluster | eks-idp-dev |
| Region | eu-west-1 |
| K8s version | |
| Tester | |

## Test 1: Karpenter scale-up

**Setup:** 40 pods × 500m CPU in `load-testing` namespace

| Metric | Target | Measured |
|--------|--------|----------|
| Time to first NodeClaim | < 60s | |
| Time to all pods Running | < 180s | |
| Nodes provisioned | ≥ 2 | |
| Instance types selected | | |
| Spot vs on-demand ratio | | |

**Notes:**

## Test 2: HPA scale-out (golden-path)

**Setup:** 3 load-generator replicas → golden-path Service

| Metric | Target | Measured |
|--------|--------|----------|
| Baseline replicas | 2 | |
| Max replicas reached | 6 | |
| Time to scale out | < 5m | |
| CPU utilization at peak | > 70% | |

**Notes:**

## Test 3: Kyverno admission stress

**Setup:** Job with 100 completions, parallelism 10

| Metric | Target | Measured |
|--------|--------|----------|
| Total job duration | < 300s | |
| Failed admissions | 0 | |
| Kyverno pod restarts | 0 | |

**Notes:**

## Test 4: Cilium policy scale (optional)

**Setup:** Apply N CiliumNetworkPolicies incrementally

| Policy count | Connectivity test pass? | Hubble latency |
|--------------|-------------------------|----------------|
| 10 | | |
| 50 | | |
| 100 | | |

## Known ceilings observed

1.
2.
3.

## Recommended next steps

- [ ]
- [ ]
