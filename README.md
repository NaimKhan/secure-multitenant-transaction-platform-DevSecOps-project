# Secure Multi-Tenant Transaction Platform — DevSecOps Lab

A locally reproducible DevSecOps implementation demonstrating secure delivery, software supply-chain controls, multi-tenant runtime security, deployment safety, observability, and rollback on Docker Swarm.

---

## 🚀 Start Here

If you are reviewing this repository, the main implementation can be verified without reading the entire README.

### 1. Clone

```bash
git clone git@github.com:NaimKhan/secure-multitenant-transaction-platform-DevSecOps-project.git
cd secure-multitenant-transaction-platform-DevSecOps-project
```

### 2. Start the platform

```bash
make up
```

This starts the application stack on Docker Swarm.

### 3. Run the required security/reliability demos

```bash
make demo-unsafe-release
make demo-bad-deploy
make demo-suspicious-traffic
```

### 4. Check observability

Prometheus:

```text
http://localhost:9090
```

Application metrics include tenant and release information, for example:

```text
http_requests_total{tenant="Alpha",version="v1.0.0"}
```

### 5. Test the offline delivery bundle

```bash
make bundle
```

The generated bundle contains the release artifacts, deployment definitions, SBOMs, checksums, and deployment helpers.

### 6. Stop the environment

```bash
make down
```

---

# 1. Assessment Requirements → Implementation

The implementation is organized around the problems described in the assessment.

| Assessment Problem                          | Solution                                                                                                                      | Where to Look                              |
| ------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------ |
| Multi-tenant API access                     | Tenant identity is passed through `X-Tenant-ID` and validated at the controlled edge                                          | Traefik / edge configuration               |
| Tenant isolation                            | Only supported tenants such as `Alpha` and `Beta` are accepted; invalid tenants are rejected before reaching private services | Edge middleware/config                     |
| Public vs private network boundary          | External traffic enters through Traefik; backend services use a private Docker Swarm overlay network                          | `docker-stack.yml` / network configuration |
| Unsafe code/artifact should not be released | CI security gates scan for vulnerabilities, secrets, and configuration issues                                                 | `.github/workflows/`, Trivy, Gitleaks      |
| Artifact trust                              | Images are built, scanned, SBOMs are generated, and release artifacts are signed/verified                                     | CI/CD and release configuration            |
| Secrets must not be committed               | Runtime secrets are provided through Docker Swarm Secrets                                                                     | `secrets/` / stack configuration           |
| Containers should not run as root           | Application containers use UID/GID `10001:10001`                                                                              | Dockerfiles                                |
| Bad deployment must be detected             | Healthchecks and runtime metrics expose degraded releases                                                                     | Swarm configuration + Prometheus           |
| Bad release must be recoverable             | Swarm update/rollback configuration provides predictable rollback behavior                                                    | `docker-stack.yml`                         |
| Suspicious traffic must be controlled       | Tenant validation and rate limiting reject unauthorized or abusive requests                                                   | Traefik configuration                      |
| Operator needs useful signals               | Prometheus metrics identify request activity, tenant, and application version                                                 | `observability/`                           |
| Operational problems should trigger alerts  | Alerts cover high error rates and unauthorized tenant activity                                                                | `observability/alerts.yml`                 |
| Environment should be reproducible          | Setup, demos, teardown, and offline packaging are exposed through Make targets                                                | `Makefile`                                 |
| Customer may have restricted connectivity   | Offline-style release bundle supports controlled customer-managed delivery                                                    | `docs/RESTRICTED_DELIVERY.md`              |

---

# 2. Architecture

The platform follows this delivery path:

```text
Source Code
    │
    ▼
CI / Build
    │
    ├── Tests
    ├── Trivy
    │     ├── Vulnerability
    │     ├── Secret
    │     └── Configuration scanning
    ├── Gitleaks
    ├── SBOM
    └── Artifact Trust
    │
    ▼
Trusted Release Artifact
    │
    ▼
Docker Swarm
    │
    ▼
Traefik Edge
    │
    ├── Tenant validation
    ├── Rate limiting
    └── Security telemetry
    │
    ▼
Private Backend Network
    │
    ├── Search
    ├── Transfer
    └── Health
    │
    ▼
Prometheus / Alerts
```

The important trust boundary is between the external client and the private application network. Backend services are not intended to be directly exposed to external clients.

---

# 3. Security Design

### Tenant and Edge Security

The controlled edge is responsible for the first layer of request policy.

* `X-Tenant-ID` identifies the requested tenant.
* Supported tenants include `Alpha` and `Beta`.
* Missing or unauthorized tenant identities are rejected.
* Rate limiting is configured at approximately **10 requests/second with a burst of 5**.
* Rejected requests remain visible through runtime/security telemetry.

Example:

```text
Client
  │
  ▼
Traefik
  │
  ├── Tenant validation
  ├── Rate limit
  └── Request policy
       │
       ▼
Private Backend Network
```

### Container Security

* Application containers run as non-root UID/GID `10001:10001`.
* Backend services are placed on a private Docker Swarm overlay network.
* Runtime secrets are provided through Docker Swarm Secrets under `/run/secrets/`.
* Docker socket access is avoided for application containers; where required by the edge component, access is restricted/read-only.

---

# 4. Secure CI/CD & Supply Chain

The release pipeline follows:

```text
Source
  → Build
  → Test
  → Security Gates
  → SBOM
  → Trusted Artifact
  → Deployment
```

### Security Gates

Trivy is used for:

* Vulnerability scanning
* Secret scanning
* Configuration scanning

Gitleaks is used for the unsafe-release demonstration and detects intentionally introduced secrets/private keys.

A failing security condition can block the release.

### SBOM

An SBOM is generated for the release artifact using a standard machine-readable format.

This provides visibility into the software components included in the release and supports customer-side verification.

### Artifact Integrity

Release artifacts are associated with integrity information such as:

* Image identity
* SBOM
* Checksums
* Signing/verification metadata

Deployment should use immutable artifact identity where practical instead of relying only on mutable tags.

---

# 5. Required Demonstration Scenarios

The assessment specifically asks for three repeatable scenarios.

## A. Unsafe Release

Run:

```bash
make demo-unsafe-release
```

The demo introduces an intentionally unsafe condition.

Expected result:

```text
Unsafe condition
      ↓
Security scan / policy gate
      ↓
Release blocked
```

This demonstrates that security controls are enforced as part of delivery rather than existing only as documentation.

---

## B. Bad Deployment

Run:

```bash
make demo-bad-deploy
```

A deliberately degraded application version such as:

```text
v1.0.1-degraded
```

returns HTTP `500`.

The healthy release is:

```text
v1.0.0
```

Expected flow:

```text
Bad Release
    ↓
Health / error signal
    ↓
Deployment degradation detected
    ↓
Configured rollback behavior
    ↓
Healthy release restored
```

---

## C. Suspicious / Unauthorized Traffic

Run:

```bash
make demo-suspicious-traffic
```

Example expected behavior:

| Request                 | Expected |
| ----------------------- | -------: |
| Alpha tenant            |    `200` |
| Beta tenant             |    `200` |
| Missing tenant          |    `403` |
| Unauthorized tenant     |    `403` |
| Excessive request burst |    `429` |

The objective is not only to deny the request, but also to leave enough telemetry to investigate the activity.

---

# 6. Observability & Detection

Prometheus is included for runtime visibility.

```text
http://localhost:9090
```

Application metrics include:

```text
http_requests_total{tenant="Alpha",version="v1.0.0"}
```

This allows an operator to correlate:

* Which tenant was affected
* Which application version was running
* Whether errors increased
* Whether traffic was rejected
* Whether a deployment introduced degradation

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

# 7. Deployment & Rollback

The application is deployed using Docker Swarm.

Deployment configuration includes:

* Healthchecks
* Restart behavior
* Update configuration
* Rollback configuration
* Service/network boundaries
* Resource configuration

The objective is to make deployment behavior predictable when a new release becomes unhealthy.

Rollback behavior is demonstrated through:

```bash
make demo-bad-deploy
```

---

# 8. Customer-Managed / Restricted-Connectivity Delivery

The assessment also asks how the same release could be delivered into a customer-controlled environment with limited or no direct connectivity to external CI systems or registries.

This implementation includes an offline-style bundle:

```bash
make bundle
```

The bundle is designed to contain:

* Container images
* Docker/Swarm deployment definitions
* SBOMs
* SHA256 checksums
* Release/version metadata
* Deployment helpers

The intended customer flow is:

```text
Vendor Release
     │
     ▼
Signed / Checksum-verified Bundle
     │
     ▼
Customer Verification
     │
     ▼
Offline Import
     │
     ▼
Deploy
     │
     ├── Upgrade
     └── Rollback
```

Detailed design:

```text
docs/RESTRICTED_DELIVERY.md
```

The document also describes version tracking, verification, controlled upgrades, rollback, and diagnostics.

---

# 9. Repository Structure

```text
.
├── .github/
│   └── workflows/              # CI/CD and security gates
├── app/                         # Application services
├── deploy/                      # Docker/Swarm deployment configuration
├── observability/               # Prometheus and alert configuration
├── scripts/                     # Demo and operational scripts
├── docs/
│   └── RESTRICTED_DELIVERY.md  # Customer-managed delivery design
├── Dockerfile*
├── docker-stack.yml
├── Makefile
└── README.md
```

The exact implementation can be explored from the paths above.

---

# 10. Makefile Operations

The main reviewer commands are:

```bash
make up
make down

make demo-unsafe-release
make demo-bad-deploy
make demo-suspicious-traffic

make bundle
```

The Makefile keeps common operations reproducible and minimizes hidden manual setup.

---

# 11. Known Gaps & Production Improvements

This assessment is intentionally scoped to a small, locally reproducible environment.

Before production, I would further improve:

* Production-grade identity/workload authentication
* Centralized secret management such as Vault or a cloud-native equivalent
* Stronger CI identity and short-lived credentials
* Production-grade artifact registry controls
* Centralized logging and security monitoring
* More comprehensive tenant authorization policies
* Production PKI and certificate lifecycle management
* Highly available/multi-region deployment where required
* Formalized incident response and compliance controls

These are intentionally identified as future improvements rather than presented as implemented controls.

---

# 12. AI Usage

AI coding assistance was used for initial configuration bootstrapping and Bash scaffolding.

One AI-generated suggestion was to mount the Docker socket directly into the application container with root-level access.

That approach was rejected.

The implementation instead uses:

* Non-root application containers
* Restricted/read-only socket access only where required by the edge component
* Docker Swarm Secrets
* Private overlay networking
* Explicit service boundaries

This was manually reviewed and adjusted based on the required security model.

---

# 13. Assessment Traceability

| Assessment Area                               | Implementation                                                         |
| --------------------------------------------- | ---------------------------------------------------------------------- |
| 3.1 Application, tenancy & network boundaries | Traefik, tenant validation, private overlay network                    |
| 3.2 Secure CI/CD & supply chain               | CI gates, Trivy, Gitleaks, SBOM, artifact integrity                    |
| 3.3 Secrets, identity & least privilege       | Swarm Secrets, non-root containers, restricted access                  |
| 3.4 Deployment & rollback                     | Swarm healthchecks, update/rollback configuration, bad deployment demo |
| 3.5 Observability & detection                 | Prometheus metrics, alerts, tenant/version visibility                  |
| 3.6 Reproducibility                           | Makefile-driven setup, demos, teardown and bundle generation           |
| Required scenarios                            | Unsafe release, bad deployment, suspicious traffic                     |
| Restricted connectivity                       | Offline-style release bundle + design document                         |

---

## Final Note

The implementation intentionally focuses on a **small, reproducible working slice** rather than a large application.

The main engineering goal is to demonstrate a defensible path:

```text
Source
 → Security Gates
 → Trusted Artifact
 → Secure Deployment
 → Runtime Protection
 → Observability
 → Detection
 → Rollback
```

The repository is designed so that a reviewer can run the core workflow first and then inspect the individual security, deployment, and operational decisions as needed.

