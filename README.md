# Customer-Managed & Restricted / Air-Gapped Environment Delivery Design

## Overview

This document specifies the architecture and operational guidelines for delivering the **Axiler Transaction Platform** into customer-managed, restricted, or fully air-gapped environments.

In these environments, the production platform may have no direct internet connectivity and therefore cannot depend on external container registries, CI/CD systems, or internet-based observability services.

The delivery model provides a **self-contained, verifiable, and repeatable release process** using signed offline artifacts, integrity verification, container image packaging, declarative deployment manifests, SBOMs, and controlled rollback procedures.

---

## 1. Release Packaging & Trust Verification

In an air-gapped environment, the platform cannot directly reach external registries such as **GHCR** or **Docker Hub**, nor can it communicate with external CI/CD infrastructure.

Therefore, releases are packaged into a self-contained offline bundle using:

```bash
make bundle
```

Example release artifact:

```text
axiler-release-v1.0.0-offline.tar.gz
```

### 1.1 Bundle Contents

The offline release bundle contains the following artifacts:

| Component                  | Description                                             |
| -------------------------- | ------------------------------------------------------- |
| Container Image Tarballs   | Gzip-compressed Docker images such as `api-service.tar` |
| Software Bill of Materials | Machine-readable CycloneDX JSON SBOM                    |
| Declarative Manifests      | Docker Swarm stack / Compose deployment definitions     |
| Integrity Information      | SHA256 checksum manifest                                |
| Authenticity Information   | Cosign signature and public-key verification materials  |
| Operational Helpers        | Offline installation and verification scripts           |

Example bundle contents:

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

> The exact generated bundle structure should match the output produced by the repository's `make bundle` implementation.

### 1.2 Customer Verification Procedure

Before executing any installation or deployment step, the customer should verify the integrity and authenticity of the received release artifacts on an approved bastion or administration host.

#### Step 1 — Verify SHA256 Integrity

```bash
sha256sum -c checksums.sha256
```

This verifies that the release artifacts have not been modified or corrupted during transfer.

#### Step 2 — Verify Cosign Signature

Using the vendor-provided public key:

```bash
cosign verify-blob \
  --key cosign.pub \
  --signature bundle.sig \
  axiler-release-v1.0.0-offline.tar.gz
```

A successful verification confirms that the release bundle was signed using the corresponding trusted signing key.

### 1.3 Release Trust Flow

```text
                  Offline Release Bundle
                           │
                           ▼
                 ┌──────────────────┐
                 │  SHA256 Verify   │
                 │    Integrity     │
                 └────────┬─────────┘
                          │
                          ▼
                 ┌──────────────────┐
                 │  Cosign Verify   │
                 │   Authenticity   │
                 └────────┬─────────┘
                          │
                    Verification
                       Passed
                          │
                          ▼
                 ┌──────────────────┐
                 │    Installation  │
                 │    / Deployment  │
                 └──────────────────┘
```

---

# 2. Air-Gapped Installation & Controlled Upgrade Strategy

## 2.1 Initial Installation

The initial deployment is performed entirely from the verified offline release bundle.

### Step 1 — Extract the Release Bundle

```bash
tar -xzf axiler-release-v1.0.0-offline.tar.gz
cd axiler-release-v1.0.0-offline
```

### Step 2 — Load Container Images

Load the packaged container image into the local Docker environment:

```bash
docker load -i api-service.tar
```

For larger customer-managed environments, the image may instead be imported into an internal air-gapped container registry.

### Step 3 — Initialize Docker Swarm Secrets

Sensitive credentials must not be embedded into application images or committed directly into deployment manifests.

Example:

```bash
docker secret create db_password \
  - < /path/to/secure/db_password
```

### Step 4 — Deploy the Stack

```bash
docker stack deploy \
  -c docker-compose.yml \
  axiler-stack
```

Verify the deployed services:

```bash
docker service ls
```

and:

```bash
docker service ps axiler-stack_api-service
```

---

## 2.2 Controlled Upgrade Strategy

For a new release, the customer receives a new offline release bundle through the approved secure transfer process.

Example:

```text
Current Release
     │
     ▼
v1.0.0
     │
     │  New Offline Release
     ▼
v1.1.0 Bundle
     │
     ├── SHA256 Verification
     ├── Cosign Verification
     ├── Image Import
     └── Controlled Deployment
              │
              ▼
         Rolling Update
```

### Load the New Image

```bash
docker load -i api-service-v1.1.0.tar
```

### Trigger a Controlled Rolling Update

```bash
docker service update \
  --image axiler/api-service:v1.1.0 \
  --update-parallelism 1 \
  --update-delay 5s \
  axiler-stack_api-service
```

The controlled update strategy limits the number of tasks updated simultaneously and introduces a delay between updates, reducing the risk of a full-service outage during deployment.

### Verify the Updated Service

```bash
docker service ps axiler-stack_api-service
```

and:

```bash
docker service inspect axiler-stack_api-service
```

Application-level health and expected service behavior should also be validated after the upgrade.

---

# 3. Offline Rollback & Diagnostics

## 3.1 Rollback Procedure

If the newly deployed release experiences runtime issues or health-check failures, the deployment can be reverted using Docker Swarm rollback mechanisms.

### Automated Rollback

Docker Swarm's `rollback_config` can automatically revert a failed deployment according to the configured health-check and rollback policy.

The actual rollback timing depends on the configured:

* Health-check interval
* Health-check timeout
* Failure threshold
* `update_config`
* `rollback_config`

Therefore, the rollback behavior should be validated in the target customer environment before production rollout.

### Manual Rollback

Operators can manually revert the service to its previous version:

```bash
docker service rollback axiler-stack_api-service
```

Verify the resulting service state:

```bash
docker service ps axiler-stack_api-service
```

---

## 3.2 Diagnostics & Troubleshooting

Air-gapped environments cannot rely on external observability platforms or internet-based troubleshooting services.

The following commands provide a basic offline diagnostic workflow.

### Check Service Health

```bash
docker service ps axiler-stack_api-service
```

### Inspect Service Configuration

```bash
docker service inspect axiler-stack_api-service
```

### Inspect Runtime Logs

```bash
docker service logs -f axiler-stack_api-service
```

### Export Diagnostic Telemetry

```bash
docker service inspect \
  axiler-stack_api-service \
  > diagnostic-report.json
```

Additional container-level information can be collected with:

```bash
docker ps
```

and:

```bash
docker inspect <container_id>
```

### Recommended Offline Incident Workflow

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
       ┌────┴────┐
       │         │
     Healthy   Unhealthy
       │         │
       ▼         ▼
 Continue      Rollback
 Monitoring       │
                  ▼
          Export Diagnostics
```

---

# 4. Security Considerations for Restricted Environments

Air-gapped deployment reduces external network dependencies but does not automatically make the environment secure.

The following controls should remain enforced throughout the release and operational lifecycle.

## 4.1 Artifact Integrity

Every release should contain:

* SHA256 checksums
* CycloneDX SBOM
* Cosign signature
* Trusted public key
* Versioned deployment manifests

Artifacts should be verified before installation.

## 4.2 Image Provenance

Container images should originate from the approved CI/CD supply chain.

Unverified or locally modified images should not be introduced into the production environment unless explicitly authorized by the customer's release-management process.

## 4.3 Secrets Management

Application secrets must be supplied through controlled secret-management mechanisms.

For the current Docker Swarm implementation:

```text
Docker Swarm Secrets
        │
        ▼
/run/secrets/<secret-name>
        │
        ▼
Application Container
```

Secrets must not be:

* Hard-coded in source code
* Stored inside Dockerfiles
* Embedded into container images
* Committed to Git
* Stored in publicly accessible configuration files

## 4.4 Network Isolation

The application should continue to use the defined internal network boundaries.

External traffic should enter through the approved edge gateway, while backend services remain isolated on the internal Docker Swarm overlay network.

---

# 5. Known Gaps & Recommended Production Improvements

The current implementation demonstrates the required DevSecOps controls while keeping the lab environment operationally lightweight.

For a larger enterprise production environment, the following improvements are recommended:

| Component             | Current Local / Demo Approach                                   | Recommended Production Improvement                                                               |
| --------------------- | --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| Secret Management     | Docker Swarm Secrets initialized through controlled CLI scripts | Integrate HashiCorp Vault or another customer-approved enterprise secrets manager                |
| Registry Management   | Direct `docker load` on Swarm nodes                             | Deploy an internal air-gapped registry such as Harbor or Nexus with controlled image replication |
| Policy Enforcement    | Traefik-based tenant/header validation                          | Add centralized policy enforcement and runtime admission controls where supported                |
| Image Trust           | Release-level Cosign verification                               | Enforce signed-image and provenance policies throughout the production supply chain              |
| Observability Storage | Local / ephemeral Prometheus storage                            | Configure durable metric storage and offline log aggregation                                     |
| Key Management        | Vendor/customer-managed signing materials                       | Integrate enterprise KMS/HSM where required                                                      |
| Access Control        | Host and Swarm-level administrative controls                    | Integrate centralized enterprise IAM/RBAC and privileged-access management                       |
| Disaster Recovery     | Application-level rollback                                      | Add customer-specific backup, restore, and disaster-recovery procedures                          |

---

# 6. Enterprise Air-Gapped Deployment Model

A mature customer-managed deployment can evolve toward the following architecture:

```text
                         Vendor CI/CD
                              │
                              │ Signed Release
                              ▼
                 ┌────────────────────────┐
                 │ Offline Release Bundle │
                 │                        │
                 │ • Container Images     │
                 │ • SBOM                 │
                 │ • Signatures           │
                 │ • Checksums            │
                 │ • Deployment Manifests │
                 └───────────┬────────────┘
                             │
                      Secure Transfer
                             │
                             ▼
                 ┌────────────────────────┐
                 │ Customer Bastion       │
                 │                        │
                 │ SHA256 Verification    │
                 │ Cosign Verification   │
                 └───────────┬────────────┘
                             │
                             ▼
                 ┌────────────────────────┐
                 │ Internal Registry      │
                 │ / Artifact Repository  │
                 └───────────┬────────────┘
                             │
                             ▼
                 ┌────────────────────────┐
                 │ Docker Swarm Cluster   │
                 │                        │
                 │  ┌──────────────────┐  │
                 │  │ Traefik Gateway  │  │
                 │  └────────┬─────────┘  │
                 │           │            │
                 │  ┌────────▼─────────┐  │
                 │  │ Private Backend  │  │
                 │  │ Overlay Network  │  │
                 │  └────────┬─────────┘  │
                 │           │            │
                 │  ┌────────▼─────────┐  │
                 │  │ API Services     │  │
                 │  └──────────────────┘  │
                 └────────────────────────┘
```

This model separates the **vendor release process** from the **customer runtime environment**, while preserving artifact integrity and software provenance throughout the delivery lifecycle.

---

# 7. Operational Checklist

## Release Verification

* [ ] Release version confirmed
* [ ] Offline bundle received through the approved channel
* [ ] SHA256 checksums verified
* [ ] Cosign signature verified
* [ ] Trusted public key confirmed
* [ ] SBOM present
* [ ] Deployment manifests present
* [ ] Required container images present

## Pre-Deployment

* [ ] Docker Swarm cluster is healthy
* [ ] Required secrets are available
* [ ] Required storage is available
* [ ] Required internal network connectivity is verified
* [ ] Previous healthy release is identified
* [ ] Maintenance/change window is approved

## Deployment

* [ ] Container images imported successfully
* [ ] Docker stack deployed
* [ ] Expected service replicas are running
* [ ] Health checks are passing
* [ ] Application endpoints are validated
* [ ] Tenant isolation is validated
* [ ] Monitoring and alerts are operational

## Post-Deployment

* [ ] Application functionality verified
* [ ] Runtime logs reviewed
* [ ] Metrics reviewed
* [ ] No unexpected errors observed
* [ ] Release version confirmed
* [ ] Required diagnostic information retained according to customer policy

---

# 8. Release Lifecycle

```text
Developer / CI
      │
      ▼
Security Scanning
      │
      ▼
SBOM Generation
      │
      ▼
Container Image Build
      │
      ▼
Image Signing
      │
      ▼
Offline Bundle Creation
      │
      ▼
Secure Transfer
      │
      ▼
Customer Verification
      │
      ├──────── Verification Failed
      │                    │
      │                    ▼
      │               Reject Release
      │
      ▼
Image Import
      │
      ▼
Controlled Deployment
      │
      ▼
Health Validation
      │
      ├──────── Failure
      │             │
      │             ▼
      │          Rollback
      │
      ▼
Production Release
      │
      ▼
Offline Monitoring
& Diagnostics
```

---

# 9. Summary

The restricted-delivery model provides a controlled mechanism for deploying the **Axiler Transaction Platform** into environments where internet connectivity and external infrastructure cannot be relied upon.

The approach combines:

* Self-contained offline release bundles
* SHA256 integrity verification
* Cosign-based cryptographic verification
* CycloneDX SBOMs
* Immutable release artifacts
* Docker Swarm deployment
* Docker Swarm Secrets
* Controlled rolling upgrades
* Automated and manual rollback
* Offline diagnostics
* Customer-managed infrastructure
* A defined path toward enterprise-grade air-gapped operations

The design intentionally separates **release artifact creation and signing** from **customer-side deployment and operations**, allowing the customer to independently verify the integrity and authenticity of each release before it enters the restricted production environment.

