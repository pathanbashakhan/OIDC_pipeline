# Root Configuration — Outputs
#
# These outputs are displayed after a successful terraform apply.

output "ec2_instance_id" {
  description = "The ID of the provisioned EC2 instance."
  value       = module.ec2.instance_id
}

output "ec2_private_ip" {
  description = "The private IP of the EC2 instance."
  value       = module.ec2.private_ip
}

output "s3_bucket_id" {
  description = "The name of the provisioned S3 bucket."
  value       = module.s3.bucket_id
}

output "s3_bucket_arn" {
  description = "The ARN of the provisioned S3 bucket."
  value       = module.s3.bucket_arn
}
