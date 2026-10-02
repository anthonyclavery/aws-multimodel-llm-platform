terraform {
  required_version = "~> 1.16"

  # These values are replaced by scripts/bootstrap-terraform-state.sh.
  backend "s3" {
    bucket         = "configure-with-bootstrap-script"
    key            = "configure-with-bootstrap-script"
    region         = "eu-central-1"
    dynamodb_table = "configure-with-bootstrap-script"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
