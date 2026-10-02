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

The `/cost` route is a separate, HTTP Basic Auth protected dashboard. It shows
an immediate token-based estimate by model and an AWS Cost Explorer total for
Amazon Bedrock. The estimate is scoped to LibreChat transactions. Cost Explorer
is account-level consolidated billing data, can include another account workload
that uses Bedrock, and can lag. Google Gemini is therefore shown as an estimate
only. Its credentials and its read-only MongoDB account are rendered from a
dedicated Secrets Manager secret.

The price catalogue is refreshed at every EC2 startup, not during a normal
deployment. A systemd one-shot service calls the AWS Price List API for Amazon
Nova in EU (Frankfurt), reads the Google Gemini paid-tier publication, verifies
the AWS Bedrock Claude publication, writes the resulting catalogue on the EBS
volume, then recreates only the cost dashboard. A failed refresh does not block
LibreChat or Caddy and keeps the last valid catalogue. Claude 5 price amounts
remain a reviewed baseline because AWS does not currently expose those values
through the Price List API; the dashboard clearly keeps AWS Cost Explorer as the
authoritative Bedrock billing total.

After the approved Terraform apply has created that secret and granted Cost
Explorer read access to the EC2 role, initialize it locally with
`scripts/initialize-cost-dashboard-secret.sh`. On EC2, run
`scripts/configure-cost-dashboard-mongodb-on-ec2.sh` once, review its explicit
confirmation prompt, then use the normal reviewed deployment script. No domain,
password or secret value belongs in the repository.

The normal deployment installs and enables the startup service but does not run
the catalogue refresh itself. It will run automatically after the next EC2
start. Its result can be checked on EC2 with:

```sh
sudo systemctl status aws-multimodel-cost-pricing.service
```

To upgrade LibreChat, pass an approved, immutable image digest to the normal
deployment script. The script shows the selected image and updates the ignored
runtime `.env` only after the explicit deployment confirmation:

```sh
./scripts/deploy-librechat-on-ec2.sh --image registry.example/librechat@sha256:<digest>
```

For a blank EC2, run the stack on the target host with:

```sh
docker compose --env-file .env -f compose.yaml up -d
```
