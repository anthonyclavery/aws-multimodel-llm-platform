#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' "Usage: $0 [--profile <AWS profile>] [--region <AWS region>] [--project-name <name>] [--environment <name>]"
}

aws_profile='aws-multimodel-llm'
aws_region='eu-central-1'
project_name='aws-multimodel-llm-platform'
environment_name='v0'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) aws_profile=${2:?}; shift 2 ;;
    --region) aws_region=${2:?}; shift 2 ;;
    --project-name) project_name=${2:?}; shift 2 ;;
    --environment) environment_name=${2:?}; shift 2 ;;
    --help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

command -v aws >/dev/null || {
  printf '%s\n' 'The AWS CLI is required.' >&2
  exit 1
}

aws_args=(--profile "$aws_profile" --region "$aws_region")
instance_ids=$(aws ec2 describe-instances "${aws_args[@]}" \
  --filters \
    "Name=tag:Project,Values=$project_name" \
    "Name=tag:Environment,Values=$environment_name" \
    'Name=instance-state-name,Values=pending,running,stopping,stopped' \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text)

read -r -a instance_list <<<"$instance_ids"
if [[ ${#instance_list[@]} -ne 1 ]]; then
  printf 'Expected one non-terminated instance tagged Project=%s and Environment=%s, found: %s\n' \
    "$project_name" "$environment_name" "${instance_ids:-none}" >&2
  exit 1
fi

instance_id=${instance_list[0]}
state=$(aws ec2 describe-instances "${aws_args[@]}" \
  --instance-ids "$instance_id" \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text)

case "$state" in
  running)
    printf 'Instance %s is already running.\n' "$instance_id"
    ;;
  pending)
    printf 'Instance %s is starting. Waiting for it to run.\n' "$instance_id"
    aws ec2 wait instance-running "${aws_args[@]}" --instance-ids "$instance_id"
    ;;
  stopped)
    printf 'Starting instance %s.\n' "$instance_id"
    aws ec2 start-instances "${aws_args[@]}" --instance-ids "$instance_id" >/dev/null
    aws ec2 wait instance-running "${aws_args[@]}" --instance-ids "$instance_id"
    ;;
  stopping)
    printf 'Instance %s is stopping. Waiting until it can be started.\n' "$instance_id"
    aws ec2 wait instance-stopped "${aws_args[@]}" --instance-ids "$instance_id"
    aws ec2 start-instances "${aws_args[@]}" --instance-ids "$instance_id" >/dev/null
    aws ec2 wait instance-running "${aws_args[@]}" --instance-ids "$instance_id"
    ;;
  *)
    printf 'Instance %s is in unsupported state %s.\n' "$instance_id" "$state" >&2
    exit 1
    ;;
esac

elastic_ip=$(aws ec2 describe-addresses "${aws_args[@]}" \
  --filters "Name=instance-id,Values=$instance_id" \
  --query 'Addresses[0].PublicIp' \
  --output text)

printf 'Instance %s is running. Elastic IP: %s\n' "$instance_id" "$elastic_ip"
printf 'Open an SSM shell with:\naws ssm start-session --target %s --profile %s --region %s\n' \
  "$instance_id" "$aws_profile" "$aws_region"
