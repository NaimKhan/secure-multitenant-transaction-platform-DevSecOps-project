# Restricted / Air-Gapped Environment Delivery Design

## Overview
This document specifies the mechanism for delivering Axiler release artifacts into customer-managed, air-gapped, or zero-connectivity environments.

## 1. Release Packaging & Trust
Vendor artifacts are bundled into a signed, immutable release archive containing:
1. Gzip-compressed Container Images (`.tar.gz`).
2. CycloneDX SBOM (`.json`).
3. Declarative Compose/Swarm definitions.
4. SHA256 Cryptographic Checksums & Cosign Public Key Signatures.

## 2. Customer Verification Procedure
On the customer's bastion host prior to deployment:
1. **Verification**:
   ```bash
   sha256sum -c CHECKSUMS.txt
   cosign verify-blob --key vendor-public.pub --signature bundle.sig release.tar.gz
