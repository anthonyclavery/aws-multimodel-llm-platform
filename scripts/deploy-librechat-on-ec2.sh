#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' "Usage: $0 [--branch <Git branch>] [--image <immutable image digest>]"
}

branch='main'
requested_image=''
compose_project='aws-multimodel-llm-platform-v0'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch) branch=${2:?}; shift 2 ;;
    --image) requested_image=${2:?}; shift 2 ;;
    --help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
compose_file="$repo_root/docker/librechat/compose.yaml"
env_file="$repo_root/docker/librechat/.env"

command -v git >/dev/null || { printf '%s\n' 'Git is required.' >&2; exit 1; }
command -v docker >/dev/null || { printf '%s\n' 'Docker is required.' >&2; exit 1; }

cd "$repo_root"
if ! git diff --quiet || ! git diff --cached --quiet; then
  printf '%s\n' 'Repository has local changes. Commit, stash or discard them before deployment.' >&2
  exit 1
fi

git fetch --prune origin "$branch"
git switch "$branch"
git merge --ff-only "origin/$branch"

if [[ ! -f "$env_file" ]]; then
  printf '%s\n' 'Runtime .env is absent. Run the initial bootstrap with reviewed domain, ACME email and image digest first.' >&2
  exit 1
fi

image=$(sudo sed -n 's/^LIBRECHAT_IMAGE=//p' "$env_file")
if [[ -n "$requested_image" ]]; then
  if [[ ! "$requested_image" =~ ^[a-z0-9][a-z0-9./:_@-]*@sha256:[a-f0-9]{64}$ ]]; then
    printf '%s\n' 'The requested LibreChat image must be a lowercase immutable image digest.' >&2
    exit 2
  fi
  image="$requested_image"
fi
if [[ "$image" != *@sha256:* ]]; then
  printf '%s\n' 'LIBRECHAT_IMAGE must use an immutable digest before deployment.' >&2
  exit 1
fi

data_root=$(sudo sed -n 's/^RUNTIME_DATA_ROOT=//p' "$env_file")
if [[ "$data_root" != '/opt/aws-multimodel-llm-platform/data' ]]; then
  printf '%s\n' 'RUNTIME_DATA_ROOT must be the reviewed EC2 EBS data directory.' >&2
  exit 1
fi
sudo install -d -m 0750 -o 1000 -g 1000 \
  "$data_root/librechat/app-data" \
  "$data_root/librechat/uploads" \
  "$data_root/librechat/logs" \
  "$data_root/librechat/images"

while IFS= read -r container_id; do
  [[ -z "$container_id" ]] && continue
  container_project=$(sudo docker inspect --format '{{ index .Config.Labels "com.docker.compose.project" }}' "$container_id")
  if [[ "$container_project" != "$compose_project" ]]; then
    printf 'HTTPS port is occupied by unmanaged container %s (Compose project: %s). Migration must be planned separately.\n' \
      "$container_id" "${container_project:-none}" >&2
    exit 1
  fi
done < <(sudo docker ps -q --filter publish=443)

compose=(sudo docker compose -p "$compose_project" --env-file "$env_file" -f "$compose_file")
"${compose[@]}" config --quiet

commit=$(git rev-parse --short HEAD)
printf 'Repository synchronized at %s. Image: %s\n' "$commit" "$image"
printf 'Type DEPLOY %s to pull and apply this Compose revision: ' "$commit"
read -r confirmation
if [[ "$confirmation" != "DEPLOY $commit" ]]; then
  printf '%s\n' 'Deployment cancelled. Containers were not changed.'
  exit 0
fi

if [[ -n "$requested_image" ]]; then
  sudo sed -i "s|^LIBRECHAT_IMAGE=.*$|LIBRECHAT_IMAGE=$requested_image|" "$env_file"
fi

"${compose[@]}" pull
"${compose[@]}" up -d
"${compose[@]}" ps
