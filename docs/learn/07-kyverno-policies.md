# Lesson 7: Kyverno Policies

## What you'll learn

How a cluster enforces rules automatically, what the four policies in this repo actually prevent, and why they start in "audit" rather than "block" mode.

## The problem in simple words

A platform with 20 teams cannot rely on code review to catch every mistake. Someone *will* deploy an image tagged `:latest`, forget resource limits, or run a container as root. You need rules that the **cluster itself** enforces — the same way a compiler enforces syntax.

Kubernetes has a hook for this: **admission control**. Every object sent to the API server can be inspected — and rejected — before it's stored. Kyverno is a policy engine that plugs into that hook and lets you write rules as YAML.

## The four rules, and the incident each one prevents

From `modules/kyverno/main.tf`:

| Policy | The incident it prevents |
|--------|--------------------------|
| `require-standard-labels` (`app`, `app.team`, `environment`) | 3am incident, nobody knows which team owns the crashing pod. Labels are how cost allocation, alert routing, and ownership work. |
| `disallow-latest-tag` | `:latest` points at different images over time. Two "identical" pods run different code; rollbacks become impossible because you don't know what you were running. |
| `require-resource-limits` | One memory-leaking pod without limits eats its whole node and takes the neighbors down with it. Limits are the blast-radius wall between tenants. |
| `require-non-root` | A container escape from a root container is a root shell on the node. Running as non-root turns a disaster into an inconvenience. |

Notice these are exactly the rules the golden-path app (`apps/golden-path/manifests.yaml`) already follows. **The policies and the paved road are the same thing**, expressed twice — once as an example, once as enforcement.

## Audit vs Enforce: the rollout that doesn't cause a riot

Every policy here sets:

```yaml
validationFailureAction: Audit
```

Audit mode = violations are *recorded* but nothing is blocked. Why start there?

Turn on Enforce day one and every existing deployment that violates a rule breaks on its next rollout — you become the platform team that broke everyone's Friday. The professional rollout is:

1. **Audit** — collect violation reports, see the real blast radius
2. **Communicate** — teams get the list and a deadline
3. **Enforce** — flip the field, now with near-zero violations left

Rules first, feelings later doesn't work in platform teams. This one field is the difference.

## What breaks at scale

Admission control sits **in the write path of the API server**. Every pod create waits for Kyverno's webhook to answer. Three consequences:

- Kyverno's admission controller runs **2 replicas** (see the Helm values) — if it's down and the webhook is required, *nothing can deploy*.
- It runs on the tainted system nodes (Lesson 4), so a workload storm can't starve it.
- Policy latency multiplies: at high pod churn (think: big batch jobs, mass rollouts), slow policies visibly slow the cluster. That's why the benchmark suite includes an admission stress test:

```bash
cd tests/load && ./run-benchmark.sh kyverno   # 100 pod creations, timed
```

## Check yourself

1. Why do labels deserve to be a *blocking* rule rather than a convention?
2. Explain the audit → enforce rollout to a team lead who wants Enforce tomorrow.
3. What happens to the cluster if all Kyverno replicas crash while the webhook is set to "fail closed"? What's the trade-off of "fail open"?

Next: [Lesson 8 — GitOps with ArgoCD](08-argocd-gitops.md)
