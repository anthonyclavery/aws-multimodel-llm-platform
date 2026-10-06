#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
iam_file="$repo_root/infrastructure/terraform/iam.tf"
env_template="$repo_root/docker/librechat/.env.example"
env_renderer="$repo_root/scripts/render-librechat-env.sh"
deploy_script="$repo_root/scripts/deploy-librechat-on-ec2.sh"

if grep -Eq '^BEDROCK_AWS_MODELS=' "$env_template" "$env_renderer"; then
  printf '%s\n' 'BEDROCK_AWS_MODELS must remain unset so LibreChat can expose its known compatible serverless models.' >&2
  exit 1
fi

if ! grep -Fq 'BEDROCK_AWS_MODELS=/d' "$deploy_script"; then
  printf '%s\n' 'The deployment script must remove the legacy Bedrock model allow-list from existing runtime files.' >&2
  exit 1
fi

for expected in \
  'arn:aws:bedrock:*::foundation-model/*' \
  'arn:aws:bedrock:*:*:inference-profile/*'; do
  if ! grep -Fq -- "$expected" "$iam_file"; then
    printf 'Missing Bedrock serverless invocation resource: %s\n' "$expected" >&2
    exit 1
  fi
done

if grep -Eq 'aws-marketplace:|marketplace/model-endpoint|sagemaker:' "$iam_file"; then
  printf '%s\n' 'The EC2 role must not subscribe to, deploy or invoke Bedrock Marketplace models.' >&2
  exit 1
fi
