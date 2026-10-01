#!/usr/bin/env bash
set -euo pipefail
echo "=== DEMO 1: Unsafe Release Pipeline Security Gate ==="
echo "Injecting dummy AWS secret key into app codebase..."
echo "AWS_SECRET_KEY='AKIAIOSFODNN7EXAMPLE'" >> app/main.py

echo "Executing local Gitleaks scanner check..."
if docker run --rm -v "$(pwd):/path" zricethezav/gitleaks:latest detect --source="/path" -v; then
    echo "[FAIL] Security gate failed to block secret!"
    git checkout app/main.py
    exit 1
else
    echo "--------------------------------------------------------"
    echo "[SUCCESS] Gitleaks Security Gate DETECTED secret and BLOCKED release."
    echo "--------------------------------------------------------"
    git checkout app/main.py
fi
