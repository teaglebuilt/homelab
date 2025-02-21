#! /bin/bash

PAYLOAD='{"api_key": "${OPENWEBUI_API_KEY}"}'

curl -d $PAYLOAD -H "Content-Type: application/json" \
  -X POST https://${OPENWEBUI_HOSTNAME}/api/v1/auths/api_key