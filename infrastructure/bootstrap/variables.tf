variable "aws_region" {
  description = "AWS region hosting the Terraform state bucket."
  type        = string
  default     = "eu-central-1"
}

variable "aws_profile" {
  description = "AWS CLI profile used by Terraform."
  type        = string
  default     = "aws-multimodel-llm"
}

variable "project_name" {
  description = "Project name used in the Terraform state bucket name and tags."
  type        = string
  default     = "aws-multimodel-llm-platform"
}

variable "environment" {
  description = "Environment whose Terraform state is stored."
  type        = string
  default     = "v0"
}
