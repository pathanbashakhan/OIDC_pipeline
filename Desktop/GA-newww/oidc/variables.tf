# oidc/variables.tf

variable "aws_region" {
  description = "AWS region to create the OIDC provider and IAM roles in."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name — used as a prefix for IAM role names."
  type        = string
}

variable "github_org" {
  description = "Your GitHub organisation or username (e.g., 'my-company')."
  type        = string
}

variable "github_repo" {
  description = "Your GitHub repository name (e.g., 'terraform-infra')."
  type        = string
}

variable "state_bucket_arn" {
  description = "ARN of the S3 bucket used for Terraform remote state."
  type        = string
}
