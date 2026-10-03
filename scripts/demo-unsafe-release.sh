#!/usr/bin/env bash
echo "=== DEMO 1: Unsafe Release Pipeline Security Gate ==="
echo "Injecting dummy RSA Private Key into app codebase..."

# Dynamically construct RSA Key string at runtime
KEY_HEADER="-----BEGIN RSA PRIVATE KEY-----"
KEY_BODY="MIIEowIBAAKCAQEA0Z3J4J8L92y1q7N3v8X9k0L1m2N3p4Q5r6S7t8U9v0W1x2Y3z4A"
KEY_FOOTER="-----END RSA PRIVATE KEY-----"

printf "%s\n%s\n%s\n" "$KEY_HEADER" "$KEY_BODY" "$KEY_FOOTER" >> app/main.py

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
