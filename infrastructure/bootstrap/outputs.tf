output "terraform_state_bucket" {
  description = "Name of the versioned, encrypted S3 bucket used for Terraform state."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "terraform_lock_table" {
  description = "DynamoDB table used to lock Terraform state operations."
  value       = aws_dynamodb_table.terraform_lock.name
}
