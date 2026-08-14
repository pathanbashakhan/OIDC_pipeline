# oidc/outputs.tf
#
# After running 'terraform apply' in the oidc/ folder,
# copy these ARNs into your GitHub Environment secrets.

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider created in AWS."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "dev_role_arn" {
  description = <<-EOT
    ARN of the IAM role for DEV environment.
    → Add to GitHub Environment 'Development' as secret: AWS_OIDC_ROLE_ARN
  EOT
  value = aws_iam_role.github_actions_dev.arn
}

output "qa_role_arn" {
  description = <<-EOT
    ARN of the IAM role for QA environment.
    → Add to GitHub Environment 'QA' as secret: AWS_OIDC_ROLE_ARN
  EOT
  value = aws_iam_role.github_actions_qa.arn
}

output "prod_role_arn" {
  description = <<-EOT
    ARN of the IAM role for PROD environment.
    → Add to GitHub Environment 'Production' as secret: AWS_OIDC_ROLE_ARN
  EOT
  value = aws_iam_role.github_actions_prod.arn
}
