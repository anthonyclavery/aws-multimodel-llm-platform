data "aws_iam_policy_document" "scheduler_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "scheduler_ec2_stop" {
  name               = "${var.project_name}-${var.environment}-scheduler-ec2-stop"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume_role.json

  tags = {
    Name        = "${var.project_name}-${var.environment}-scheduler-ec2-stop"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

data "aws_iam_policy_document" "scheduler_ec2_stop" {
  statement {
    sid    = "StopOnlyThePlatformInstance"
    effect = "Allow"

    actions = ["ec2:StopInstances"]

    resources = [aws_instance.platform.arn]
  }
}

resource "aws_iam_role_policy" "scheduler_ec2_stop" {
  name   = "${var.project_name}-${var.environment}-scheduler-ec2-stop"
  role   = aws_iam_role.scheduler_ec2_stop.id
  policy = data.aws_iam_policy_document.scheduler_ec2_stop.json
}

resource "aws_scheduler_schedule_group" "platform" {
  name = "${var.project_name}-${var.environment}"

  tags = {
    Name        = "${var.project_name}-${var.environment}-schedule-group"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_scheduler_schedule" "nightly_ec2_stop" {
  name                         = "${var.project_name}-${var.environment}-nightly-ec2-stop"
  description                  = "Stops the V0 EC2 instance every day at 22:00 Europe/Paris."
  group_name                   = aws_scheduler_schedule_group.platform.name
  schedule_expression          = var.nightly_shutdown_schedule
  schedule_expression_timezone = var.schedule_timezone

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:stopInstances"
    role_arn = aws_iam_role.scheduler_ec2_stop.arn
    input = jsonencode({
      InstanceIds = [aws_instance.platform.id]
    })
  }
}
