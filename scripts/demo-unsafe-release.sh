#!/usr/bin/env bash
echo "=== DEMO 1: Unsafe Release Pipeline Security Gate ==="
echo "Injecting dummy RSA Private Key into app codebase..."

# Base64 encoded RSA key to prevent Git repository secret leaks in CI
echo "LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFb3dJQkFBS0NBUUVBMFozSjRKOEw5MnkxcTdOM3Y4WDlrMkwxbTJOM3A0UTVyNlM3dDhVOXYwVzF4MlkzCno0QS4uLgotLS0tLUVORCBSU0EgUFJJVkFURSBLRVktLS0tLQ==" | base64 -d >> app/main.py

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
