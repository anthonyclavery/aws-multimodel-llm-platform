#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
iam_file="$repo_root/infrastructure/terraform/iam.tf"
env_template="$repo_root/docker/librechat/.env.example"
deploy_script="$repo_root/scripts/deploy-librechat-on-ec2.sh"
catalog_sync="$repo_root/scripts/sync-bedrock-model-catalog.sh"
catalog_installer="$repo_root/scripts/install-bedrock-model-catalog-sync-on-ec2.sh"

if grep -Eq '^BEDROCK_AWS_MODELS=' "$env_template"; then
  printf '%s\n' 'BEDROCK_AWS_MODELS must not be hard-coded in the account-neutral environment template.' >&2
  exit 1
fi

for required_file in "$catalog_sync" "$catalog_installer"; do
  if [[ ! -x "$required_file" ]]; then
    printf 'Bedrock runtime catalog script is missing or not executable: %s\n' "$required_file" >&2
    exit 1
  fi
done

if ! grep -Fq 'sync-bedrock-model-catalog.sh' "$deploy_script"; then
  printf '%s\n' 'The deployment script must synchronize the Bedrock runtime catalog.' >&2
  exit 1
fi

for expected in \
  'arn:aws:bedrock:*::foundation-model/*' \
  'arn:aws:bedrock:*:*:inference-profile/*' \
  'project/default' \
  'bedrock:ListFoundationModels' \
  'bedrock:ListInferenceProfiles'; do
  if ! grep -Fq -- "$expected" "$iam_file"; then
    printf 'Missing Bedrock serverless invocation resource: %s\n' "$expected" >&2
    exit 1
  fi
done

if grep -Eq 'aws-marketplace:|marketplace/model-endpoint|sagemaker:' "$iam_file"; then
  printf '%s\n' 'The EC2 role must not subscribe to, deploy or invoke Bedrock Marketplace models.' >&2
  exit 1
fi

temporary_dir=$(mktemp -d)
trap 'rm -rf "$temporary_dir"' EXIT
mock_bin="$temporary_dir/mock-bin"
runtime_env="$temporary_dir/runtime.env"
mkdir "$mock_bin"
cp "$env_template" "$runtime_env"

cat >"$mock_bin/aws" <<'MOCK_AWS'
#!/usr/bin/env bash
set -euo pipefail

case " $* " in
  *' list-foundation-models '*)
    printf '%s\n' '{"modelSummaries":[{"modelId":"cohere.command-r-v1:0","modelLifecycle":{"status":"ACTIVE"},"outputModalities":["TEXT"],"responseStreamingSupported":true,"inferenceTypesSupported":["ON_DEMAND"]},{"modelId":"amazon.nova-pro-v1:0","modelLifecycle":{"status":"ACTIVE"},"outputModalities":["TEXT"],"responseStreamingSupported":true,"inferenceTypesSupported":["INFERENCE_PROFILE"]},{"modelId":"openai.gpt-5.6-luna","modelLifecycle":{"status":"ACTIVE"},"outputModalities":["TEXT"],"responseStreamingSupported":true,"inferenceTypesSupported":["INFERENCE_PROFILE"]},{"modelId":"amazon.titan-embed-text-v2:0","modelLifecycle":{"status":"ACTIVE"},"outputModalities":["EMBEDDING"],"responseStreamingSupported":true,"inferenceTypesSupported":["ON_DEMAND"]}]}'
    ;;
  *' list-inference-profiles '*)
    printf '%s\n' '{"inferenceProfileSummaries":[{"inferenceProfileId":"eu.amazon.nova-pro-v1:0","status":"ACTIVE","models":[{"modelArn":"arn:aws:bedrock:eu-central-1::foundation-model/amazon.nova-pro-v1:0"}]},{"inferenceProfileId":"global.openai.gpt-5.6-luna","status":"ACTIVE","models":[{"modelArn":"arn:aws:bedrock:::foundation-model/openai.gpt-5.6-luna"},{"modelArn":"arn:aws:bedrock:eu-central-1::foundation-model/openai.gpt-5.6-luna"}]},{"inferenceProfileId":"global.amazon.titan-embed-text-v2:0","status":"ACTIVE","models":[{"modelArn":"arn:aws:bedrock:::foundation-model/amazon.titan-embed-text-v2:0"}]}]}'
    ;;
  *)
    printf 'Unexpected AWS CLI command: %s\n' "$*" >&2
    exit 1
    ;;
esac
MOCK_AWS
chmod 0755 "$mock_bin/aws"

PATH="$mock_bin:$PATH" "$catalog_sync" --env-file "$runtime_env" --aws-region eu-central-1
expected_models='cohere.command-r-v1:0,eu.amazon.nova-pro-v1:0,global.openai.gpt-5.6-luna'
actual_models=$(sed -n 's/^BEDROCK_AWS_MODELS=//p' "$runtime_env")
if [[ "$actual_models" != "$expected_models" ]]; then
  printf 'Unexpected generated Bedrock runtime catalog: %s\n' "$actual_models" >&2
  exit 1
fi
