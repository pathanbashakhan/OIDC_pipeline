# Root Configuration — Variables
#
# These are declared here and populated by the environment-specific .tfvars file.
# GitHub Actions passes: -var-file=dev.tfvars, qa.tfvars, or prod.tfvars

variable "project_name" {
  description = "The project name prefix for all resources."
  type        = string
}

variable "environment" {
  description = "The target environment. Must match the branch (dev, qa, prod)."
  type        = string
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "environment must be dev, qa, or prod."
  }
}

variable "aws_region" {
  description = "The AWS region where resources will be provisioned."
  type        = string
  default     = "us-east-1"
}

# ── EC2 Variables ──────────────────────────────────────────────────────────────

variable "ami_id" {
  description = "The AMI ID for the EC2 instance. Varies per region and environment."
  type        = string
}

variable "instance_type" {
  description = "The EC2 instance type. Smaller for dev, larger for prod."
  type        = string
}

variable "subnet_id" {
  description = "The VPC Subnet ID to launch the EC2 instance into."
  type        = string
}

variable "security_group_ids" {
  description = "List of Security Group IDs for the EC2 instance."
  type        = list(string)
}

variable "volume_size" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 20
}

# ── S3 Variables ───────────────────────────────────────────────────────────────

variable "bucket_suffix" {
  description = "Suffix for the S3 bucket name to ensure global uniqueness."
  type        = string
}

variable "s3_versioning_enabled" {
  description = "Enable S3 versioning. Recommended true for all environments."
  type        = bool
  default     = true
}

# ── Common Tags ────────────────────────────────────────────────────────────────

variable "common_tags" {
  description = "Common tags applied to all resources for cost allocation and tracking."
  type        = map(string)
  default     = {}
}
