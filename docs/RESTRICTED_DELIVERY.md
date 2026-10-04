# Customer-Managed & Restricted / Air-Gapped Environment Delivery Design

## Overview

This document defines the architecture, release packaging, verification procedures, deployment strategy, rollback procedures, and operational considerations for delivering the **Axiler Transaction Platform** into customer-managed, restricted, or fully air-gapped environments.

The design assumes that the target environment may have:

* No direct internet connectivity
* No access to external container registries such as GHCR or Docker Hub
* No connectivity to external CI/CD systems
* Restricted outbound network access
* Customer-controlled infrastructure and security policies
* Customer-managed Docker Swarm nodes

The objective is to provide a **self-contained, verifiable, repeatable, and operationally controlled release process** without requiring internet connectivity from the production environment.

---

## 1. Release Packaging & Trust Verification

In a restricted or air-gapped environment, the platform cannot directly pull container images from external registries or communicate with external CI/CD services.

Therefore, each release is packaged as a **self-contained offline release bundle** using:

```bash
make bundle
```

The resulting bundle contains the application image, deployment manifests, SBOM, integrity information, and operational helper scripts required for offline installation.

### 1.1 Offline Bundle

Example release artifact:

```text
axiler-release-v1.0.0-offline.tar.gz
```

### 1.2 Bundle Contents

| Component                | Description                                                     |
| ------------------------ | --------------------------------------------------------------- |
| Container Image Tarballs | Gzip-compressed Docker image archives such as `api-service.tar` |
| SBOM                     | Machine-readable CycloneDX JSON software inventory              |
| Declarative Manifests    | Docker Swarm stack / Compose deployment definitions             |
| Integrity Manifest       | SHA256 checksum manifest for release artifacts                  |
| Signature Materials      | Cosign signature and vendor public-key verification materials   |
| Operational Helpers      | Offline installation and verification scripts                   |

Example bundle structure:

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

### 1.3 Customer Verification Procedure

Before executing installation or deployment steps, the customer should verify the integrity and authenticity of the received artifacts on a trusted bastion or administration host.

#### Step 1 — Verify SHA256 Integrity

```bash
sha256sum -c checksums.sha256
```

This confirms that the release files have not been modified or corrupted after packaging.

#### Step 2 — Verify the Release Signature

Using the vendor-provided Cosign public key:

```bash
cosign verify-blob \
  --key cosign.pub \
  --signature bundle.sig \
  axiler-release-v1.0.0-offline.tar.gz
```

A successful verification confirms that the release bundle was signed using the corresponding private signing key.

### 1.4 Trust Verification Flow

```text
                 Offline Release Bundle
                         │
                         ▼
                ┌─────────────────┐
                │ SHA256 Check    │
                │ Integrity       │
                └────────┬────────┘
                         │
                         ▼
                ┌─────────────────┐
                │ Cosign Verify   │
                │ Authenticity    │
                └────────┬────────┘
                         │
                    Verification
                      Successful
                         │
                         ▼
                ┌─────────────────┐
                │ Installation /  │
                │ Deployment      │
                └─────────────────┘
```

---

# 2. Air-Gapped Installation & Controlled Upgrade Strategy

## 2.1 Initial Installation

The initial deployment is performed entirely from the verified offline release bundle.

### Step 1 — Transfer the Bundle

Transfer the release bundle to the customer-controlled bastion or deployment host using the customer's approved secure media or transfer mechanism.

No direct internet access is required.

### Step 2 — Extract the Bundle

```bash
tar -xzf axiler-release-v1.0.0-offline.tar.gz
cd axiler-release-v1.0.0-offline
```

### Step 3 — Load Container Images

Load the packaged container image into the local Docker environment:

```bash
docker load -i api-service.tar
```

For larger customer environments, the image can instead be imported into an internal, air-gapped container registry.

### Step 4 — Initialize Docker Swarm Secrets

Secrets must not be embedded directly into application images or committed to deployment manifests.

Example:

```bash
docker secret create db_password \
  - < /path/to/secure/db_password
```

Additional application secrets can be initialized using the same controlled procedure.

### Step 5 — Deploy the Stack

```bash
docker stack deploy \
  -c docker-compose.yml \
  axiler-stack
```

After deployment, verify the service state:

```bash
docker service ls
```

and:

```bash
docker service ps axiler-stack_api-service
```

---

## 2.2 Controlled Upgrade Strategy

For a new release, the customer receives a new offline bundle through the approved release-transfer process.

Example:

```text
v1.0.0
   │
   ├── Verification
   │
   ▼
v1.1.0 Offline Bundle
   │
   ├── SHA256 Verification
   ├── Cosign Verification
   ├── Image Import
   └── Deployment
          │
          ▼
     Rolling Update
```

### Load the New Image

```bash
docker load -i api-service-v1.1.0.tar
```

### Trigger a Controlled Rolling Update

Example:

```bash
docker service update \
  --image axiler/api-service:v1.1.0 \
  --update-parallelism 1 \
  --update-delay 5s \
  axiler-stack_api-service
```

The update strategy limits the number of tasks updated simultaneously and introduces a delay between updates, reducing the risk of a full-service outage during deployment.

### Verify the Deployment

```bash
docker service ps axiler-stack_api-service
```

and:

```bash
docker service inspect axiler-stack_api-service
```

Application-level health and expected service behavior should also be validated after the update.

---

# 3. Offline Rollback & Diagnostics

## 3.1 Rollback Strategy

The platform uses Docker Swarm's deployment and rollback capabilities to provide controlled recovery when a release fails.

Rollback can be initiated automatically according to the configured `rollback_config` policy or manually by an authorized operator.

### Automated Rollback

The Swarm service configuration can define rollback behavior based on deployment failures and health-check results.

The exact rollback timing depends on the configured:

* Health-check interval
* Health-check timeout
* Failure threshold
* Update configuration
* Rollback configuration

The configured policy should therefore be validated in the target customer environment before production rollout.

### Manual Rollback

An operator can manually revert the service to its previous version:

```bash
docker service rollback axiler-stack_api-service
```

Verify the rollback:

```bash
docker service ps axiler-stack_api-service
```

---

## 3.2 Diagnostics & Troubleshooting

Air-gapped environments cannot depend on external observability platforms or internet-based troubleshooting services.

The following commands provide the basic offline diagnostic workflow.

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

### Export Diagnostic Information

```bash
docker service inspect \
  axiler-stack_api-service \
  > diagnostic-report.json
```

Additional container-level information can be collected using:

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
Inspect Application Logs
          │
          ▼
Inspect Deployment Configuration
          │
          ├── Healthy
          │     │
          │     ▼
          │   Continue Monitoring
          │
          └── Unhealthy
                │
                ▼
          Rollback Release
                │
                ▼
          Export Diagnostics
```

---

# 4. Security Considerations for Restricted Environments

Air-gapped deployment removes external network dependencies but does not automatically make the environment secure.

The following controls should remain enforced.

## 4.1 Artifact Integrity

Every release should be accompanied by:

* SHA256 checksums
* SBOM
* Cosign signature
* Vendor public key
* Versioned deployment manifests

The customer should verify these artifacts before deployment.

## 4.2 Image Provenance

Container images should originate from the approved CI/CD supply chain and should not be replaced with locally built or unverified images unless explicitly authorized by the customer's release process.

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

Secrets should not be:

* Hard-coded in source code
* Stored in Dockerfiles
* Included in container images
* Committed to Git
* Added to public configuration files

## 4.4 Network Isolation

The application should continue to use the intended internal network boundaries.

External access should be limited to the approved edge gateway and customer-defined network policies.

---

# 5. Known Gaps & Recommended Production Improvements

The current implementation intentionally demonstrates the required DevSecOps controls while keeping the lab deployment operationally lightweight.

The following areas can be strengthened for enterprise production environments.

| Component             | Current Local / Demo Approach                                   | Recommended Production Improvement                                                                            |
| --------------------- | --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| Secret Management     | Docker Swarm Secrets initialized through controlled CLI scripts | Integrate an enterprise secrets platform such as HashiCorp Vault or another customer-approved secrets manager |
| Registry Management   | Direct `docker load` on Swarm nodes                             | Deploy an internal air-gapped enterprise registry such as Harbor or Nexus with controlled image replication   |
| Policy Enforcement    | Traefik-based tenant/header validation                          | Add centralized policy enforcement and runtime admission controls where supported by the target platform      |
| Image Trust           | Release-level Cosign verification                               | Enforce signed-image policies and provenance verification throughout the production supply chain              |
| Observability Storage | Local / ephemeral Prometheus storage                            | Deploy durable metric storage and offline log aggregation appropriate for the customer's environment          |
| Key Management        | Vendor/customer-managed signing materials                       | Integrate with enterprise KMS/HSM where required                                                              |
| Access Control        | Host and Swarm-level administrative controls                    | Integrate with centralized enterprise IAM/RBAC and privileged-access management                               |
| Disaster Recovery     | Application-level rollback                                      | Add customer-specific backup, restore, and disaster-recovery procedures                                       |

---

# 6. Enterprise Air-Gapped Deployment Model

A mature customer-managed deployment can evolve toward the following architecture:

```text
                    Vendor CI/CD
                         │
                         │ Signed Release
                         ▼
              ┌──────────────────────┐
              │ Offline Release       │
              │ Bundle                │
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
              │ Cosign Verification  │
              └──────────┬───────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │ Internal Registry    │
              │ / Artifact Store     │
              └──────────┬───────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │ Docker Swarm Cluster │
              │                      │
              │ ┌──────────────────┐ │
              │ │ Traefik          │ │
              │ └────────┬─────────┘ │
              │          │           │
              │ ┌────────▼─────────┐ │
              │ │ Private Backend  │ │
              │ │ Network          │ │
              │ └────────┬─────────┘ │
              │          │           │
              │ ┌────────▼─────────┐ │
              │ │ API Services     │ │
              │ └──────────────────┘ │
              └──────────────────────┘
```

This model separates the **vendor release process** from the **customer runtime environment**, while maintaining verifiable software provenance throughout the delivery chain.

---

# 7. Operational Checklist

Before approving an air-gapped release, the customer/operator should verify:

### Release Verification

* [ ] Release version confirmed
* [ ] Offline bundle received through approved channel
* [ ] SHA256 checksums verified
* [ ] Cosign signature verified
* [ ] Vendor public key verified/trusted
* [ ] SBOM present
* [ ] Deployment manifests present
* [ ] Required container images present

### Pre-Deployment

* [ ] Docker Swarm cluster healthy
* [ ] Required secrets available
* [ ] Required storage available
* [ ] Required internal network connectivity verified
* [ ] Previous release / rollback point identified
* [ ] Maintenance/change window approved

### Deployment

* [ ] Images imported successfully
* [ ] Stack deployed
* [ ] Services running expected replicas
* [ ] Health checks passing
* [ ] Application endpoints validated
* [ ] Tenant isolation validated
* [ ] Monitoring and alerts operational

### Post-Deployment

* [ ] Application functionality verified
* [ ] Logs reviewed
* [ ] Metrics reviewed
* [ ] No unexpected errors observed
* [ ] Release version confirmed
* [ ] Diagnostic information retained according to customer policy

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
Image Build
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
      ├── Verification Failed ──► Reject Release
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
      ├── Failure ──► Rollback
      │
      ▼
Production Release
      │
      ▼
Offline Monitoring & Diagnostics
```

---

## 9. Summary

The restricted-delivery model provides a controlled mechanism for deploying the Axiler transaction platform into environments where internet connectivity and external infrastructure cannot be relied upon.

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
* A documented path toward enterprise-grade air-gapped operations

The design intentionally separates **release artifact creation and signing** from **customer-side deployment and operations**, allowing the customer to independently verify the integrity and authenticity of each release before it enters the restricted production environment.

