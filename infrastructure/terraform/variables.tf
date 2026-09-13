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

variable "project_name" {
  description = "Project name used in resource names and tags."
  type        = string
  default     = "aws-multimodel-llm-platform"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "v0"
}

variable "vpc_cidr" {
  description = "CIDR block assigned to the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block assigned to the public subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "Availability Zone used by the public subnet."
  type        = string
  default     = "eu-central-1a"
}

variable "instance_type" {
  description = "EC2 instance type used by the V0 platform."
  type        = string
  default     = "t3.medium"
}

variable "root_volume_size_gb" {
  description = "Size in GiB of the encrypted EC2 root EBS volume."
  type        = number
  default     = 40
}
