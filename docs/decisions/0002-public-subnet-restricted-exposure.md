# ADR-0002 — Use a Public Subnet with Strictly Limited Exposure

- Status: accepted
- Date: 2026-09-12

## Context

A private EC2 instance would require an inbound access path and additional components such as a Load Balancer and/or NAT Gateway. For V0, this would increase cost and complexity without a proportionate benefit.

## Decision

The EC2 instance is placed in a public subnet and assigned an Elastic IP. Its Security Group allows inbound TCP/443 traffic only. Caddy is the only exposed container and terminates HTTPS. LibreChat and MongoDB remain on the internal Docker network. No SSH port is open; administration uses AWS Systems Manager Session Manager.

## Consequences

- The application is accessible without a Load Balancer.
- The public network surface is limited to HTTPS.
- Security depends on rigorous Security Group, Docker, Caddy and OS configuration.
- Hardening, security updates and monitoring are required.

## Rejected Alternatives

A private EC2 instance behind an Application Load Balancer and a NAT Gateway architecture are deferred until stronger availability or security requirements justify them.
