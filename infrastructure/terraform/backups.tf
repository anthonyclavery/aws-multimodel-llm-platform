data "aws_iam_policy_document" "backup_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "backup" {
  name               = "${var.project_name}-${var.environment}-backup"
  assume_role_policy = data.aws_iam_policy_document.backup_assume_role.json

  tags = {
    Name        = "${var.project_name}-${var.environment}-backup"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "backup_service" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "backup_restore_service" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

resource "aws_backup_vault" "platform" {
  name = "${var.project_name}-${var.environment}-vault"

  tags = {
    Name        = "${var.project_name}-${var.environment}-vault"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_backup_plan" "daily_ebs" {
  name = "${var.project_name}-${var.environment}-daily-ebs"

  rule {
    rule_name                    = "daily-ebs-30-days"
    target_vault_name            = aws_backup_vault.platform.name
    schedule                     = var.ebs_backup_schedule
    schedule_expression_timezone = var.schedule_timezone
    start_window                 = 60
    completion_window            = 180

    lifecycle {
      delete_after = var.ebs_backup_retention_days
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-daily-ebs"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_backup_selection" "platform_ec2" {
  name         = "${var.project_name}-${var.environment}-ec2"
  iam_role_arn = aws_iam_role.backup.arn
  plan_id      = aws_backup_plan.daily_ebs.id
  resources    = [aws_instance.platform.arn]

  depends_on = [
    aws_iam_role_policy_attachment.backup_service,
    aws_iam_role_policy_attachment.backup_restore_service,
  ]
}
