#!/usr/bin/env bash
echo "=== DEMO 3: Edge Security, Tenant Isolation & Abuse Control ==="

echo "1. Valid Request (Tenant: Alpha):"
curl -s -H "X-Tenant-ID: Alpha" http://127.0.0.1:8000/search | jq . || true

echo -e "\n2. Unauthorized Request (No Tenant Header):"
curl -s -i http://127.0.0.1:8000/search | grep "HTTP" || true

echo -e "\n3. Unauthorized Request (Invalid Spoofed Tenant):"
curl -s -i -H "X-Tenant-ID: MaliciousCorp" http://127.0.0.1:8000/search | grep "HTTP" || true

echo -e "\n4. Rate Limit Abuse / Request Execution Test:"
for i in {1..5}; do
  echo -n "Req $i Status: "
  curl -s -o /dev/null -w "%{http_code}\n" -H "X-Tenant-ID: Alpha" http://127.0.0.1:8000/search
done

echo -e "\n[SUCCESS] Edge Security Test Completed."
