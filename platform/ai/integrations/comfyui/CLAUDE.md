# ComfyUI Video Project

## Purpose

This project creates, validates, tests, and maintains ComfyUI video workflows
for an NVIDIA RTX 4070 SUPER with 12 GB VRAM.

## Required workflow

For requests involving ComfyUI workflows or video generation:

1. Use the installed `comfyui-workflow` user skill to plan or generate the
   initial workflow.
2. Use the ComfyUI MCP tools to inspect the live ComfyUI installation before
   finalizing the workflow.
3. Confirm that every required node, custom node, model, VAE, CLIP model, and
   checkpoint exists.
4. Validate the workflow through the ComfyUI MCP server.
5. Do not execute a generation unless explicitly requested.
6. When execution is requested, start with a low-cost test.
7. Inspect errors and outputs through MCP and revise the workflow as needed.
8. Save reusable workflow JSON under `workflows/validated/`.

## Hardware constraints

- GPU: NVIDIA RTX 4070 SUPER
- VRAM: 12 GB
- Prefer quantized or low-VRAM models where appropriate.
- Prefer model and text-encoder offloading.
- Avoid loading Ollama and ComfyUI generation models on the GPU simultaneously.
- Start video tests at 832x480 or lower.
- Start with approximately 49 frames.
- Generate one video at a time.
- Avoid workflows requiring more than 12 GB VRAM unless explicitly requested.

## Workflow requirements

- Prefer native ComfyUI nodes when practical.
- Verify custom nodes rather than assuming they are installed.
- Never invent node class names, model filenames, or input fields.
- Preserve seed, dimensions, frame count, FPS, sampler, scheduler, and model
  settings in generated workflow documentation.
- Save UI-compatible JSON and API-compatible JSON when both are available.

## Project directories

- `workflows/templates/`: imported reference workflows
- `workflows/generated/`: unverified generated workflows
- `workflows/validated/`: workflows successfully validated or executed
- `inputs/`: source images, audio, masks, and control media
- `outputs/`: generated media and execution metadata
