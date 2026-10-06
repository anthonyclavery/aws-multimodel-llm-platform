#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' "Usage: $0 --env-file <absolute .env path> [--aws-region <region>]"
}

env_file=''
aws_region=''

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-file) env_file=${2:?}; shift 2 ;;
    --aws-region) aws_region=${2:?}; shift 2 ;;
    --help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

if [[ -z "$env_file" || "$env_file" != /* || ! -f "$env_file" ]]; then
  printf '%s\n' 'An existing absolute runtime .env file is required.' >&2
  usage >&2
  exit 2
fi

for command in aws jq awk mktemp install; do
  command -v "$command" >/dev/null || {
    printf 'Missing required command: %s\n' "$command" >&2
    exit 1
  }
done

if [[ -z "$aws_region" ]]; then
  aws_region=$(sed -n 's/^BEDROCK_AWS_DEFAULT_REGION=//p' "$env_file")
fi
if [[ -z "$aws_region" ]]; then
  printf '%s\n' 'BEDROCK_AWS_DEFAULT_REGION is required in the runtime .env file.' >&2
  exit 1
fi

models=$(
  {
    aws bedrock list-foundation-models \
      --region "$aws_region" \
      --output json
    aws bedrock list-inference-profiles \
      --region "$aws_region" \
      --type-equals SYSTEM_DEFINED \
      --output json
  } | jq -sr '
  def active_text_streaming_model:
    (.modelLifecycle.status // "ACTIVE") == "ACTIVE"
    and ((.outputModalities // []) | index("TEXT") != null)
    and (.responseStreamingSupported == true);

  [ .[0].modelSummaries[]
    | select(active_text_streaming_model)
  ] as $chat_models
  | ($chat_models | map({ key: .modelId, value: true }) | from_entries) as $chat_model_ids
  | [ $chat_models[]
      | select((.inferenceTypesSupported // []) | index("ON_DEMAND") != null)
      | .modelId
    ] as $direct_model_ids
  | [ .[1].inferenceProfileSummaries[]
      | select(.status == "ACTIVE")
      | [ .models[]?.modelArn
          | capture("foundation-model/(?<model_id>.+)$").model_id
        ] as $underlying_model_ids
      | select(($underlying_model_ids | length) > 0)
      | select(all($underlying_model_ids[]; $chat_model_ids[.] == true))
      | .inferenceProfileId
    ] as $profile_ids
  | ($direct_model_ids + $profile_ids | unique | sort)
  | .[]
  '
)

if [[ -z "$models" ]]; then
  printf 'No active text streaming Bedrock models were discovered in %s. The existing runtime catalog was retained.\n' "$aws_region" >&2
  exit 1
fi

if ! grep -Eq '^[A-Za-z0-9._:-]+$' <<<"$models"; then
  printf '%s\n' 'The Bedrock catalog contains an unexpected model identifier.' >&2
  exit 1
fi

model_list=$(paste -sd, <<<"$models")
temporary_env_file=$(mktemp "${env_file}.XXXXXX")
trap 'rm -f "$temporary_env_file"' EXIT

awk -v model_list="$model_list" '
  !/^BEDROCK_AWS_MODELS=/ { print }
  END { print "BEDROCK_AWS_MODELS=" model_list }
' "$env_file" >"$temporary_env_file"

install -m 600 "$temporary_env_file" "$env_file"
printf 'Synchronized %s Bedrock text streaming model identifiers for %s.\n' "$(wc -l <<<"$models")" "$aws_region"
