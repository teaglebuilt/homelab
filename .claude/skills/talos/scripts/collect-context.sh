#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Collect safe, read-only Talos repository and optional live-node context.

Usage:
  collect-context.sh --cluster <name> [--node <ip-or-name>] [--output <file>] [--offline]

Options:
  --cluster NAME   Cluster directory/name, for example mlops.
  --node NODE      Optional Talos node for live read-only queries.
  --output FILE    Write Markdown output to FILE instead of stdout.
  --offline        Skip all live talosctl and kubectl queries.
  -h, --help       Show this help.

The script never prints complete talosconfig, kubeconfig, machine secrets, or
SOPS-decrypted content.
EOF
}

cluster=""
node=""
output=""
offline="false"

while (($#)); do
  case "$1" in
    --cluster)
      cluster="${2:-}"
      shift 2
      ;;
    --node)
      node="${2:-}"
      shift 2
      ;;
    --output)
      output="${2:-}"
      shift 2
      ;;
    --offline)
      offline="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$cluster" ]]; then
  echo "--cluster is required" >&2
  usage >&2
  exit 2
fi

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

cluster_tf="kubernetes/terraform/${cluster}"
cluster_meta="kubernetes/clusters/${cluster}/cluster.yaml"
module_dir="tf_modules/talos_cluster"

if [[ ! -d "$cluster_tf" ]]; then
  echo "Cluster Terraform directory not found: $cluster_tf" >&2
  exit 3
fi

emit() {
  printf '%s\n' "$*"
}

code_block() {
  local language="$1"
  shift
  emit "\`\`\`${language}"
  "$@" 2>&1 || true
  emit '```'
}

run_section() {
  local title="$1"
  shift
  emit
  emit "## ${title}"
  emit
  code_block text "$@"
}

collect() {
  emit "# Talos Context: ${cluster}"
  emit
  emit "Generated: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  emit "Repository: ${repo_root}"
  [[ -n "$node" ]] && emit "Node: ${node}"

  run_section "Git State" git status --short --branch

  emit
  emit "## Relevant Paths"
  emit
  for path in "$cluster_tf" "$cluster_meta" "$module_dir" \
              "kubernetes/.taskfiles/talos" \
              "kubernetes/apps/networking/cilium" \
              "kubernetes/apps/hardware/nvidia"; do
    if [[ -e "$path" ]]; then
      emit "- \`${path}\`"
    fi
  done

  emit
  emit "## Declared Versions and Cluster Inputs"
  emit
  emit '```text'
  if command -v rg >/dev/null 2>&1; then
    rg -n --glob '*.tf' --glob '*.yaml' \
      'talos_version|kubernetes_version|update_version|podSubnet|pod_subnet|serviceSubnet|service_subnet|clusterId|cluster_id' \
      "$cluster_tf" "$cluster_meta" "$module_dir" 2>/dev/null || true
  else
    grep -RInE \
      'talos_version|kubernetes_version|update_version|podSubnet|pod_subnet|serviceSubnet|service_subnet|clusterId|cluster_id' \
      "$cluster_tf" "$cluster_meta" "$module_dir" 2>/dev/null || true
  fi
  emit '```'

  emit
  emit "## Talos Module Files"
  emit
  emit '```text'
  find "$module_dir" -maxdepth 3 -type f \
    \( -name '*.tf' -o -name '*.yaml' -o -name '*.yml' -o -name '*.tftpl' \) \
    -print 2>/dev/null | sort
  emit '```'

  if [[ "$offline" == "true" ]]; then
    emit
    emit "Live queries skipped (--offline)."
    return
  fi

  if command -v talosctl >/dev/null 2>&1; then
    run_section "Local talosctl Version" talosctl version --client
    run_section "Talos Context Summary" talosctl config info

    if [[ -n "$node" ]]; then
      run_section "Node Version" talosctl version --nodes "$node"
      run_section "Node Extensions" talosctl get extensions --nodes "$node"
      run_section "Node Disks" talosctl get disks --nodes "$node"
      run_section "Node Mounts" talosctl get mounts --nodes "$node"
    else
      emit
      emit "> No --node supplied; node-specific live queries were skipped."
    fi
  else
    emit
    emit "> talosctl is not installed; live Talos queries were skipped."
  fi

  if command -v kubectl >/dev/null 2>&1; then
    run_section "Kubernetes Nodes" kubectl get nodes -o wide
    if [[ -n "$node" ]]; then
      run_section "Matching Kubernetes Node" kubectl get node "$node" -o wide
    fi
  else
    emit
    emit "> kubectl is not installed; Kubernetes correlation was skipped."
  fi
}

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  collect >"$output"
  echo "Wrote $output"
else
  collect
fi
