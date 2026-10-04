# Secure Multi-Tenant Transaction Platform — DevSecOps Lab

A locally reproducible DevSecOps implementation for a secure multi-tenant transaction platform running on Docker Swarm.

The project demonstrates the complete path:

```text
Source
  ↓
Build & Test
  ↓
Security Gates
  ↓
SBOM & Trusted Artifact
  ↓
Secure Deployment
  ↓
Runtime Security
  ↓
Observability
  ↓
Detection & Rollback
```

---

# 🚀 1. Start Here — Reviewer Quick Guide

You do **not** need to read the entire README before running the project.

## Clone

```bash
git clone git@github.com:NaimKhan/secure-multitenant-transaction-platform-DevSecOps-project.git
cd secure-multitenant-transaction-platform-DevSecOps-project
```

## Start the environment

```bash
make up
```

## Run the required demonstrations

### Unsafe Release

```bash
make demo-unsafe-release
```

Demonstrates that an unsafe release condition is detected and blocked by security gates.

### Bad Deployment

```bash
make demo-bad-deploy
```

Deploys a deliberately degraded release and demonstrates detection and rollback behavior.

### Suspicious / Unauthorized Traffic

```bash
make demo-suspicious-traffic
```

Demonstrates tenant validation, unauthorized access rejection, and rate limiting.

### Observability

Prometheus:

```text
http://localhost:9090
```

Example application metric:

```text
http_requests_total{tenant="Alpha",version="v1.0.0"}
```

### Generate Offline Release Bundle

```bash
make bundle
```

### Stop the environment

```bash
make down
```

---

# 2. Assessment Problem → Solution

The implementation is organized around the problems described in the assessment.

| Assessment Problem                                  | Implemented Solution                                  | Where to Look                      |
| --------------------------------------------------- | ----------------------------------------------------- | ---------------------------------- |
| How should external traffic reach private services? | Traefik controlled security edge                      | Traefik / deployment configuration |
| How is tenant identity established?                 | `X-Tenant-ID` validation at the edge                  | Traefik configuration              |
| How are tenants protected from unauthorized access? | Supported tenant allow-list + policy enforcement      | Edge configuration                 |
| How are backend services protected?                 | Private Docker Swarm overlay network                  | Swarm deployment                   |
| How can an unsafe release be blocked?               | Trivy + Gitleaks security gates                       | `.github/workflows/`               |
| How is software composition understood?             | CycloneDX SBOM generation                             | CI configuration                   |
| How is artifact integrity established?              | Signing / verification + SHA256 integrity information | Release configuration              |
| How are secrets protected?                          | Docker Swarm Secrets                                  | Swarm configuration                |
| How are containers prevented from running as root?  | UID/GID `10001:10001`                                 | Dockerfiles                        |
| How is a bad deployment detected?                   | Healthchecks + Prometheus metrics                     | Deployment / observability         |
| How is rollback handled?                            | Swarm update/rollback configuration                   | Swarm deployment                   |
| How is suspicious traffic controlled?               | Tenant policy + rate limiting                         | Traefik                            |
| How can an operator investigate an incident?        | Metrics, logs, tenant and version visibility          | `observability/`                   |
| How is restricted-connectivity delivery handled?    | Offline release bundle + verification design          | `docs/RESTRICTED_DELIVERY.md`      |
| How is the environment reproduced?                  | Makefile-driven setup, demos and teardown             | `Makefile`                         |

---

# 3. Architecture

## 3.1 End-to-End Delivery Flow

```text
┌──────────────┐
│ Source Code  │
└──────┬───────┘
       │
       ▼
┌─────────────────────┐
│ CI / Build / Tests  │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────────────┐
│ Security Gates              │
│                             │
│ Trivy:                      │
│  • Vulnerabilities          │
│  • Secrets                  │
│  • Configuration            │
│                             │
│ Gitleaks: Secret Detection  │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ SBOM + Artifact Integrity   │
│                             │
│ • CycloneDX SBOM            │
│ • Checksums                 │
│ • Signing / Verification    │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ Trusted Release Artifact    │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ Docker Swarm Deployment     │
└──────────────┬──────────────┘
               │
               ▼
        Runtime Security
        + Observability
        + Rollback
```

---

## 3.2 Runtime Request Flow

External clients do not directly access the backend services.

```text
                 External Client
                       │
                       ▼
              ┌─────────────────┐
              │ Traefik Edge     │
              │                 │
              │ Tenant Policy   │
              │ Rate Limiting   │
              │ Security Logs   │
              └────────┬────────┘
                       │
                 Allowed Request
                       │
                       ▼
              ┌─────────────────┐
              │ Private Swarm   │
              │ Overlay Network │
              └────────┬────────┘
                       │
             ┌─────────┼─────────┐
             ▼         ▼         ▼
          Search    Transfer    Health
             │         │         │
             └─────────┼─────────┘
                       ▼
                 Observability
                 Prometheus
```

The main trust boundary is at the controlled edge. Tenant validation and traffic policy are applied before requests reach the private backend network.

---

# 4. Application, Tenancy & Network Security

The application exposes:

* Search
* Transfer
* Health

Tenant identity is represented through:

```text
X-Tenant-ID
```

Supported tenants include:

```text
Alpha
Beta
```

Unauthorized or missing tenant identities are rejected at the edge.

Rate limiting is configured at approximately:

```text
10 requests/second
Burst: 5
```

This provides a simple demonstration of:

* Tenant-aware access control
* Request policy enforcement
* Abuse protection
* Security telemetry

Backend services are kept on a private Docker Swarm overlay network.

---

# 5. Container & Secrets Security

The runtime follows basic least-privilege principles.

### Non-root execution

Application containers use:

```text
UID/GID: 10001:10001
```

### Runtime secrets

Secrets are provided using Docker Swarm Secrets and exposed to services through:

```text
/run/secrets/
```

Plaintext application secrets are not committed to the repository.

### Service isolation

The application uses:

* Private overlay networking
* Explicit service boundaries
* Restricted runtime access
* Healthchecks
* Controlled update/rollback behavior

---

# 6. Secure CI/CD & Software Supply Chain

The release pipeline is designed to prevent unsafe software from reaching deployment.

```text
Code
 │
 ▼
Build
 │
 ▼
Tests
 │
 ▼
Security Scanning
 │
 ├── Trivy
 │    ├── Vulnerability
 │    ├── Secret
 │    └── Configuration
 │
 └── Gitleaks
      └── Secret Detection
 │
 ▼
SBOM
 │
 ▼
Artifact Integrity
 │
 ▼
Release
```

## Security Gates

A security finding or policy violation can prevent the release from proceeding.

The repository intentionally demonstrates this behavior through:

```bash
make demo-unsafe-release
```

---

# 7. SBOM & Artifact Trust

Each release is associated with software inventory and integrity information.

The release process includes:

* CycloneDX SBOM
* Container/image identity
* SHA256 checksums
* Signing / verification metadata

The objective is to make the release identifiable and verifiable rather than relying only on mutable image tags.

---

# 8. Required Demonstration Scenarios

The assessment requires three repeatable scenarios.

## 8.1 Unsafe Release

```bash
make demo-unsafe-release
```

Flow:

```text
Intentionally Unsafe Condition
             │
             ▼
       Security Gate
             │
       ┌─────┴─────┐
       │           │
    Unsafe       Safe
       │           │
       ▼           ▼
    BLOCK        RELEASE
```

The purpose is to demonstrate that security controls are enforced during delivery.

---

## 8.2 Bad Deployment

```bash
make demo-bad-deploy
```

A deliberately degraded release such as:

```text
v1.0.1-degraded
```

is introduced.

Expected behavior:

```text
Bad Release
     │
     ▼
Health / Error Signal
     │
     ▼
Degradation Detected
     │
     ▼
Configured Rollback
     │
     ▼
Healthy Release
```

The healthy release used in the demonstration is:

```text
v1.0.0
```

The rollback behavior follows the configured Docker Swarm update/rollback policy.

---

## 8.3 Suspicious / Unauthorized Traffic

```bash
make demo-suspicious-traffic
```

Example expected results:

| Request                 | Expected |
| ----------------------- | -------: |
| Alpha tenant            |    `200` |
| Beta tenant             |    `200` |
| Missing tenant          |    `403` |
| Unauthorized tenant     |    `403` |
| Excessive request burst |    `429` |

The important part is not only blocking the request, but also leaving enough telemetry to investigate the activity.

---

# 9. Observability & Detection

Prometheus provides runtime visibility:

```text
http://localhost:9090
```

Example:

```text
http_requests_total{tenant="Alpha",version="v1.0.0"}
```

This allows an operator to identify:

* Which tenant was affected
* Which application version was running
* Request/error activity
* Rejected traffic
* Deployment-related degradation

Configured alert conditions include:

```text
HighErrorRate
TenantUnauthorizedAbuseAttempt
```

Alert configuration:

```text
observability/alerts.yml
```

---

# 10. Deployment & Rollback

The runtime is deployed using Docker Swarm.

Deployment configuration includes:

* Healthchecks
* Restart behavior
* Update configuration
* Rollback configuration
* Resource configuration
* Network boundaries

The bad deployment demonstration shows how an unhealthy release becomes visible and how the platform can return to a healthy version.

```text
Healthy v1.0.0
      │
      ▼
Deploy v1.0.1-degraded
      │
      ▼
Health / Error Signal
      │
      ▼
Rollback
      │
      ▼
Healthy v1.0.0
```

---

# 11. Customer-Managed / Air-Gapped Delivery

The assessment also asks how the same release could be delivered into a customer-controlled environment with restricted or no direct internet connectivity.

The repository provides an offline-style release workflow:

```bash
make bundle
```

The bundle is intended to package the artifacts required for offline verification and deployment.

## 11.1 Offline Release Bundle

Typical release contents include:

| Component                      | Purpose                           |
| ------------------------------ | --------------------------------- |
| Container image archives       | Offline image delivery            |
| Docker/Swarm manifests         | Declarative deployment            |
| CycloneDX SBOM                 | Software inventory                |
| SHA256 checksums               | Integrity verification            |
| Signature/public-key materials | Release authenticity verification |
| Operational helpers            | Offline installation/verification |

Example conceptual structure:

```text
release-bundle/
├── images/
├── sbom/
├── manifests/
├── security/
└── scripts/
```

The exact generated structure should be verified against the output of:

```bash
make bundle
```

---

# 12. Offline Release Verification

A customer should verify a release before installation.

## Integrity Verification

```bash
sha256sum -c checksums.sha256
```

This verifies that release artifacts have not been modified or corrupted after packaging.

## Signature Verification

Where the generated release includes Cosign verification materials:

```bash
cosign verify-blob \
  --key cosign.pub \
  --signature bundle.sig \
  <release-bundle>
```

The verification confirms that the bundle corresponds to the expected vendor signing identity.

---

# 13. Offline Trust Verification Flow

```text
             Offline Release Bundle
                      │
                      ▼
              ┌────────────────┐
              │ SHA256 Check   │
              │ Integrity      │
              └───────┬────────┘
                      │
                      ▼
              ┌────────────────┐
              │ Cosign Verify  │
              │ Authenticity   │
              └───────┬────────┘
                      │
                 Verification
                   Successful
                      │
                      ▼
              ┌────────────────┐
              │ Installation / │
              │ Deployment     │
              └────────────────┘
```

This separates **integrity verification** from **release authenticity verification** before deployment.

---

# 14. Offline Diagnostics & Troubleshooting

An air-gapped environment cannot depend on internet-based troubleshooting services.

Basic operational diagnostics can be collected directly from Docker Swarm.

### Check service health

```bash
docker service ps <service-name>
```

### Inspect service configuration

```bash
docker service inspect <service-name>
```

### Inspect runtime logs

```bash
docker service logs -f <service-name>
```

### Export diagnostic information

```bash
docker service inspect \
  <service-name> \
  > diagnostic-report.json
```

Additional container information:

```bash
docker ps
```

```bash
docker inspect <container_id>
```

## Offline Incident Workflow

```text
Service Alert / User Report
           │
           ▼
    Check Service State
           │
           ▼
    Check Task / Replica
           │
           ▼
    Inspect Application Logs
           │
           ▼
    Inspect Deployment Config
           │
      ┌────┴─────┐
      │          │
   Healthy    Unhealthy
      │          │
      ▼          ▼
 Continue      Rollback
 Monitoring      │
                 ▼
       Export Diagnostics
```

---

# 15. Enterprise Air-Gapped Deployment Model

A mature customer-managed deployment could evolve toward:

```text
                    Vendor CI/CD
                         │
                    Signed Release
                         │
                         ▼
              ┌──────────────────────┐
              │ Offline Release      │
              │ Bundle               │
              │                      │
              │ • Images             │
              │ • SBOM               │
              │ • Signatures         │
              │ • Checksums          │
              │ • Manifests          │
              └──────────┬───────────┘
                         │
                  Secure Transfer
                         │
                         ▼
              ┌──────────────────────┐
              │ Customer Bastion     │
              │                      │
              │ SHA256 Verification  │
              │ Signature Verification│
              └──────────┬───────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │ Internal Registry /  │
              │ Artifact Store       │
              └──────────┬───────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │ Docker Swarm Cluster │
              │                      │
              │       Traefik        │
              │          │           │
              │          ▼           │
              │   Private Backend    │
              │      Network         │
              │          │           │
              │          ▼           │
              │     API Services     │
              └──────────────────────┘
```

This separates the vendor release process from the customer runtime environment while maintaining verifiable release information throughout the delivery chain.

Detailed customer-managed delivery design:

```text
docs/RESTRICTED_DELIVERY.md
```

---

# 16. Reproducibility

The environment is designed to minimize hidden manual setup.

Main operations are available through the Makefile:

```bash
make up
make down

make demo-unsafe-release
make demo-bad-deploy
make demo-suspicious-traffic

make bundle
```

The repository keeps deployment and observability configuration under source control.

If the system fails, the primary areas to inspect are:

```text
.github/workflows/     → CI/CD and security gates
deploy/                → Swarm deployment
observability/         → Metrics and alerts
scripts/               → Demo/operational workflows
Makefile               → Reproducible operations
docs/                  → Design documentation
```

---

# 17. Repository Structure

```text
.
├── .github/
│   └── workflows/              # CI/CD and security gates
├── app/                         # Application services
├── deploy/                      # Docker/Swarm configuration
├── observability/               # Prometheus and alert rules
├── scripts/                     # Demo and operational scripts
├── docs/
│   └── RESTRICTED_DELIVERY.md  # Restricted-connectivity design
├── Dockerfile*
├── docker-stack.yml
├── Makefile
└── README.md
```

---

# 18. Known Gaps & Production Improvements

This assessment is intentionally scoped to a small local environment.

Before production, I would further improve:

* Centralized secret management / Vault or equivalent
* Stronger workload identity and service authentication
* Short-lived CI credentials
* Hardened artifact registry controls
* Centralized logging and security monitoring
* More comprehensive tenant authorization policies
* Production PKI and certificate lifecycle management
* High-availability / multi-region architecture where required
* Formal incident response and compliance controls

These are identified as future production improvements and are not presented as implemented controls.

---

# 19. AI Usage

AI coding assistance was used for initial configuration bootstrapping and Bash scaffolding.

One AI-generated suggestion was to mount the Docker socket directly into the application container with root-level access.

That approach was rejected after review.

The implementation instead uses:

* Non-root application containers
* Restricted/read-only Docker socket access only where required by the edge component
* Docker Swarm Secrets
* Private overlay networking
* Explicit service boundaries

This example demonstrates that generated suggestions were reviewed and adapted rather than accepted blindly.

---

# 20. Assessment Traceability

| Assessment Requirement                        | Implementation                                                           |
| --------------------------------------------- | ------------------------------------------------------------------------ |
| 3.1 Application, tenancy & network boundaries | Search/Transfer/Health, tenant validation, Traefik, private overlay      |
| 3.2 Secure CI/CD & supply chain               | CI security gates, Trivy, Gitleaks, SBOM, artifact integrity             |
| 3.3 Secrets, identity & least privilege       | Swarm Secrets, non-root containers, restricted access                    |
| 3.4 Deployment & rollback                     | Swarm healthchecks, update/rollback configuration, degraded release demo |
| 3.5 Observability & detection                 | Prometheus metrics, alert rules, tenant/version visibility               |
| 3.6 Reproducibility                           | Makefile-driven setup, demos, teardown and bundle generation             |
| Required demonstrations                       | Unsafe release, bad deployment, suspicious traffic                       |
| Customer-managed delivery                     | Offline bundle, verification, diagnostics and deployment model           |
| AI usage                                      | Tool usage and verified/rejected suggestion documented                   |

---

## Final Flow

The implementation focuses on a coherent and reproducible DevSecOps path:

```text
Source
  │
  ▼
Build & Test
  │
  ▼
Security Gates
  │
  ├── Vulnerability
  ├── Secret
  └── Configuration
  │
  ▼
SBOM + Artifact Trust
  │
  ▼
Secure Deployment
  │
  ▼
Runtime Security
  │
  ├── Tenant Policy
  ├── Rate Limiting
  └── Private Network
  │
  ▼
Observability
  │
  ├── Metrics
  ├── Alerts
  └── Security Telemetry
  │
  ▼
Detection
  │
  ▼
Rollback
```

The goal is not to demonstrate the largest number of tools, but to show how the controls work together to create a secure, reproducible, observable, and recoverable release workflow.











