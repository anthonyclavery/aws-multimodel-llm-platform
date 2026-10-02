#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' "Usage: $0 [--profile <AWS profile>] [--aws-region <region>]"
}

aws_profile='aws-multimodel-llm'
aws_region='eu-central-1'
secret_prefix='aws-multimodel-llm-platform-v0'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) aws_profile=${2:?}; shift 2 ;;
    --aws-region) aws_region=${2:?}; shift 2 ;;
    --help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

for command in aws jq openssl; do
  command -v "$command" >/dev/null || {
    printf 'Missing required command: %s\n' "$command" >&2
    exit 1
  }
done

secret_ids=(
  "$secret_prefix/mongodb-credentials"
  "$secret_prefix/librechat-jwt"
  "$secret_prefix/gemini-api-key"
)

for secret_id in "${secret_ids[@]}"; do
  aws secretsmanager describe-secret --profile "$aws_profile" --region "$aws_region" --secret-id "$secret_id" >/dev/null
  if aws secretsmanager get-secret-value --profile "$aws_profile" --region "$aws_region" --secret-id "$secret_id" >/dev/null 2>&1; then
    printf 'Secret %s already has a value. Refusing to overwrite it.\n' "$secret_id" >&2
    exit 1
  fi
done

read -r -s -p 'Paste the Google Gemini API key: ' google_key
printf '\n'
[[ -n "$google_key" ]] || { printf '%s\n' 'A non-empty Gemini API key is required.' >&2; exit 1; }

mongo_root_password=$(openssl rand -hex 32)
mongo_app_password=$(openssl rand -hex 32)
jwt_secret=$(openssl rand -hex 48)
jwt_refresh_secret=$(openssl rand -hex 48)
creds_key=$(openssl rand -hex 32)
creds_iv=$(openssl rand -hex 16)
trap 'unset google_key mongo_root_password mongo_app_password jwt_secret jwt_refresh_secret creds_key creds_iv' EXIT

mongodb_json=$(jq -cn \
  --arg root_username root \
  --arg root_password "$mongo_root_password" \
  --arg app_username librechat \
  --arg app_password "$mongo_app_password" \
  '{root_username:$root_username,root_password:$root_password,app_username:$app_username,app_password:$app_password}')
jwt_json=$(jq -cn \
  --arg jwt_secret "$jwt_secret" \
  --arg jwt_refresh_secret "$jwt_refresh_secret" \
  --arg creds_key "$creds_key" \
  --arg creds_iv "$creds_iv" \
  '{jwt_secret:$jwt_secret,jwt_refresh_secret:$jwt_refresh_secret,creds_key:$creds_key,creds_iv:$creds_iv}')
gemini_json=$(jq -cn --arg google_key "$google_key" '{google_key:$google_key}')

aws secretsmanager put-secret-value --profile "$aws_profile" --region "$aws_region" \
  --secret-id "$secret_prefix/mongodb-credentials" --secret-string "$mongodb_json" >/dev/null
aws secretsmanager put-secret-value --profile "$aws_profile" --region "$aws_region" \
  --secret-id "$secret_prefix/librechat-jwt" --secret-string "$jwt_json" >/dev/null
aws secretsmanager put-secret-value --profile "$aws_profile" --region "$aws_region" \
  --secret-id "$secret_prefix/gemini-api-key" --secret-string "$gemini_json" >/dev/null

printf '%s\n' 'The three V0 secret values were initialized. No secret value was printed.'
