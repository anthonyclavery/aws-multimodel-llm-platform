#!/usr/bin/env bash
set -euo pipefail

repo_root='/home/ssm-user/projects/aws-multimodel-llm-platform'
compose_project='aws-multimodel-llm-platform-v0'
compose_file="$repo_root/docker/librechat/compose.yaml"
env_file="$repo_root/docker/librechat/.env"

[[ $EUID -eq 0 ]] || { printf '%s\\n' 'This startup service must run as root.' >&2; exit 1; }
[[ -f "$compose_file" && -f "$env_file" ]] || { printf '%s\\n' 'The reviewed LibreChat runtime is not installed yet.' >&2; exit 1; }

data_root=$(sed -n 's/^RUNTIME_DATA_ROOT=//p' "$env_file")
[[ "$data_root" == '/opt/aws-multimodel-llm-platform/data' ]] || { printf '%s\\n' 'RUNTIME_DATA_ROOT is not the reviewed EBS directory.' >&2; exit 1; }
install -d -m 0750 -o 1000 -g 1000 "$data_root/cost-dashboard"

compose=(docker compose -p "$compose_project" --env-file "$env_file" -f "$compose_file")
image_id=$("${compose[@]}" images -q cost-dashboard)
[[ -n "$image_id" ]] || { printf '%s\\n' 'The cost dashboard image is absent. It will be synchronized after the first reviewed deployment.' >&2; exit 1; }

docker run --rm --network host --read-only --tmpfs /tmp \
  --security-opt no-new-privileges:true --cap-drop ALL \
  -e COST_DASHBOARD_PRICING_OUTPUT=/var/lib/cost-dashboard/pricing.json \
  -v "$data_root/cost-dashboard:/var/lib/cost-dashboard" \
  "$image_id" node sync-pricing.mjs

chown 1000:1000 "$data_root/cost-dashboard/pricing.json"
chmod 0640 "$data_root/cost-dashboard/pricing.json"

"${compose[@]}" up -d --no-deps --force-recreate cost-dashboard
