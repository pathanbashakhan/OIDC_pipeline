# Root Configuration — Main
#
# This is the SINGLE SOURCE OF TRUTH for all environments.
# The same file is used for dev, qa, and prod.
# The correct environment values are injected via -var-file=<env>.tfvars
# by the respective GitHub Actions workflow.
#
# Branch → Environment Mapping:
#   feature/* → dev branch  → dev.tfvars  → AWS Dev Account
#   dev branch → qa branch  → qa.tfvars   → AWS QA Account
#   qa branch  → prod branch → prod.tfvars → AWS Prod Account

# ──────────────────────────────────────────────────────────────────────────────
# EC2 Module
# ──────────────────────────────────────────────────────────────────────────────
module "ec2" {
  source = "../modules/ec2"

  project_name       = var.project_name
  environment        = var.environment
  ami_id             = var.ami_id
  instance_type      = var.instance_type
  subnet_id          = var.subnet_id
  security_group_ids = var.security_group_ids
  volume_size        = var.volume_size
  tags               = var.common_tags
}

# ──────────────────────────────────────────────────────────────────────────────
# S3 Module
# ──────────────────────────────────────────────────────────────────────────────
module "s3" {
  source = "../modules/s3"

  project_name       = var.project_name
  environment        = var.environment
  bucket_suffix      = var.bucket_suffix
  versioning_enabled = var.s3_versioning_enabled
  tags               = var.common_tags
}
