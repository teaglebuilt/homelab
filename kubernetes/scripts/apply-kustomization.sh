#!/usr/bin/env bash
# Idempotent kustomize build | kubectl apply with cluster verification and
# optional server-side dry-run of a representative CR before apply.
#
# Usage:
#   KUBECONFIG=... CLUSTER=mlops ./apply-kustomization.sh <kustomize-dir> \
#     [--dry-run-file <path-to-cr.yaml>] \
#     [--kustomize-flags "<flags>"]
set -euo pipefail

: "${KUBECONFIG:?KUBECONFIG is required}"
: "${CLUSTER:?CLUSTER is required}"

KUSTOMIZE_DIR=""
DRY_RUN_FILE=""
# Match prior platform Taskfile defaults for charts/ksops overlays.
KUSTOMIZE_FLAGS="${KUSTOMIZE_FLAGS:---enable-helm --enable-exec --enable-alpha-plugins --load-restrictor LoadRestrictionsNone}"

verify_cluster() {
  local ctx
  ctx="$(kubectl config current-context 2>/dev/null || true)"
  if [[ -z "${ctx}" ]]; then
    echo "error: no current kubectl context (KUBECONFIG=${KUBECONFIG})" >&2
    exit 1
  fi
  if [[ "${ctx}" != *"${CLUSTER}"* ]]; then
    echo "error: context '${ctx}' does not match expected CLUSTER='${CLUSTER}'" >&2
    exit 1
  fi
}

usage() {
  sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
}

KUSTOMIZE_DIR="${1:?kustomize directory required}"
shift || true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run-file) DRY_RUN_FILE="${2:?}"; shift 2 ;;
    --kustomize-flags) KUSTOMIZE_FLAGS="${2:?}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "unknown arg: $1" >&2; usage ;;
  esac
done

if [[ ! -d "${KUSTOMIZE_DIR}" ]]; then
  echo "error: kustomize directory not found: ${KUSTOMIZE_DIR}" >&2
  exit 1
fi

verify_cluster

# shellcheck disable=SC2086
if [[ -n "${DRY_RUN_FILE}" ]]; then
  echo "server-side dry-run: ${DRY_RUN_FILE}"
  kubectl apply --dry-run=server -f "${DRY_RUN_FILE}"
fi

echo "applying kustomization: ${KUSTOMIZE_DIR}"
# shellcheck disable=SC2086
kustomize build ${KUSTOMIZE_FLAGS} "${KUSTOMIZE_DIR}" | kubectl apply -f -

echo "apply complete"
