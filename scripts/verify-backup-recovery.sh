#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' "Usage: $0 [--profile <AWS profile>] [--region <AWS region>] [--max-age-hours <hours>]"
}

aws_profile='aws-multimodel-llm'
aws_region='eu-central-1'
max_age_hours='26'
project_name='aws-multimodel-llm-platform'
environment_name='v0'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) aws_profile=${2:?}; shift 2 ;;
    --region) aws_region=${2:?}; shift 2 ;;
    --max-age-hours) max_age_hours=${2:?}; shift 2 ;;
    --help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

if ! [[ "$max_age_hours" =~ ^[1-9][0-9]*$ ]]; then
  printf '%s\n' '--max-age-hours must be a positive whole number.' >&2
  exit 2
fi

for command in aws jq date terraform; do
  command -v "$command" >/dev/null || {
    printf 'Missing required command: %s\n' "$command" >&2
    exit 1
  }
done

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
terraform_dir="$repo_root/infrastructure/terraform"
vault_name="${project_name}-${environment_name}-vault"

export AWS_PROFILE="$aws_profile"
export AWS_REGION="$aws_region"
export TF_VAR_aws_profile="$aws_profile"
export TF_VAR_aws_region="$aws_region"

instance_id=$(terraform -chdir="$terraform_dir" output -raw ec2_instance_id)
resource_arn="arn:aws:ec2:${aws_region}:$(aws sts get-caller-identity --query Account --output text):instance/${instance_id}"
recovery_points=$(aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name "$vault_name" \
  --region "$aws_region" \
  --output json)

latest_recovery_point=$(jq -cer --arg resource_arn "$resource_arn" '
  [ .RecoveryPoints[]
    | select(.ResourceArn == $resource_arn)
    | select(.ResourceType == "EC2")
    | select(.Status == "COMPLETED")
    | select(.IsEncrypted == true)
  ] | max_by(.CompletionDate)
' <<<"$recovery_points") || {
  printf 'No completed encrypted EC2 recovery point exists for %s in vault %s.\n' "$instance_id" "$vault_name" >&2
  exit 1
}

completion_date=$(jq -r '.CompletionDate' <<<"$latest_recovery_point")
completion_epoch=$(date --date="$completion_date" +%s)
current_epoch=$(date +%s)
age_seconds=$((current_epoch - completion_epoch))
max_age_seconds=$((max_age_hours * 3600))

if (( age_seconds < 0 || age_seconds > max_age_seconds )); then
  printf 'Latest completed encrypted recovery point is too old: %s. Maximum age is %s hours.\n' "$completion_date" "$max_age_hours" >&2
  exit 1
fi

printf 'Backup recovery readiness verified for %s.\n' "$instance_id"
printf 'Recovery point: %s\n' "$(jq -r '.RecoveryPointArn' <<<"$latest_recovery_point")"
printf 'Completed: %s\n' "$completion_date"
printf 'Delete after: %s\n' "$(jq -r '.CalculatedLifecycle.DeleteAt' <<<"$latest_recovery_point")"
