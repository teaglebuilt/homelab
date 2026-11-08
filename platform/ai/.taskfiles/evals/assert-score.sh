#!/usr/bin/env bash

set -euo pipefail
# Fail-closed assertion on agentevals --output json.
#
# Usage: assert-score.sh <SCORE_JSON>
# Optional: REQUIRE_PASS=false to allow quality failures while requiring metrics.

SCORE="${1:?SCORE json path required}"
REQUIRE_PASS="${REQUIRE_PASS:-true}"

if [[ ! -f "$SCORE" ]]; then
  echo "score file not found: $SCORE" >&2
  exit 1
fi

if ! jq -e '
  (.errors | length) == 0
  and (.traces | length) > 0
  and all(.traces[]; (.metrics | length) > 0)
' "$SCORE" >/dev/null; then
  echo "ASSERT FAIL: missing traces/metrics or top-level errors" >&2
  jq '{errors, trace_count: (.traces|length), metrics: [.traces[]?.metrics[]? | {metric_name, score, eval_status}]}' "$SCORE" >&2 || true
  exit 1
fi

if [[ "$REQUIRE_PASS" == "true" ]]; then
  if ! jq -e 'all(.traces[].metrics[]; .eval_status == "PASSED")' "$SCORE" >/dev/null; then
    echo "ASSERT FAIL: one or more metrics not PASSED" >&2
    jq -r '.traces[].metrics[] | [.metric_name, .score, .eval_status] | @tsv' "$SCORE" >&2
    exit 1
  fi
fi

echo "ASSERT OK"
jq -r '.traces[].metrics[] | [.metric_name, .score, .eval_status] | @tsv' "$SCORE"
