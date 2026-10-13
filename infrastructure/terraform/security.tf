resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-${var.environment}-ec2-sg"
  description = "Allow inbound HTTPS traffic to the EC2 instance only."
  vpc_id      = aws_vpc.platform.id

  ingress {
    description = "HTTPS access to Caddy"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound traffic required by the platform"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ec2-sg"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
