#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' "Usage: sudo $0 --domain <DNS name> --acme-email <email> --image <immutable digest> [--aws-region <region>]"
}

domain=''
acme_email=''
aws_region='eu-central-1'
librechat_image=''

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain) domain=${2:?}; shift 2 ;;
    --acme-email) acme_email=${2:?}; shift 2 ;;
    --aws-region) aws_region=${2:?}; shift 2 ;;
    --image) librechat_image=${2:?}; shift 2 ;;
    --help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

if [[ $EUID -ne 0 || -z "$domain" || -z "$acme_email" || "$librechat_image" != *@sha256:* ]]; then
  printf '%s\n' 'An immutable LibreChat image digest is required with --image.' >&2
  usage >&2
  exit 2
fi

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

apt-get update
apt-get install -y ca-certificates curl gnupg jq awscli
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
printf '%s\n' \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

"$repo_root/scripts/render-librechat-env.sh" \
  --domain "$domain" \
  --acme-email "$acme_email" \
  --aws-region "$aws_region" \
  --image "$librechat_image"

cd "$repo_root/docker/librechat"
docker compose --env-file .env -f compose.yaml pull
docker compose --env-file .env -f compose.yaml up -d
docker compose --env-file .env -f compose.yaml ps
