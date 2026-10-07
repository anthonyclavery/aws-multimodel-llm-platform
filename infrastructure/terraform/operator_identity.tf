locals {
  operator_terraform_state_bucket = "${var.project_name}-${data.aws_caller_identity.current.account_id}-${var.aws_region}-tfstate"
  operator_terraform_lock_table   = "${var.project_name}-${var.environment}-terraform-lock"
}

resource "aws_iam_user" "librechat_operator" {
  name          = var.operator_iam_user_name
  force_destroy = false

  tags = {
    Name        = var.operator_iam_user_name
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "HumanTerraformOperator"
  }
}

data "aws_iam_policy_document" "librechat_operator_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.librechat_operator.arn]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "terraform_operator" {
  name               = "${var.project_name}-${var.environment}-terraform-operator"
  assume_role_policy = data.aws_iam_policy_document.librechat_operator_assume_role.json

  tags = {
    Name        = "${var.project_name}-${var.environment}-terraform-operator"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "HumanTerraformOperator"
  }
}

data "aws_iam_policy_document" "librechat_operator_assume_project_role" {
  statement {
    sid    = "AssumeOnlyTheLibreChatTerraformRole"
    effect = "Allow"

    actions   = ["sts:AssumeRole"]
    resources = [aws_iam_role.terraform_operator.arn]
  }
}

resource "aws_iam_user_policy" "librechat_operator_assume_project_role" {
  name   = "${var.project_name}-${var.environment}-assume-terraform-operator"
  user   = aws_iam_user.librechat_operator.name
  policy = data.aws_iam_policy_document.librechat_operator_assume_project_role.json
}

data "aws_iam_policy_document" "librechat_operator_self_manage_access_keys" {
  statement {
    sid    = "RotateOnlyOwnAccessKeys"
    effect = "Allow"

    actions = [
      "iam:CreateAccessKey",
      "iam:DeleteAccessKey",
      "iam:ListAccessKeys",
      "iam:UpdateAccessKey",
    ]

    resources = [aws_iam_user.librechat_operator.arn]
  }
}

resource "aws_iam_user_policy" "librechat_operator_self_manage_access_keys" {
  name   = "${var.project_name}-${var.environment}-self-manage-access-keys"
  user   = aws_iam_user.librechat_operator.name
  policy = data.aws_iam_policy_document.librechat_operator_self_manage_access_keys.json
}

data "aws_iam_policy_document" "terraform_operator" {
  statement {
    sid    = "ReadAndWritePlatformTerraformState"
    effect = "Allow"

    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]

    resources = ["arn:aws:s3:::${local.operator_terraform_state_bucket}"]
  }

  statement {
    sid    = "ReadAndWriteOnlyPlatformTerraformStateObject"
    effect = "Allow"

    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
    ]

    resources = ["arn:aws:s3:::${local.operator_terraform_state_bucket}/platform/${var.environment}/terraform.tfstate"]
  }

  statement {
    sid    = "LockOnlyPlatformTerraformState"
    effect = "Allow"

    actions = [
      "dynamodb:DeleteItem",
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
    ]

    resources = ["arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${local.operator_terraform_lock_table}"]
  }

  statement {
    sid    = "ManageOnlyRequiredEc2CapabilitiesInProjectRegion"
    effect = "Allow"

    actions = [
      "ec2:AllocateAddress",
      "ec2:AssociateAddress",
      "ec2:AssociateRouteTable",
      "ec2:AttachInternetGateway",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateInternetGateway",
      "ec2:CreateRoute",
      "ec2:CreateRouteTable",
      "ec2:CreateSecurityGroup",
      "ec2:CreateSubnet",
      "ec2:CreateTags",
      "ec2:CreateVpc",
      "ec2:DeleteInternetGateway",
      "ec2:DeleteRoute",
      "ec2:DeleteRouteTable",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteSubnet",
      "ec2:DeleteTags",
      "ec2:DeleteVpc",
      "ec2:Describe*",
      "ec2:DetachInternetGateway",
      "ec2:DisassociateAddress",
      "ec2:DisassociateRouteTable",
      "ec2:ModifyInstanceAttribute",
      "ec2:ModifySubnetAttribute",
      "ec2:ModifyVpcAttribute",
      "ec2:ReleaseAddress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RunInstances",
      "ec2:StartInstances",
      "ec2:StopInstances",
      "ec2:TerminateInstances",
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }

  statement {
    sid    = "ManageOnlyProjectRolesAndProfiles"
    effect = "Allow"

    actions = [
      "iam:AddRoleToInstanceProfile",
      "iam:AttachRolePolicy",
      "iam:CreateInstanceProfile",
      "iam:CreateRole",
      "iam:DeleteInstanceProfile",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:GetInstanceProfile",
      "iam:GetRole",
      "iam:ListRolePolicies",
      "iam:PassRole",
      "iam:PutRolePolicy",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile",
      "iam:TagRole",
      "iam:UntagInstanceProfile",
      "iam:UntagRole",
    ]

    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-${var.environment}-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/${var.project_name}-${var.environment}-*",
    ]
  }

  statement {
    sid    = "ManageOnlyProjectSecrets"
    effect = "Allow"

    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:ListSecretVersionIds",
      "secretsmanager:PutSecretValue",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource",
      "secretsmanager:UpdateSecret",
    ]

    resources = ["arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}-${var.environment}/*"]
  }

  statement {
    sid    = "ListProjectSecrets"
    effect = "Allow"

    actions   = ["secretsmanager:ListSecrets"]
    resources = ["*"]
  }

  statement {
    sid    = "ManagePlatformBackupAndRecovery"
    effect = "Allow"

    actions = [
      "backup:CreateBackupPlan",
      "backup:CreateBackupSelection",
      "backup:CreateBackupVault",
      "backup:DeleteBackupPlan",
      "backup:DeleteBackupSelection",
      "backup:DeleteBackupVault",
      "backup:DescribeBackupJob",
      "backup:DescribeBackupVault",
      "backup:DescribeRecoveryPoint",
      "backup:GetBackupPlan",
      "backup:GetBackupSelection",
      "backup:ListBackupJobs",
      "backup:ListBackupPlans",
      "backup:ListBackupSelections",
      "backup:ListProtectedResources",
      "backup:ListRecoveryPointsByBackupVault",
      "backup:ListRestoreJobs",
      "backup:StartRestoreJob",
      "backup:TagResource",
      "backup:UntagResource",
      "backup:UpdateBackupPlan",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "ManageOnlyProjectSchedule"
    effect = "Allow"

    actions = [
      "scheduler:CreateSchedule",
      "scheduler:CreateScheduleGroup",
      "scheduler:DeleteSchedule",
      "scheduler:DeleteScheduleGroup",
      "scheduler:GetSchedule",
      "scheduler:GetScheduleGroup",
      "scheduler:ListSchedules",
      "scheduler:UpdateSchedule",
    ]

    resources = [
      "arn:aws:scheduler:${var.aws_region}:${data.aws_caller_identity.current.account_id}:schedule/${var.project_name}-${var.environment}/*",
      "arn:aws:scheduler:${var.aws_region}:${data.aws_caller_identity.current.account_id}:schedule-group/${var.project_name}-${var.environment}",
    ]
  }

  statement {
    sid    = "ReadCostAndPricingForTheDashboard"
    effect = "Allow"

    actions = [
      "ce:GetCostAndUsage",
      "pricing:GetProducts",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "ConnectToOnlyThePlatformInstanceThroughSsm"
    effect = "Allow"

    actions = [
      "ssm:DescribeInstanceInformation",
      "ssm:StartSession",
    ]

    resources = [
      aws_instance.platform.arn,
      "arn:aws:ssm:${var.aws_region}::document/AWS-StartInteractiveCommand",
      "arn:aws:ssm:${var.aws_region}::document/AWS-StartSSHSession",
    ]
  }

  statement {
    sid    = "EndOnlyOwnSsmSessions"
    effect = "Allow"

    actions = [
      "ssm:ResumeSession",
      "ssm:TerminateSession",
    ]

    resources = ["arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:session/$${aws:userid}-*"]
  }
}

resource "aws_iam_role_policy" "terraform_operator" {
  name   = "${var.project_name}-${var.environment}-terraform-operator"
  role   = aws_iam_role.terraform_operator.id
  policy = data.aws_iam_policy_document.terraform_operator.json
}
