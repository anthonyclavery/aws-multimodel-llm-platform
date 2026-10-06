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
  # AWS evaluates permission against a cross-region profile and its destination
  # foundation model. The EC2 role may invoke Bedrock serverless models and
  # profiles, but it cannot subscribe to Marketplace products, deploy endpoints
  # or invoke Marketplace endpoints.
  bedrock_serverless_inference_resources = [
    "arn:aws:bedrock:*::foundation-model/*",
    "arn:aws:bedrock:*:*:inference-profile/*",
    "arn:aws:bedrock:*:${data.aws_caller_identity.current.account_id}:project/default",
  ]
}

data "aws_iam_policy_document" "ec2_bedrock_inference" {
  statement {
    sid    = "InvokeBedrockServerlessModels"
    effect = "Allow"

    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
    ]

    resources = local.bedrock_serverless_inference_resources
  }

  statement {
    sid    = "DiscoverBedrockServerlessCatalog"
    effect = "Allow"

    actions = [
      "bedrock:ListFoundationModels",
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
      aws_secretsmanager_secret.cost_dashboard_credentials.arn,
    ]
  }
}

resource "aws_iam_role_policy" "ec2_secrets_read" {
  name   = "${var.project_name}-${var.environment}-secrets-read"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.ec2_secrets_read.json
}

data "aws_iam_policy_document" "ec2_cost_explorer_read" {
  statement {
    sid    = "ReadBedrockBillingTotals"
    effect = "Allow"

    actions = [
      "ce:GetCostAndUsage",
      "pricing:GetProducts",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ec2_cost_explorer_read" {
  name   = "${var.project_name}-${var.environment}-cost-explorer-read"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.ec2_cost_explorer_read.json
}
