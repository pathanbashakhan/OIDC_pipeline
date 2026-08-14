# S3 Module — Variable Declarations

variable "project_name" {
  description = "The project name — used as a prefix for the S3 bucket name."
  type        = string
}

variable "environment" {
  description = "The deployment environment (dev, qa, prod). Used in bucket naming and tagging."
  type        = string
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "Environment must be one of: dev, qa, prod."
  }
}

variable "bucket_suffix" {
  description = "A suffix to make the bucket name unique globally (e.g., 'data', 'artifacts', 'logs')."
  type        = string
}

variable "versioning_enabled" {
  description = "Whether to enable S3 bucket versioning. Always true for prod."
  type        = bool
  default     = true
}

variable "tags" {
  description = "A map of additional tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}
