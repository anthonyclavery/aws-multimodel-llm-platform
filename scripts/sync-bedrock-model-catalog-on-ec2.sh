#!/usr/bin/env bash
set -euo pipefail

repo_root='/home/ssm-user/projects/aws-multimodel-llm-platform'
compose_project='aws-multimodel-llm-platform-v0'
compose_file="$repo_root/docker/librechat/compose.yaml"
env_file="$repo_root/docker/librechat/.env"

if [[ $EUID -ne 0 ]]; then
  printf '%s\n' 'Run this script with sudo so it can update the protected runtime environment.' >&2
  exit 2
fi

if [[ ! -f "$env_file" ]]; then
  printf '%s\n' 'Runtime .env is absent; Bedrock model catalog synchronization skipped.' >&2
  exit 0
fi

if ! "$repo_root/scripts/sync-bedrock-model-catalog.sh" --env-file "$env_file"; then
  printf '%s\n' 'Bedrock model catalog synchronization failed; the last valid runtime catalog was retained.' >&2
  exit 0
fi

docker compose -p "$compose_project" --env-file "$env_file" -f "$compose_file" up -d --no-deps librechat
