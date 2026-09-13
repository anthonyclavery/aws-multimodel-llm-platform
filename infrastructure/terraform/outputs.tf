output "aws_account_id" {
  description = "AWS account ID targeted by Terraform."
  value       = data.aws_caller_identity.current.account_id
}

output "aws_caller_arn" {
  description = "ARN of the AWS identity used by Terraform."
  value       = data.aws_caller_identity.current.arn
}
