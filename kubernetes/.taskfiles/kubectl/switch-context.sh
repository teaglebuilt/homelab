#!/usr/bin/env bash
# Switch the current kubeconfig to admin@<cluster>.
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

context="admin@${cluster}"
if ! kubectl config get-contexts -o name | grep -qx "$context"; then
  echo "switch-context: context $context missing — run kubernetes:kubectl:merge-kubeconfig" >&2
  exit 1
fi

# Short names for interactive `kubectx mlops` / `kubectx application`.
if command -v kubectx >/dev/null 2>&1; then
  kubectx "${cluster}=${context}" >/dev/null
  kubectx "$cluster"
else
  kubectl config use-context "$context"
fi
