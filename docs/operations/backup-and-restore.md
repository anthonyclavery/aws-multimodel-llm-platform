# Backup and restore

AWS Backup protects the EC2 instance and its encrypted EBS volume every day in
the `aws-multimodel-llm-platform-v0-vault` vault. Retention is 30 days. The
scheduled backup is independent from LibreChat and remains valid while the
instance is stopped overnight.

## Daily check

From WSL, confirm that a recent encrypted EC2 recovery point exists:

```sh
./scripts/verify-backup-recovery.sh --profile librechat-user
```

The command fails if the latest recovery point is missing, unencrypted, or more
than 26 hours old. It does not modify any AWS resource.

## Non-destructive restore

An AWS Backup restore creates a new AMI, a new instance, and new volumes. It
does not replace the existing production instance.

In the event of an incident, open AWS Backup in `eu-central-1`, choose
**Protected resources**, select the LibreChat instance, then select the latest
completed recovery point. Choose **Restore** and retain the project's VPC,
subnet, security group, and instance profile. Do not associate the production
Elastic IP with the restored instance during validation.

Wait for the `COMPLETED` status, then verify the restored instance through SSM.
Test LibreChat using its private address or a test address. Confirm that the
data is present under `/opt/aws-multimodel-llm-platform/data`, that the
containers start, and that it is possible to sign in with the LibreChat
account.

Only after explicit validation, prepare the Elastic IP cutover to the restored
instance. This step interrupts production traffic and must be performed during
a maintenance window. The old instance and its Elastic IP must never be deleted
before full functional validation.

AWS Backup does not restore EC2 user data. This project does not rely on it:
the deployment and scripts are versioned in Git, while application data remains
on the backed-up volume.

## Restore exercise

A full exercise temporarily creates a billable instance and volumes. It must be
requested and approved separately. Once the exercise is complete, stop and
delete only the test resources identified during the restore, after confirming
that they do not have the production Elastic IP.
