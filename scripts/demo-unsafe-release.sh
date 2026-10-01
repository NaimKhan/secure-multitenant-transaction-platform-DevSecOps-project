#!/usr/bin/env bash
echo "=== DEMO 1: Unsafe Release Pipeline Security Gate ==="
echo "Injecting dummy RSA Private Key into app codebase..."

# RSA Private Key format reliably triggers Gitleaks generic-api-key / private-key scanner
cat << 'APP_EOF' >> app/main.py

-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEA0Z3J4J8L92y1q7N3v8X9k0L1m2N3p4Q5r6S7t8U9v0W1x2Y3
z4A5b6C7d8E9f0G1h2I3j4K5l6M7n8O9p0Q1r2S3t4U5v6W7x8Y9z0A1b2C3d4E5
f6G1h2I3j4K5l6M7n8O9p0Q1r2S3t4U5v6W7x8Y9z0A1b2C3d4E5f6G1h2I3j4K5
-----END RSA PRIVATE KEY-----
APP_EOF

echo "Executing Gitleaks scanner check..."
set +e
docker run --rm -v "$(pwd)/app:/path" zricethezav/gitleaks:latest detect --source="/path" --no-git -v
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
    echo "--------------------------------------------------------"
    echo "[SUCCESS] Gitleaks Security Gate DETECTED secret and BLOCKED release."
    echo "--------------------------------------------------------"
    git checkout app/main.py
    exit 0
else
    echo "--------------------------------------------------------"
    echo "[FAIL] Security gate failed to detect secret!"
    echo "--------------------------------------------------------"
    git checkout app/main.py
    exit 1
fi
