#!/usr/bin/env bash
set -euo pipefail
echo "=== DEMO 3: Edge Security, Tenant Isolation & Abuse Control ==="

echo "1. Valid Request (Tenant: Alpha):"
curl -s -H "X-Tenant-ID: Alpha" http://localhost/search | jq .

echo "2. Unauthorized Request (No Tenant Header):"
curl -s -i http://localhost/search | grep "HTTP/1.1 403" && echo "[BLOCKED 403 Forbidden]"

echo "3. Unauthorized Request (Invalid Spoofed Tenant):"
curl -s -i -H "X-Tenant-ID: MaliciousCorp" http://localhost/search | grep "HTTP/1.1 403" && echo "[BLOCKED 403 Forbidden]"

echo "4. Simulating Rate Abuse Burst (Rate Limit Test):"
for i in {1..15}; do
  curl -s -o /dev/null -w "%{http_code}\n" http://localhost/search -H "X-Tenant-ID: Alpha"
done | grep "429" && echo "[SUCCESS] Traefik Edge Enforcement triggered 429 Too Many Requests."
