variable "aws_region" {
  description = "AWS region used by the platform."
  type        = string
  default     = "eu-central-1"
}

variable "aws_profile" {
  description = "AWS CLI profile used by Terraform."
  type        = string
  default     = "aws-multimodel-llm"
}
