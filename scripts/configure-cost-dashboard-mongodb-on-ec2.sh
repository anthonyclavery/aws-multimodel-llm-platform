#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
env_file="$repo_root/docker/librechat/.env"
compose_file="$repo_root/docker/librechat/compose.yaml"
compose_project='aws-multimodel-llm-platform-v0'
secret_id='aws-multimodel-llm-platform-v0/cost-dashboard-credentials'
aws_region='eu-central-1'

[[ -f "$env_file" ]] || { printf '%s\n' 'Runtime .env is absent. Run the reviewed bootstrap first.' >&2; exit 1; }
for command in aws jq docker; do
  command -v "$command" >/dev/null || { printf 'Missing required command: %s\n' "$command" >&2; exit 1; }
done

secret_json=$(aws secretsmanager get-secret-value --region "$aws_region" --secret-id "$secret_id" --query SecretString --output text)
dashboard_username=$(jq -er '.mongo_username | strings | select(test("^[A-Za-z0-9_-]{3,64}$"))' <<<"$secret_json")
dashboard_password=$(jq -er '.mongo_password | strings | select(length >= 32)' <<<"$secret_json")
root_username=$(sudo sed -n 's/^MONGO_INITDB_ROOT_USERNAME=//p' "$env_file")
root_password=$(sudo sed -n 's/^MONGO_INITDB_ROOT_PASSWORD=//p' "$env_file")
[[ -n "$root_username" && -n "$root_password" ]] || { printf '%s\n' 'MongoDB root credentials are absent from runtime .env.' >&2; exit 1; }
trap 'unset secret_json dashboard_username dashboard_password root_username root_password' EXIT

read -r -p "Type CONFIGURE COST DASHBOARD to grant read-only access to the dashboard: " confirmation
[[ "$confirmation" == 'CONFIGURE COST DASHBOARD' ]] || { printf '%s\n' 'MongoDB was not changed.'; exit 0; }

sudo docker compose -p "$compose_project" --env-file "$env_file" -f "$compose_file" exec -T \
  -e COST_DASHBOARD_MONGO_USERNAME="$dashboard_username" \
  -e COST_DASHBOARD_MONGO_PASSWORD="$dashboard_password" \
  mongodb mongosh --quiet --username "$root_username" --password "$root_password" --authenticationDatabase admin LibreChat <<'EOF'
const username = process.env.COST_DASHBOARD_MONGO_USERNAME;
const password = process.env.COST_DASHBOARD_MONGO_PASSWORD;
const role = [{ role: 'read', db: 'LibreChat' }];
if (db.getUser(username)) {
  db.updateUser(username, { pwd: password, roles: role });
} else {
  db.createUser({ user: username, pwd: password, roles: role });
}
EOF

printf '%s\n' 'The cost dashboard MongoDB account now has read-only access to LibreChat.'
