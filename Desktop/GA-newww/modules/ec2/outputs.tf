# EC2 Module — Outputs
#
# Outputs expose useful attributes of the created EC2 instance
# to the root configuration or other modules.

output "instance_id" {
  description = "The ID of the EC2 instance."
  value       = aws_instance.this.id
}

output "instance_arn" {
  description = "The ARN of the EC2 instance."
  value       = aws_instance.this.arn
}

output "private_ip" {
  description = "The private IP address of the EC2 instance."
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "The public IP address of the EC2 instance. Empty if no public IP assigned."
  value       = aws_instance.this.public_ip
}
