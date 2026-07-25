#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Validate rendered Talos machine configuration without applying it.

Usage:
  validate-configs.sh --cluster <name> [--config-dir <dir>] [--mode <mode>]
                      [--no-strict] [config-file ...]

Options:
  --cluster NAME      Cluster name, for version/context reporting.
  --config-dir DIR    Directory to scan when no files are passed.
                      Default: kubernetes/generated
  --mode MODE         Talos validation mode: metal, cloud, or container.
                      Default: metal
  --no-strict         Do not treat warnings as errors.
  -h, --help          Show this help.

The script excludes files named talosconfig, kubeconfig, secrets, and encrypted
secret manifests. It never applies configuration to a node.
EOF
}

cluster=""
config_dir="kubernetes/generated"
mode="metal"
strict="true"
declare -a explicit_files=()

while (($#)); do
  case "$1" in
    --cluster)
      cluster="${2:-}"
      shift 2
      ;;
    --config-dir)
      config_dir="${2:-}"
      shift 2
      ;;
    --mode)
      mode="${2:-}"
      shift 2
      ;;
    --no-strict)
      strict="false"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      explicit_files+=("$1")
      shift
      ;;
  esac
done

if [[ -z "$cluster" ]]; then
  echo "--cluster is required" >&2
  exit 2
fi

case "$mode" in
  metal|cloud|container) ;;
  *)
    echo "Invalid --mode '$mode'; expected metal, cloud, or container" >&2
    exit 2
    ;;
esac

if ! command -v talosctl >/dev/null 2>&1; then
  echo "talosctl is required" >&2
  exit 127
fi

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

cluster_tf="kubernetes/terraform/${cluster}"
if [[ ! -d "$cluster_tf" ]]; then
  echo "Cluster Terraform directory not found: $cluster_tf" >&2
  exit 3
fi

printf 'Cluster: %s\n' "$cluster"
printf 'Mode: %s\n' "$mode"
printf 'Local talosctl: '
talosctl version --client 2>/dev/null | head -n 3 || true

printf '\nDeclared versions:\n'
if command -v rg >/dev/null 2>&1; then
  rg -n --glob '*.tf' 'talos_version|kubernetes_version|update_version' \
    "$cluster_tf" 2>/dev/null || true
else
  grep -RInE 'talos_version|kubernetes_version|update_version' \
    "$cluster_tf" 2>/dev/null || true
fi

is_candidate() {
  local file="$1"
  local name
  name="$(basename "$file")"
  case "$name" in
    talosconfig|kubeconfig|*secret*|*.enc.yaml|*.enc.yml) return 1 ;;
  esac
  grep -Eq '^(version: v1alpha1|apiVersion: v1alpha1|kind: (MachineConfig|SideroLinkConfig|ExtensionServiceConfig))' \
    "$file" 2>/dev/null
}

declare -a files=()
if ((${#explicit_files[@]})); then
  for file in "${explicit_files[@]}"; do
    if [[ ! -f "$file" ]]; then
      echo "Config file not found: $file" >&2
      exit 4
    fi
    files+=("$file")
  done
else
  if [[ ! -d "$config_dir" ]]; then
    echo "Config directory not found: $config_dir" >&2
    echo "Pass rendered config files explicitly or set --config-dir." >&2
    exit 4
  fi

  while IFS= read -r -d '' file; do
    if is_candidate "$file"; then
      files+=("$file")
    fi
  done < <(find "$config_dir" -type f \( -name '*.yaml' -o -name '*.yml' \) -print0 | sort -z)
fi

if ((${#files[@]} == 0)); then
  echo "No Talos machine configuration files found." >&2
  echo "Searched: $config_dir" >&2
  exit 5
fi

declare -a validate_args=(--mode "$mode")
if [[ "$strict" == "true" ]]; then
  validate_args+=(--strict)
fi

passed=0
failed=0
for file in "${files[@]}"; do
  printf '\n==> Validating %s\n' "$file"
  if talosctl validate --config "$file" "${validate_args[@]}"; then
    ((passed += 1))
  else
    ((failed += 1))
  fi
done

printf '\nValidation summary: %d passed, %d failed\n' "$passed" "$failed"
if ((failed > 0)); then
  exit 1
fi
