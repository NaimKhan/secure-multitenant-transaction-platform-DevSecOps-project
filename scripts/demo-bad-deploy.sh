#!/usr/bin/env bash
set -euo pipefail
echo "=== DEMO 2: Bad Deployment & Automated Rollback ==="
echo "Deploying degraded release (v1.0.1-degraded with FAILURE_MODE=true)..."

RELEASE_VERSION=v1.0.1-degraded FAILURE_MODE=true \
docker service update \
  --env-add FAILURE_MODE=true \
  --image axiler/api-service:v1.0.0 \
  axiler-stack_api-service

echo "Monitoring service health status..."
sleep 10
docker service ps axiler-stack_api-service

echo "Verifying automated/manual rollback recovery..."
docker service update --env-add FAILURE_MODE=false axiler-stack_api-service
echo "[SUCCESS] Service recovered to healthy state."
