#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' "Usage: $0 --plan <path to a reviewed plan file>"
}

plan_path=''
while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan) plan_path=${2:?}; shift 2 ;;
    --help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

[[ -n "$plan_path" ]] || { usage >&2; exit 2; }

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
plans_dir="$repo_root/.terraform-plans"
terraform_dir="$repo_root/infrastructure/terraform"
plan_path=$(realpath "$plan_path")
plans_dir=$(realpath "$plans_dir")

case "$plan_path" in
  "$plans_dir"/*.tfplan) ;;
  *)
    printf '%s\n' 'The plan must be a reviewed .tfplan file created in .terraform-plans.' >&2
    exit 2
    ;;
esac

[[ -f "$plan_path" ]] || { printf '%s\n' 'Plan file not found.' >&2; exit 2; }

plan_sha=$(sha256sum "$plan_path" | awk '{print $1}')
terraform -chdir="$terraform_dir" show -no-color "$plan_path"
printf '\nTo apply this exact plan, type: APPLY %s\n> ' "$plan_sha"
read -r confirmation

if [[ "$confirmation" != "APPLY $plan_sha" ]]; then
  printf '%s\n' 'Apply cancelled. No AWS resource was changed.'
  exit 0
fi

terraform -chdir="$terraform_dir" apply -input=false "$plan_path"
