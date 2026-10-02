#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

[[ $EUID -eq 0 ]] || { printf '%s\\n' 'Run this installer with sudo.' >&2; exit 1; }
[[ -f "$repo_root/scripts/sync-cost-pricing-on-ec2.sh" ]] || { printf '%s\\n' 'The cost pricing startup script is absent.' >&2; exit 1; }

install -m 0755 "$repo_root/scripts/sync-cost-pricing-on-ec2.sh" /usr/local/sbin/aws-multimodel-sync-cost-pricing
install -m 0644 /dev/stdin /etc/systemd/system/aws-multimodel-cost-pricing.service <<'UNIT'
[Unit]
Description=Synchronize LibreChat cost prices after EC2 startup
Wants=network-online.target
After=network-online.target docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/aws-multimodel-sync-cost-pricing

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable aws-multimodel-cost-pricing.service
printf '%s\\n' 'Cost pricing synchronization is enabled for the next EC2 startup.'
