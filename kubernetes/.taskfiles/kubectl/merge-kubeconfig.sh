#!/usr/bin/env bash
# Merge both cluster kubeconfigs (mlops + application) into a single kubeconfig
# (default ~/.kube/config) so kubectl/k9s can `:ctx` between mlops and
# application.
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

# Talos names the admin credential admin@<cluster>. Keep context and user
# names as the cluster name. First entry wins when both the short name and
# the legacy name are present (generated kubeconfigs are merged first).
python3 - "$dest" <<'PY'
import pathlib, sys
import yaml

renames = {
    "admin@mlops": "mlops",
    "admin@application": "application",
}
path = pathlib.Path(sys.argv[1])
data = yaml.safe_load(path.read_text())

users = []
seen_users = set()
for user in data.get("users") or []:
    name = renames.get(user.get("name"), user.get("name"))
    if name in seen_users:
        continue
    user["name"] = name
    users.append(user)
    seen_users.add(name)
data["users"] = users

contexts = []
seen_contexts = set()
for entry in data.get("contexts") or []:
    ctx = entry.get("context") or {}
    user = renames.get(ctx.get("user"), ctx.get("user"))
    if user in seen_users:
        ctx["user"] = user
    name = renames.get(entry.get("name"), entry.get("name"))
    if name in seen_contexts:
        continue
    entry["name"] = name
    entry["context"] = ctx
    contexts.append(entry)
    seen_contexts.add(name)
data["contexts"] = contexts

current = data.get("current-context")
current = renames.get(current, current)
if current in seen_contexts:
    data["current-context"] = current

path.write_text(yaml.safe_dump(data, sort_keys=False))
path.chmod(0o600)
PY

case "$prev_ctx" in
  admin@mlops) prev_ctx=mlops ;;
  admin@application) prev_ctx=application ;;
esac

# Restore the prior context if it still exists, else default to mlops.
if [ -n "$prev_ctx" ] && KUBECONFIG="$dest" kubectl config get-contexts -o name | grep -qx "$prev_ctx"; then
  KUBECONFIG="$dest" kubectl config use-context "$prev_ctx" >/dev/null
else
  KUBECONFIG="$dest" kubectl config use-context mlops >/dev/null 2>&1 || true
fi

echo "Merged mlops + application into $dest"
KUBECONFIG="$dest" kubectl config get-contexts
