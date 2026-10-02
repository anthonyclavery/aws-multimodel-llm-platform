# ADR 0006: Evaluation first and GitHub human approval

## Context

This repository is public and its infrastructure changes can affect a running
AWS environment. A green technical check alone does not prove that a change is
appropriate to apply or merge.

## Decision

Every change is evaluated before implementation. The evaluation records the
scope, expected resource actions, risks and verification method. Terraform is
planned into a reviewed file before application and the exact plan fingerprint
must be confirmed interactively.

Changes reach `main` only through a pull request with the required CI checks
and the `Human approval` GitHub environment job approved by the repository
owner. The environment permits approval by that same owner account because the
repository has a single maintainer. The deployment agent verifies the approved
job and the current commit again before it merges or applies a plan.

## Consequences

Changes take one explicit review step longer. This is intentional: it makes the
human decision visible in GitHub and prevents an automated agent from treating
technical validation as authorization to change production.
