#!/usr/bin/env bash
# Print Agent conditions and substrate worker + controller logs.
# Invoked by Taskfile with env: KUBECONFIG (or KUBECONFIG_FILE), AGENT, AI_NAMESPACE, TAIL.

set -euo pipefail

if [ -n "${KUBECONFIG_FILE:-}" ]; then
  export KUBECONFIG="$KUBECONFIG_FILE"
fi
: "${KUBECONFIG:?KUBECONFIG or KUBECONFIG_FILE required}"

agent="${AGENT:?AGENT required}"
ns="${AI_NAMESPACE:-ai}"
tail_n="${TAIL:-200}"

echo "=== Agent ${agent} conditions ==="
kubectl -n "$ns" get agent "$agent" -o jsonpath='{range .status.conditions[*]}{.type}={.status} reason={.reason} msg={.message}{"\n"}{end}'
echo

harness="$(kubectl -n "$ns" get agent "$agent" -o jsonpath='{.spec.harnessRef.name}')"
if [ -z "$harness" ]; then
  echo "Agent has no harnessRef.name" >&2
  exit 1
fi
worker_pool="$(kubectl -n "$ns" get harness "$harness" -o jsonpath='{.spec.substrate.workerPoolRef.name}')"
if [ -z "$worker_pool" ]; then
  echo "Harness $harness has no substrate.workerPoolRef.name" >&2
  exit 1
fi

echo "=== Harness=${harness} WorkerPool=${worker_pool} pods ==="
kubectl -n "$ns" get pods -l "ate.dev/worker-pool=${worker_pool}" -o wide
echo

echo "=== Worker logs (ate.dev/worker-pool=${worker_pool}, last ${tail_n}) ==="
kubectl -n "$ns" logs -l "ate.dev/worker-pool=${worker_pool}" --tail="$tail_n" --prefix=true \
  | grep -iE "${agent}|golden|crash|error|fail|panic" || true
echo

echo "=== kagent-controller logs (filtered, last ${tail_n}) ==="
kubectl -n "$ns" logs deploy/kagent-controller --tail="$tail_n" \
  | grep -iE "${agent}|Golden|ActorTemplate|crash|error" || true
