#! /bin/bash

if [[ -z "$OPENWEBUI_API_KEY" || -z "$OPENWEBUI_HOSTNAME" ]]; then
  echo "Error: OPENWEBUI_API_KEY or OPENWEBUI_HOSTNAME is not set"
  exit 1
fi

PAYLOAD=$(jq -n --arg key "$OPENWEBUI_API_KEY" '{"api_key": $key}')
RESPONSE=$(curl -vv -s -d "$PAYLOAD" -H "Content-Type: application/json" -X POST "http://${OPENWEBUI_HOSTNAME}/api/v1/auths/api_key")

if [[ $? -ne 0 ]]; then
  echo "Error: Failed to make request to OpenWebUI"
  exit 1
fi
