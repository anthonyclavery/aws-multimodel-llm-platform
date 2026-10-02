# ADR-0004 — Use Manual Startup and Automatic Nightly Shutdown

- Status: accepted
- Date: 2026-09-12

## Context

The platform does not need 24/7 availability in V0. Running EC2 continuously would create avoidable costs, while automatic daily startup would be unnecessary on days without usage.

## Decision

The instance is started manually. An AWS scheduling mechanism stops it every night as a safeguard against forgotten shutdowns. No automatic startup is configured.

## Consequences

- Unused compute hours are limited.
- A user must start the instance before accessing the platform.
- The service becomes unavailable after the scheduled nightly shutdown unless manually restarted.
- EBS storage and the Elastic IP continue to incur their respective costs while EC2 is stopped.

## Reassessment Criterion

This decision must be reassessed when AI agents, asynchronous processing or an availability commitment require operation outside interactive usage periods.
