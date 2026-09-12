# AWS Multi-Model LLM Platform

A self-hosted multi-model LLM platform running on AWS, providing a single
interface to access and compare multiple Large Language Models.

The platform is built around LibreChat and is initially intended for a small
number of users. It provides access to models hosted through Amazon Bedrock
as well as external LLM providers such as Google Gemini.

The project is also used as a practical AWS infrastructure and GenAI
engineering project, with a focus on simplicity, reproducibility,
observability and cost control.

## Objectives

- Provide a single user interface for interacting with multiple LLMs
- Self-host LibreChat on AWS
- Integrate Amazon Bedrock models
- Integrate external LLM providers such as Google Gemini
- Allow users to select and compare models
- Monitor infrastructure usage and costs
- Deploy the AWS infrastructure using Terraform
- Automate deployment progressively through CI/CD
- Provide a foundation for future AI agents and integrations

## V0 Architecture

The V0 architecture is intentionally simple and optimized for a small number
of users, controlled operating costs and straightforward maintenance.

LibreChat, MongoDB and Caddy run with Docker Compose on a single Amazon EC2
instance. The application provides access to Amazon Bedrock through an IAM
instance role and to Google Gemini through credentials stored in AWS Secrets
Manager.

The EC2 instance is hosted in a public subnet, but only HTTPS traffic is
allowed. Administration is performed through AWS Systems Manager Session
Manager, without exposing SSH. The instance is started manually and automatically
stopped every night to avoid unnecessary compute costs.

- [Detailed V0 architecture](docs/architecture/v0.md)
- [Architecture diagram](docs/diagrams/v0-architecture.md)
- [Architecture Decision Records](docs/decisions/)

## Technology Stack

Initial stack:

- AWS
- Amazon EC2
- Amazon Bedrock
- LibreChat
- MongoDB
- Google Gemini
- Docker / Docker Compose
- Terraform
- GitHub Actions

Additional AWS services will be introduced only when required by concrete
technical or operational needs.

## Repository Structure

```text
.
├── .github/
│   └── workflows/             # CI/CD workflows
├── config/
│   └── librechat/             # LibreChat configuration
├── docker/
│   └── librechat/             # Docker runtime configuration
├── docs/
│   ├── architecture/          # Architecture documentation
│   ├── decisions/             # Architecture Decision Records
│   └── diagrams/              # Architecture diagrams
├── infrastructure/
│   └── terraform/
│       ├── environments/
│       │   ├── dev/
│       │   └── prod/
│       └── modules/           # Reusable Terraform modules
├── scripts/                   # Operational and bootstrap scripts
└── tests/
    └── infrastructure/        # Infrastructure tests
```

## Roadmap

The platform will be built incrementally.

1. Initialize the Git repository and project conventions
2. Define and document the V0 architecture
3. Build the Terraform infrastructure
4. Deploy the initial AWS environment
5. Bootstrap Docker on the AWS host
6. Deploy LibreChat
7. Integrate Amazon Bedrock
8. Integrate Google Gemini
9. Add Terraform CI/CD
10. Add monitoring and cost visibility
11. Build an initial multi-LLM benchmark
12. Explore AI agents and Amazon Bedrock AgentCore

Future capabilities may include dedicated agents, additional LLM providers,
automated evaluations and application-specific integrations.

These capabilities are intentionally kept outside the initial architecture
until concrete use cases justify them.

## Design Principles

The project follows a few core principles:

- Keep the initial architecture simple
- Prefer managed AWS services where they provide clear value
- Provision infrastructure through Infrastructure as Code
- Avoid unnecessary architectural complexity
- Keep secrets and credentials outside the Git repository
- Make infrastructure costs observable
- Document significant architectural decisions
- Introduce new components only when justified by a concrete requirement

## Project Status

Work in progress.

The repository is being built incrementally. Architecture decisions,
implementation choices and trade-offs are documented as the platform evolves.
