#!/usr/bin/env bash
# Fails if plaintext secrets appear in files that are meant to be committed.
set -euo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

SECRETS=homelab.sops.env
PLAIN_FILES=(.envrc .envrc.next homelab.env)
SECRET_NAME='(KEY|TOKEN|SECRET|PASSWORD|PASS)$'
SECRET_VALUE='(sk-[A-Za-z0-9_-]{16,}|nvapi-|hf_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|![A-Za-z0-9_-]+=[0-9a-f-]{36})'
fail=0

if [ -f "$SECRETS" ]; then
  grep -q '^sops_mac=' "$SECRETS" || { echo "$SECRETS is not sops-encrypted"; fail=1; }
  if grep -vE '^(#|$|sops_)' "$SECRETS" | grep -vqE '^[A-Z0-9_]+=ENC\['; then
    echo "$SECRETS contains unencrypted values"; fail=1
  fi
  managed="$(grep -oE '^[A-Z0-9_]+=' "$SECRETS" | grep -v '^sops_' | tr -d '=' | paste -sd'|' -)"
fi

for f in "${PLAIN_FILES[@]}"; do
  [ -f "$f" ] || continue
  git check-ignore -q "$f" && [ "$f" = .envrc ] && continue
  while IFS= read -r line; do
    [[ $line =~ ^[[:space:]]*(export[[:space:]]+)?([A-Z0-9_]+)=(.+)$ ]] || continue
    key=${BASH_REMATCH[2]}; val=${BASH_REMATCH[3]}
    [[ $val == *'$('* || $val == *'${'* || $val == '""' ]] && continue
    if [[ -n "${managed:-}" && $key =~ ^($managed)$ ]]; then
      echo "$f: $key is managed in $SECRETS and must not be set here"; fail=1
    elif [[ $key =~ $SECRET_NAME ]] || [[ $val =~ $SECRET_VALUE ]]; then
      echo "$f: $key looks like a secret; move it to $SECRETS (task secrets:edit)"; fail=1
    fi
  done < "$f"
done

exit $fail
