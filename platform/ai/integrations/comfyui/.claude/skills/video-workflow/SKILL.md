---
name: video-workflow
description: Create, validate, debug, execute, or optimize ComfyUI video workflows in this repository. Use whenever the user asks for a ComfyUI video, image-to-video workflow, text-to-video workflow, workflow JSON, workflow repair, workflow validation, model compatibility check, or VRAM optimization.
---

# ComfyUI Video Workflow

Follow the repository instructions in `CLAUDE.md`.

## Procedure

1. Determine whether the request is text-to-video, image-to-video,
   video-to-video, animation, interpolation, or upscaling.
2. Use the installed general ComfyUI workflow skill for workflow construction
   knowledge.
3. Inspect the live ComfyUI server with the configured MCP tools.
4. Verify installed nodes and models before writing final workflow JSON.
5. Create the initial workflow under `workflows/generated/`.
6. Validate it using the ComfyUI MCP validation tools.
7. Correct invalid node classes, inputs, links, models, and dimensions.
8. Move successfully validated workflows into `workflows/validated/`.
9. Execute only when the user explicitly requests generation.
10. Record important model, frame, resolution, FPS, and VRAM settings beside
    the workflow.
