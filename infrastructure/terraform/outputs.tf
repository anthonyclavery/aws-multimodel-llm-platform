output "aws_account_id" {
  description = "AWS account ID targeted by Terraform."
  value       = data.aws_caller_identity.current.account_id
}

output "aws_caller_arn" {
  description = "ARN of the AWS identity used by Terraform."
  value       = data.aws_caller_identity.current.arn
}

output "vpc_id" {
  description = "ID of the platform VPC."
  value       = aws_vpc.platform.id
}

output "public_subnet_id" {
  description = "ID of the platform public subnet."
  value       = aws_subnet.public.id
}
