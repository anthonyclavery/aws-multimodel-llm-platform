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

variable "operator_iam_user_name" {
  description = "IAM user allowed to assume the dedicated Terraform operator role for this project."
  type        = string
  default     = "librechat_user"
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

variable "ami_id" {
  description = "Pinned Ubuntu AMI for the stateful V0 instance. Change only as part of an approved instance replacement."
  type        = string
  default     = "ami-03f92a7a8a26c81af"
}

variable "root_volume_size_gb" {
  description = "Size in GiB of the encrypted EC2 root EBS volume."
  type        = number
  default     = 40
}

variable "nightly_shutdown_schedule" {
  description = "EventBridge Scheduler cron expression for the nightly EC2 shutdown."
  type        = string
  default     = "cron(0 22 * * ? *)"
}

variable "schedule_timezone" {
  description = "IANA time zone used by the shutdown and backup schedules."
  type        = string
  default     = "Europe/Paris"
}

variable "ebs_backup_schedule" {
  description = "AWS Backup cron expression for the daily EBS backup."
  type        = string
  default     = "cron(0 1 ? * * *)"
}

variable "ebs_backup_retention_days" {
  description = "Number of days an EBS recovery point is retained."
  type        = number
  default     = 30
}
