# envs/dev.tfvars — Development Environment Variable Values
#
# Loaded by GitHub Actions via:
#   terraform plan  -var-file="../../envs/dev.tfvars"
#   terraform apply -var-file="../../envs/dev.tfvars"
#
# Triggered by: Pull Requests and merges to the 'dev' branch.
# AWS Account:  Dev AWS Account (separate from QA and Prod)

# ── Project ────────────────────────────────────────────────────────────────────
project_name = "myapp"
environment  = "dev"
aws_region   = "us-east-1"

# ── EC2 — Use small/cheap instance for dev ────────────────────────────────────
ami_id             = "ami-07a5b367e8dc8bd92" # Amazon Linux 2 — us-east-1
instance_type      = "t3.micro"              # Smallest for cost savings in dev
subnet_id          = "subnet-00de18d56b2a1c362"     # ← Replace: Dev VPC Private Subnet ID
security_group_ids = ["sg-07ddf791d65b46da7"]       # ← Replace: Dev Security Group ID
volume_size        = 20                      # 20 GB root volume

# ── S3 ────────────────────────────────────────────────────────────────────────
bucket_suffix         = "app-data-dev-001"   # Must be globally unique across AWS
s3_versioning_enabled = true

# ── Tags ──────────────────────────────────────────────────────────────────────
common_tags = {
  Owner      = "platform-team"
  CostCenter = "cc-dev-001"
  Tier       = "development"
}
