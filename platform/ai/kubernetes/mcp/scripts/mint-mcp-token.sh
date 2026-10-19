#!/bin/sh
# Mint the n8n instance MCP key once and store it in ai/n8n-mcp-token.
# Runs on mlops. n8n is reached through the ClusterMesh Service n8n-mesh.
# A later GET is redacted. This script never calls rotate unless
# N8N_MCP_ROTATE=true (manual task only).
set -u

url="${N8N_URL:-http://n8n-mesh.automation.svc.cluster.local:5678}"
ns="ai"
secret="n8n-mcp-token"
token_file=/var/run/secrets/kubernetes.io/serviceaccount/token
ca=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
api="https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT:-443}"

fail() {
  echo "$1"
  exit 1
}

# /healthz is 200 before /rest/* exists. Wait until POST /rest/login is JSON.
echo "waiting for n8n REST API"
i=0
while true; do
  ctype=$(curl -s -D - -o /dev/null -X POST \
    -H 'content-type: application/json' -d '{}' "$url/rest/login" \
    | tr -d '\r' | awk 'tolower($1)=="content-type:" {print tolower($2); exit}') || true
  case "$ctype" in
    application/json*) break ;;
  esac
  i=$((i + 1))
  if [ "$i" -ge 90 ]; then
    fail "n8n /rest/login did not return JSON after 3 minutes"
  fi
  sleep 2
done

if [ -z "${N8N_OWNER_EMAIL:-}" ] || [ -z "${N8N_OWNER_PASSWORD:-}" ]; then
  fail "secret n8n-owner is missing N8N_OWNER_EMAIL or N8N_OWNER_PASSWORD"
fi

email=$(printf '%s' "$N8N_OWNER_EMAIL" | tr -d '\r\n')
password=$(printf '%s' "$N8N_OWNER_PASSWORD" | tr -d '\r\n')
escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

auth="Authorization: Bearer $(cat "$token_file")"

# Confirm mlops will accept the Secret before n8n is asked for a one-time key.
apply_secret() {
  dry="$1"
  value="$2"
  qs="fieldManager=n8n-mcp-token-minter&force=true"
  if [ "$dry" = "1" ]; then
    qs="${qs}&dryRun=All"
  fi
  body=$(printf '%s\n' \
    "apiVersion: v1" \
    "kind: Secret" \
    "metadata:" \
    "  name: ${secret}" \
    "  namespace: ${ns}" \
    "stringData:" \
    "  token: \"${value}\"")
  code=$(curl -s -o /tmp/k8s.json -w '%{http_code}' --cacert "$ca" \
    -H "$auth" -H 'Content-Type: application/apply-patch+yaml' \
    -X PATCH --data-binary "$body" \
    "$api/api/v1/namespaces/${ns}/secrets/${secret}?${qs}") || return 1
  case "$code" in
    200|201) return 0 ;;
  esac
  echo "secret apply HTTP ${code}"
  return 1
}

if ! apply_secret 1 "Bearer dry-run"; then
  fail "dry-run write of ${ns}/${secret} failed; not asking n8n for a key"
fi

echo "logging in"
code=$(curl -s -o /tmp/login.json -w '%{http_code}' -c /tmp/cj \
  -H 'content-type: application/json' \
  --data-raw "{\"emailOrLdapLoginId\":\"$(escape "$email")\",\"password\":\"$(escape "$password")\"}" \
  "$url/rest/login") || true
if [ "$code" != "200" ]; then
  fail "owner login failed (HTTP ${code})"
fi

fetch_key() {
  path="$1"
  method="$2"
  body=""
  n=0
  while [ "$n" -lt 30 ]; do
    body=$(curl -sf -b /tmp/cj -X "$method" "$url$path") && break
    n=$((n + 1))
    sleep 2
  done
  printf '%s' "$body"
}

if [ "${N8N_MCP_ROTATE:-}" = "true" ]; then
  echo "rotating MCP key"
  raw=$(fetch_key /rest/mcp/api-key/rotate POST)
else
  raw=$(fetch_key /rest/mcp/api-key GET)
fi
[ -n "$raw" ] || fail "MCP api-key request failed"
key=$(printf '%s' "$raw" | sed -n 's/.*"apiKey"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
case "$key" in
  "") fail "response had no apiKey" ;;
  *\"*|*\\*) fail "apiKey is not safe to store" ;;
esac

store_key() {
  n=0
  while [ "$n" -lt 5 ]; do
    if apply_secret 0 "Bearer ${key}"; then
      return 0
    fi
    n=$((n + 1))
    sleep 2
  done
  return 1
}

if [ "${N8N_MCP_ROTATE:-}" = "true" ]; then
  case "$key" in
    *\**) fail "rotate returned a redacted key" ;;
  esac
  store_key || fail "rotated the MCP key but writing ${ns}/${secret} failed"
  echo "stored a rotated MCP token in ${ns}/${secret}"
  exit 0
fi

case "$key" in
  *\**)
    code=$(curl -s -o /tmp/existing.json -w '%{http_code}' --cacert "$ca" \
      -H "$auth" "$api/api/v1/namespaces/${ns}/secrets/${secret}") || fail "reading ${ns}/${secret} failed"
    if [ "$code" = "404" ]; then
      fail "n8n already has an MCP key and ${ns}/${secret} is missing. Run task platform:ai:n8n:mcp-token:rotate"
    fi
    if [ "$code" != "200" ]; then
      fail "reading ${ns}/${secret} failed (HTTP ${code})"
    fi
    b64=$(sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' /tmp/existing.json)
    [ -n "$b64" ] || fail "${ns}/${secret} has no token. Run task platform:ai:n8n:mcp-token:rotate"
    stored=$(printf '%s' "$b64" | base64 -d 2>/dev/null || true)
    probe=$(curl -s -o /dev/null -w '%{http_code}' \
      -H "Authorization: ${stored}" -H 'content-type: application/json' \
      --data-raw '{}' "$url/mcp-server/http") || probe="000"
    if [ "$probe" = "401" ]; then
      fail "stored MCP token was rejected. Run task platform:ai:n8n:mcp-token:rotate"
    fi
    echo "MCP key already exists; leaving ${ns}/${secret} unchanged"
    exit 0
    ;;
esac

store_key || fail "n8n issued a new MCP key but writing ${ns}/${secret} failed. Run task platform:ai:n8n:mcp-token:rotate"
echo "stored a new MCP token in ${ns}/${secret}"
