# Root Configuration — S3 Backend with Native Locking
#
# LOCKING STRATEGY: use_lockfile = true (Terraform >= 1.10)
#   Terraform writes a `.tflock` file in S3 alongside the state file.
#   This replaces DynamoDB — zero extra AWS infrastructure needed.
#
# STATE ISOLATION via Partial Backend Configuration:
#   The 'key' is intentionally omitted here. Each GitHub Actions
#   workflow injects the correct key at runtime:
#
#   Dev:   terraform init -backend-config="key=dev/terraform.tfstate"
#   QA:    terraform init -backend-config="key=qa/terraform.tfstate"
#   Prod:  terraform init -backend-config="key=prod/terraform.tfstate"
#
# Result — isolated state per environment in S3:
#   s3://YOUR_STATE_BUCKET/dev/terraform.tfstate  + dev/terraform.tfstate.tflock
#   s3://YOUR_STATE_BUCKET/qa/terraform.tfstate   + qa/terraform.tfstate.tflock
#   s3://YOUR_STATE_BUCKET/prod/terraform.tfstate + prod/terraform.tfstate.tflock

terraform {
  backend "s3" {
    bucket       = "YOUR_TERRAFORM_STATE_BUCKET_NAME" # ← Replace with your S3 bucket
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # Native S3 locking — no DynamoDB required
    # 'key' is injected at runtime by GitHub Actions — do NOT hardcode it here
  }
}
