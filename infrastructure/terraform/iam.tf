data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ec2" {
  name               = "${var.project_name}-${var.environment}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name        = "${var.project_name}-${var.environment}-ec2-role"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2.name

  tags = {
    Name        = "${var.project_name}-${var.environment}-ec2-profile"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

locals {
  bedrock_inference_profile_arns = [
    "arn:aws:bedrock:eu-central-1:*:inference-profile/eu.anthropic.claude-haiku-4-5-20251001-v1:0",
    "arn:aws:bedrock:eu-central-1:*:inference-profile/eu.anthropic.claude-sonnet-5",
    "arn:aws:bedrock:eu-central-1:*:inference-profile/eu.anthropic.claude-opus-5",
    "arn:aws:bedrock:eu-central-1:*:inference-profile/global.anthropic.claude-fable-5-1",
    "arn:aws:bedrock:eu-central-1:*:inference-profile/global.xai.grok-4.6",
    "arn:aws:bedrock:eu-central-1:*:inference-profile/eu.amazon.nova-micro-v1:0",
    "arn:aws:bedrock:eu-central-1:*:inference-profile/eu.amazon.nova-lite-v1:0",
    "arn:aws:bedrock:eu-central-1:*:inference-profile/eu.amazon.nova-pro-v1:0",
    "arn:aws:bedrock:eu-central-1:*:inference-profile/global.amazon.nova-2-lite-v1:0",
  ]

  bedrock_foundation_model_arns = [
    "arn:aws:bedrock:eu-*::foundation-model/anthropic.claude-haiku-4-5-20251001-v1:0",
    "arn:aws:bedrock:eu-*::foundation-model/anthropic.claude-sonnet-5",
    "arn:aws:bedrock:eu-*::foundation-model/anthropic.claude-opus-5",
    "arn:aws:bedrock:eu-*::foundation-model/amazon.nova-micro-v1:0",
    "arn:aws:bedrock:eu-*::foundation-model/amazon.nova-lite-v1:0",
    "arn:aws:bedrock:eu-*::foundation-model/amazon.nova-pro-v1:0",

    "arn:aws:bedrock:::foundation-model/anthropic.claude-fable-5-1",
    "arn:aws:bedrock:eu-central-1::foundation-model/anthropic.claude-fable-5-1",
    "arn:aws:bedrock:::foundation-model/xai.grok-4.6",
    "arn:aws:bedrock:eu-central-1::foundation-model/xai.grok-4.6",
    "arn:aws:bedrock:::foundation-model/amazon.nova-2-lite-v1:0",
    "arn:aws:bedrock:eu-central-1::foundation-model/amazon.nova-2-lite-v1:0",
  ]
}

data "aws_iam_policy_document" "ec2_bedrock_inference" {
  statement {
    sid    = "InvokeApprovedBedrockModels"
    effect = "Allow"

    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
    ]

    resources = concat(
      local.bedrock_inference_profile_arns,
      local.bedrock_foundation_model_arns,
    )
  }

  statement {
    sid    = "GetApprovedBedrockInferenceProfiles"
    effect = "Allow"

    actions = [
      "bedrock:GetInferenceProfile",
    ]

    resources = local.bedrock_inference_profile_arns
  }

  statement {
    sid    = "ListBedrockInferenceProfiles"
    effect = "Allow"

    actions = [
      "bedrock:ListInferenceProfiles",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ec2_bedrock_inference" {
  name   = "${var.project_name}-${var.environment}-bedrock-inference"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.ec2_bedrock_inference.json
}

data "aws_iam_policy_document" "ec2_secrets_read" {
  statement {
    sid    = "ReadPlatformApplicationSecrets"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
    ]

    resources = [
      aws_secretsmanager_secret.gemini_api_key.arn,
      aws_secretsmanager_secret.mongodb_credentials.arn,
      aws_secretsmanager_secret.librechat_jwt.arn,
    ]
  }
}

resource "aws_iam_role_policy" "ec2_secrets_read" {
  name   = "${var.project_name}-${var.environment}-secrets-read"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.ec2_secrets_read.json
}
