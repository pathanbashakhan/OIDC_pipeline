# envs/prod.tfvars — Production Environment Variable Values
#
# Loaded by GitHub Actions via:
#   terraform plan  -var-file="../../envs/prod.tfvars"
#   terraform apply -var-file="../../envs/prod.tfvars"
#
# Triggered by: Pull Requests and merges to the 'prod' branch.
# Promotion:    Merge 'qa' branch into 'prod' branch to promote.
# AWS Account:  Production AWS Account (most restricted)
#
# ⚠️  WARNING: Changes here affect Production. Review extremely carefully.

# ── Project ────────────────────────────────────────────────────────────────────
project_name = "myapp"
environment  = "prod"
aws_region   = "us-east-1"

# ── EC2 — Production-grade sizing ─────────────────────────────────────────────
ami_id             = "ami-07a5b367e8dc8bd92" # Amazon Linux 2 — us-east-1
instance_type      = "t3.medium"             # Production-grade sizing
subnet_id          = "subnet-00de18d56b2a1c362"     # ← Replace: Prod VPC Private Subnet ID
security_group_ids = ["sg-07ddf791d65b46da7"]       # ← Replace: Prod Security Group ID
volume_size        = 50                      # Larger volume for production workloads

# ── S3 ────────────────────────────────────────────────────────────────────────
bucket_suffix         = "app-data-prod-001"  # Must be globally unique across AWS
s3_versioning_enabled = true                  # Always true in production

# ── Tags ──────────────────────────────────────────────────────────────────────
common_tags = {
  Owner      = "platform-team"
  CostCenter = "cc-prod-001"
  Tier       = "production"
}
