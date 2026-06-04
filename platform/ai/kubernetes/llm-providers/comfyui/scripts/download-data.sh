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
  "${MODELS_DIR}/diffusion_models" \
  "${MODELS_DIR}/gligen" \
  "${MODELS_DIR}/photomaker" \
  "${MODELS_DIR}/configs" \
  "${NODES_DIR}" \
  "${INPUT_DIR}" \
  "${OUTPUT_DIR}" \
  "${USER_DIR}"

# Skip download when dest exists and is non-empty; resume partial downloads otherwise.
# Usage: download <url> <dest_dir> [rename_to]
download() {
  url="$1"
  dest_dir="$2"
  filename="${3:-$(basename "${url}")}"
  dest="${dest_dir}/${filename}"

  if [ -s "${dest}" ]; then
    echo "[skip] ${dest} already present"
    return 0
  fi

  rm -f "${dest}"
  echo "[get ] ${url} -> ${dest}"
  wget -c -q --show-progress -O "${dest}" "${url}" || {
    rm -f "${dest}"
    echo "[err ] failed to download ${url}"
    return 1
  }
}

# Clone custom node only when missing; skip if already on the PVC.
clone_node() {
  repo="$1"
  name="$(basename "${repo}" .git)"
  target="${NODES_DIR}/${name}"

  if [ -d "${target}/.git" ] || [ -f "${target}/__init__.py" ]; then
    echo "[skip] ${name} already present at ${target}"
    return 0
  fi

  echo "[git ] cloning ${repo}"
  git clone --depth 1 "${repo}" "${target}"
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
download \
  "https://civitai.com/api/download/models/128713?type=Model&format=SafeTensor&size=pruned&fp=fp16" \
  "${MODELS_DIR}/checkpoints" \
  "dreamshaper_8.safetensors"
download \
  "https://huggingface.co/Lykon/DreamShaper/resolve/main/DreamShaper_5_beta2_noVae_half_pruned.safetensors?download=true" \
  "${MODELS_DIR}/checkpoints" \
  "dreamshaper5.safetensors"

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
clone_node "https://github.com/lum3on/ComfyUI-StableAudioX"

echo "=== AudioX (StableAudioX) ==="
download \
  "https://huggingface.co/HKUSTAudio/AudioX/resolve/main/model.ckpt" \
  "${MODELS_DIR}/diffusion_models" \
  "AudioX.ckpt"
download \
  "https://huggingface.co/HKUSTAudio/AudioX/resolve/main/config.json" \
  "${MODELS_DIR}/diffusion_models"

echo "=== Bootstrap complete ==="
