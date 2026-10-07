# Terraform state backend

Terraform state is stored in a dedicated S3 bucket created by the isolated
`infrastructure/bootstrap` configuration. The bucket has versioning, S3-managed
server-side encryption, all public access blocked, bucket-owner-enforced object
ownership and a policy denying non-TLS requests.

The bootstrap and platform states are separate objects in that bucket:

```text
bootstrap/terraform.tfstate
platform/v0/terraform.tfstate
```

Both configurations use a dedicated DynamoDB lock table with the required
`LockID` primary key. The table is encrypted and uses on-demand billing.

## Human approval for infrastructure changes

Terraform application is intentionally separate from planning. The operator
must inspect the complete plan before any AWS mutation. The operator runs both
the plan and apply commands locally. Codex can analyse an output shared by the
operator, but never runs Terraform plan or apply on the operator's behalf.

After the remote backend is configured, create a reviewed plan from WSL:

```sh
./scripts/terraform-plan.sh
```

The command stores an ignored `.tfplan` file in `.terraform-plans`, displays
its full content and its SHA-256 fingerprint. Apply only that reviewed file:

```sh
./scripts/terraform-apply-plan.sh --plan .terraform-plans/platform-<timestamp>.tfplan
```

The apply script displays the plan again and requires the exact phrase
`APPLY <SHA-256>` typed interactively. A plan is refused if it was not created
under `.terraform-plans`. Never use `terraform apply` directly for the
platform configuration.

For the initial migration, use a local AWS profile that has been explicitly
authorized to create the state backend. For routine platform operations after
the dedicated identity is installed, use `librechat-user` as documented in
[`librechat-user.md`](librechat-user.md). Check the active identity before any
state operation:

```sh
aws sts get-caller-identity --profile librechat-user
```

The one-time bootstrap script first shows the protected-bucket plan through a
locally held bootstrap state and requires `APPLY_BOOTSTRAP` typed
interactively. It then creates an ignored backend configuration from the
tracked template and migrates that bootstrap state and the existing platform
state to S3. Do not delete the existing local state files manually. Terraform
preserves a local backup during migration.
