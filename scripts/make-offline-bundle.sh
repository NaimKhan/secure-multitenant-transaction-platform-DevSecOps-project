#!/usr/bin/env bash
set -euo pipefail
echo "=== Generating Offline Air-Gapped Release Bundle ==="
BUNDLE_DIR="release-bundle-v1.0.0"
mkdir -p "$BUNDLE_DIR/images" "$BUNDLE_DIR/manifests" "$BUNDLE_DIR/sbom"

docker save axiler/api-service:v1.0.0 | gzip > "$BUNDLE_DIR/images/api-service.tar.gz"
cp swarm/docker-compose.yml "$BUNDLE_DIR/manifests/"
cp app-sbom.cyclonedx.json "$BUNDLE_DIR/sbom/" 2>/dev/null || true
sha256sum "$BUNDLE_DIR/images/api-service.tar.gz" > "$BUNDLE_DIR/CHECKSUMS.txt"

tar -czvf "axiler-release-v1.0.0-offline.tar.gz" "$BUNDLE_DIR"
echo "[SUCCESS] Air-Gapped Bundle created: axiler-release-v1.0.0-offline.tar.gz"
