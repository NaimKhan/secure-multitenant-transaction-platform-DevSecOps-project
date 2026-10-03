# Secure Multi-Tenant Transaction Platform — DevSecOps Lab

[![Secure DevSecOps Release Pipeline](https://github.com/NaimKhan/secure-multitenant-transaction-platform-DevSecOps-project/actions/workflows/ci-cd.yaml/badge.svg)](https://github.com/NaimKhan/secure-multitenant-transaction-platform-DevSecOps-project/actions)

> **Production-grade DevSecOps Lab** demonstrating a secure, multi-tenant financial services platform running on **Docker Swarm**, with edge security, network isolation, supply-chain security, immutable releases, automated rollback, secrets management, and observability.

**Services:** `Search` · `Transfer` · `Health`

---

## 1. Requirement vs. Implementation Summary

| #     | Requirement / Challenge           | Problem Statement                                                                        | Implemented DevSecOps Solution                                                                                                                 |
| ----- | --------------------------------- | ---------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| **1** | **Multi-Tenancy & Edge Security** | Prevent unauthorized access and cross-tenant access.                                     | **Traefik Edge Gateway** validates `X-Tenant-ID` (`Alpha` / `Beta`) and enforces rate limiting.                                                |
| **2** | **Network Isolation**             | Prevent direct external access to backend services.                                      | Application services run on an isolated Docker Swarm **`private-backend` overlay network** behind the edge gateway.                            |
| **3** | **Supply Chain Security**         | Prevent secrets, vulnerable dependencies, and untrusted artifacts from reaching release. | GitHub Actions pipeline with **Trivy scanning, Gitleaks, CycloneDX SBOM generation, Cosign signing, and immutable image digests**.             |
| **4** | **Secrets & Least Privilege**     | Avoid plaintext credentials and privileged containers.                                   | Docker Swarm Secrets mounted under **`/run/secrets/`** and application containers run as non-root **UID/GID `10001:10001`**.                   |
| **5** | **Auto-Rollback & Resiliency**    | Prevent unhealthy releases from remaining in production.                                 | Docker Swarm **healthchecks + `update_config` / `rollback_config`** automatically revert failed deployments.                                   |
| **6** | **Air-Gapped Delivery**           | Support customer-managed environments without internet connectivity.                     | `make bundle` generates an offline release package containing images, manifests, SBOMs, SHA256 checksums, and verification/deployment helpers. |

---

## 2. System Architecture

### 2.1 CI/CD & Software Supply-Chain Flow

```text
┌──────────────────────┐
│   Developer Push     │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────────────────────────────┐
│           GitHub Actions Pipeline             │
└──────────────────────┬───────────────────────┘
                       │
        ┌──────────────┼───────────────┐
        │              │               │
        ▼              ▼               ▼
┌──────────────┐ ┌──────────────┐ ┌───────────────┐
│ Secret Scan  │ │ Build & Scan │ │  SBOM         │
│   Gitleaks   │ │    Trivy     │ │  CycloneDX    │
└──────┬───────┘ └──────┬───────┘ └───────┬───────┘
       │                │                 │
       └────────────────┼─────────────────┘
                        ▼
             ┌──────────────────────┐
             │ Immutable Image      │
             │ SHA256 Digest        │
             └──────────┬───────────┘
                        │
                        ▼
             ┌──────────────────────┐
             │ Cosign / Sigstore    │
             │ Image Signing        │
             └──────────┬───────────┘
                        │
                        ▼
             ┌──────────────────────┐
             │      GHCR            │
             │ Container Registry   │
             └──────────┬───────────┘
                        │
                        ▼
                 Secure Deployment
```

### 2.2 Runtime Architecture & Trust Boundaries

```text
                         External Clients
                               │
                               │ HTTP :80
                               ▼
┌──────────────────────────────────────────────────────────┐
│                  PUBLIC EDGE NETWORK                     │
│                                                          │
│                 Traefik Edge Gateway                     │
│                                                          │
│  • X-Tenant-ID validation                                │
│  • Allowed tenants: Alpha / Beta                         │
│  • Rate limiting: 10 req/s, burst 5                     │
│  • Access / security telemetry                           │
└───────────────────────────┬──────────────────────────────┘
                            │
                            │
                            │ private-backend
                            │ Overlay Network
                            ▼
              ┌──────────────────────────────┐
              │       PRIVATE BACKEND        │
              │                              │
              │  ┌────────────────────────┐  │
              │  │   Multi-Tenant API     │  │
              │  │                        │  │
              │  │ • Search               │  │
              │  │ • Transfer             │  │
              │  │ • Health               │  │
              │  │                        │  │
              │  │ • Non-root UID 10001   │  │
              │  │ • Swarm Secrets        │  │
              │  └───────────┬────────────┘  │
              │              │               │
              │              │ Metrics       │
              │              ▼               │
              │  ┌────────────────────────┐  │
              │  │      Prometheus        │  │
              │  │ • Metrics collection   │  │
              │  │ • Alerting             │  │
              │  └────────────────────────┘  │
              └──────────────────────────────┘
```

### Key Trust Boundaries

**Public Edge → Private Backend**

External traffic enters through Traefik. Application services are placed behind the isolated `private-backend` overlay network rather than being directly exposed to external clients.

**Tenant Identity**

Requests must contain an allowed tenant identity:

```http
X-Tenant-ID: Alpha
```

or:

```http
X-Tenant-ID: Beta
```

Missing or unauthorized tenant identities are rejected with `403 Forbidden`.

**Application Privilege**

Application containers run as non-root UID/GID `10001:10001`, reducing the impact of a potential container compromise.

---

## 3. Security Controls

### 3.1 Edge Security

Traefik provides the first security enforcement layer:

* Tenant identity validation
* Unauthorized tenant rejection
* Request rate limiting
* Access logging
* Security telemetry

Configured rate limit:

```text
10 requests / second
Burst: 5
```

---

### 3.2 Network Isolation

The application services communicate through the Docker Swarm overlay network:

```text
private-backend
```

The intended traffic flow is:

```text
Internet
   │
   ▼
Traefik
   │
   ▼
private-backend
   │
   ▼
Application
```

This prevents the application service from being treated as a directly exposed public endpoint.

---

### 3.3 Secrets Management

Sensitive values are provided through **Docker Swarm Secrets**.

Secrets are exposed to the application through:

```text
/run/secrets/
```

They are not intended to be stored as plaintext credentials in source control or ordinary environment variables.

---

### 3.4 Least Privilege

Application containers run as:

```text
UID: 10001
GID: 10001
```

The application is therefore not dependent on root privileges for normal operation.

---

## 4. Software Supply-Chain Security

The CI/CD pipeline applies multiple security controls before release.

### Secret Detection

**Gitleaks** detects accidentally committed secrets such as:

* Private keys
* API credentials
* Passwords
* Tokens

A detected secret causes the security gate to fail.

### Vulnerability Scanning

**Trivy** is used to scan application/container-related artifacts for known vulnerabilities.

### SBOM Generation

A **CycloneDX JSON SBOM** is generated during the build.

Example:

```text
app-sbom.cyclonedx.json
```

The SBOM provides a machine-readable inventory of software components included in the release.

### Container Signing

Container images are signed using:

```text
Cosign / Sigstore
```

This provides cryptographic verification of the release artifact.

### Immutable Images

Deployment references immutable SHA256 digests rather than relying only on mutable image tags:

```text
registry/image@sha256:<digest>
```

This makes the deployed artifact explicitly identifiable and reduces ambiguity around mutable tags.

---

## 5. Repository Structure

```text
.
├── .github/
│   └── workflows/
│       └── ci-cd.yaml
│           # CI/CD pipeline:
│           # security scanning, SBOM, signing, GHCR release
│
├── app/
│   ├── ...
│   # FastAPI application source
│   # Search / Transfer / Health endpoints
│   # Non-root container configuration
│
├── docs/
│   ├── ...
│   # Design documentation
│   # Restricted / air-gapped delivery guide
│
├── edge/
│   ├── ...
│   # Traefik edge gateway
│   # Tenant validation
│   # Rate limiting
│
├── observability/
│   ├── ...
│   # Prometheus configuration
│   # Metrics
│   # Operational alert rules
│
├── scripts/
│   ├── ...
│   # Demonstration scenarios
│   # Security tests
│   # Release/bundle helpers
│
├── swarm/
│   ├── docker-compose.yml
│   # Docker Swarm stack configuration
│
├── Makefile
│   # One-command operational workflows
│   # up / down / demos / bundle
│
└── README.md
    # Project documentation
```

---

## 6. Quick Start

### Prerequisites

Required tools:

* Docker Engine
* Docker Swarm
* Git
* Make
* curl
* jq

Initialize Swarm if it has not already been initialized:

```bash
docker swarm init
```

Verify Docker:

```bash
docker info
```

---

### Deploy the Platform

Run:

```bash
make up
```

This initializes and deploys:

* Docker Swarm secrets
* Overlay networks
* Traefik edge gateway
* Application services
* Prometheus observability

---

### Verify Services

```bash
docker service ls
```

Inspect a specific service:

```bash
docker service ps <service-name>
```

---

### Tear Down

```bash
make down
```

---

## 7. Required Demonstration Scenarios

The repository contains reproducible demonstrations for the major assessment requirements.

---

### Scenario 1 — Unsafe Release Security Gate

Simulates an unsafe release containing an injected credential or RSA private key.

Run:

```bash
make demo-unsafe-release
```

Expected behavior:

```text
Injected Secret
      │
      ▼
  Gitleaks
      │
      ▼
Security Gate FAILED
      │
      ▼
Release BLOCKED
```

**Expected Outcome:** The scanner detects the exposed secret and prevents the unsafe release from progressing.

---

### Scenario 2 — Bad Deployment & Automatic Rollback

Deploys a deliberately degraded release:

```text
v1.0.1-degraded
```

The degraded release produces HTTP `500` responses and fails health checks.

Run:

```bash
make demo-bad-deploy
```

Expected flow:

```text
Healthy v1.0.0
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
Healthy v1.0.0
```

**Expected Outcome:** Docker Swarm detects the unhealthy release and automatically rolls back to the previous healthy version according to the configured rollback policy.

---

### Scenario 3 — Suspicious & Unauthorized Traffic

Tests tenant identity enforcement and rate limiting.

Run:

```bash
make demo-suspicious-traffic
```

Expected results:

| Test Case                    | Expected Result |
| ---------------------------- | --------------- |
| `X-Tenant-ID: Alpha`         | `200 OK`        |
| `X-Tenant-ID: Beta`          | `200 OK`        |
| Missing `X-Tenant-ID`        | `403 Forbidden` |
| `X-Tenant-ID: MaliciousCorp` | `403 Forbidden` |
| Excessive request burst      | Rate limited    |

---

## 8. Observability & Telemetry

The platform includes Prometheus-based operational monitoring.

### Prometheus

When running locally:

```text
http://localhost:9090
```

### Application Metrics

The application exposes HTTP metrics with contextual labels such as:

```text
http_requests_total{
  tenant="Alpha",
  version="v1.0.0"
}
```

These labels allow request behavior to be correlated with:

* Tenant
* Application version
* HTTP status
* Request activity

### Alert Rules

Operational and security-oriented alert rules are maintained under:

```text
observability/alerts.yml
```

Examples include:

```text
HighErrorRate
TenantUnauthorizedAbuseAttempt
```

---

## 9. Air-Gapped / Customer-Managed Delivery

The project supports environments where the deployment target cannot directly access the public internet.

Generate an offline release bundle:

```bash
make bundle
```

The bundle is designed to contain:

```text
Release Bundle
├── Container Images
├── Deployment Manifests
├── SBOMs
├── SHA256 Checksums
├── Cosign Verification Material
└── Deployment Helpers
```

The intended delivery flow is:

```text
Build
  │
  ▼
Security Scan
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
Verify Artifacts
  │
  ▼
Deploy
```

Detailed verification and offline upgrade procedures are documented in:

```text
docs/RESTRICTED_DELIVERY.md
```

---

## 10. Makefile Operations

The project provides a simplified operational interface through `make`.

| Command                        | Purpose                                          |
| ------------------------------ | ------------------------------------------------ |
| `make up`                      | Deploy the complete platform                     |
| `make down`                    | Remove the deployed environment                  |
| `make demo-unsafe-release`     | Demonstrate secret/security gate                 |
| `make demo-bad-deploy`         | Demonstrate failed deployment and rollback       |
| `make demo-suspicious-traffic` | Demonstrate tenant enforcement and rate limiting |
| `make bundle`                  | Generate the offline release bundle              |

---

## 11. Release Security Model

The overall release lifecycle is designed around the following principle:

```text
        Source Code
             │
             ▼
       Secret Detection
             │
             ▼
    Vulnerability Scanning
             │
             ▼
       Build Container
             │
             ▼
         Generate SBOM
             │
             ▼
        Sign Artifact
             │
             ▼
     Immutable Digest
             │
             ▼
        Deploy Release
             │
             ▼
       Health Checks
             │
       ┌─────┴─────┐
       │           │
    Healthy      Failed
       │           │
       ▼           ▼
    Continue    Rollback
       │           │
       └─────┬─────┘
             ▼
        Observability
```

---

## 12. AI Usage Statement

AI-assisted development tools were used for initial configuration bootstrapping and Bash script scaffolding.

AI-generated suggestions were treated as development input and were reviewed before implementation, particularly for security-sensitive configurations.

### Security Review Example

An initial AI suggestion proposed mounting the Docker socket directly into the API container while running the application with root privileges.

This approach was rejected as an insecure design because unrestricted Docker socket access can provide excessive control over the Docker host.

The implemented design instead uses:

* Non-root application execution
* UID/GID `10001:10001`
* Restricted Docker socket access where required
* Read-only Docker socket access (`:ro`) for the relevant edge component
* Public-edge / private-backend network separation
* Docker Swarm Secrets for sensitive credentials

This demonstrates an important DevSecOps principle:

> **AI-generated configuration is subject to security review and engineering validation before adoption.**

---

## 13. Key DevSecOps Practices Demonstrated

This project brings together the following practices in a single reproducible environment:

* 🔐 Multi-tenant request isolation
* 🛡️ Edge security controls
* 🌐 Network segmentation
* 🔎 Secret detection
* 🧪 Vulnerability scanning
* 📦 SBOM generation
* ✍️ Container image signing
* 🔒 Immutable image deployment
* 🔑 Secrets management
* 👤 Non-root container execution
* ♻️ Automated rollback
* 📊 Prometheus observability
* 🚨 Security/operational alerting
* 📦 Offline / air-gapped delivery
* 🤖 Security review of AI-assisted configuration

---

## 14. Assessment Notes

The repository is structured to make the implementation easy to evaluate:

**Requirement → Implementation → Configuration → Demonstration**

Each major assessment area is represented by:

1. A documented requirement
2. An implementation in the repository
3. A reproducible command or configuration
4. An expected security/operational outcome

The demonstration scenarios can be executed independently to verify the major security, resiliency, and release-engineering controls.

