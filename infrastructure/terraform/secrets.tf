resource "aws_secretsmanager_secret" "gemini_api_key" {
  name        = "${var.project_name}-${var.environment}/gemini-api-key"
  description = "Google Gemini API key used by LibreChat."

  tags = {
    Name        = "${var.project_name}-${var.environment}-gemini-api-key"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_secretsmanager_secret" "mongodb_credentials" {
  name        = "${var.project_name}-${var.environment}/mongodb-credentials"
  description = "MongoDB credentials used by LibreChat."

  tags = {
    Name        = "${var.project_name}-${var.environment}-mongodb-credentials"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_secretsmanager_secret" "librechat_jwt" {
  name        = "${var.project_name}-${var.environment}/librechat-jwt"
  description = "JWT secret used by LibreChat."

  tags = {
    Name        = "${var.project_name}-${var.environment}-librechat-jwt"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
