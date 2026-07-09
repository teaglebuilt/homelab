#!/usr/bin/env bash
# Merge both cluster kubeconfigs (mlops + application) into a single kubeconfig
# (default ~/.kube/config) so kubectl/k9s can `:ctx` between admin@mlops and
# admin@application.
#
# Usage: merge-kubeconfig.sh <mlops-kubeconfig> <application-kubeconfig> [dest]
#   dest defaults to $KUBECONFIG_DEST or ~/.kube/config.
set -euo pipefail

mlops_kubeconfig="${1:?mlops kubeconfig path required}"
app_kubeconfig="${2:?application kubeconfig path required}"
dest="${3:-${KUBECONFIG_DEST:-$HOME/.kube/config}}"

mkdir -p "$(dirname "$dest")"

# Remember the user's selected context so we can restore it after merging.
prev_ctx=""
[ -f "$dest" ] && prev_ctx="$(KUBECONFIG="$dest" kubectl config current-context 2>/dev/null || true)"

# Fresh generated kubeconfigs FIRST so their CA/creds/server win over any stale
# copies already in $dest — `kubectl config view --flatten` resolves key
# conflicts first-file-wins, so a re-provisioned cluster's new CA must lead or
# the old (broken) entry shadows it. $dest LAST keeps any unrelated contexts.
sources="${mlops_kubeconfig}:${app_kubeconfig}"
[ -f "$dest" ] && sources="${sources}:${dest}"

tmp="$(mktemp)"
KUBECONFIG="$sources" kubectl config view --flatten > "$tmp"
mv "$tmp" "$dest"
chmod 600 "$dest"

# Prune the pre-rename `administration` entries (this cluster is now `application`).
for res in context cluster user; do
  KUBECONFIG="$dest" kubectl config delete-"$res" administration >/dev/null 2>&1 || true
done
KUBECONFIG="$dest" kubectl config delete-context admin@administration >/dev/null 2>&1 || true
KUBECONFIG="$dest" kubectl config delete-user admin@administration >/dev/null 2>&1 || true

# Restore the prior context if it still exists, else default to mlops.
if [ -n "$prev_ctx" ] && KUBECONFIG="$dest" kubectl config get-contexts -o name | grep -qx "$prev_ctx"; then
  KUBECONFIG="$dest" kubectl config use-context "$prev_ctx" >/dev/null
else
  KUBECONFIG="$dest" kubectl config use-context admin@mlops >/dev/null 2>&1 || true
fi

echo "Merged admin@mlops + admin@application into $dest"
KUBECONFIG="$dest" kubectl config get-contexts
