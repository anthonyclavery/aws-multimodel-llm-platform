#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' "Usage: $0 [--profile <AWS profile>] [--aws-region <region>]"
}

aws_profile='aws-multimodel-llm'
aws_region='eu-central-1'
secret_id='aws-multimodel-llm-platform-v0/librechat-jwt'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) aws_profile=${2:?}; shift 2 ;;
    --aws-region) aws_region=${2:?}; shift 2 ;;
    --help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

for command in aws base64 jq od; do
  command -v "$command" >/dev/null || {
    printf 'Missing required command: %s\n' "$command" >&2
    exit 1
  }
done

secret_json=$(aws secretsmanager get-secret-value \
  --profile "$aws_profile" \
  --region "$aws_region" \
  --secret-id "$secret_id" \
  --query SecretString \
  --output text)

creds_key=$(jq -er '.creds_key | strings | select(length > 0)' <<<"$secret_json")
creds_iv=$(jq -er '.creds_iv | strings | select(length > 0)' <<<"$secret_json")
trap 'unset secret_json creds_key creds_iv converted_key converted_iv migrated_secret' EXIT

to_hex() {
  local value=$1
  printf '%s' "$value" | base64 --decode | od -An -tx1 -v | tr -d ' \n'
}

if [[ "$creds_key" =~ ^[a-f0-9]{64}$ ]]; then
  converted_key=$creds_key
else
  converted_key=$(to_hex "$creds_key") || {
    printf '%s\n' 'CREDS_KEY is neither valid hexadecimal nor decodable Base64.' >&2
    exit 1
  }
fi

if [[ "$creds_iv" =~ ^[a-f0-9]{32}$ ]]; then
  converted_iv=$creds_iv
else
  converted_iv=$(to_hex "$creds_iv") || {
    printf '%s\n' 'CREDS_IV is neither valid hexadecimal nor decodable Base64.' >&2
    exit 1
  }
fi

if [[ ! "$converted_key" =~ ^[a-f0-9]{64}$ || ! "$converted_iv" =~ ^[a-f0-9]{32}$ ]]; then
  printf '%s\n' 'Decoded credentials do not have the expected 32-byte key and 16-byte IV lengths.' >&2
  exit 1
fi

if [[ "$creds_key" == "$converted_key" && "$creds_iv" == "$converted_iv" ]]; then
  printf '%s\n' 'LibreChat credentials are already encoded in the required hexadecimal format.'
  exit 0
fi

commit=$(git -C "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" rev-parse --short HEAD)
printf '%s\n' 'This preserves the existing credential bytes and changes only their encoding from Base64 to hexadecimal.'
printf 'Type MIGRATE CREDENTIALS %s to update the Secrets Manager value: ' "$commit"
read -r confirmation
if [[ "$confirmation" != "MIGRATE CREDENTIALS $commit" ]]; then
  printf '%s\n' 'Migration cancelled. The secret was not changed.'
  exit 0
fi

migrated_secret=$(jq --arg key "$converted_key" --arg iv "$converted_iv" \
  '.creds_key = $key | .creds_iv = $iv' <<<"$secret_json")
aws secretsmanager put-secret-value \
  --profile "$aws_profile" \
  --region "$aws_region" \
  --secret-id "$secret_id" \
  --secret-string "$migrated_secret" >/dev/null

printf '%s\n' 'LibreChat credential encoding was migrated. No secret value was printed.'
