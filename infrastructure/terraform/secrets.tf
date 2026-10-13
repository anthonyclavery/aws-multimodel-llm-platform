resource "aws_secretsmanager_secret" "gemini_api_key" {
  name        = "${var.project_name}-${var.environment}/gemini-api-key"
  description = "Google Gemini API key used by LibreChat."

  tags = {
    Name        = "${var.project_name}-${var.environment}-gemini-api-key"
    project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_secretsmanager_secret" "mongodb_credentials" {
  name        = "${var.project_name}-${var.environment}/mongodb-credentials"
  description = "MongoDB credentials used by LibreChat."

  tags = {
    Name        = "${var.project_name}-${var.environment}-mongodb-credentials"
    project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_secretsmanager_secret" "librechat_jwt" {
  name        = "${var.project_name}-${var.environment}/librechat-jwt"
  description = "JWT secret used by LibreChat."

  tags = {
    Name        = "${var.project_name}-${var.environment}-librechat-jwt"
    project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_secretsmanager_secret" "cost_dashboard_credentials" {
  name        = "${var.project_name}-${var.environment}/cost-dashboard-credentials"
  description = "Caddy authentication and read-only MongoDB credentials for the cost dashboard."

  tags = {
    Name        = "${var.project_name}-${var.environment}-cost-dashboard-credentials"
    project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
