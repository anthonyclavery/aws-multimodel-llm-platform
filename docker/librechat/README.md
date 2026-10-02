# LibreChat runtime

This directory is the V0 runtime stack. Caddy is the only service with host
ports. LibreChat and MongoDB share an internal Docker network, and MongoDB has
no published port.

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

Run the stack on the target host with:

```sh
docker compose --env-file .env -f compose.yaml up -d
```
