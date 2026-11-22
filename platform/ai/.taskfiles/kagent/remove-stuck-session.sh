#!/usr/bin/env bash
# List or delete kagent Sessions that hold WorkerPool capacity.
# Golden ActorTemplate builds fail with "no worker has room for the actor"
# when a live session occupies the only worker replica.
#
# Env (from Taskfile):
#   KUBECONFIG / KUBECONFIG_FILE  cluster kubeconfig
#   AI_NAMESPACE                  Agent namespace (default: ai)
#   SESSION                       Session id to delete (optional)
#   AGENT                         Filter list/delete by Agent name (optional)
#   ALL                           if true with AGENT, delete every matching Session
#   FORCE                         prefer Force delete (CLI --force or API) (default: true)
#   USER_ID                       kagent --user-id (default: admin@kagent.dev)
#   KAGENT_PROTO                  path to kagent proto module (buf.yaml) for API Force
#                                 fallback when CLI < 1.0.1 lacks --force

set -euo pipefail

if [ -n "${KUBECONFIG_FILE:-}" ]; then
  export KUBECONFIG="$KUBECONFIG_FILE"
fi
: "${KUBECONFIG:?KUBECONFIG or KUBECONFIG_FILE required}"

ns="${AI_NAMESPACE:-ai}"
user_id="${USER_ID:-admin@kagent.dev}"
force="${FORCE:-true}"
session_id="${SESSION:-}"
agent_filter="${AGENT:-}"
delete_all="${ALL:-false}"

if ! command -v kagent >/dev/null 2>&1; then
  echo "kagent CLI not found on PATH (install: task platform:ai:kagent:install)" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found on PATH" >&2
  exit 1
fi

echo "=== Agents waiting on golden snapshot (ActorTemplatePending) ==="
kubectl -n "$ns" get agents -o json 2>/dev/null \
  | jq -r '
      .items[]
      | select([.status.conditions[]? | select(.type=="Ready" and .reason=="ActorTemplatePending")] | length > 0)
      | "\(.metadata.name)\t\(.status.conditions[] | select(.type=="Ready") | .message)"
    ' || true
echo

agent_names="$(kubectl -n "$ns" get agents -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')"

echo "=== Sessions (namespace=${ns}, user=${user_id}) ==="
# Default api-url is localhost:8083; CLI port-forwards service/kagent-controller when needed.
# Strip C0 controls from agent.namespace (CLI protobuf leftovers) so jq stays valid.
raw="$(
  kagent -n "$ns" --user-id "$user_id" -o json agent session list --page-size 100 \
    | tr -d '\000-\010\013\014\016-\037'
)"

sessions="$(
  jq --arg filter "$agent_filter" --arg names "$agent_names" '
    def rows:
      if type == "array" then .
      elif .sessions then .sessions
      elif .items then .items
      elif .data then .data
      else []
      end;
    def unwrap: if type == "object" and has("session") then .session else . end;
    def sanitize: gsub("[^\\x20-\\x7E]"; " ");
    ($names | split("\n") | map(select(length > 0))) as $agentNames
    | [
        rows[]
        | unwrap
        | . as $s
        | ($s.agent.namespace // "" | sanitize) as $blob
        # Bind name before piping — `$blob | contains(.)` would rebind `.` to $blob.
        | ($agentNames | map(. as $n | select($blob | contains($n))) | last) as $resolved
        | {
            id: ($s.id // $s.sessionId // $s.session_id // $s.contextId // "?"),
            agent: ($resolved // "?"),
            state: ($s.state // $s.status // "-"),
            createdAt: ($s.createdAt // $s.createTime // $s.created_at // "-")
          }
        | select(($filter == "") or (.agent == $filter))
      ]
  ' <<<"$raw"
)"

count="$(jq 'length' <<<"$sessions")"
if [ "$count" -eq 0 ]; then
  echo "(none)"
  echo
  echo "Tip: confirm USER_ID matches the partition that created the Session,"
  echo "     or pass SESSION=<id> from the UI / A2A contextId."
  exit 0
fi

jq -r '.[] | [.id, .agent, .state, .createdAt] | @tsv' <<<"$sessions" \
  | column -t -s $'\t'
echo

ids_to_delete=()
if [ -n "$session_id" ]; then
  ids_to_delete=("$session_id")
elif [ "$delete_all" = "true" ]; then
  if [ -z "$agent_filter" ]; then
    echo "Refusing ALL=true without AGENT=<name> (would delete every Session for this user)." >&2
    exit 1
  fi
  while IFS= read -r id; do
    [ -n "$id" ] && [ "$id" != "null" ] && ids_to_delete+=("$id")
  done < <(jq -r '.[].id' <<<"$sessions")
else
  echo "Dry-run only. Delete with:"
  echo "  task platform:ai:kagent:remove-stuck-session SESSION=<id>"
  echo "  task platform:ai:kagent:remove-stuck-session AGENT=<agent> ALL=true"
  exit 0
fi

# --force exists on newer CLIs (1.0.1+); alpha16 and earlier reject the flag.
# When the CLI lacks --force (or delete aborts on an active task/checkpoint), fall
# back to SessionService.DeleteSession{force:true} via buf curl + port-forward.
want_force=false
if [ "$force" = "true" ] || [ "$force" = "1" ]; then
  want_force=true
fi

force_args=()
cli_has_force=false
if $want_force; then
  if kagent agent session delete --help 2>&1 | grep -q -- '--force'; then
    force_args=(--force)
    cli_has_force=true
  else
    echo "note: this kagent CLI has no --force; will use API Force fallback on conflict"
  fi
fi

resolve_kagent_proto() {
  if [ -n "${KAGENT_PROTO:-}" ] && [ -f "${KAGENT_PROTO}/buf.yaml" ]; then
    printf '%s\n' "$KAGENT_PROTO"
    return 0
  fi
  local candidate
  for candidate in \
    "${HOME}/github/opensource/kagent-dev/kagent/proto" \
    "${HOME}/src/kagent/proto" \
    "${HOME}/code/kagent/proto"
  do
    if [ -f "${candidate}/buf.yaml" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

# DeleteSession with force=true over gRPC (bypasses CLI flag gap / active-task Abort).
force_delete_via_api() {
  local id="$1"
  local proto_dir pf_log local_port pf_pid err

  if ! command -v buf >/dev/null 2>&1; then
    echo "warn: buf not on PATH; cannot Force-delete ${id} via API" >&2
    echo "      install buf, or upgrade CLI: task platform:ai:kagent:install" >&2
    return 1
  fi
  if ! proto_dir="$(resolve_kagent_proto)"; then
    echo "warn: kagent proto module not found; set KAGENT_PROTO=/path/to/kagent/proto" >&2
    echo "      or upgrade CLI (1.0.1+ has --force): task platform:ai:kagent:install" >&2
    return 1
  fi

  local_port="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')"
  pf_log="$(mktemp -t kagent-pf.XXXXXX)"
  kubectl -n "$ns" port-forward "svc/kagent-controller" "${local_port}:8083" >"$pf_log" 2>&1 &
  pf_pid=$!
  cleanup_pf() {
    kill "$pf_pid" 2>/dev/null || true
    wait "$pf_pid" 2>/dev/null || true
    rm -f "$pf_log"
  }

  # Wait until the forward is listening (or the pf process dies).
  for _ in $(seq 1 40); do
    if ! kill -0 "$pf_pid" 2>/dev/null; then
      echo "warn: port-forward to kagent-controller failed:" >&2
      cat "$pf_log" >&2 || true
      cleanup_pf
      return 1
    fi
    if nc -z 127.0.0.1 "$local_port" 2>/dev/null; then
      break
    fi
    sleep 0.1
  done

  echo "=== Force-deleting Session ${id} via API (buf curl) ==="
  if ! err="$(
    buf curl \
      --http2-prior-knowledge \
      --protocol grpc \
      --schema "$proto_dir" \
      --header "x-user-id: ${user_id}" \
      --data "{\"sessionId\":\"${id}\",\"force\":true}" \
      "http://127.0.0.1:${local_port}/kagent.api.v1.SessionService/DeleteSession" 2>&1
  )"; then
    echo "warn: API Force-delete failed for ${id}:" >&2
    echo "$err" >&2
    cleanup_pf
    return 1
  fi
  cleanup_pf

  if ! jq -e --arg id "$id" '.session.id == $id' >/dev/null 2>&1 <<<"$err"; then
    echo "warn: unexpected API response for ${id}:" >&2
    echo "$err" >&2
    return 1
  fi
  jq -c '{id: .session.id, state: .session.state}' <<<"$err"
  return 0
}

is_active_task_conflict() {
  local msg="$1"
  grep -qiE 'active task or checkpoint|lifecycle work is active|resource conflict|code = Aborted' <<<"$msg"
}

failed=0
for id in "${ids_to_delete[@]}"; do
  [ -n "$id" ] && [ "$id" != "null" ] || continue
  echo "=== Deleting Session ${id} ${force_args[*]:-} ==="
  delete_out=""
  if delete_out="$(kagent -n "$ns" --user-id "$user_id" agent session delete "$id" "${force_args[@]+"${force_args[@]}"}" 2>&1)"; then
    echo "$delete_out"
    continue
  fi
  echo "$delete_out" >&2

  if $want_force && { ! $cli_has_force || is_active_task_conflict "$delete_out"; }; then
    if force_delete_via_api "$id"; then
      continue
    fi
  fi

  echo "warn: failed to delete ${id}" >&2
  failed=$((failed + 1))
done
if [ "$failed" -gt 0 ]; then
  echo "error: ${failed} session delete(s) failed" >&2
  exit 1
fi

echo
echo "=== Agent Ready after delete ==="
kubectl -n "$ns" get agents -o custom-columns=\
'NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,REASON:.status.conditions[?(@.type=="Ready")].reason'
echo
echo "Golden snapshots may take a minute once a worker slot frees."
