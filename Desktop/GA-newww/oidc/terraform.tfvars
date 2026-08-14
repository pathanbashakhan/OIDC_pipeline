# oidc/terraform.tfvars
#
# Fill in your actual values before running 'terraform apply' in oidc/
# This is the ONLY file you edit before the one-time bootstrap.

project_name = "myapp"
aws_region   = "us-east-1"

# Your GitHub organisation name or username
github_org  = "pathanbashakhan"  # ← Replace (e.g., "my-company")

# Your GitHub repository name
github_repo = "OIDC_pipeline"  # ← Replace (e.g., "aws-infra-repo")

# ARN of the S3 bucket that stores Terraform state
# Format: arn:aws:s3:::YOUR_BUCKET_NAME
state_bucket_arn = "arn:aws:s3:::s3-bucket-for-oidc-pipeline-2026" # ← Replace
