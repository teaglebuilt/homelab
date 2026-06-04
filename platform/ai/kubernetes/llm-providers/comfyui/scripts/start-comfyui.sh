#!/bin/sh

set -eu

NODES_DIR=/app/custom_nodes

# Install requirements for every custom node into THIS container's Python
# environment. Init containers can't do this for us because their site-packages
# live on an ephemeral image layer that doesn't survive container exit.
if [ -d "${NODES_DIR}" ]; then
  for req in "${NODES_DIR}"/*/requirements.txt; do
    [ -f "${req}" ] || continue
    node_name="$(basename "$(dirname "${req}")")"
    echo "[pip ] installing requirements for ${node_name}"
    pip3 install --no-cache-dir -r "${req}" || \
      echo "[warn] pip install failed for ${node_name}, continuing"
  done
fi

echo "[boot] starting ComfyUI"
exec python3 main.py --listen 0.0.0.0
