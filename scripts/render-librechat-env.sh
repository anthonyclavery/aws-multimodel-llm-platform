#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' "Usage: $0 --domain <DNS name> --acme-email <email> --image <immutable digest> [--aws-region <region>] [--project-name <name>] [--environment <name>]"
}

domain=''
acme_email=''
aws_region='eu-central-1'
project_name='aws-multimodel-llm-platform'
environment_name='v0'
librechat_image=''

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain) domain=${2:?}; shift 2 ;;
    --acme-email) acme_email=${2:?}; shift 2 ;;
    --aws-region) aws_region=${2:?}; shift 2 ;;
    --project-name) project_name=${2:?}; shift 2 ;;
    --environment) environment_name=${2:?}; shift 2 ;;
    --image) librechat_image=${2:?}; shift 2 ;;
    --help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

if [[ -z "$domain" || -z "$acme_email" || "$librechat_image" != *@sha256:* ]]; then
  printf '%s\n' 'An immutable LibreChat image digest is required with --image.' >&2
  usage >&2
  exit 2
fi

for command in aws jq; do
  command -v "$command" >/dev/null || {
    printf 'Missing required command: %s\n' "$command" >&2
    exit 1
  }
done

runtime_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../docker/librechat" && pwd)
secret_prefix="${project_name}-${environment_name}"

get_secret() {
  aws secretsmanager get-secret-value \
    --secret-id "$1" \
    --region "$aws_region" \
    --query SecretString \
    --output text
}

required_json_field() {
  local document=$1
  local field=$2
  jq -er --arg field "$field" '.[$field] | strings | select(length > 0)' <<<"$document"
}

url_encode() {
  jq -rn --arg value "$1" '$value | @uri'
}

mongodb_secret=$(get_secret "${secret_prefix}/mongodb-credentials")
jwt_secret=$(get_secret "${secret_prefix}/librechat-jwt")
gemini_secret=$(get_secret "${secret_prefix}/gemini-api-key")

mongo_root_username=$(required_json_field "$mongodb_secret" root_username)
mongo_root_password=$(required_json_field "$mongodb_secret" root_password)
mongo_app_username=$(required_json_field "$mongodb_secret" app_username)
mongo_app_password=$(required_json_field "$mongodb_secret" app_password)
jwt_value=$(required_json_field "$jwt_secret" jwt_secret)
jwt_refresh_value=$(required_json_field "$jwt_secret" jwt_refresh_secret)
creds_key=$(required_json_field "$jwt_secret" creds_key)
creds_iv=$(required_json_field "$jwt_secret" creds_iv)

if jq -e '.google_key | strings | select(length > 0)' >/dev/null 2>&1 <<<"$gemini_secret"; then
  google_key=$(required_json_field "$gemini_secret" google_key)
else
  google_key=$gemini_secret
fi

mongo_uri="mongodb://$(url_encode "$mongo_app_username"):$(url_encode "$mongo_app_password")@mongodb:27017/LibreChat?authSource=LibreChat"

umask 077
env_file="$runtime_dir/.env"
tmp_file=$(mktemp "${env_file}.XXXXXX")
trap 'rm -f "$tmp_file"' EXIT

cat >"$tmp_file" <<EOF
CADDY_DOMAIN=$domain
CADDY_ACME_EMAIL=$acme_email
LIBRECHAT_IMAGE=$librechat_image
DOMAIN_CLIENT=https://$domain
DOMAIN_SERVER=https://$domain
TRUST_PROXY=1
SESSION_COOKIE_SECURE=true
SECURITY_HEADERS=true
HSTS_ENABLED=true
HSTS_MAX_AGE=31536000
HSTS_INCLUDE_SUBDOMAINS=false
REFERRER_POLICY=no-referrer
CONSOLE_JSON=true
LOG_TO_FILE=false
ENDPOINTS=bedrock,google
ALLOW_EMAIL_LOGIN=true
ALLOW_REGISTRATION=false
ALLOW_SOCIAL_LOGIN=false
ALLOW_SOCIAL_REGISTRATION=false
ALLOW_PASSWORD_RESET=false
ALLOW_UNVERIFIED_EMAIL_LOGIN=true
MIN_PASSWORD_LENGTH=14
SESSION_EXPIRY=1000 * 60 * 15
REFRESH_TOKEN_EXPIRY=(1000 * 60 * 60 * 24) * 7
JWT_SECRET=$jwt_value
JWT_REFRESH_SECRET=$jwt_refresh_value
CREDS_KEY=$creds_key
CREDS_IV=$creds_iv
MONGO_INITDB_ROOT_USERNAME=$mongo_root_username
MONGO_INITDB_ROOT_PASSWORD=$mongo_root_password
MONGO_APP_USERNAME=$mongo_app_username
MONGO_APP_PASSWORD=$mongo_app_password
MONGO_URI=$mongo_uri
BEDROCK_AWS_DEFAULT_REGION=$aws_region
BEDROCK_AWS_MODELS=eu.anthropic.claude-haiku-4-5-20251001-v1:0,eu.anthropic.claude-sonnet-5,eu.anthropic.claude-opus-5,eu.amazon.nova-micro-v1:0,eu.amazon.nova-lite-v1:0,eu.amazon.nova-pro-v1:0
GOOGLE_KEY=$google_key
EOF

install -m 600 "$tmp_file" "$env_file"
printf 'Rendered %s from AWS Secrets Manager.\n' "$env_file"
