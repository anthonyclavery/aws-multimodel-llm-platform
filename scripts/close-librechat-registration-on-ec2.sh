#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
runtime_dir="$repo_root/docker/librechat"
compose_file="$runtime_dir/compose.yaml"
env_file="$runtime_dir/.env"
compose_project='aws-multimodel-llm-platform-v0'

if [[ $EUID -ne 0 ]]; then
  printf '%s\n' 'Run this script with sudo.' >&2
  exit 2
fi

for command in docker git sed; do
  command -v "$command" >/dev/null || {
    printf 'Missing required command: %s\n' "$command" >&2
    exit 1
  }
done

cd "$repo_root"
if ! git -c safe.directory="$repo_root" diff --quiet || ! git -c safe.directory="$repo_root" diff --cached --quiet; then
  printf '%s\n' 'Repository has tracked local changes. Resolve them before changing registration.' >&2
  exit 1
fi

[[ -f "$env_file" ]] || { printf '%s\n' 'Runtime .env is absent.' >&2; exit 1; }
grep -qx 'ALLOW_REGISTRATION=true' "$env_file" || {
  printf '%s\n' 'Registration is already closed or the .env file has an unexpected value.' >&2
  exit 1
}

commit=$(git -c safe.directory="$repo_root" rev-parse --short HEAD)
printf 'Type CLOSE REGISTRATION %s to disable public sign-up: ' "$commit"
read -r confirmation
if [[ "$confirmation" != "CLOSE REGISTRATION $commit" ]]; then
  printf '%s\n' 'Operation cancelled. Registration remains unchanged.'
  exit 0
fi

sed -i 's/^ALLOW_REGISTRATION=true$/ALLOW_REGISTRATION=false/' "$env_file"
compose=(docker compose -p "$compose_project" --env-file "$env_file" -f "$compose_file")
"${compose[@]}" config --quiet
"${compose[@]}" up -d --no-deps librechat
printf '%s\n' 'Public registration is disabled.'
