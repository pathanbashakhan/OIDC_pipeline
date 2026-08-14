# envs/qa.tfvars — QA Environment Variable Values
#
# Loaded by GitHub Actions via:
#   terraform plan  -var-file="../../envs/qa.tfvars"
#   terraform apply -var-file="../../envs/qa.tfvars"
#
# Triggered by: Pull Requests and merges to the 'qa' branch.
# Promotion:    Merge 'dev' branch into 'qa' branch to promote.
# AWS Account:  QA AWS Account (separate from Dev and Prod)

# ── Project ────────────────────────────────────────────────────────────────────
project_name = "myapp"
environment  = "qa"
aws_region   = "us-east-1"

# ── EC2 — Mid-size to replicate prod-like behaviour for testing ───────────────
ami_id             = "ami-07a5b367e8dc8bd92" # Amazon Linux 2 — us-east-1
instance_type      = "t3.small"              # Closer to prod for accurate QA testing
subnet_id          = "subnet-00de18d56b2a1c362"     # ← Replace: QA VPC Private Subnet ID
security_group_ids = ["sg-07ddf791d65b46da7"]       # ← Replace: QA Security Group ID
volume_size        = 30                      # Slightly larger than dev

# ── S3 ────────────────────────────────────────────────────────────────────────
bucket_suffix         = "app-data-qa-001"    # Must be globally unique across AWS
s3_versioning_enabled = true

# ── Tags ──────────────────────────────────────────────────────────────────────
common_tags = {
  Owner      = "platform-team"
  CostCenter = "cc-qa-001"
  Tier       = "quality-assurance"
}
