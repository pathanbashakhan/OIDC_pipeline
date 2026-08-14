# 🏗️ AWS Infrastructure Automation — Terraform + GitHub Actions

> **Production-grade, industry-standard** GitOps pipeline for provisioning AWS EC2 and S3 resources across **Dev**, **QA**, and **Production** environments. Zero static credentials, fully automated environment promotion, and complete state isolation — all managed as code.

---

## 📌 Table of Contents
1. [Project Overview](#1-project-overview)
2. [Architecture Diagram](#2-architecture-diagram)
3. [Repository Structure](#3-repository-structure)
4. [Core Design Decisions](#4-core-design-decisions)
5. [How OIDC Authentication Works](#5-how-oidc-authentication-works)
6. [How State Is Managed](#6-how-state-is-managed)
7. [How Code Promotion Works](#7-how-code-promotion-works)
8. [Step-by-Step Setup Guide](#8-step-by-step-setup-guide)
9. [GitHub Actions — Values to Configure](#9-github-actions--values-to-configure)
10. [Day-to-Day Developer Workflow](#10-day-to-day-developer-workflow)
11. [Terraform Modules Reference](#11-terraform-modules-reference)
12. [Production-Grade Feature Checklist](#12-production-grade-feature-checklist)
13. [Interview Explainer](#13-interview-explainer)

---

## 1. Project Overview

This project automates the provisioning of AWS infrastructure using **Terraform** as the IaC tool and **GitHub Actions** as the CI/CD platform. It eliminates:
- ❌ Manual `terraform apply` commands
- ❌ Static AWS access keys in CI/CD
- ❌ Manual copy-paste to promote changes across environments
- ❌ Risk of applying unapproved changes to production

And replaces them with:
- ✅ Automated plan + apply pipelines triggered by Git events
- ✅ Keyless AWS authentication via OIDC
- ✅ Automated environment promotion through branch merges
- ✅ Isolated Terraform state per environment via native S3 locking

---

## 2. Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        DEVELOPER WORKFLOW                                   │
│                                                                             │
│   feature/* ──PR──▶ dev ──PR──▶ qa ──PR──▶ prod                           │
│       │               │           │           │                             │
│   (commits)       (Plan runs) (Plan runs) (Plan runs)                      │
│                       │           │           │                             │
│                   (Merge)     (Merge)     (Merge + Reviewer)               │
│                       │           │           │                             │
│                   (Apply)     (Apply)     (Apply)                          │
└───────────────────────┼───────────┼───────────┼─────────────────────────────┘
                        │           │           │
              ┌─────────▼──┐ ┌──────▼───┐ ┌────▼──────┐
              │  AWS DEV   │ │  AWS QA  │ │ AWS PROD  │
              │            │ │          │ │           │
              │ EC2 t3.micro│ │EC2 t3.small│ │EC2 t3.medium│
              │ S3 Bucket  │ │ S3 Bucket│ │ S3 Bucket │
              └────────────┘ └──────────┘ └───────────┘

GitHub Actions Authentication (OIDC — No Static Keys):

  GitHub ──OIDC Token──▶ AWS STS ──Temp Creds (1hr)──▶ Terraform
  (short-lived, auto-expires, no keys stored anywhere)

Terraform State (S3 Native Locking — No DynamoDB):

  s3://state-bucket/dev/terraform.tfstate  + .tflock
  s3://state-bucket/qa/terraform.tfstate   + .tflock
  s3://state-bucket/prod/terraform.tfstate + .tflock
```

---

## 3. Repository Structure

```
terraform-infra/
│
├── .github/
│   └── workflows/
│       ├── dev-plan.yml        # Trigger: PR → dev
│       ├── dev-apply.yml       # Trigger: Merge → dev
│       ├── qa-plan.yml         # Trigger: PR → qa
│       ├── qa-apply.yml        # Trigger: Merge → qa
│       ├── prod-plan.yml       # Trigger: PR → prod
│       └── prod-apply.yml      # Trigger: Merge → prod
│
├── oidc/                       # ONE-TIME BOOTSTRAP (run manually once)
│   ├── main.tf                 # GitHub OIDC provider + 3 IAM roles + policies
│   ├── variables.tf
│   ├── outputs.tf              # Outputs the 3 role ARNs to paste into GitHub
│   ├── providers.tf
│   ├── backend.tf
│   └── terraform.tfvars        # Fill in: github_org, github_repo, state_bucket_arn
│
├── envs/                       # Environment-specific variable files
│   ├── dev.tfvars              # Dev: t3.micro, dev subnet/SG IDs
│   ├── qa.tfvars               # QA: t3.small, qa subnet/SG IDs
│   └── prod.tfvars             # Prod: t3.medium, prod subnet/SG IDs
│
├── terraform/                  # Single root Terraform config (shared by all envs)
│   ├── main.tf                 # Calls EC2 and S3 modules
│   ├── variables.tf            # Variable declarations
│   ├── outputs.tf              # Outputs
│   ├── providers.tf            # AWS provider (requires Terraform >= 1.10)
│   └── backend.tf              # Partial S3 backend — key injected at runtime
│
├── modules/
│   ├── ec2/                    # Reusable EC2 module
│   │   ├── main.tf             # Instance with IMDSv2 + encrypted EBS
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── s3/                     # Reusable S3 module
│       ├── main.tf             # Bucket with encryption, versioning, public block
│       ├── variables.tf
│       └── outputs.tf
│
├── .gitignore
└── README.md
```

---

## 4. Core Design Decisions

| Design Choice | Decision | Why |
|---|---|---|
| **Single Terraform folder** | `terraform/` with `envs/*.tfvars` | Enables automated branch-based promotion. Separate env folders break this. |
| **State backend** | S3 + `use_lockfile = true` | Native S3 locking (Terraform ≥ 1.10). No DynamoDB needed. |
| **AWS Auth** | GitHub OIDC | Zero static credentials. Creds expire in 1 hour. |
| **3 separate IAM roles** | One per environment | Dev role cannot assume Prod permissions. Least privilege. |
| **Artifact-based apply** | Binary `tfplan` uploaded then downloaded | Guarantees exactly what was reviewed is what gets applied. |
| **Concurrency control** | `cancel-in-progress: true` for plan, `false` for apply | Prevents stale plans; never interrupts an active apply. |
| **Environment promotion** | Branch merge: dev→qa→prod | Fully automated; merging the branch promotes the code. |

---

## 5. How OIDC Authentication Works

```
Step 1: GitHub Actions starts
Step 2: GitHub generates a short-lived OIDC JWT token
        (contains: repo name, branch, run ID)
Step 3: Token is sent to AWS STS
Step 4: AWS STS verifies token against GitHub's OIDC provider
        (registered in oidc/main.tf as aws_iam_openid_connect_provider)
Step 5: STS checks the IAM role's trust policy:
        "Is this token from repo:my-org/terraform-infra:ref:refs/heads/dev?"
Step 6: If yes → returns temporary credentials (Access Key + Secret + Token)
        These expire in 1 HOUR automatically.
Step 7: Terraform uses these credentials to provision AWS resources.
```

**No static AWS credentials are ever stored in GitHub Secrets.**

Each environment has its own IAM role with its own permissions:
- `myapp-github-actions-dev` → can only be assumed from `dev` branch
- `myapp-github-actions-qa` → can only be assumed from `qa` branch
- `myapp-github-actions-prod` → can ONLY be assumed from `prod` branch (NOT from PRs)

---

## 6. How State Is Managed

**Problem:** With one Terraform codebase for all environments, they must not share the same state file.

**Solution:** Partial Backend Configuration + Native S3 Locking

`terraform/backend.tf` has NO `key` field:
```hcl
terraform {
  backend "s3" {
    bucket       = "your-state-bucket"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true   # No DynamoDB — native S3 locking
  }
}
```

Each GitHub Actions workflow injects the key at runtime:
```yaml
# dev-plan.yml / dev-apply.yml
terraform init -backend-config="key=dev/terraform.tfstate"

# qa-plan.yml / qa-apply.yml
terraform init -backend-config="key=qa/terraform.tfstate"

# prod-plan.yml / prod-apply.yml
terraform init -backend-config="key=prod/terraform.tfstate"
```

**Result:**
```
s3://your-state-bucket/
├── dev/
│   ├── terraform.tfstate       ← Dev infrastructure state
│   └── terraform.tfstate.tflock
├── qa/
│   ├── terraform.tfstate       ← QA infrastructure state
│   └── terraform.tfstate.tflock
└── prod/
    ├── terraform.tfstate       ← Prod infrastructure state
    └── terraform.tfstate.tflock
```

When two workflows try to run simultaneously, the second one fails to acquire the `.tflock` file and waits — preventing state corruption.

---

## 7. How Code Promotion Works

This is the most important concept in this project.

**Key insight:** All three branches (`dev`, `qa`, `prod`) contain identical Terraform code in `terraform/main.tf`. The ONLY things that differ per environment are:
1. The `.tfvars` values (from `envs/`) — e.g., instance type, subnet ID
2. The S3 state key — e.g., `dev/terraform.tfstate`
3. The IAM role assumed — e.g., `myapp-github-actions-dev`

**All three are controlled by GitHub Actions workflows — not by the code itself.**

### Promotion flow:

```
1. FEATURE → DEV
   git checkout -b feature/add-ec2 dev
   # Edit terraform/main.tf
   git push → Open PR: feature/add-ec2 → dev
   # dev-plan.yml runs with envs/dev.tfvars
   # Reviewer approves PR
   # Merge → dev-apply.yml runs → DEV AWS updated

2. DEV → QA (Automated Promotion)
   Open PR: dev → qa
   # qa-plan.yml runs automatically with envs/qa.tfvars
   # Same code, different values (t3.small, QA subnet, etc.)
   # Reviewer approves PR
   # Merge → qa-apply.yml runs → QA AWS updated

3. QA → PROD (Automated Promotion)
   Open PR: qa → prod
   # prod-plan.yml runs automatically with envs/prod.tfvars
   # Same code, production values (t3.medium, Prod subnet, etc.)
   # Senior reviewer approves PR
   # Merge → GitHub Environment reviewer approves Apply
   # prod-apply.yml runs → PRODUCTION AWS updated
```

Zero manual copy-paste. Zero drift between environments in terms of code.

---

## 8. Step-by-Step Setup Guide

### Prerequisites
- [ ] AWS account(s) for Dev, QA, Prod
- [ ] An S3 bucket for Terraform state (create manually or via AWS Console)
- [ ] Terraform >= 1.10 installed locally
- [ ] GitHub repository with `dev`, `qa`, `prod` branches created

### Step 1 — Create the State S3 Bucket

```bash
aws s3 mb s3://your-terraform-state-bucket --region us-east-1
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption \
  --bucket your-terraform-state-bucket \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

### Step 2 — Bootstrap OIDC (Run ONCE manually)

```bash
cd oidc/

# 1. Edit terraform.tfvars with your actual values:
#    - github_org      = "your-github-org"
#    - github_repo     = "terraform-infra"
#    - state_bucket_arn = "arn:aws:s3:::your-terraform-state-bucket"

# 2. Update backend.tf with your bucket name

# 3. Run with your personal AWS credentials (admin access needed for IAM)
terraform init
terraform plan
terraform apply
```

This outputs three IAM role ARNs. **Copy them — you need them in Step 3.**

### Step 3 — Configure GitHub Environments and Secrets

Go to: **GitHub Repository → Settings → Environments**

Create three environments:

#### `Development`
| Type | Name | Value |
|---|---|---|
| Secret | `AWS_OIDC_ROLE_ARN` | ARN from `oidc` output: `dev_role_arn` |

#### `QA`
| Type | Name | Value |
|---|---|---|
| Secret | `AWS_OIDC_ROLE_ARN` | ARN from `oidc` output: `qa_role_arn` |

#### `Production`
| Type | Name | Value |
|---|---|---|
| Secret | `AWS_OIDC_ROLE_ARN` | ARN from `oidc` output: `prod_role_arn` |
| **Required Reviewers** | Add senior engineers | They must approve before apply runs |

### Step 4 — Add Repository Variable

Go to: **GitHub Repository → Settings → Secrets and Variables → Actions → Variables**

| Variable | Value |
|---|---|
| `AWS_REGION` | `us-east-1` |

### Step 5 — Update Infrastructure Variables

Edit `envs/dev.tfvars`, `envs/qa.tfvars`, `envs/prod.tfvars` with your actual:
- `subnet_id` — VPC subnet ID for each environment
- `security_group_ids` — Security Group ID(s) for each environment
- `ami_id` — Valid AMI ID for your AWS region
- `bucket_suffix` — Globally unique suffix for the S3 bucket name

### Step 6 — Update backend.tf

In `terraform/backend.tf`, replace:
```
YOUR_TERRAFORM_STATE_BUCKET_NAME
```
with your actual S3 bucket name.

### Step 7 — Add Branch Protection Rules

Go to: **GitHub Repository → Settings → Branches**

For each of `dev`, `qa`, `prod`:
- ✅ Require pull request before merging
- ✅ Require approvals (at least 1 for dev/qa, 2 for prod)
- ✅ Require status checks to pass (`Plan — DEV/QA/PROD`)
- ✅ Do not allow bypassing the above settings

---

## 9. GitHub Actions — Values to Configure

### Summary of all secrets and variables per environment:

```
GitHub Environment: Development
└── Secret: AWS_OIDC_ROLE_ARN = arn:aws:iam::ACCOUNT_ID:role/myapp-github-actions-dev

GitHub Environment: QA
└── Secret: AWS_OIDC_ROLE_ARN = arn:aws:iam::ACCOUNT_ID:role/myapp-github-actions-qa

GitHub Environment: Production
└── Secret: AWS_OIDC_ROLE_ARN = arn:aws:iam::ACCOUNT_ID:role/myapp-github-actions-prod
└── Required Reviewers: [senior-engineer-1, senior-engineer-2]

GitHub Repository Variables:
└── Variable: AWS_REGION = us-east-1
```

### How secrets flow through the system:

```
oidc/main.tf → Creates IAM roles → Outputs ARNs
    │
    ▼
terraform apply (one-time)
    │
    ▼
Copy ARNs → Paste as GitHub Environment Secrets (AWS_OIDC_ROLE_ARN)
    │
    ▼
dev-plan.yml → secrets.AWS_OIDC_ROLE_ARN → aws-actions/configure-aws-credentials
    │
    ▼
GitHub exchanges OIDC token → Temporary AWS credentials → Terraform runs
```

---

## 10. Day-to-Day Developer Workflow

### Making an infrastructure change:

```bash
# 1. Always branch from 'dev'
git checkout dev
git pull origin dev
git checkout -b feature/resize-ec2

# 2. Make your Terraform changes
# Example: Change instance type in envs/dev.tfvars
vim envs/dev.tfvars
# instance_type = "t3.small"

# 3. Test locally (optional)
cd terraform/
terraform init -backend-config="key=dev/terraform.tfstate"
terraform plan -var-file="../envs/dev.tfvars"

# 4. Push and open PR
git add .
git commit -m "feat: resize EC2 to t3.small in dev"
git push origin feature/resize-ec2
# Open PR on GitHub: feature/resize-ec2 → dev
# ✅ dev-plan.yml runs automatically
# ✅ Plan is posted as PR comment
# ✅ Teammate reviews and approves
# ✅ Merge → dev-apply.yml runs → DEV updated

# 5. Promote to QA (just open a PR!)
# On GitHub: Open PR: dev → qa
# ✅ qa-plan.yml runs automatically (same code, qa.tfvars used)
# ✅ Merge → qa-apply.yml runs → QA updated

# 6. Promote to Prod
# On GitHub: Open PR: qa → prod
# ✅ prod-plan.yml runs automatically (same code, prod.tfvars used)
# ✅ Senior reviewer approves PR
# ✅ Merge → GitHub Environment reviewer approves
# ✅ prod-apply.yml runs → PRODUCTION updated
```

---

## 11. Terraform Modules Reference

### EC2 Module (`modules/ec2`)

**Security features built-in:**
- EBS root volume always encrypted (`encrypted = true`)
- IMDSv2 enforced (`http_tokens = "required"`)
- No public IP by default

| Variable | Type | Required | Description |
|---|---|---|---|
| `project_name` | string | ✅ | Resource name prefix |
| `environment` | string | ✅ | dev / qa / prod (validated) |
| `ami_id` | string | ✅ | AMI ID |
| `instance_type` | string | ✅ | e.g., t3.micro |
| `subnet_id` | string | ✅ | VPC subnet ID |
| `security_group_ids` | list(string) | ✅ | SG IDs |
| `volume_size` | number | ❌ | Default: 20 GB |
| `volume_type` | string | ❌ | Default: gp3 |

### S3 Module (`modules/s3`)

**Security features built-in:**
- All public access blocked by default
- AES-256 server-side encryption
- Lifecycle rules: old versions → STANDARD_IA after 30 days, deleted after 90 days

| Variable | Type | Required | Description |
|---|---|---|---|
| `project_name` | string | ✅ | Bucket name prefix |
| `environment` | string | ✅ | dev / qa / prod (validated) |
| `bucket_suffix` | string | ✅ | Globally unique suffix |
| `versioning_enabled` | bool | ❌ | Default: true |

---

## 12. Production-Grade Feature Checklist

| Feature | Status | Implementation |
|---|---|---|
| No static AWS keys | ✅ | OIDC keyless auth |
| Per-environment AWS roles | ✅ | 3 IAM roles in `oidc/main.tf` |
| Least-privilege IAM | ✅ | Roles can only access their env's state |
| State isolation | ✅ | Partial backend + dynamic S3 key |
| State locking | ✅ | `use_lockfile = true` (native S3) |
| Plan before apply | ✅ | Binary artifact uploaded then downloaded |
| No re-plan on apply | ✅ | Artifact downloaded, not re-generated |
| PR comment visibility | ✅ | Plan posted as PR comment automatically |
| Concurrent plan cancel | ✅ | `concurrency.cancel-in-progress: true` |
| Apply never cancelled | ✅ | `concurrency.cancel-in-progress: false` |
| Production gate | ✅ | GitHub Environment required reviewers |
| Branch protection | ✅ | Must set up in GitHub Settings |
| Reusable modules | ✅ | EC2 + S3 as separate modules |
| Auto resource tagging | ✅ | `default_tags` in provider block |
| EBS encryption | ✅ | `encrypted = true` in EC2 module |
| IMDSv2 enforced | ✅ | `http_tokens = required` |
| S3 public access blocked | ✅ | All 4 public access block settings |
| S3 encryption | ✅ | AES-256 SSE |
| Plugin caching | ✅ | `actions/cache` for `.terraform.d` |
| Terraform version pinned | ✅ | `1.10.3` in all workflows |

---

## 13. Interview Explainer

### "Walk me through this project"

> "This is a production-grade infrastructure automation project where I use Terraform to provision AWS EC2 and S3 resources across three environments — Dev, QA, and Production — and GitHub Actions to automate the CI/CD pipeline.
>
> The first thing I solved was authentication. Instead of storing static AWS access keys in GitHub, I implemented OIDC — GitHub generates a short-lived token, AWS validates it against the GitHub OIDC provider I registered, and returns temporary credentials that expire in one hour. I created three separate IAM roles, one per environment, each with least-privilege permissions and trust policies that restrict which branch can assume them.
>
> For state management, I use S3 with native locking via `use_lockfile = true` introduced in Terraform 1.10, which eliminates the need for DynamoDB. The state key is injected dynamically by GitHub Actions — `dev/terraform.tfstate`, `qa/terraform.tfstate`, `prod/terraform.tfstate` — ensuring complete isolation.
>
> For code promotion, I use a single Terraform folder with environment-specific `.tfvars` files in an `envs/` directory. Because all three branches contain identical Terraform code, promoting from dev to QA is as simple as merging the dev branch into the qa branch — GitHub Actions automatically picks up the change and runs the QA pipeline with `qa.tfvars`. This eliminates manual copy-paste and drift.
>
> The pipeline is decoupled into Plan and Apply stages. Plan runs on Pull Requests, generates a binary artifact, and posts the output as a PR comment for review. Apply runs only after the PR is merged and downloads the exact same artifact — so what was reviewed is exactly what gets deployed. Production has an additional GitHub Environment gate requiring explicit reviewer approval."

---

**Q: Why not use separate `environments/dev`, `environments/qa` folders?**
> With separate folders, merging branches doesn't propagate code changes between environments. If I merge `dev` into `qa`, only the `environments/dev/` folder updates in the QA branch — the `environments/qa/` folder is untouched. By using a single folder with `.tfvars`, the code is genuinely shared and branch merges promote changes automatically.

**Q: Why download the plan artifact instead of re-running `terraform plan` in the apply workflow?**
> If something changes between the plan (PR) and the apply (merge) — another resource created, a cloud provider API change — a re-plan could produce a different result. Applying the downloaded artifact guarantees exactly what the reviewer saw is what gets deployed. This is the audit-trail guarantee.

**Q: How do you prevent someone from bypassing QA and deploying directly to production?**
> Three layers: (1) Branch protection rules require approved PRs before merging to `prod`. (2) The Production IAM role's trust policy restricts assumption to the `prod` branch only — no developer can assume it from their workstation. (3) The `Production` GitHub Environment requires designated reviewers to approve the apply workflow even after the PR merges.
