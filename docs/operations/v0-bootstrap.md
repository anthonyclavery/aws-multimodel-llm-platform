# V0 deployment bootstrap

The EC2 instance has an IAM role that can read the three platform secrets. No
AWS access key is written to the host or to the runtime environment.

Initialize the three existing AWS Secrets Manager secrets from WSL before
running a first deployment. The helper creates random MongoDB and LibreChat
values locally, prompts without echoing for the Gemini API key, and refuses to
overwrite an existing secret value:

```sh
./scripts/initialize-v0-secrets.sh --profile aws-multimodel-llm
```

The secret values are never committed to Git or printed to the terminal. The
EC2 role has read-only access to these values.

Clone a reviewed revision of this repository onto the EC2 host, verify that the
public DNS name already resolves to the instance Elastic IP, then run:

```sh
sudo scripts/bootstrap-v0.sh \
  --domain chat.example.com \
  --acme-email ops@example.com \
  --image registry.librechat.ai/librechat-ai/librechat-dev@sha256:replace-with-a-validated-digest
```

The script is safe to rerun for package installation, secret rendering and
Compose reconciliation. It does not recreate MongoDB users once the persistent
MongoDB volume exists. Do not change the MongoDB application password without a
coordinated credential rotation.

For the initial administrator only, edit the generated runtime `.env` on the
host, change `ALLOW_REGISTRATION` to `true`, restart LibreChat, create the
first local account, then restore `ALLOW_REGISTRATION=false` and restart it.

## Daily shutdown, backup and local start

Terraform schedules an EC2 `StopInstances` request every day at 22:00 in the
`Europe/Paris` time zone. It never starts the instance. The EBS-backed EC2
instance is backed up every day at 01:00 in the same time zone and each
recovery point is retained for 30 days.

From WSL, start the instance from the local repository with:

```sh
./scripts/start-v0-instance.sh
```

The script uses the configured AWS CLI profile, locates the sole non-terminated
instance by its Terraform tags, starts it only when needed, waits for the
`running` state and displays its Elastic IP and SSM command.
