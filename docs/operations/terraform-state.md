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

From WSL, authenticate the AWS SSO profile, then migrate the existing local
states once:

```sh
aws sso login --profile aws-multimodel-llm
./scripts/bootstrap-terraform-state.sh
```

The script first creates the protected bucket through a locally held bootstrap
state. It then creates an ignored backend configuration from the tracked
template and migrates that bootstrap state and the existing platform state to
S3. It prompts for Terraform approval before creating the bucket. Do not delete
the existing local state files manually. Terraform preserves a local backup
during migration.
