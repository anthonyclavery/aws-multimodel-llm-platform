#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
env_file="$repo_root/docker/librechat/.env"
secret_id='aws-multimodel-llm-platform-v0/librechat-jwt'
aws_region='eu-central-1'

[[ -f "$env_file" ]] || { printf '%s\n' 'Runtime .env is absent.' >&2; exit 1; }
command -v aws >/dev/null || { printf '%s\n' 'AWS CLI is required.' >&2; exit 1; }
command -v jq >/dev/null || { printf '%s\n' 'jq is required.' >&2; exit 1; }

secret_json=$(aws secretsmanager get-secret-value \
  --region "$aws_region" \
  --secret-id "$secret_id" \
  --query SecretString \
  --output text)
creds_key=$(jq -er '.creds_key | strings | select(test("^[a-f0-9]{64}$"))' <<<"$secret_json")
creds_iv=$(jq -er '.creds_iv | strings | select(test("^[a-f0-9]{32}$"))' <<<"$secret_json")
trap 'unset secret_json creds_key creds_iv; rm -f "${tmp_file:-}"' EXIT

umask 077
tmp_file=$(mktemp "${env_file}.XXXXXX")
awk -v key="$creds_key" -v iv="$creds_iv" '
  /^CREDS_KEY=/ { print "CREDS_KEY=" key; key_found = 1; next }
  /^CREDS_IV=/ { print "CREDS_IV=" iv; iv_found = 1; next }
  { print }
  END { if (!key_found || !iv_found) exit 1 }
' "$env_file" >"$tmp_file" || {
  printf '%s\n' 'CREDS_KEY or CREDS_IV is absent from runtime .env.' >&2
  exit 1
}

sudo install -m 600 "$tmp_file" "$env_file"
printf '%s\n' 'LibreChat runtime credentials were refreshed from Secrets Manager. No secret value was printed.'
