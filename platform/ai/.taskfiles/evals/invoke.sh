#!/usr/bin/env bash

set -euo pipefail
# Invoke one eval case against a live kagent agent via A2A JSON-RPC.
# Avoids kagent CLI / controller proto skew (CLI rc3 ≠ cluster alpha16).
#
# Usage:
#   ROOT_DIR=… [EVAL_NAMESPACE=ai] [KAGENT_ENDPOINT=http://ai.homelab.internal/api] \
#     invoke.sh <agent> <suite> <case>
#
# Default endpoint is the HTTPRoute (ai.homelab.internal/api → controller, /api stripped).
# Override with KAGENT_ENDPOINT=http://localhost:8083 when port-forwarding.
#
# A2A HTTP path is /agents/{namespace}/{name} (not harness).

AGENT="${1:?agent name required}"
SUITE="${2:?suite directory under agents/ required}"
CASE="${3:?eval case id required}"

ROOT_DIR="${ROOT_DIR:?ROOT_DIR required}"
EVAL_NAMESPACE="${EVAL_NAMESPACE:-ai}"
KAGENT_ENDPOINT="${KAGENT_ENDPOINT:-http://ai.homelab.internal/api}"
EVAL_USER="${EVAL_USER:-eval@$(hostname -s 2>/dev/null || echo local).invalid}"
TIMEOUT_SECS="${TIMEOUT_SECS:-600}"

eval_set="${ROOT_DIR}/platform/ai/agents/${SUITE}/evals/eval_set.json"
if [[ ! -f "$eval_set" ]]; then
  echo "eval set not found: $eval_set" >&2
  exit 1
fi

prompt="$(jq -er --arg id "$CASE" '
  [.eval_cases[] | select(.eval_id == $id) |
    .conversation[0].user_content.parts[] | .text] | join("\n")
  ' "$eval_set")"

mkdir -p "${ROOT_DIR}/.eval-runs"
run_dir="$(mktemp -d "${ROOT_DIR}/.eval-runs/${SUITE}-XXXXXXXX")"
printf '%s\n' "$EVAL_USER" >"$run_dir/user-id"
printf '%s\n' "$prompt" >"$run_dir/prompt.txt"

endpoint="${KAGENT_ENDPOINT%/}/agents/${EVAL_NAMESPACE}/${AGENT}"

send_message() {
  local text="$1"
  local context_id="${2:-}"
  local msg_id
  msg_id="$(uuidgen | tr '[:upper:]' '[:lower:]')"

  jq -nc \
    --arg text "$text" \
    --arg ctx "$context_id" \
    --arg id "$msg_id" \
    --arg rid "$(uuidgen | tr '[:upper:]' '[:lower:]')" \
    '{
      jsonrpc: "2.0",
      id: $rid,
      method: "SendMessage",
      params: {
        message: (
          {
            messageId: $id,
            role: "ROLE_USER",
            parts: [{ text: $text }]
          }
          + (if $ctx == "" then {} else { contextId: $ctx } end)
        )
      }
    }' | curl -sS --fail-with-body --max-time "$TIMEOUT_SECS" \
      -H 'Content-Type: application/json' \
      -H "X-User-Id: ${EVAL_USER}" \
      --data-binary @- \
      "$endpoint"
}

echo "POST ${endpoint}" >&2
response="$(send_message "$prompt")"
printf '%s\n' "$response" >"$run_dir/response.json"

if jq -e '.error' >/dev/null 2>&1 <<<"$response"; then
  echo "A2A error:" >&2
  jq . <<<"$response" >&2
  exit 1
fi

context_id="$(jq -er '.result.task.contextId // .result.contextId // empty' <<<"$response" || true)"
task_id="$(jq -er '.result.task.id // .result.id // empty' <<<"$response" || true)"
task_state="$(jq -er '.result.task.status.state // empty' <<<"$response" || true)"
[[ -n "$context_id" ]] && printf '%s\n' "$context_id" >"$run_dir/session-id"
[[ -n "$task_id" ]] && printf '%s\n' "$task_id" >"$run_dir/task-id"
[[ -n "$task_state" ]] && printf '%s\n' "$task_state" >"$run_dir/task-state"

case "$task_state" in
  TASK_STATE_COMPLETED|TASK_STATE_FAILED|TASK_STATE_CANCELED|TASK_STATE_REJECTED|"")
    ;;
  *)
    echo "A2A task not terminal: state=${task_state:-<missing>}" >&2
    jq . <<<"$response" >&2
    exit 1
    ;;
esac

if [[ "$task_state" == "TASK_STATE_FAILED" || "$task_state" == "TASK_STATE_CANCELED" || "$task_state" == "TASK_STATE_REJECTED" ]]; then
  echo "A2A task ended unsuccessfully: ${task_state}" >&2
  jq . <<<"$response" >&2
  exit 1
fi

if [[ -z "$context_id" ]]; then
  echo "A2A response missing contextId / session-id" >&2
  jq . <<<"$response" >&2
  exit 1
fi

# Prefer the last agent text part; fall back to full JSON.
answer="$(jq -r '
  [
    (.result.task.status.message.parts // [])[],
    (.result.task.artifacts // [])[]?.parts[]?,
    (.result.message.parts // [])[]
  ]
  | map(select(.text != null) | .text)
  | last // empty
' <<<"$response")"

if [[ -n "$answer" ]]; then
  printf '%s\n' "$answer" | tee "$run_dir/response.txt"
else
  jq . <<<"$response" | tee "$run_dir/response.txt"
fi

# Machine-readable pointer for chained Taskfile tasks (export/score).
printf '%s\n' "$run_dir" >"${ROOT_DIR}/.eval-runs/last-run-dir"

echo "Session: ${context_id}"
echo "Task: ${task_id:-unknown}"
echo "State: ${task_state:-unknown}"
echo "Artifacts: $run_dir"
