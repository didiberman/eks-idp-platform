# Lesson 2: Terraform State

## What you'll learn

Why the boring `bootstrap/state-backend` module exists, and why state handling is the first thing that goes wrong in real teams.

## The problem in simple words

Terraform keeps a file — the *state* — that maps "what I wrote in code" to "what actually exists in AWS". Lose it, and Terraform forgets it owns anything. Corrupt it, and Terraform may delete things it shouldn't.

Now add a second engineer. If you both run `terraform apply` at the same time against the same state, you get a corrupted mess. This is not theoretical — it's the classic first-week platform outage.

## The three protections in this repo

Open `bootstrap/state-backend/main.tf` and find each of these:

### 1. The state lives in S3, not on a laptop

```hcl
resource "aws_s3_bucket" "state" { ... }
resource "aws_s3_bucket_versioning" "state" { ... }
```

S3 is durable and versioned. If someone breaks the state, you roll back to the previous version. A laptop offers neither.

### 2. A DynamoDB lock stops simultaneous applies

```hcl
resource "aws_dynamodb_table" "locks" {
  hash_key = "LockID"
  ...
}
```

Before touching state, Terraform writes a lock row. A second engineer's apply waits (or fails fast) instead of corrupting state. One tiny table prevents the whole class of "two applies at once" incidents.

### 3. Encryption and transport rules

The bucket policy in the same file **denies** two things outright:

- any request not using TLS (`aws:SecureTransport = false`)
- any upload not encrypted with KMS

State files contain secrets — database passwords, certificate keys, anything a resource outputs. Treating state as sensitive data is not paranoia; it's the baseline.

## The chicken-and-egg problem

You may notice something odd: Terraform creates the S3 bucket that Terraform's own state will live in. Where does the *bootstrap's* state live?

Answer: locally, once, and that's fine. The bootstrap module creates three nearly-static resources. After it runs, every other environment (like `environments/dev`) points its backend at the bucket. This "one local bootstrap, everything else remote" pattern is standard practice — you'll see it in almost every serious Terraform codebase.

## What breaks at scale

- **One state file for everything** — applies get slow and risky as the platform grows. That's why `environments/dev` has its own state key, and staging/prod would each get their own. Small blast radius per state file.
- **Human access to state** — in mature teams, only CI can touch prod state. Humans propose PRs; pipelines apply them (Lesson 9 touches the pipeline).

## Check yourself

1. What two failure modes does the DynamoDB table prevent?
2. Why is state considered secret material?
3. Your teammate suggests one shared state file for dev, staging, and prod "to keep it simple". What do you say?

Next: [Lesson 3 — Networking](03-networking.md)
