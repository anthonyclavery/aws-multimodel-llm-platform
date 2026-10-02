#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' "Usage: sudo $0 --acme-email <email> --image <immutable digest> [--domain librechat.anthonyclavery.fr] [--aws-region eu-central-1] [--open-registration]"
}

domain='librechat.anthonyclavery.fr'
acme_email=''
aws_region='eu-central-1'
librechat_image=''
open_registration='false'
data_root='/opt/aws-multimodel-llm-platform/data'
compose_project='aws-multimodel-llm-platform-v0'
legacy_containers=(multimodel-caddy multimodel-librechat multimodel-mongodb)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain) domain=${2:?}; shift 2 ;;
    --acme-email) acme_email=${2:?}; shift 2 ;;
    --aws-region) aws_region=${2:?}; shift 2 ;;
    --image) librechat_image=${2:?}; shift 2 ;;
    --open-registration) open_registration='true'; shift ;;
    --help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

if [[ $EUID -ne 0 || -z "$acme_email" || "$librechat_image" != *@sha256:* ]]; then
  printf '%s\n' 'Root access, an ACME email and an immutable LibreChat image digest are required.' >&2
  usage >&2
  exit 2
fi

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
runtime_dir="$repo_root/docker/librechat"
compose_file="$runtime_dir/compose.yaml"
env_file="$runtime_dir/.env"

for command in aws docker git jq; do
  command -v "$command" >/dev/null || {
    printf 'Missing required command: %s\n' "$command" >&2
    exit 1
  }
done

cd "$repo_root"
if ! git -c safe.directory="$repo_root" diff --quiet || ! git -c safe.directory="$repo_root" diff --cached --quiet; then
  printf '%s\n' 'Repository has tracked local changes. Resolve them before rebuilding.' >&2
  exit 1
fi

git -c safe.directory="$repo_root" fetch --prune origin main
git -c safe.directory="$repo_root" switch main
git -c safe.directory="$repo_root" merge --ff-only origin/main

legacy_ids=()
for container in "${legacy_containers[@]}"; do
  if docker inspect "$container" >/dev/null 2>&1; then
    legacy_ids+=("$(docker inspect --format '{{.Id}}' "$container")")
  fi
done

while IFS= read -r container_id; do
  [[ -z "$container_id" ]] && continue
  allowed='false'
  for legacy_id in "${legacy_ids[@]}"; do
    [[ "$container_id" == "$legacy_id" ]] && allowed='true'
  done
  if [[ "$allowed" != 'true' ]]; then
    container_name=$(docker inspect --format '{{.Name}}' "$container_id")
    printf 'HTTPS port is occupied by non-LibreChat container %s. Rebuild aborted.\n' "$container_name" >&2
    exit 1
  fi
done < <(docker ps -q --filter publish=443)

legacy_configdb_volume=''
if docker inspect multimodel-mongodb >/dev/null 2>&1; then
  legacy_configdb_volume=$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/data/configdb"}}{{.Name}}{{end}}{{end}}' multimodel-mongodb)
fi

commit=$(git -c safe.directory="$repo_root" rev-parse --short HEAD)
printf '%s\n' "This permanently removes only the legacy multimodel containers, their MongoDB config volume and these LibreChat data directories:"
printf '  %s\n' "$data_root/mongodb" "$data_root/mongodb-configdb" "$data_root/caddy" "$data_root/librechat"
printf '%s\n' 'It does not modify AWS resources, the EC2 instance, the Elastic IP or any unrelated Docker container.'
printf 'Type RESET %s to create a blank LibreChat installation: ' "$commit"
read -r confirmation
if [[ "$confirmation" != "RESET $commit" ]]; then
  printf '%s\n' 'Rebuild cancelled. Nothing was changed.'
  exit 0
fi

for container in "${legacy_containers[@]}"; do
  if docker inspect "$container" >/dev/null 2>&1; then
    docker rm -f "$container"
  fi
done

if [[ -n "$legacy_configdb_volume" ]]; then
  docker volume rm "$legacy_configdb_volume"
fi

rm -rf -- "$data_root/mongodb" "$data_root/mongodb-configdb" "$data_root/caddy" "$data_root/librechat"
install -d -m 0700 \
  "$data_root/mongodb" \
  "$data_root/mongodb-configdb" \
  "$data_root/caddy/data" \
  "$data_root/caddy/config" \
  "$data_root/librechat/app-data" \
  "$data_root/librechat/uploads" \
  "$data_root/librechat/logs" \
  "$data_root/librechat/images"

"$repo_root/scripts/render-librechat-env.sh" \
  --domain "$domain" \
  --acme-email "$acme_email" \
  --aws-region "$aws_region" \
  --image "$librechat_image" \
  --runtime-data-root "$data_root" \
  --allow-registration "$open_registration"

compose=(docker compose -p "$compose_project" --env-file "$env_file" -f "$compose_file")
"${compose[@]}" config --quiet
"${compose[@]}" pull
"${compose[@]}" up -d
"${compose[@]}" ps

curl --fail --silent --show-error --retry 12 --retry-delay 5 \
  --resolve "$domain:443:127.0.0.1" "https://$domain/" >/dev/null
printf 'LibreChat is responding at https://%s/\n' "$domain"
if [[ "$open_registration" == 'true' ]]; then
  printf '%s\n' 'Registration is temporarily open. Create the initial account, then immediately run scripts/close-librechat-registration-on-ec2.sh.'
fi
