# EC2 Module — Main Configuration
#
# This module creates a single EC2 instance.
# It is designed to be reusable across Dev, QA, and Prod environments.
# All environment-specific values are injected via variables.

resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  associate_public_ip_address = var.associate_public_ip

  # Root EBS volume configuration
  root_block_device {
    volume_type           = var.volume_type
    volume_size           = var.volume_size
    delete_on_termination = true
    encrypted             = true  # Always encrypt at rest — security best practice
  }

  # Disable metadata service v1 (IMDSv2 only) — AWS security best practice
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Forces IMDSv2
    http_put_response_hop_limit = 1
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-ec2"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}
