# Dedicated LibreChat AWS identity

`librechat_user` is the local identity reserved for this project. It has no
direct permissions over infrastructure: its only administrative permission is
to assume the dedicated Terraform role for the project. It can also manage its
own access keys, allowing key rotation without returning to the global
administrator account.

## Initial local setup

After applying Terraform, create an access key for `librechat_user` in the IAM
console. Do not create a console password, and never place the key in Git, in a
project file, or in a command copied into shell history.

Configure the key interactively in WSL:

```sh
aws configure --profile librechat-user-source
```

Retrieve the role ARN displayed by Terraform, then create the profile that
assumes that role:

```sh
aws configure set role_arn '<ARN shown in librechat_terraform_operator_role_arn>' --profile librechat-user
aws configure set source_profile librechat-user-source --profile librechat-user
aws configure set region eu-central-1 --profile librechat-user
aws configure set output json --profile librechat-user
aws sts get-caller-identity --profile librechat-user
```

The final command must display the
`aws-multimodel-llm-platform-v0-terraform-operator` role ARN, not the
`librechat_user` or `musical_madness_user` ARN.

Then explicitly use this profile for local project operations, for example:

```sh
./scripts/terraform-plan.sh --profile librechat-user
./scripts/verify-backup-recovery.sh --profile librechat-user
./scripts/start-v0-instance.sh --profile librechat-user
```

## Identity scope

The role authorizes only this environment's Terraform backend, the platform
services required in `eu-central-1`, AWS Backup, SSM access to the project
instance, secrets whose names start with the project prefix, and IAM roles that
share that prefix. It grants neither access to Musical Madness application
resources, nor Marketplace subscriptions, nor general administrative rights.

The source key is a long-term key. Rotate it as soon as it is exposed, lost, or
no longer needed. AWS recommends temporary credentials whenever they are
available. Here, the key only permits assuming a role limited to this project.
