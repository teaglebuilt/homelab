#!/bin/bash

set -euo pipefail

export KUBECONFIG='{{.KUBECONFIG_FILE}}'
ns='{{.AI_NAMESPACE}}'
agent='{{.AGENT}}'
tail_n='{{.TAIL}}'

echo "=== Agent {{.AGENT}} conditions ==="
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
