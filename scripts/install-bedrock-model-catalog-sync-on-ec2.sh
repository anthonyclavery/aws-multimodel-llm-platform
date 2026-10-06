#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if [[ $EUID -ne 0 ]]; then
  printf '%s\n' 'Run this script with sudo to install the EC2 startup synchronization service.' >&2
  exit 2
fi

install -m 0755 "$repo_root/scripts/sync-bedrock-model-catalog.sh" /usr/local/sbin/aws-multimodel-sync-bedrock-model-catalog
install -m 0755 "$repo_root/scripts/sync-bedrock-model-catalog-on-ec2.sh" /usr/local/sbin/aws-multimodel-sync-bedrock-model-catalog-on-ec2
install -m 0644 /dev/stdin /etc/systemd/system/aws-multimodel-bedrock-model-catalog.service <<'UNIT'
[Unit]
Description=Synchronize the LibreChat Bedrock model catalog from AWS
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/aws-multimodel-sync-bedrock-model-catalog-on-ec2

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable aws-multimodel-bedrock-model-catalog.service
