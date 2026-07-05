# Lesson 8: GitOps with ArgoCD

## What you'll learn

Why production clusters *pull* changes from Git instead of receiving pushes from CI, and how the golden-path app actually reaches the cluster.

## The problem in simple words

The obvious way to deploy: CI pipeline runs `kubectl apply`. It works, and it has three quiet problems:

1. **CI holds cluster credentials.** Every CI runner that can deploy is a credential-theft target (remember Lesson 9's attack — CI secrets were exactly what the attackers stole).
2. **Drift is invisible.** Someone `kubectl edit`s a deployment during an incident. Now the cluster disagrees with Git, and nobody knows.
3. **No single source of truth.** "What's running in prod?" requires archaeology across pipeline logs.

GitOps inverts the flow: an agent **inside the cluster** (ArgoCD) watches a Git repo and pulls the cluster toward whatever Git says. CI never touches the cluster; it only pushes commits.

## How it's wired here

`modules/argocd/main.tf` installs ArgoCD and creates one `Application` object that says, in essence:

```
watch:  github.com/didiberman/eks-idp-platform, branch main, path apps/golden-path
target: this cluster, namespace golden-path
policy: automated  +  prune  +  selfHeal
```

The three policy words carry the whole model:

- **automated** — new commit to `main` → cluster updates itself. Deploy = merge a PR.
- **prune** — delete a manifest from Git → ArgoCD deletes it from the cluster. Git is authoritative in both directions.
- **selfHeal** — someone hand-edits a live object → ArgoCD notices the drift and reverts it. The 2am hotfix that nobody remembers? Gone at the next sync, *by design*. Fixes must land in Git or they didn't happen.

Rollback, in this world, is `git revert`. The deployment history *is* the Git history — signed, reviewed, and diffable.

## The interview-grade insight

GitOps turns the cluster into a **projection of a Git repo**. Every operational question gets a Git answer:

| Question | Answer |
|----------|--------|
| What's running? | `git log main -- apps/` |
| Who changed it? | The PR and its approvals |
| How do we roll back? | `git revert`, ArgoCD does the rest |
| Disaster recovery? | Point a fresh cluster's ArgoCD at the repo, wait |

That last row is underrated: this repo's entire app layer can be reconstructed from Git on a brand-new cluster with zero manual steps.

## What breaks at scale

- One ArgoCD instance comfortably manages ~100 apps; beyond that, sync queues back up. Fixes: **ApplicationSets** (one template stamping out many apps), sharded application controllers, or ArgoCD-per-team.
- ArgoCD runs on the tainted system nodes (Lesson 4) — its controllers are platform machinery like everything else there.
- Dev convenience flags to undo for production: `server.insecure = true` and a plain `LoadBalancer` service (README's Known Challenges table tracks both).

## Try it

Deploy the platform, then:

```bash
kubectl -n argocd get applications
kubectl -n golden-path get pods    # you never applied these by hand — ArgoCD did
```

Then delete the golden-path deployment manually and watch selfHeal put it back within seconds.

## Check yourself

1. Give two security reasons pull-based beats push-based deployment.
2. A teammate hotfixed prod with `kubectl edit` and selfHeal reverted it. Was the platform wrong? What's the correct workflow?
3. How would you onboard 50 microservices without writing 50 Application objects by hand?

Next: [Lesson 9 — Supply Chain Security](09-supply-chain-security.md)
