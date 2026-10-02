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
terraform_dir="$repo_root/infrastructure/terraform"
plans_dir="$repo_root/.terraform-plans"
timestamp=$(date -u +%Y%m%dT%H%M%SZ)
plan_path="$plans_dir/platform-$timestamp.tfplan"

mkdir -p "$plans_dir"
export AWS_PROFILE="$aws_profile"
export AWS_REGION="$aws_region"
export TF_VAR_aws_profile="$aws_profile"
export TF_VAR_aws_region="$aws_region"

terraform -chdir="$terraform_dir" init -input=false
terraform -chdir="$terraform_dir" plan -input=false -lock-timeout=5m -out="$plan_path"
terraform -chdir="$terraform_dir" show -no-color "$plan_path"

printf '\nPlan file: %s\n' "$plan_path"
printf 'Plan SHA-256: '
sha256sum "$plan_path" | awk '{print $1}'
printf '%s\n' 'Review this output before using scripts/terraform-apply-plan.sh.'
