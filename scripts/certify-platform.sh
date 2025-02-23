#!/bin/bash

# Variables
NAMESPACE="cert-manager"
SECRET_NAME="homelab-ca-secret"
CERT_FILE="/tmp/homelab-ca.crt"
KEYCHAIN="login.keychain"
MAX_WAIT=300  # Maximum wait time in seconds (5 minutes)
SLEEP_INTERVAL=10  # Time between checks

echo "⏳ Waiting for certificate secret '$SECRET_NAME' to be created in namespace '$NAMESPACE'..."

# Wait for the secret to be created
elapsed_time=0
while ! kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &>/dev/null; do
  if [[ $elapsed_time -ge $MAX_WAIT ]]; then
    echo "❌ Timeout: Secret '$SECRET_NAME' not found after $MAX_WAIT seconds."
    exit 1
  fi
  echo "🔄 Checking again in $SLEEP_INTERVAL seconds..."
  sleep $SLEEP_INTERVAL
  elapsed_time=$((elapsed_time + SLEEP_INTERVAL))
done

echo "✅ Secret '$SECRET_NAME' found! Extracting certificate..."

# Export the CA certificate
kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath="{.data.ca\.crt}" | base64 --decode > "$CERT_FILE"

# Verify the certificate was retrieved
if [[ ! -s "$CERT_FILE" ]]; then
  echo "❌ Failed to retrieve certificate. File is empty."
  exit 1
fi

echo "🔓 Importing certificate into macOS Keychain..."
sudo security add-trusted-cert -d -r trustRoot -k "$KEYCHAIN" "$CERT_FILE"

echo "🎉 Certificate successfully imported and trusted!"
