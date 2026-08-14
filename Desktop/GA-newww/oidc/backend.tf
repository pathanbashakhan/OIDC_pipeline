# oidc/backend.tf
#
# The OIDC bootstrap state is stored in a separate prefix
# to keep it isolated from the main infrastructure state.

terraform {
  backend "s3" {
    bucket       = "s3-bucket-for-oidc-pipeline-2026" # ← Replace with your bucket
    key          = "oidc-bootstrap/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
