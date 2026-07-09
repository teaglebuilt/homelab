#!/bin/bash

set -euo pipefail
tmp="$(mktemp -d)"
# SOPS matches .sops.yaml's `kubernetes/*` rule by the file path RELATIVE to the
# config, so the plaintext must live under kubernetes/. Keep it in _shared as a
# dotfile and trap-remove it (also on failure) so key material is never committed.
plain="clusters/_shared/.cilium-ca.plain.yaml"
trap 'rm -rf "$tmp"; rm -f "$plain"' EXIT
mkdir -p clusters/_shared
# 4096-bit self-signed CA (10y). Raw key/cert stay in $tmp.
openssl req -x509 -new -nodes -newkey rsa:4096 -days 3650 \
  -keyout "$tmp/ca.key" -out "$tmp/ca.crt" -subj "/CN=Cilium CA" 2>/dev/null
# Build the cilium-ca Secret client-side (no cluster needed).
kubectl create secret generic cilium-ca -n kube-system \
  --from-file=ca.crt="$tmp/ca.crt" --from-file=ca.key="$tmp/ca.key" \
  --dry-run=client -o yaml > "$plain"
# Encrypt via the repo .sops.yaml (kubernetes/* KMS rule + Secret-field regex).
# Write ciphertext to $tmp first; only move it into place on success (set -e).
sops -e "$plain" > "$tmp/enc.yaml"
mv "$tmp/enc.yaml" clusters/_shared/cilium-ca.sops.yaml
echo "Generated clusters/_shared/cilium-ca.sops.yaml — COMMIT it so the CA is reused across runs."
