# Lesson 9: Supply Chain Security

## What you'll learn

How a CI pipeline gets hacked in the real world, and the three cheap layers in `.github/workflows/terraform.yml` that stop it.

## The attack, in simple words

Your pipeline runs other people's code. Every `uses: someone/some-action@v4` line downloads and executes a stranger's software **with access to your secrets**.

In March 2026 this stopped being theoretical: attackers compromised the `trivy-action` repository — a *security scanner* used by thousands of pipelines — and force-pushed malicious code onto 76 existing version tags. Any pipeline referencing `@v0.30.0` or `@master` silently started running attacker code that stole CI credentials while the logs showed a normal, passing scan. Over 1,000 organizations were hit.

The root cause fits in one sentence: **tags are mutable pointers, and everyone trusted them.**

## Layer 1: Pin to commit SHAs

```yaml
# Vulnerable — the tag can be moved to malicious code at any time:
uses: aquasecurity/trivy-action@v0.30.0

# Safe — a SHA is a cryptographic hash of the content itself:
uses: aquasecurity/trivy-action@57a97c7e7821a5776cebc9bb87c984fa69cba8f1 # v0.35.0
```

A commit SHA cannot be re-pointed — changing the code changes the hash. Every third-party action in this repo's workflow is pinned this way (the human-readable version lives in the trailing comment). Teams that had pinned before March 2026 were simply unaffected.

## Layer 2: Watch the network (harden-runner)

SHA pinning stops *known references* from moving. It doesn't help if the code behind a SHA was malicious all along, or if a deeper transitive dependency is compromised. So the first step of **every job** is:

```yaml
- uses: step-security/harden-runner@9af89fc7... # v2.19.4
  with:
    egress-policy: audit
```

harden-runner watches every outbound connection the CI runner makes. Stolen credentials are worthless if they can't leave the building — and in the March attack, it was exactly this kind of egress monitoring that detected the exfiltration to a typosquatted domain (`aquasecurtiy.org` — read it twice).

`audit` mode logs; the production endgame is `block` with an explicit allowlist, at which point exfiltration fails *even if malicious code runs*. (Still on this repo's roadmap — baselining first, as audit data tells you what to allow.)

## Layer 3: Minimum token permissions

```yaml
permissions:
  contents: read
```

The workflow's GitHub token can read the repo and nothing else. Compromised action tries to push a backdoor commit or tamper with releases? The token simply lacks the permission. One block, whole classes of attack gone.

## The layered model — why all three

| Attack | Stopped by |
|--------|-----------|
| Tag force-pushed to malicious code | SHA pinning |
| Malicious code already behind the SHA | harden-runner egress control |
| Stolen token used to write to repo | `permissions: contents: read` |

No single layer is sufficient; each has a hole the next one covers. That's not defense-in-depth as a slogan — you can point at the exact line covering each hole.

## The uncomfortable irony to remember

The compromised component *was a security scanner*. Trivy scans this repo's Terraform in the same pipeline. Security tools are themselves supply chain — they get no special trust, so the scanner is SHA-pinned like everything else.

## Check yourself

1. Why is `@v4` unsafe when `@<sha> # v4` is safe — what property does the SHA have that the tag doesn't?
2. Layer 2 assumes malicious code *will run*. Why is that a reasonable assumption to design for?
3. Your teammate says "we only use popular, well-maintained actions, so we're fine." Use March 2026 to answer.

Next: [Lesson 10 — Scalability and Limits](10-scalability-and-limits.md)
