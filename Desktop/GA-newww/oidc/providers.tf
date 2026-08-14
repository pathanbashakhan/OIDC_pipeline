# oidc/providers.tf
#
# This is a ONE-TIME BOOTSTRAP configuration.
# Run this ONCE manually to create the AWS OIDC provider and IAM roles
# that all GitHub Actions workflows will use going forward.
#
# After running this, the role ARNs in the output are added to
# GitHub Environments as secrets (AWS_OIDC_ROLE_ARN).

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
      Purpose   = "OIDC-Bootstrap"
    }
  }
}
