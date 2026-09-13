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
  bedrock_model_arns = [
    "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.nova-lite-*",
    "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.nova-pro-*",
    "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.*",
    "arn:aws:bedrock:${var.aws_region}::foundation-model/openai.*",
    "arn:aws:bedrock:${var.aws_region}::foundation-model/deepseek.*",
    "arn:aws:bedrock:${var.aws_region}::foundation-model/mistral.*",
    "arn:aws:bedrock:${var.aws_region}::foundation-model/xai.grok-*",
    "arn:aws:bedrock:${var.aws_region}::foundation-model/meta.*",
    "arn:aws:bedrock:${var.aws_region}::foundation-model/cohere.*",
    "arn:aws:bedrock:${var.aws_region}::foundation-model/ai21.*",
    "arn:aws:bedrock:${var.aws_region}::foundation-model/qwen.*",
    "arn:aws:bedrock:${var.aws_region}::foundation-model/moonshot.*",
    "arn:aws:bedrock:${var.aws_region}::foundation-model/minimax.*",
    "arn:aws:bedrock:${var.aws_region}::foundation-model/nvidia.*",
    "arn:aws:bedrock:${var.aws_region}::foundation-model/writer.*",
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

    resources = local.bedrock_model_arns
  }
  statement {
    sid    = "ListBedrockInferenceProfiles"
    effect = "Allow"

    actions = [
      "bedrock:ListInferenceProfiles"
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
