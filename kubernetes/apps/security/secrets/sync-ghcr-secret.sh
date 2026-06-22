#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

kubectl delete job create-ghcr-registry-secret -n default --ignore-not-found=true
kustomize build --enable-exec --enable-alpha-plugins "${SCRIPT_DIR}" | kubectl apply -f -
kubectl wait --for=condition=complete job/create-ghcr-registry-secret -n default --timeout=120s
