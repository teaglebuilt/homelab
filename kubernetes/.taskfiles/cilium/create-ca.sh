#!/bin/bash

set -euo pipefail
tmp="$(mktemp -d)"

plain="clusters/_shared/.cilium-ca.plain.yaml"
encrypted="clusters/_shared/cilium-ca.sops.yaml"
trap 'rm -rf "$tmp"; rm -f "$plain"' EXIT

create-certificate() {
  openssl req -x509 -new -nodes -newkey rsa:4096 -days 3650 \
    -keyout "$tmp/ca.key" -out "$tmp/ca.crt" -subj "/CN=Cilium CA" 2>/dev/null

  kubectl create secret generic cilium-ca -n kube-system \
    --from-file=ca.crt="$tmp/ca.crt" --from-file=ca.key="$tmp/ca.key" \
    --dry-run=client -o yaml > "$plain"

  sops -e "$plain" > "$tmp/enc.yaml"
  mv "$tmp/enc.yaml" "$encrypted"
  echo "Generated $encrypted"
}

if [[ -f "$encrypted" ]]; then
  echo "$encrypted already exists — skipping CA generation"
  exit 0
fi

create-certificate
