# V0 Architecture

## Runtime and Request Flow

```mermaid
flowchart TB
    Users["Authorized users"]
    DNS["Public DNS<br/>application hostname"]

    subgraph EC2["Amazon EC2 · Ubuntu"]
        direction TB
        Caddy["Caddy<br/>HTTPS entry point"]
        LibreChat["LibreChat<br/>multi-model interface"]
        MongoDB["Authenticated MongoDB<br/>persistent application data"]

        Caddy -->|"internal Docker network"| LibreChat
        LibreChat -->|"internal Docker network"| MongoDB
    end

    Bedrock["Amazon Bedrock<br/>authorized models"]
    Gemini["Google Gemini API"]

    Users -->|"HTTPS"| DNS
    DNS -->|"Elastic IP · TCP 443"| Caddy
    LibreChat -->|"EC2 IAM role"| Bedrock
    LibreChat -->|"protected API key"| Gemini
```

The EC2 Security Group accepts inbound TCP/443 traffic only. Caddy is the only
container exposed publicly; LibreChat and MongoDB remain on the internal Docker
network.

## Infrastructure and Operations

```mermaid
flowchart TB
    Admin["Administrator"]
    Scheduler["AWS scheduling<br/>nightly shutdown"]

    subgraph AWS["AWS account"]
        direction TB

        subgraph VPC["VPC · Public subnet"]
            EC2["Amazon EC2 · Ubuntu<br/>stable public endpoint<br/>Docker Compose"]
            EBS["Encrypted EBS gp3<br/>persistent volumes"]
            EC2 --> EBS
        end

        IAM["IAM Instance Profile<br/>least-privilege Bedrock access"]
        Secrets["AWS Secrets Manager<br/>application and provider secrets"]
        CloudWatch["Amazon CloudWatch<br/>essential logs and metrics"]
        S3["Amazon S3<br/>documents when required"]

        EC2 --> IAM
        EC2 --> Secrets
        EC2 --> CloudWatch
        EC2 -.->|"optional"| S3
    end

    Admin -->|"Systems Manager Session Manager<br/>no public SSH"| EC2
    Scheduler -->|"StopInstances"| EC2
```

## Security Boundaries

- The Security Group allows inbound TCP/443 traffic only.
- LibreChat and MongoDB ports are never published by Docker.
- Caddy terminates TLS and is the only public application entry point.
- Administration uses AWS Systems Manager Session Manager; port 22 remains closed.
- Amazon Bedrock is accessed through the EC2 IAM role without static AWS credentials.
- Application secrets are stored in AWS Secrets Manager and injected at runtime.
- Persistent data is stored on encrypted EBS volumes and protected with snapshots.

## Lifecycle

- The instance is started manually.
- A scheduled action stops it every night.
- No automatic morning startup is configured in V0.
- This strategy must be reassessed if agents or asynchronous workloads need to
  operate outside interactive usage periods.
