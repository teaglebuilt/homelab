#!/usr/bin/env bash
# Wait until every named CRD reports Established=True.
#
# Usage:
#   KUBECONFIG=... CLUSTER=mlops ./wait-for-crds.sh <crd> [<crd> ...]
#   KUBECONFIG=... CLUSTER=mlops ./wait-for-crds.sh --group ate.dev
set -euo pipefail

: "${KUBECONFIG:?KUBECONFIG is required}"
: "${CLUSTER:?CLUSTER is required}"

TIMEOUT="${TIMEOUT:-120s}"

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

verify_cluster

crds=()
if [[ "${1:-}" == "--group" ]]; then
  group="${2:?--group requires an API group}"
  shift 2
  while IFS= read -r crd; do
    [[ -n "${crd}" ]] && crds+=("${crd}")
  done < <(kubectl get crd -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
    | grep "\.${group}$" || true)
  if [[ ${#crds[@]} -eq 0 ]]; then
    echo "error: no CRDs found for group ${group}" >&2
    exit 1
  fi
fi

crds+=("$@")
if [[ ${#crds[@]} -eq 0 ]]; then
  echo "usage: $0 [--group <apiGroup>] <crd> [<crd> ...]" >&2
  exit 1
fi

for crd in "${crds[@]}"; do
  echo "waiting for CRD ${crd} Established..."
  kubectl wait --for=condition=Established "crd/${crd}" --timeout="${TIMEOUT}"
done

echo "all requested CRDs are Established"
