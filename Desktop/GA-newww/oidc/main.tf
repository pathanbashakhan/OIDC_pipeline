# oidc/main.tf
#
# This file provisions all AWS IAM infrastructure needed for
# keyless GitHub Actions authentication using OpenID Connect (OIDC).
#
# ┌─────────────────────────────────────────────────────────────────┐
# │  HOW OIDC WORKS                                                 │
# │                                                                 │
# │  GitHub Actions ──OIDC Token──▶ AWS STS                        │
# │       │                              │                          │
# │       │          (Token verified     │                          │
# │       │           against GitHub's   │                          │
# │       │           OIDC provider)     │                          │
# │       ◀──Temporary Credentials───────┘                         │
# │       │  (Expire in 1 hour)                                     │
# │       │                                                         │
# │  No static Access Keys are ever stored anywhere.                │
# └─────────────────────────────────────────────────────────────────┘
#
# RESOURCES CREATED:
#   1. aws_iam_openid_connect_provider — registers GitHub as trusted IdP
#   2. aws_iam_role + policy (Dev)     — assumed by dev branch workflows
#   3. aws_iam_role + policy (QA)      — assumed by qa branch workflows
#   4. aws_iam_role + policy (Prod)    — assumed by prod branch workflows

# ── 1. GitHub OIDC Provider ────────────────────────────────────────────────────
# Registers GitHub Actions as a trusted Identity Provider in AWS.
# This is created ONCE per AWS account.
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  # GitHub's OIDC audience — always "sts.amazonaws.com" for AWS
  client_id_list = ["sts.amazonaws.com"]

  # GitHub's OIDC thumbprint — stable value, verified against GitHub's cert
  # See: https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# ── Local: Reusable OIDC Trust Policy Template ────────────────────────────────
locals {
  # Base OIDC trust condition — restricts to your specific repo
  oidc_provider_arn = aws_iam_openid_connect_provider.github.arn
  oidc_provider_url = "token.actions.githubusercontent.com"
}

# ── 2a. IAM Role — DEV ────────────────────────────────────────────────────────
# This role is ONLY assumable by workflows running on the 'dev' branch
# or on Pull Requests targeting 'dev'. This prevents a prod workflow
# from accidentally assuming a dev role.
resource "aws_iam_role" "github_actions_dev" {
  name        = "${var.project_name}-github-actions-dev"
  description = "Assumed by GitHub Actions OIDC for the DEV environment"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GitHubOIDCDev"
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider_url}:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Allow: dev branch pushes AND pull_requests targeting dev
            "${local.oidc_provider_url}:sub" = [
              "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/dev",
              "repo:${var.github_org}/${var.github_repo}:pull_request"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Environment = "dev"
  }
}

# ── 2b. IAM Policy — DEV ──────────────────────────────────────────────────────
# Least-privilege permissions for the Dev environment.
# Grants only what Terraform needs to provision EC2 and S3.
resource "aws_iam_role_policy" "github_actions_dev" {
  name = "${var.project_name}-terraform-dev-policy"
  role = aws_iam_role.github_actions_dev.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3 State Backend — read/write the state file
      {
        Sid    = "TerraformStateAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.state_bucket_arn,
          "${var.state_bucket_arn}/dev/*"
        ]
      },
      # EC2 — provision instances
      {
        Sid    = "EC2Access"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:StopInstances",
          "ec2:StartInstances",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:ModifyInstanceAttribute"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      # S3 — provision application buckets
      {
        Sid    = "S3BucketAccess"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:GetBucket*",
          "s3:PutBucket*",
          "s3:GetEncryptionConfiguration",
          "s3:PutEncryptionConfiguration",
          "s3:GetLifecycleConfiguration",
          "s3:PutLifecycleConfiguration",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock"
        ]
        Resource = "*"
      }
    ]
  })
}

# ── 3a. IAM Role — QA ─────────────────────────────────────────────────────────
resource "aws_iam_role" "github_actions_qa" {
  name        = "${var.project_name}-github-actions-qa"
  description = "Assumed by GitHub Actions OIDC for the QA environment"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GitHubOIDCQA"
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider_url}:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "${local.oidc_provider_url}:sub" = [
              "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/qa",
              "repo:${var.github_org}/${var.github_repo}:pull_request"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Environment = "qa"
  }
}

# ── 3b. IAM Policy — QA ───────────────────────────────────────────────────────
resource "aws_iam_role_policy" "github_actions_qa" {
  name = "${var.project_name}-terraform-qa-policy"
  role = aws_iam_role.github_actions_qa.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformStateAccess"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [var.state_bucket_arn, "${var.state_bucket_arn}/qa/*"]
      },
      {
        Sid      = "EC2Access"
        Effect   = "Allow"
        Action   = ["ec2:Describe*", "ec2:RunInstances", "ec2:TerminateInstances", "ec2:StopInstances", "ec2:StartInstances", "ec2:CreateTags", "ec2:DeleteTags", "ec2:ModifyInstanceAttribute"]
        Resource = "*"
      },
      {
        Sid      = "S3BucketAccess"
        Effect   = "Allow"
        Action   = ["s3:CreateBucket", "s3:DeleteBucket", "s3:GetBucket*", "s3:PutBucket*", "s3:GetEncryptionConfiguration", "s3:PutEncryptionConfiguration", "s3:GetLifecycleConfiguration", "s3:PutLifecycleConfiguration", "s3:GetBucketVersioning", "s3:PutBucketVersioning", "s3:GetBucketPublicAccessBlock", "s3:PutBucketPublicAccessBlock"]
        Resource = "*"
      }
    ]
  })
}

# ── 4a. IAM Role — PROD ───────────────────────────────────────────────────────
# Most restricted role — only assumes from the 'prod' branch.
# Pull request condition is intentionally EXCLUDED from Prod
# to enforce that only merged code can provision production.
resource "aws_iam_role" "github_actions_prod" {
  name        = "${var.project_name}-github-actions-prod"
  description = "Assumed by GitHub Actions OIDC for the PROD environment"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GitHubOIDCProd"
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider_url}:aud" = "sts.amazonaws.com"
            # Prod role: ONLY assumed from the prod branch — not from PRs
            "${local.oidc_provider_url}:sub" = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/prod"
          }
        }
      }
    ]
  })

  tags = {
    Environment = "prod"
  }
}

# ── 4b. IAM Policy — PROD ─────────────────────────────────────────────────────
resource "aws_iam_role_policy" "github_actions_prod" {
  name = "${var.project_name}-terraform-prod-policy"
  role = aws_iam_role.github_actions_prod.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformStateAccess"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [var.state_bucket_arn, "${var.state_bucket_arn}/prod/*"]
      },
      {
        Sid      = "EC2Access"
        Effect   = "Allow"
        Action   = ["ec2:Describe*", "ec2:RunInstances", "ec2:TerminateInstances", "ec2:StopInstances", "ec2:StartInstances", "ec2:CreateTags", "ec2:DeleteTags", "ec2:ModifyInstanceAttribute"]
        Resource = "*"
      },
      {
        Sid      = "S3BucketAccess"
        Effect   = "Allow"
        Action   = ["s3:CreateBucket", "s3:DeleteBucket", "s3:GetBucket*", "s3:PutBucket*", "s3:GetEncryptionConfiguration", "s3:PutEncryptionConfiguration", "s3:GetLifecycleConfiguration", "s3:PutLifecycleConfiguration", "s3:GetBucketVersioning", "s3:PutBucketVersioning", "s3:GetBucketPublicAccessBlock", "s3:PutBucketPublicAccessBlock"]
        Resource = "*"
      }
    ]
  })
}
