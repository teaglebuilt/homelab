#!/usr/bin/env bash
# Switch the current kubeconfig to <cluster> (mlops or application).
# Usage: switch-context.sh <mlops|application>
set -euo pipefail

cluster="${1:?usage: switch-context.sh <mlops|application>}"
case "$cluster" in
  mlops|application) ;;
  *)
    echo "switch-context: unknown cluster '$cluster' (expected mlops or application)" >&2
    exit 1
    ;;
esac

if ! kubectl config get-contexts -o name | grep -qx "$cluster"; then
  echo "switch-context: context $cluster missing — run kubernetes:kubectl:merge-kubeconfig" >&2
  exit 1
fi

if command -v kubectx >/dev/null 2>&1; then
  kubectx "$cluster"
else
  kubectl config use-context "$cluster"
fi
