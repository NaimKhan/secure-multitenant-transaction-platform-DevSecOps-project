# 🔐 Secure Multi-Tenant Transaction Platform — DevSecOps Lab

[![Secure DevSecOps Release Pipeline](https://github.com/NaimKhan/secure-multitenant-transaction-platform-DevSecOps-project/actions/workflows/ci-cd.yaml/badge.svg)](https://github.com/NaimKhan/secure-multitenant-transaction-platform-DevSecOps-project/actions)

> A production-oriented DevSecOps reference implementation for a secure, multi-tenant financial transaction platform running on Docker Swarm.

**Demonstration Video:** [Loom / Google Drive Video — Coming Soon]

---

## 📌 Overview

This repository demonstrates how to build, secure, deploy, verify, and operate a **multi-tenant financial services platform** using modern DevSecOps practices.

The platform consists of three application services:

* **Search** — transaction/account search functionality
* **Transfer** — transaction transfer functionality
* **Health** — service health and operational endpoints

The platform runs on **Docker Swarm** behind a controlled **Traefik edge gateway**, with security enforcement, automated CI/CD security gates, container signing, SBOM generation, immutable deployments, automated rollback, secrets management, and observability.

### Core Engineering Goals

* 🔐 Secure-by-default application deployment
* 🏢 Multi-tenant request isolation
* 🛡️ Edge security and abuse protection
* 🔎 Automated vulnerability and secret detection
* 📦 Software supply-chain visibility
* ✍️ Cryptographic container signing
* 🧾 SBOM generation and artifact verification
* 🚀 Immutable deployments
* ♻️ Automated rollback on unhealthy releases
* 📊 Production-style observability
* 📡 Restricted / air-gapped release delivery

---

# 🏗️ System Architecture

```text
                    ┌──────────────────────────────┐
                    │     External Clients         │
                    │       / Tenants              │
                    └──────────────┬───────────────┘
                                   │
                                   │ HTTP :80
                                   ▼
        ┌─────────────────────────────────────────────────────┐
        │              TRAEFIK EDGE GATEWAY                  │
        │                                                     │
        │  • Tenant Identity Validation                      │
        │    X-Tenant-ID: Alpha / Beta                       │
        │                                                     │
        │  • Rate Limiting                                   │
        │    10 req/s + burst 5                              │
        │                                                     │
        │  • Access Logging                                  │
        │  • Security Telemetry                              │
        └─────────────────────────┬───────────────────────────┘
                                  │
                                  │ private-backend
                                  │ Overlay Network
                                  ▼
                 ┌────────────────────────────────┐
                 │       Multi-Tenant API         │
                 │                                │
                 │  • Search Service              │
                 │  • Transfer Service            │
                 │  • Health Service              │
                 │                                │
                 │  • Non-root UID 10001          │
                 │  • Read-only filesystem        │
                 │  • Tenant-aware requests       │
                 └───────────────┬────────────────┘
                                 │
                                 │ Metrics
                                 ▼
                    ┌──────────────────────────┐
                    │       Prometheus         │
                    │                          │
                    │ • Metrics Collection     │
                    │ • Service Monitoring     │
                    │ • Operational Alerts     │
                    └──────────────────────────┘
```

---

# 🔒 Security & Trust Boundaries

The architecture intentionally separates external traffic from internal application services.

### Public Edge → Private Backend

All external requests enter through the **Traefik edge gateway**.

Application containers are attached to the isolated `private-backend` overlay network and are not intended to be directly reachable from the public network.

```text
Internet
   │
   ▼
Traefik Edge
   │
   │ Security Policies
   ▼
Private Backend Network
   │
   ▼
Application Services
```

### Tenant Isolation

Requests must provide a valid tenant identity:

```http
X-Tenant-ID: Alpha
```

Supported tenants:

```text
Alpha
Beta
```

Requests with missing or unauthorized tenant identities are rejected.

Example:

```text
Valid Tenant
X-Tenant-ID: Alpha
        │
        ▼
      200 OK


Missing Tenant
(no X-Tenant-ID)
        │
        ▼
      403


Invalid Tenant
X-Tenant-ID: MaliciousCorp
        │
        ▼
      403
```

### Abuse Protection

The edge gateway enforces:

```text
Rate Limit: 10 requests / second
Burst:      5 requests
```

This provides a basic protection layer against excessive request bursts and abusive traffic.

---

# 🧰 Technology Stack

| Area                      | Technology                                 |
| ------------------------- | ------------------------------------------ |
| Container Runtime         | Docker                                     |
| Orchestration             | Docker Swarm                               |
| Edge Gateway              | Traefik                                    |
| CI/CD                     | GitHub Actions                             |
| Secret Detection          | Gitleaks                                   |
| Vulnerability Scanning    | Trivy                                      |
| SBOM                      | CycloneDX                                  |
| Image Signing             | Cosign / Sigstore                          |
| Monitoring                | Prometheus                                 |
| Infrastructure Automation | Make / Bash                                |
| Artifact Integrity        | SHA256                                     |
| Application Security      | Non-root containers + network segmentation |
| Release Model             | Immutable container images                 |
| Restricted Delivery       | Offline / Air-gapped Bundle                |

---

# 🚀 Quick Start

## Prerequisites

The environment requires:

* Ubuntu / Linux or macOS
* Docker Engine
* Docker Swarm
* Git
* Make
* curl
* jq

Initialize Docker Swarm if required:

```bash
docker swarm init
```

Verify:

```bash
docker info
```

---

## 1. Deploy the Platform

The entire stack can be initialized using:

```bash
make up
```

This provisions:

* Docker Swarm secrets
* Overlay networks
* Traefik edge gateway
* Application services
* Prometheus observability
* Required deployment configuration

---

## 2. Verify Services

Check the running services:

```bash
docker service ls
```

Inspect service details:

```bash
docker service ps <service-name>
```

---

## 3. Tear Down

To remove the deployed stack:

```bash
make down
```

---

# 🧪 Security Demonstration Scenarios

The repository includes reproducible demonstration scenarios designed to validate the security and reliability controls.

---

## Scenario 1 — Unsafe Release Security Gate

### Objective

Demonstrate that the CI/CD security pipeline blocks a release containing an injected secret such as an RSA private key or leaked credential.

Run:

```bash
make demo-unsafe-release
```

### Expected Result

The security pipeline should:

1. Detect the exposed credential using **Gitleaks**
2. Return a non-zero exit code
3. Fail the security gate
4. Prevent the unsafe release from progressing to deployment

```text
Secret Detected
      │
      ▼
Gitleaks
      │
      ▼
Security Gate FAILED
      │
      ▼
Deployment BLOCKED
```

---

# 🔄 Scenario 2 — Failed Deployment & Automatic Rollback

### Objective

Simulate a degraded application release:

```text
v1.0.1-degraded
```

The degraded version intentionally introduces failure conditions such as HTTP 500 responses and failed health checks.

Run:

```bash
make demo-bad-deploy
```

### Expected Result

Docker Swarm detects the unhealthy service through health checks.

```text
v1.0.0
  │
  ▼
Deploy v1.0.1-degraded
  │
  ▼
Health Checks Fail
  │
  ▼
Deployment Degraded
  │
  ▼
Automatic Rollback
  │
  ▼
v1.0.0 Healthy Release
```

The expected recovery target is the previously healthy `v1.0.0` release.

---

# 🚨 Scenario 3 — Suspicious & Unauthorized Traffic

### Objective

Validate tenant identity enforcement and edge rate limiting.

Run:

```bash
make demo-suspicious-traffic
```

### Expected Results

| Test                       | Expected Response |
| -------------------------- | ----------------- |
| Valid `X-Tenant-ID: Alpha` | `200 OK`          |
| Valid `X-Tenant-ID: Beta`  | `200 OK`          |
| Missing Tenant Header      | `403 Forbidden`   |
| Invalid Tenant             | `403 Forbidden`   |
| Excessive Burst Traffic    | Rate Limited      |

Example:

```text
X-Tenant-ID: Alpha
        │
        ▼
     200 OK


X-Tenant-ID: MaliciousCorp
        │
        ▼
  403 Forbidden


No Tenant Header
        │
        ▼
  403 Forbidden
```

---

# 🔗 Software Supply Chain Security

The GitHub Actions pipeline implements multiple security controls before an artifact is promoted toward deployment.

Pipeline controls include:

### 🔍 Secret Detection

**Gitleaks** scans source code and release content for accidentally committed credentials and private keys.

```text
Source
  │
  ▼
Gitleaks
  │
  ├── PASS → Continue
  │
  └── FAIL → Release Blocked
```

### 🛡️ Filesystem Vulnerability Scanning

**Trivy** scans the source filesystem and container-related artifacts for known vulnerabilities.

### 📦 SBOM Generation

A CycloneDX Software Bill of Materials is generated during the build.

Example artifact:

```text
app-sbom.cyclonedx.json
```

The SBOM provides visibility into the software components included in the release.

### ✍️ Container Image Signing

Container images are cryptographically signed using:

```text
Cosign / Sigstore
```

This allows downstream environments to verify artifact authenticity.

### 🔒 Immutable Deployment

Deployments reference immutable image digests rather than mutable tags.

Instead of relying solely on:

```text
myapp:v1.0.0
```

the deployment uses an immutable SHA256 digest:

```text
myapp@sha256:<digest>
```

This reduces the risk of an image tag being moved or replaced after approval.

---

# 🔑 Secrets Management & Least Privilege

Security-sensitive configuration is intentionally kept outside source code.

### Docker Swarm Secrets

Sensitive values such as:

```text
db_password
```

are delivered using Docker Swarm Secrets rather than:

```text
environment variables
```

or committed configuration files.

Conceptually:

```text
Secret Store
     │
     ▼
Docker Swarm Secret
     │
     ▼
Application Container
```

### Non-Root Containers

Application services run using a restricted user:

```text
UID: 10001
GID: 10001
```

The containers are not intended to run as root.

Where appropriate, the root filesystem is configured as read-only.

---

# 📦 Restricted / Air-Gapped Release Delivery

The platform supports customer-managed delivery for restricted or disconnected environments.

Generate a self-contained release bundle:

```bash
make bundle
```

The release bundle can contain:

* Container images
* Compose / deployment manifests
* SBOM files
* SHA256 checksums
* Deployment helpers
* Release metadata

Example structure:

```text
release-bundle-v1.0.0/
├── images/
├── manifests/
├── sbom/
├── checksums/
└── scripts/
```

Detailed procedures are documented in:

```text
docs/RESTRICTED_DELIVERY.md
```

The intended workflow is:

```text
Build
  │
  ▼
Scan
  │
  ▼
Generate SBOM
  │
  ▼
Sign Images
  │
  ▼
Generate Checksums
  │
  ▼
Create Offline Bundle
  │
  ▼
Transfer to Restricted Environment
  │
  ▼
Verify
  │
  ▼
Deploy
```

---

# 📁 Repository Structure

```text
.
├── .github/
│   └── workflows/
│       └── ci-cd.yaml
│
├── app/
│   └── Application services
│
├── edge/
│   └── Traefik edge gateway configuration
│
├── observability/
│   └── Prometheus monitoring configuration
│
├── scripts/
│   └── Security and demonstration scripts
│
├── swarm/
│   └── Docker Swarm deployment configuration
│
├── docs/
│   └── Restricted delivery documentation
│
├── Makefile
│
└── README.md
```

---

# 🧭 DevSecOps Release Flow

The overall delivery process follows a security-first release lifecycle:

```text
                    ┌─────────────────┐
                    │   Developer     │
                    │     Commit      │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │   CI Pipeline   │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
          Gitleaks         Trivy          Tests
              │              │              │
              └──────────────┼──────────────┘
                             │
                             ▼
                      Build Container
                             │
                             ▼
                        Generate SBOM
                             │
                             ▼
                       Sign Image
                             │
                             ▼
                  Immutable SHA256 Image
                             │
                             ▼
                        Deployment
                             │
                             ▼
                    Health Validation
                             │
                   ┌─────────┴─────────┐
                   │                   │
                 Healthy            Failed
                   │                   │
                   ▼                   ▼
                Release            Rollback
                   │                   │
                   └─────────┬─────────┘
                             ▼
                        Observability
```

---

# 🤖 AI Usage Statement

AI-assisted development tools were used during the initial configuration bootstrapping and Bash script scaffolding.

All security-sensitive implementation decisions were reviewed and validated manually.

### Example

An initial AI-generated suggestion proposed mounting the Docker socket directly into an API container while running the application with root privileges.

That approach was rejected because unrestricted Docker socket access can effectively provide excessive control over the Docker host.

The final implementation instead enforces:

* Non-root application execution
* UID `10001`
* Restricted container privileges
* Docker socket access limited to the required edge component
* Read-only Docker socket access where applicable
* Separation between public-edge and private-backend networks

This project intentionally treats AI-generated configuration as **input for review, not as an authority on security**.

---

# 🎯 Project Objectives

This lab demonstrates practical implementation of:

* DevSecOps CI/CD
* Secure containerization
* Docker Swarm orchestration
* Multi-tenant security controls
* Edge security
* Secret detection
* Vulnerability scanning
* SBOM generation
* Container signing
* Immutable deployments
* Automated rollback
* Runtime observability
* Least-privilege execution
* Docker Swarm Secrets
* Offline / air-gapped delivery
* Security-focused release engineering

---

# 📜 License

This project is intended for **educational, demonstration, and DevSecOps engineering evaluation purposes**.

See the repository license for applicable terms.

