# EC2 Module — Variable Declarations
#
# All variables must be supplied by the environment root configuration
# (terraform/*.tfvars). No defaults for critical values — forces
# explicit configuration for each environment.

variable "project_name" {
  description = "The project name — used as a prefix for all resource names."
  type        = string
}

variable "environment" {
  description = "The deployment environment (dev, qa, prod). Used in resource naming and tagging."
  type        = string
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "Environment must be one of: dev, qa, prod."
  }
}

variable "ami_id" {
  description = "The AMI ID to use for the EC2 instance. Should be region-specific."
  type        = string
}

variable "instance_type" {
  description = "The EC2 instance type (e.g., t3.micro for dev, t3.large for prod)."
  type        = string
}

variable "subnet_id" {
  description = "The ID of the subnet to launch the EC2 instance into."
  type        = string
}

variable "security_group_ids" {
  description = "A list of security group IDs to associate with the EC2 instance."
  type        = list(string)
}

variable "associate_public_ip" {
  description = "Whether to associate a public IP address with the instance."
  type        = bool
  default     = false # Secure default — no public IP by default
}

variable "volume_type" {
  description = "The type of the root EBS volume (e.g., gp3, gp2)."
  type        = string
  default     = "gp3"
}

variable "volume_size" {
  description = "The size of the root EBS volume in GiB."
  type        = number
  default     = 20
}

variable "tags" {
  description = "A map of additional tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}
