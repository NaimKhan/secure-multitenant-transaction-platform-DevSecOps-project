# Secure Multi-Tenant Transaction Platform — DevSecOps

A reproducible DevSecOps implementation for a secure, multi-tenant transaction platform running on Docker Swarm.

The project demonstrates:

* Multi-tenant edge security
* Network isolation
* Secure CI/CD and supply-chain controls
* Secret management and least privilege
* SBOM generation and vulnerability auditing
* Automated health checks and rollback
* Suspicious traffic detection
* Customer-managed / air-gapped delivery
* Reproducible setup, demos, teardown, and offline packaging

---

## 1. Start Here — Reviewer Quick Guide

### Prerequisites

* Linux host / Ubuntu recommended
* Docker Engine with Swarm support
* Docker Compose
* Git
* `make`
* `jq` for local SBOM inspection
* Internet access for the normal development workflow

Clone the repository:

```bash
git clone git@github.com:NaimKhan/secure-multitenant-transaction-platform-DevSecOps-project.git
cd secure-multitenant-transaction-platform-DevSecOps-project
```

Start the platform:

```bash
make up
```

Run the required assessment demonstrations:

```bash
make demo-unsafe-release
make demo-bad-deploy
make demo-suspicious-traffic
```

Prometheus:

```text
http://localhost:9090
```

Create the restricted-connectivity/offline delivery bundle:

```bash
make bundle
```

Stop and clean up:

```bash
make down
```

### Reviewer Flow

```text
make up
   │
   ├── demo-unsafe-release
   ├── demo-bad-deploy
   ├── demo-suspicious-traffic
   │
   ├── Prometheus → http://localhost:9090
   │
   ├── make bundle
   │
   └── make down
```

The main implementation and configuration are source-controlled, so the reviewer can reproduce the environment without relying on undocumented manual setup.

---

# 2. Assessment Problem → Implementation

| Assessment Area               | Implementation                                                                   |
| ----------------------------- | -------------------------------------------------------------------------------- |
| Multi-tenancy & Edge Security | Traefik validates `X-Tenant-ID` for `Alpha` and `Beta`                           |
| Rate Limiting                 | 10 requests/sec with burst 5                                                     |
| Network Isolation             | Docker Swarm `private-backend` overlay network                                   |
| Least Privilege               | Application containers run as UID/GID `10001:10001`                              |
| Secrets                       | Docker Swarm Secrets mounted under `/run/secrets/`                               |
| Supply Chain Security         | Trivy, Gitleaks, CycloneDX SBOM, Cosign, immutable image digests                 |
| Runtime Resilience            | Swarm healthchecks with update and rollback configuration                        |
| Bad Deployment Detection      | Healthcheck detects HTTP 500 and triggers configured rollback behavior           |
| Suspicious Traffic            | Unauthorized tenants return `403`; excessive traffic returns `429`               |
| Observability                 | Prometheus metrics and alert rules                                               |
| Restricted Connectivity       | Offline bundle with images, manifests, SBOMs, checksums and verification helpers |
| Reproducibility               | Makefile-based setup, demos, teardown and packaging                              |

---

# 3. System Architecture

## 3.1 CI/CD & Supply-Chain Flow

```text
Developer Push
      │
      ▼
GitHub Actions
      │
      ├── Gitleaks
      │     └── Secret / private-key detection
      │
      ├── Build
      │
      ├── Trivy
      │     ├── Vulnerability scanning
      │     ├── Secret scanning
      │     └── Configuration scanning
      │
      ├── CycloneDX SBOM
      │
      ├── Immutable Image Digest
      │
      └── Cosign / Sigstore Signing
                │
                ▼
              GHCR
```

The release pipeline creates traceable artifacts and applies security gates before release.

---

## 3.2 Runtime Request Flow

```text
External Client
      │
      │ HTTP :80
      ▼
┌─────────────────────────────┐
│ Traefik Edge Gateway        │
│                             │
│ • X-Tenant-ID validation    │
│ • Alpha / Beta tenants      │
│ • Rate limit: 10 req/s      │
│ • Burst: 5                  │
│ • Access/security telemetry │
└──────────────┬──────────────┘
               │
               │ private-backend
               ▼
┌─────────────────────────────┐
│ Private Multi-Tenant API    │
│                             │
│ • Search / Transfer APIs    │
│ • UID/GID 10001:10001       │
│ • Swarm Secrets             │
│ • Healthcheck               │
└──────────────┬──────────────┘
               │
               ▼
          Prometheus
```

The backend services are isolated behind the edge gateway using the Docker Swarm `private-backend` overlay network.

---

# 4. Security Architecture

## 4.1 Multi-Tenant Edge Security

The edge gateway validates the `X-Tenant-ID` request header.

Allowed tenants:

```text
Alpha
Beta
```

Requests without a valid tenant identity are rejected.

Example behavior:

```text
Alpha          → 200
Beta           → 200
Missing Header → 403
MaliciousCorp  → 403
Excessive Burst → 429
```

Rate limiting:

```text
10 requests/sec
Burst: 5
```

---

## 4.2 Network Isolation

Backend services communicate through the dedicated Docker Swarm overlay network:

```text
private-backend
```

The intended traffic path is:

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
API Services
```

This keeps application services behind the edge layer rather than exposing them directly.

---

## 4.3 Least Privilege

Application containers do not run as root.

Configured application identity:

```text
UID: 10001
GID: 10001
```

The implementation also uses restricted container capabilities and network isolation where applicable.

---

## 4.4 Secrets Management

Sensitive application configuration is stored using Docker Swarm Secrets.

Secrets are exposed to the application through:

```text
/run/secrets/
```

Secrets are therefore kept outside the application image and source code.

---

# 5. Secure CI/CD & Supply Chain

The GitHub Actions pipeline includes multiple security controls:

```text
Source
  │
  ├── Gitleaks
  │
  ├── Docker Build
  │
  ├── Trivy
  │    ├── Vulnerabilities
  │    ├── Secrets
  │    └── Configuration
  │
  ├── CycloneDX SBOM
  │
  ├── Immutable Image Digest
  │
  └── Cosign Signing
```

### Important distinction

Trivy is used for:

* Vulnerability scanning
* Secret scanning
* Configuration scanning

Gitleaks is used as an additional secret-detection/security gate, particularly demonstrated through the unsafe-release scenario.

---

# 6. SBOM & Software Composition Audit

SBOMs provide visibility into the software components contained in a release.

This project uses CycloneDX SBOM generation and supports both CI/CD and independent local auditing.

## 6.1 CI/CD SBOM

The release pipeline generates a CycloneDX SBOM as part of the build/release process.

The SBOM provides component-level information that can be used for:

* Dependency visibility
* Vulnerability investigation
* Release traceability
* Customer-side software composition review

---

## 6.2 Manual Local SBOM Generation

A fresh SBOM can also be generated independently from the local image.

### Step A — Generate CycloneDX SBOM

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  anchore/syft:latest axiler/api-service:v1.0.0 \
  -o cyclonedx-json > app-sbom.cyclonedx.json
```

This generates a CycloneDX JSON SBOM from the local container image.

---

### Step B — Audit the SBOM with Trivy

```bash
docker run --rm \
  -v $(pwd):/path \
  aquasec/trivy:latest \
  sbom /path/app-sbom.cyclonedx.json
```

This scans the generated SBOM and provides a human-readable vulnerability report, including OS and Python package vulnerabilities.

---

### Step C — Inspect Components

```bash
cat app-sbom.cyclonedx.json \
  | jq '.components[] | {name: .name, version: .version}' \
  | head -n 30
```

This provides a quick component/version view of the generated SBOM.

---

## 6.3 Vulnerability Policy

The GitHub CI/CD release gate hard-blocks releases on **CRITICAL** severity CVEs.

Independent local/offline SBOM auditing provides visibility into:

```text
CRITICAL
HIGH
MEDIUM
LOW
```

This allows lower-severity vulnerabilities to be tracked for patch planning even when they do not block the release.

---

# 7. Runtime Services & Verification

The runtime environment can be inspected directly through Docker Swarm.

List services:

```bash
docker service ls
```

Inspect service tasks:

```bash
docker service ps axiler-stack_api-service
```

Inspect service configuration:

```bash
docker service inspect axiler-stack_api-service
```

View service logs:

```bash
docker service logs -f axiler-stack_api-service
```

Inspect running containers:

```bash
docker ps
```

Inspect networks:

```bash
docker network ls
```

Inspect the private backend network:

```bash
docker network inspect private-backend
```

These commands provide a direct troubleshooting path from service state → task/replica state → configuration → logs → network state.

---

# 8. Required Demonstration Scenarios

## 8.1 Unsafe Release — Secret Detection

Run:

```bash
make demo-unsafe-release
```

The demo intentionally introduces an RSA private key/secret into the release path.

Expected behavior:

```text
Unsafe change
     │
     ▼
Gitleaks detection
     │
     ▼
Security gate fails
     │
     ▼
Release blocked
```

This demonstrates that a detected secret does not proceed through the intended release path.

---

## 8.2 Bad Deployment — Automatic Recovery

Run:

```bash
make demo-bad-deploy
```

The demonstration deploys:

```text
v1.0.1-degraded
```

The degraded release returns:

```text
HTTP 500
```

The Swarm healthcheck detects the unhealthy deployment and the configured rollback policy returns the service to the healthy release:

```text
v1.0.1-degraded
       │
       │ HTTP 500
       ▼
Healthcheck failure
       │
       ▼
Swarm rollback
       │
       ▼
Healthy v1.0.0
```

Rollback behavior follows the deployment configuration defined in the repository.

---

## 8.3 Suspicious / Unauthorized Traffic

Run:

```bash
make demo-suspicious-traffic
```

Expected results:

```text
Valid Alpha tenant       → 200
Valid Beta tenant        → 200
Missing tenant           → 403
Unauthorized tenant      → 403
Excessive request burst  → 429
```

This demonstrates:

* Tenant identity enforcement
* Unauthorized access rejection
* Rate limiting
* Security telemetry

---

# 9. Observability & Detection

Prometheus is included for runtime monitoring.

Open:

```text
http://localhost:9090
```

Example application metric:

```promql
http_requests_total{tenant="Alpha", version="v1.0.0"}
```

Configured alert rules include:

```text
HighErrorRate
TenantUnauthorizedAbuseAttempt
```

The monitoring model supports investigation from:

```text
Metric / Alert
      │
      ▼
Service State
      │
      ▼
Task / Replica Status
      │
      ▼
Application Logs
      │
      ▼
Deployment Configuration
      │
      ▼
Continue Monitoring / Rollback
```

---

# 10. Customer-Managed / Air-Gapped Delivery

The platform supports a restricted-connectivity deployment model where the customer may have limited or no direct access to external CI/CD systems or public container registries.

Create the offline package:

```bash
make bundle
```

The package is designed to contain the release artifacts required for controlled customer-side deployment, including:

* Container images
* Deployment manifests
* CycloneDX SBOMs
* SHA256 checksums
* Release/signature verification material
* Deployment/verification helpers

The detailed operational procedure is documented in:

```text
docs/RESTRICTED_DELIVERY.md
```

---

## 10.1 Release Trust Model

```text
Vendor CI/CD
     │
     ▼
Signed Release
     │
     ▼
Offline Release Bundle
     │
     ├── Images
     ├── Manifests
     ├── SBOM
     ├── Checksums
     └── Signatures
     │
     ▼
Secure Transfer
     │
     ▼
Customer Bastion
     │
     ├── SHA256 verification
     └── Cosign verification
     │
     ▼
Internal Registry / Artifact Store
     │
     ▼
Docker Swarm Cluster
     │
     ▼
Traefik → Private Backend → API
```

This model gives the customer a controlled way to verify that the delivered package is intact and originates from the expected release process before installation.

---

# 11. Offline Verification

Integrity can be checked using SHA256:

```bash
sha256sum -c checksums.sha256
```

Where a Cosign-signed artifact is provided, authenticity can be verified using the vendor/public verification key:

```bash
cosign verify-blob \
  --key cosign.pub \
  --signature bundle.sig \
  axiler-release-v1.0.0-offline.tar.gz
```

Expected verification flow:

```text
Offline Release Bundle
        │
        ▼
SHA256 Integrity Check
        │
        ▼
Cosign Authenticity Check
        │
        ▼
Verification Successful
        │
        ▼
Installation / Deployment
```

---

# 12. Restricted-Connectivity Diagnostics

Customer-side operators can investigate service issues without external connectivity.

Service status:

```bash
docker service ps axiler-stack_api-service
```

Service configuration:

```bash
docker service inspect axiler-stack_api-service
```

Service logs:

```bash
docker service logs -f axiler-stack_api-service
```

Export deployment diagnostics:

```bash
docker service inspect axiler-stack_api-service > diagnostic-report.json
```

Running containers:

```bash
docker ps
```

Container inspection:

```bash
docker inspect <container_id>
```

### Incident Investigation Flow

```text
Service Alert / User Report
          │
          ▼
Check Service State
          │
          ▼
Check Task / Replica Status
          │
          ▼
Inspect Logs
          │
          ▼
Inspect Deployment Configuration
          │
      ┌───┴────┐
      ▼        ▼
   Healthy   Unhealthy
      │        │
      ▼        ▼
 Continue   Rollback
 Monitoring
      │        │
      └───┬────┘
          ▼
   Export Diagnostics
```

---

# 13. Example Offline Release Structure

A typical offline release package can be organized as:

```text
axiler-release-v1.0.0-offline/
├── images/
│   └── api-service.tar
├── sbom/
│   └── app-sbom.cyclonedx.json
├── manifests/
│   └── docker-compose.yml
├── security/
│   ├── checksums.sha256
│   ├── bundle.sig
│   └── cosign.pub
└── scripts/
    ├── install.sh
    └── verify.sh
```

The exact generated contents should be verified from the bundle produced by:

```bash
make bundle
```

---

# 14. Enterprise Air-Gapped Deployment Model

```text
Vendor CI/CD
      │
      ▼
Signed Release
      │
      ▼
Offline Bundle
      │
      ├── Container Images
      ├── SBOM
      ├── Signatures
      ├── Checksums
      └── Manifests
      │
      ▼
Secure Transfer
      │
      ▼
Customer Bastion
      │
      ├── Verify SHA256
      └── Verify Cosign
      │
      ▼
Internal Registry / Artifact Store
      │
      ▼
Docker Swarm
      │
      ▼
Traefik
      │
      ▼
Private Backend Network
      │
      ▼
API Services
```

This supports controlled upgrades, release verification, rollback, and offline diagnostics in environments with restricted external connectivity.

---

# 15. Reproducibility & Configuration as Code

The project is designed so that setup, demonstrations, teardown and offline packaging are driven through source-controlled configuration and Makefile commands.

Primary operations:

```bash
make up
make demo-unsafe-release
make demo-bad-deploy
make demo-suspicious-traffic
make bundle
make down
```

The intended workflow minimizes hidden manual configuration.

When troubleshooting, the reviewer can start with:

```text
Makefile
docker/compose/swarm configuration
observability/
docs/RESTRICTED_DELIVERY.md
```

and then inspect the corresponding runtime state using Docker commands.

---

# 16. Repository Structure

```text
.
├── .github/
│   └── workflows/
│       └── ...
├── observability/
│   └── alerts.yml
├── docs/
│   └── RESTRICTED_DELIVERY.md
├── Makefile
├── Dockerfile
├── docker-compose.yml
├── deploy/
│   └── ...
├── scripts/
│   └── ...
└── README.md
```

The exact repository contents can be inspected directly from the source tree.

---

# 17. Security & Reliability Controls

### Implemented

* Tenant validation at the edge
* Request rate limiting
* Private backend overlay network
* Non-root application containers
* Docker Swarm Secrets
* Healthchecks
* Configured deployment rollback
* Trivy vulnerability/secret/configuration scanning
* Gitleaks secret detection
* CycloneDX SBOM
* Cosign/Sigstore signing
* Immutable image digests
* Prometheus monitoring
* Security/abuse alerting
* Offline release packaging
* SHA256 integrity verification
* Customer-side release verification
* Offline diagnostics

---

# 18. Known Gaps / Design Boundaries

This assessment focuses on a coherent working DevSecOps slice rather than a production-scale platform.

Areas that would require further production hardening include:

* Full enterprise identity and centralized authorization
* Production-grade secret-management integration such as an external secrets manager
* HA control-plane architecture beyond the assessment environment
* Enterprise SIEM integration
* Full customer-side internal registry implementation
* Formal key rotation and long-term signing-key lifecycle
* Extended disaster-recovery automation

These are intentionally separated from the controls demonstrated by the working implementation.

---

# 19. AI Usage

AI assistance was used for:

* Initial configuration bootstrapping
* Bash and Makefile scaffolding
* Documentation structuring

One security-related AI suggestion was explicitly rejected during implementation.

The initial suggestion was to mount the Docker socket directly into an application container with root privileges.

That approach was rejected because it would unnecessarily increase the container's privilege and attack surface.

The implemented design instead uses:

* Non-root application identity `10001:10001`
* Docker Swarm Secrets
* Private backend network isolation
* Restricted read-only Docker socket access only where required by the edge component

The resulting implementation was reviewed and corrected against the assessment requirements rather than accepting generated suggestions without verification.

---

# 20. Assessment Traceability

| Requirement            | Where to Verify                         |
| ---------------------- | --------------------------------------- |
| Reproducible setup     | `Makefile`, `make up`                   |
| Secure release         | `.github/workflows/`                    |
| Secret detection       | Gitleaks / `make demo-unsafe-release`   |
| Vulnerability scanning | Trivy configuration in CI               |
| SBOM                   | CycloneDX generation                    |
| Local SBOM audit       | Syft + Trivy commands in this README    |
| Multi-tenancy          | Traefik configuration                   |
| Rate limiting          | Traefik configuration                   |
| Network isolation      | `private-backend` overlay               |
| Least privilege        | UID/GID `10001:10001`                   |
| Secrets                | Docker Swarm Secrets                    |
| Bad deployment         | `make demo-bad-deploy`                  |
| Rollback               | Swarm update/rollback configuration     |
| Suspicious traffic     | `make demo-suspicious-traffic`          |
| Observability          | Prometheus + `observability/alerts.yml` |
| Air-gapped delivery    | `make bundle`                           |
| Release integrity      | SHA256 verification                     |
| Release authenticity   | Cosign verification                     |
| Offline diagnostics    | `docs/RESTRICTED_DELIVERY.md`           |
| AI usage disclosure    | Section 19                              |

---

# 21. Final Verification Flow

```text
                    ┌──────────────────────┐
                    │   Developer Push     │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │    GitHub Actions    │
                    ├──────────────────────┤
                    │ Gitleaks             │
                    │ Trivy                │
                    │ SBOM                 │
                    │ Image Build          │
                    │ Cosign Signing       │
                    └──────────┬───────────┘
                               │
                               ▼
                         Trusted Image
                               │
                               ▼
                    ┌──────────────────────┐
                    │   Traefik Gateway    │
                    │ Tenant + Rate Limit  │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │  Private Backend     │
                    │   Overlay Network    │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │      API Service     │
                    │ Non-root + Secrets   │
                    │ Healthcheck           │
                    └──────────┬───────────┘
                               │
                    ┌──────────┴──────────┐
                    ▼                     ▼
               Prometheus             Rollback
                    │                     │
                    ▼                     ▼
              Monitoring           Healthy Release


Reviewer:
    │
    ├── make up
    ├── make demo-unsafe-release
    ├── make demo-bad-deploy
    ├── make demo-suspicious-traffic
    ├── Inspect Prometheus
    ├── make bundle
    └── make down
```

---

## Conclusion

This repository demonstrates a reproducible DevSecOps workflow covering secure release engineering, software supply-chain visibility, multi-tenant runtime security, deployment resilience, observability, and customer-managed restricted-connectivity delivery.

The implementation prioritizes a working, reviewable slice with clear verification points rather than relying on controls that exist only in documentation.

