#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' "Usage: $0 [--profile <AWS profile>] [--aws-region <region>]"
}

aws_profile='aws-multimodel-llm'
aws_region='eu-central-1'
secret_id='aws-multimodel-llm-platform-v0/cost-dashboard-credentials'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) aws_profile=${2:?}; shift 2 ;;
    --aws-region) aws_region=${2:?}; shift 2 ;;
    --help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

for command in aws jq openssl docker; do
  command -v "$command" >/dev/null || { printf 'Missing required command: %s\n' "$command" >&2; exit 1; }
done

aws secretsmanager describe-secret --profile "$aws_profile" --region "$aws_region" --secret-id "$secret_id" >/dev/null
if aws secretsmanager get-secret-value --profile "$aws_profile" --region "$aws_region" --secret-id "$secret_id" >/dev/null 2>&1; then
  printf '%s\n' 'The cost dashboard secret already has a value. Refusing to overwrite it.' >&2
  exit 1
fi

read -r -p 'Cost dashboard username [cost-admin]: ' basic_auth_username
basic_auth_username=${basic_auth_username:-cost-admin}
[[ "$basic_auth_username" =~ ^[A-Za-z0-9._-]{3,64}$ ]] || { printf '%s\n' 'Username must contain 3 to 64 letters, digits, dots, underscores or hyphens.' >&2; exit 2; }
read -r -s -p 'Cost dashboard password: ' basic_auth_password
printf '\n'
read -r -s -p 'Confirm cost dashboard password: ' basic_auth_password_confirmation
printf '\n'
[[ ${#basic_auth_password} -ge 16 && "$basic_auth_password" == "$basic_auth_password_confirmation" ]] || { printf '%s\n' 'Passwords must match and contain at least 16 characters.' >&2; exit 2; }

basic_auth_password_hash=$(docker run --rm caddy:2.10.0-alpine caddy hash-password --plaintext "$basic_auth_password" | tr -d '\n' | base64 -w0)
mongo_password=$(openssl rand -hex 32)
trap 'unset basic_auth_password basic_auth_password_confirmation basic_auth_password_hash mongo_password' EXIT

secret_json=$(jq -cn \
  --arg basic_auth_username "$basic_auth_username" \
  --arg basic_auth_password_hash "$basic_auth_password_hash" \
  --arg mongo_username cost_dashboard \
  --arg mongo_password "$mongo_password" \
  '{basic_auth_username:$basic_auth_username,basic_auth_password_hash:$basic_auth_password_hash,mongo_username:$mongo_username,mongo_password:$mongo_password}')

aws secretsmanager put-secret-value --profile "$aws_profile" --region "$aws_region" \
  --secret-id "$secret_id" --secret-string "$secret_json" >/dev/null
printf '%s\n' 'Cost dashboard credentials were initialized. No secret value was printed.'
