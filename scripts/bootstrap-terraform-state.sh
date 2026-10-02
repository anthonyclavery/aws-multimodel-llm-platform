#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' "Usage: $0 [--profile <AWS profile>] [--region <AWS region>]"
}

aws_profile='aws-multimodel-llm'
aws_region='eu-central-1'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) aws_profile=${2:?}; shift 2 ;;
    --region) aws_region=${2:?}; shift 2 ;;
    --help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
bootstrap_dir="$repo_root/infrastructure/bootstrap"
platform_dir="$repo_root/infrastructure/terraform"

export TF_VAR_aws_profile="$aws_profile"
export TF_VAR_aws_region="$aws_region"

terraform -chdir="$bootstrap_dir" init -backend=false -reconfigure
terraform -chdir="$bootstrap_dir" apply

cp "$bootstrap_dir/backend.tf.template" "$bootstrap_dir/backend.tf"

backend_args=(
  "-backend-config=bucket=$(terraform -chdir="$bootstrap_dir" output -raw terraform_state_bucket)"
  "-backend-config=region=$aws_region"
  '-backend-config=encrypt=true'
  '-backend-config=use_lockfile=true'
)

terraform -chdir="$bootstrap_dir" init -migrate-state -force-copy -input=false "${backend_args[@]}" \
  -backend-config=key=bootstrap/terraform.tfstate
terraform -chdir="$platform_dir" init -migrate-state -force-copy -input=false "${backend_args[@]}" \
  -backend-config=key=platform/v0/terraform.tfstate

printf '%s\n' 'Terraform state migration completed. Both state files now use the S3 backend with native S3 locking.'
