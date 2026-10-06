# ADR-0005 — Separate AWS Access from Application Secrets

- Status: accepted
- Date: 2026-09-12

## Context

The platform accesses Amazon Bedrock and Google Gemini. These integrations use different authentication mechanisms and must not place sensitive credentials in Git or Docker images.

## Decision

Bedrock access uses an IAM role attached to EC2 through an Instance Profile. The role can invoke Bedrock foundation models and inference profiles, which allows LibreChat to expose its known compatible serverless models. It cannot subscribe to Marketplace products, create Marketplace deployments, invoke Marketplace endpoints or manage Bedrock resources. Application and external-provider secrets are stored in AWS Secrets Manager. The instance can read only the secrets explicitly required by the application.

## Consequences

- No static AWS credentials are distributed to the application.
- Marketplace model subscriptions and deployments remain explicit operator decisions.
- Application secrets are not committed to Git.
- Secret rotation and auditing are centralized.
- Stack startup must include controlled secret retrieval and injection.
