# LibreChat runtime

This directory is the V0 runtime stack. Caddy is the only service with host
ports. LibreChat has outbound network access for Bedrock and Gemini but no
published port. MongoDB is isolated on a dedicated internal network and has no
published port. The supported database is MongoDB 7.0.41, pinned by digest.

Copy `.env.example` to `.env` only on the EC2 instance after the bootstrap
script has retrieved the values from AWS Secrets Manager. The resulting `.env`
file is deliberately ignored by Git.

`ALLOW_REGISTRATION` is `false` by default. For a fresh instance, set it to
`true` only long enough to register the initial local account. LibreChat assigns
that first account the administrator role. Set it back to `false`, then restart
the `librechat` service. Additional accounts should be created through the
application's supported administration flow.

Before first startup, the chosen DNS name must resolve to the EC2 Elastic IP so
that Caddy can obtain and renew its TLS certificate. Replace the floating
LibreChat image tag by the validated immutable digest before production use.

Persistent application directories are mounted from `RUNTIME_DATA_ROOT` on the
EC2 EBS volume. They include the MongoDB data, Caddy certificates and LibreChat
uploads. They are intentionally not anonymous Docker volumes.

Run `scripts/deploy-librechat-on-ec2.sh` as the repository owner, without
`sudo`. The script uses `sudo` only for Docker and runtime-directory operations
that require elevated rights. Launching the full script with `sudo` would make
Git metadata owned by `root`.

For a blank EC2, run the stack on the target host with:

```sh
docker compose --env-file .env -f compose.yaml up -d
```
