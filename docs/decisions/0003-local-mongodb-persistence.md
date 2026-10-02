# ADR-0003 — Use Local MongoDB with Persistent EBS Storage

- Status: accepted
- Date: 2026-09-12

## Context

LibreChat relies on MongoDB for accounts, conversations and application data. A managed or remote database would add cost and operational dependencies for a low initial workload.

## Decision

MongoDB runs through Docker Compose on the same EC2 instance as LibreChat. Authentication is enabled, its port is not published on the host, and its data is stored on a persistent volume backed by encrypted EBS `gp3`. EBS snapshots provide recovery capability.

## Consequences

- Integration with LibreChat is direct and economical.
- Data persists across instance stops and restarts.
- The database shares the EC2 lifecycle and failure domain.
- Backups, recovery tests and MongoDB upgrades remain our responsibility.

## Rejected Alternatives

MongoDB Atlas and a separate database host are deferred until availability, volume or operational requirements justify them.
