# Root Configuration — AWS Provider
#
# OIDC NOTE: AWS credentials are NOT configured here.
# They are injected as environment variables by the
# `aws-actions/configure-aws-credentials` action in each workflow,
# which exchanges GitHub's OIDC token for temporary STS credentials.

terraform {
  required_version = ">= 1.10" # Minimum version for native S3 state locking

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # All resources created by this configuration automatically receive these tags.
  # This is a production-grade pattern for cost allocation and resource tracking.
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = "github.com/your-org/terraform-infra"
    }
  }
}
