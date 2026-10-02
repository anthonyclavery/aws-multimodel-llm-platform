# ADR-0001 — Host V0 on a Single EC2 Instance with Docker Compose

- Status: accepted
- Date: 2026-09-12

## Context

The platform initially targets a small number of users and also serves as a practical AWS/GenAI and portfolio project. The architecture must remain understandable, reproducible and economical without introducing orchestration prematurely.

## Decision

V0 will run on one Ubuntu Amazon EC2 instance. Caddy, LibreChat and MongoDB will run with Docker Compose.

## Consequences

- Deployment and troubleshooting remain straightforward.
- Terraform and a limited set of scripts can provision the stack.
- The instance is a single point of failure.
- Updates and restarts cause service interruption.
- Horizontal scaling is not addressed in V0.

## Rejected Alternatives

ECS/Fargate, Kubernetes, Lambda, API Gateway and microservices are excluded because their operational complexity is not justified by the expected load and availability requirements.
