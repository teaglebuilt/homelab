#!/bin/sh
# After n8n answers /healthz, log in as the instance owner and mint the
# instance-level MCP API key once. The raw JWT is returned only on create;
# a later GET is redacted, and rotating it would invalidate every client.
# The key is stored in ai/n8n-mcp-token, which ksops does not manage.
set -u

url="http://127.0.0.1:5678"
ns="ai"
secret="n8n-mcp-token"

hold() {
  echo "$1"
  exec sleep infinity
}

# /healthz returns 200 before the REST routes are registered. A login during
# that window is a 404 from the "still starting" handler, not a bad password.
echo "waiting for n8n REST API"
i=0
while true; do
  code=$(curl -s -o /dev/null -w '%{http_code}' -X POST \
    -H 'content-type: application/json' -d '{}' "$url/rest/login") || code=000
  if [ "$code" != "404" ] && [ "$code" != "000" ]; then
    break
  fi
  i=$((i + 1))
  if [ "$i" -ge 150 ]; then
    hold "n8n /rest/login was still 404 after 5 minutes"
  fi
  sleep 2
done

if [ -z "${N8N_OWNER_EMAIL:-}" ] || [ -z "${N8N_OWNER_PASSWORD:-}" ]; then
  hold "set N8N_OWNER_EMAIL and N8N_OWNER_PASSWORD on secret n8n-secrets, then restart"
fi

escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

echo "logging in"
code=$(curl -s -o /tmp/login.json -w '%{http_code}' -c /tmp/cj \
  -H 'content-type: application/json' \
  -d "{\"emailOrLdapLoginId\":\"$(escape "$N8N_OWNER_EMAIL")\",\"password\":\"$(escape "$N8N_OWNER_PASSWORD")\"}" \
  "$url/rest/login") || true
if [ "$code" != "200" ]; then
  hold "owner login failed (HTTP ${code})"
fi

body=""
n=0
while [ "$n" -lt 30 ]; do
  body=$(curl -sf -b /tmp/cj "$url/rest/mcp/api-key") && break
  n=$((n + 1))
  sleep 2
done
[ -n "$body" ] || hold "GET /rest/mcp/api-key failed"
key=$(printf '%s' "$body" | sed -n 's/.*"apiKey"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
case "$key" in
  "") hold "response had no apiKey" ;;
  *\**) hold "MCP key already exists; leaving ai/${secret} unchanged" ;;
esac

token_file=/var/run/secrets/kubernetes.io/serviceaccount/token
ca=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
api="https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT:-443}"
auth="Authorization: Bearer $(cat "$token_file")"
payload="{\"apiVersion\":\"v1\",\"kind\":\"Secret\",\"metadata\":{\"name\":\"${secret}\",\"namespace\":\"${ns}\"},\"stringData\":{\"token\":\"Bearer ${key}\"}}"

code=$(curl -s -o /tmp/k8s.json -w '%{http_code}' --cacert "$ca" \
  -H "$auth" -H 'content-type: application/json' \
  -X POST -d "$payload" "$api/api/v1/namespaces/${ns}/secrets") || true
if [ "$code" = "409" ]; then
  code=$(curl -s -o /tmp/k8s.json -w '%{http_code}' --cacert "$ca" \
    -H "$auth" -H 'content-type: application/strategic-merge-patch+json' \
    -X PATCH -d "{\"stringData\":{\"token\":\"Bearer ${key}\"}}" \
    "$api/api/v1/namespaces/${ns}/secrets/${secret}") || true
fi
if [ "$code" != "200" ] && [ "$code" != "201" ]; then
  hold "writing secret ${ns}/${secret} failed (HTTP ${code})"
fi

hold "stored a new MCP token in secret ${ns}/${secret}"
