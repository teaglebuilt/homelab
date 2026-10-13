#!/usr/bin/env bash
# Wait for an admission webhook path to become usable:
#   1. operator Deployment Available
#   2. cert-manager Certificate Ready (optional)
#   3. webhook Service EndpointSlice has ready endpoints
#   4. webhook CA bundle is populated
#
# Usage:
#   KUBECONFIG=... CLUSTER=mlops ./wait-for-webhook.sh \
#     --deployment <ns>/<name> \
#     --service <ns>/<name> \
#     [--certificate <ns>/<name>] \
#     [--mutating-webhook <name>] \
#     [--validating-webhook <name>]
set -euo pipefail

: "${KUBECONFIG:?KUBECONFIG is required}"
: "${CLUSTER:?CLUSTER is required}"

TIMEOUT="${TIMEOUT:-300s}"
DEPLOYMENT=""
SERVICE=""
CERTIFICATE=""
MUTATING_WEBHOOK=""
VALIDATING_WEBHOOK=""

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
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --deployment) DEPLOYMENT="${2:?}"; shift 2 ;;
    --service) SERVICE="${2:?}"; shift 2 ;;
    --certificate) CERTIFICATE="${2:?}"; shift 2 ;;
    --mutating-webhook) MUTATING_WEBHOOK="${2:?}"; shift 2 ;;
    --validating-webhook) VALIDATING_WEBHOOK="${2:?}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "unknown arg: $1" >&2; usage ;;
  esac
done

[[ -n "${DEPLOYMENT}" && -n "${SERVICE}" ]] || usage

verify_cluster

deploy_ns="${DEPLOYMENT%%/*}"
deploy_name="${DEPLOYMENT#*/}"
svc_ns="${SERVICE%%/*}"
svc_name="${SERVICE#*/}"

echo "waiting for Deployment ${DEPLOYMENT} Available..."
kubectl -n "${deploy_ns}" rollout status "deploy/${deploy_name}" --timeout="${TIMEOUT}"

if [[ -n "${CERTIFICATE}" ]]; then
  cert_ns="${CERTIFICATE%%/*}"
  cert_name="${CERTIFICATE#*/}"
  echo "waiting for Certificate ${CERTIFICATE} Ready..."
  kubectl -n "${cert_ns}" wait --for=condition=Ready "certificate/${cert_name}" --timeout="${TIMEOUT}"
fi

echo "waiting for ready EndpointSlice endpoints on Service ${SERVICE}..."
deadline=$((SECONDS + ${TIMEOUT%s}))
while true; do
  ready="$(kubectl -n "${svc_ns}" get endpointslices \
    -l "kubernetes.io/service-name=${svc_name}" \
    -o jsonpath='{range .items[*].endpoints[?(@.conditions.ready==true)]}{.addresses[0]}{"\n"}{end}' 2>/dev/null || true)"
  if [[ -n "${ready}" ]]; then
    echo "EndpointSlice ready: ${ready}"
    break
  fi
  if (( SECONDS >= deadline )); then
    echo "error: timed out waiting for ready endpoints on ${SERVICE}" >&2
    exit 1
  fi
  sleep 2
done

check_ca_bundle() {
  local kind="$1" name="$2"
  local ca
  ca="$(kubectl get "${kind}" "${name}" -o jsonpath='{.webhooks[0].clientConfig.caBundle}' 2>/dev/null || true)"
  if [[ -z "${ca}" ]]; then
    echo "error: ${kind}/${name} webhook CA bundle is empty" >&2
    exit 1
  fi
  echo "${kind}/${name} CA bundle is populated (${#ca} chars)"
}

if [[ -n "${MUTATING_WEBHOOK}" ]]; then
  check_ca_bundle mutatingwebhookconfiguration "${MUTATING_WEBHOOK}"
fi
if [[ -n "${VALIDATING_WEBHOOK}" ]]; then
  check_ca_bundle validatingwebhookconfiguration "${VALIDATING_WEBHOOK}"
fi

echo "webhook readiness checks passed"
