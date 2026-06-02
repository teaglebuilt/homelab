#!/bin/sh

set -eu

MODELS_DIR=/app/models
NODES_DIR=/app/custom_nodes
INPUT_DIR=/app/input
OUTPUT_DIR=/app/output
USER_DIR=/app/user

mkdir -p \
  "${MODELS_DIR}/checkpoints" \
  "${MODELS_DIR}/vae" \
  "${MODELS_DIR}/vae_approx" \
  "${MODELS_DIR}/loras" \
  "${MODELS_DIR}/controlnet" \
  "${MODELS_DIR}/clip" \
  "${MODELS_DIR}/clip_vision" \
  "${MODELS_DIR}/embeddings" \
  "${MODELS_DIR}/upscale_models" \
  "${MODELS_DIR}/style_models" \
  "${MODELS_DIR}/hypernetworks" \
  "${MODELS_DIR}/unet" \
  "${MODELS_DIR}/diffusers" \
  "${MODELS_DIR}/gligen" \
  "${MODELS_DIR}/photomaker" \
  "${MODELS_DIR}/configs" \
  "${NODES_DIR}" \
  "${INPUT_DIR}" \
  "${OUTPUT_DIR}" \
  "${USER_DIR}"

# Idempotent download: skip if file already exists, resume if partial.
download() {
  url="$1"
  dest_dir="$2"
  filename="$(basename "${url}")"
  if [ -f "${dest_dir}/${filename}" ]; then
    echo "[skip] ${dest_dir}/${filename} already present"
  else
    echo "[get ] ${url} -> ${dest_dir}/"
    wget -c -q --show-progress -P "${dest_dir}" "${url}"
  fi
}

clone_node() {
  repo="$1"
  name="$(basename "${repo}" .git)"
  target="${NODES_DIR}/${name}"
  if [ -d "${target}/.git" ]; then
    echo "[pull] ${name}"
    git -C "${target}" pull --ff-only || echo "[warn] pull failed for ${name}, leaving as-is"
  else
    echo "[git ] cloning ${repo}"
    git clone --depth 1 "${repo}" "${target}"
  fi
}

echo "=== Checkpoints ==="
download \
  "https://huggingface.co/stable-diffusion-v1-5/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.safetensors" \
  "${MODELS_DIR}/checkpoints"
download \
  "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors" \
  "${MODELS_DIR}/checkpoints"
download \
  "https://huggingface.co/stabilityai/stable-diffusion-xl-refiner-1.0/resolve/main/sd_xl_refiner_1.0.safetensors" \
  "${MODELS_DIR}/checkpoints"

echo "=== VAE ==="
download \
  "https://huggingface.co/stabilityai/sd-vae-ft-mse-original/resolve/main/vae-ft-mse-840000-ema-pruned.safetensors" \
  "${MODELS_DIR}/vae"

echo "=== ControlNet ==="
download \
  "https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_canny.pth" \
  "${MODELS_DIR}/controlnet"
download \
  "https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11f1p_sd15_depth.pth" \
  "${MODELS_DIR}/controlnet"

echo "=== Custom nodes ==="
clone_node "https://github.com/ltdrdata/ComfyUI-Manager"

echo "=== Bootstrap complete ==="
