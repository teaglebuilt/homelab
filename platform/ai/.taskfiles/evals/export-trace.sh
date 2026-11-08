#!/usr/bin/env bash

set -euo pipefail
# Poll agentevals for the exact A2A contextId session and export OTLP JSON.
#
# Usage:
#   [AGENTEVALS_URL=http://evals.homelab.internal] [TIMEOUT_SECS=180] \
#     export-trace.sh <RUN_DIR>
#
# Requires RUN_DIR/session-id written by invoke.sh (A2A contextId).
# Never picks the newest session — unmatched IDs fail closed.

RUN_DIR="${1:?RUN_DIR required}"
AGENTEVALS_URL="${AGENTEVALS_URL:-http://evals.homelab.internal}"
TIMEOUT_SECS="${TIMEOUT_SECS:-180}"
POLL_INTERVAL_SECS="${POLL_INTERVAL_SECS:-3}"

session_file="${RUN_DIR}/session-id"
if [[ ! -f "$session_file" ]]; then
  echo "missing session-id in ${RUN_DIR}" >&2
  exit 1
fi

context_id="$(tr -d '[:space:]' <"$session_file")"
if [[ -z "$context_id" ]]; then
  echo "empty session-id in ${RUN_DIR}" >&2
  exit 1
fi

sessions_url="${AGENTEVALS_URL%/}/api/streaming/sessions"
deadline=$((SECONDS + TIMEOUT_SECS))
matched=''

echo "Waiting for agentevals sessionId=${context_id} (timeout ${TIMEOUT_SECS}s)" >&2

while (( SECONDS < deadline )); do
  listing="$(curl -fsS --max-time 15 "$sessions_url" || true)"
  if [[ -z "$listing" ]]; then
    echo "  sessions list unreachable at ${sessions_url}" >&2
    sleep "$POLL_INTERVAL_SECS"
    continue
  fi

  matched="$(jq -c --arg ctx "$context_id" '
      (.data // [])
      | map(select(.sessionId == $ctx))
      | .[0] // empty
    ' <<<"$listing")"

  if [[ -n "$matched" ]]; then
    is_complete="$(jq -r '.isComplete // false' <<<"$matched")"
    span_count="$(jq -r '.spanCount // 0' <<<"$matched")"
    echo "  found session spanCount=${span_count} isComplete=${is_complete}" >&2
    if [[ "$is_complete" == "true" ]]; then
      break
    fi
  else
    ids="$(jq -r '(.data // []) | map(.sessionId) | join(", ")' <<<"$listing")"
    echo "  no match yet; known sessions: ${ids:-<none>}" >&2
  fi
  sleep "$POLL_INTERVAL_SECS"
done

if [[ -z "$matched" ]]; then
  echo "ERROR: no agentevals session with sessionId=${context_id}" >&2
  echo "List ${sessions_url} and confirm OTEL export reaches agentevals.ai:4318" >&2
  exit 1
fi

if [[ "$(jq -r '.isComplete // false' <<<"$matched")" != "true" ]]; then
  echo "ERROR: session ${context_id} still incomplete after ${TIMEOUT_SECS}s" >&2
  jq . <<<"$matched" >&2
  exit 1
fi

eval_session_id="$(jq -r '.sessionId' <<<"$matched")"
trace_out="${RUN_DIR}/trace.otlp.json"
curl -fsS --max-time 60 \
  "${AGENTEVALS_URL%/}/api/streaming/sessions/${eval_session_id}/otlp" \
  -o "$trace_out"

if ! jq -e '(.resourceSpans | length) > 0' "$trace_out" >/dev/null; then
  echo "ERROR: ${trace_out} has no resourceSpans" >&2
  exit 1
fi

# Soft checks — warn but still succeed if conversation id is present elsewhere.
conv_hits="$(jq -r --arg ctx "$context_id" '
  [
    .. | objects
    | select(has("key") and .key == "gen_ai.conversation.id" and (.value.stringValue // "") == $ctx)
  ] | length
' "$trace_out")"

span_names="$(jq -r '
  [.resourceSpans[]?.scopeSpans[]?.spans[]?.name // empty] | unique | .[]
' "$trace_out" | head -40)"

git_sha="$(git -C "${ROOT_DIR:-.}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
eval_set_hash='unknown'
if [[ -n "${SUITE:-}" && -n "${ROOT_DIR:-}" ]]; then
  eval_set="${ROOT_DIR}/platform/ai/agents/${SUITE}/evals/eval_set.json"
  if [[ -f "$eval_set" ]]; then
    eval_set_hash="$(shasum -a 256 "$eval_set" | awk '{print $1}')"
  fi
fi

jq -nc \
  --arg sessionId "$eval_session_id" \
  --arg contextId "$context_id" \
  --argjson spanCount "$(jq -r '.spanCount // 0' <<<"$matched")" \
  --argjson convHits "$conv_hits" \
  --arg gitSha "$git_sha" \
  --arg evalSetHash "$eval_set_hash" \
  --arg agentevalsUrl "$AGENTEVALS_URL" \
  --arg exportedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson spanNames "$(jq -Rn --arg s "$span_names" '$s | split("\n") | map(select(length>0))')" \
  '{
    sessionId: $sessionId,
    contextId: $contextId,
    spanCount: $spanCount,
    conversationIdHits: $convHits,
    gitSha: $gitSha,
    evalSetHash: $evalSetHash,
    agentevalsUrl: $agentevalsUrl,
    exportedAt: $exportedAt,
    sampleSpanNames: $spanNames
  }' >"${RUN_DIR}/metadata.json"

echo "Exported ${trace_out}"
echo "Metadata: ${RUN_DIR}/metadata.json"
if [[ "$conv_hits" == "0" ]]; then
  echo "WARN: gen_ai.conversation.id == ${context_id} not found in spans (session matched by sessionId)" >&2
fi
