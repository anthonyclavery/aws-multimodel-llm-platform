# AWS Multi-Model LLM Platform

A production-oriented reference architecture for building and operating
a multi-model LLM platform on AWS.

The platform aims to dynamically route requests across multiple Large
Language Model providers according to criteria such as model capability,
latency, cost and availability.

## Objectives

- Integrate multiple LLM providers behind a common abstraction layer
- Implement configurable and dynamic model routing strategies
- Evaluate models based on quality, latency and cost
- Provide observability for LLM requests and routing decisions
- Deploy the platform on AWS using Infrastructure as Code
- Apply production-grade software engineering and MLOps practices

## Target Architecture

The platform will progressively include:

- API layer
- LLM routing engine
- Provider abstraction layer
- Amazon Bedrock integration
- External LLM provider integrations
- Evaluation framework
- Observability
- Infrastructure as Code
- CI/CD

## Technology Stack

Initial target stack:

- AWS
- Amazon Bedrock
- Python
- FastAPI
- Terraform
- Docker
- GitHub Actions

The technology stack may evolve as architectural decisions are documented
through Architecture Decision Records (ADRs).

## Repository Structure

```text
.
├── docs/                   # Architecture and technical documentation
├── infrastructure/         # Infrastructure as Code
│   └── terraform/
├── src/                    # Application source code
│   ├── api/
│   ├── routing/
│   ├── providers/
│   ├── evaluation/
│   └── observability/
├── tests/                  # Automated tests
├── config/                 # Application configuration
├── scripts/                # Development and operational scripts
└── .github/workflows/      # CI/CD pipelines

## Project Status

Work in progress.

This repository is being built incrementally, with architectural decisions
and implementation trade-offs documented throughout the project.
