# syntax=docker/dockerfile:1.7
#
# ComfyUI Container — base variant
# GPU/CPU switchable via VARIANT build arg.
#
# Usage:
#   docker build --build-arg VARIANT=gpu -t comfyui:base-gpu .
#   docker build --build-arg VARIANT=cpu -t comfyui:base-cpu .

ARG VARIANT=gpu
ARG COMFYUI_VERSION=v0.18.3
ARG PYTORCH_GPU_IMAGE=pytorch/pytorch:2.11.0-cuda13.0-cudnn9-runtime
ARG PYTORCH_CPU_IMAGE=python:3.13-slim

# ── Stage 1: builder ─────────────────────────────────────────
FROM ${PYTORCH_GPU_IMAGE} AS builder-gpu
FROM ${PYTORCH_CPU_IMAGE} AS builder-cpu
FROM builder-${VARIANT} AS builder

ARG VARIANT
ARG COMFYUI_VERSION

RUN apt-get update && \
    apt-get install -y --no-install-recommends git python3-venv && \
    rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch ${COMFYUI_VERSION} \
    https://github.com/comfy-org/ComfyUI.git /app

# Install into a venv so dependencies are self-contained
RUN python -m venv /opt/comfyui-env && \
    /opt/comfyui-env/bin/pip install --no-cache-dir --upgrade pip

# CPU: install PyTorch from CPU-only wheel index
# GPU: PyTorch is already in the base image, just install ComfyUI deps
RUN if [ "$VARIANT" = "cpu" ]; then \
      /opt/comfyui-env/bin/pip install --no-cache-dir \
        torch torchvision --index-url https://download.pytorch.org/whl/cpu; \
    fi && \
    /opt/comfyui-env/bin/pip install --no-cache-dir -r /app/requirements.txt && \
    /opt/comfyui-env/bin/pip install --no-cache-dir -r /app/manager_requirements.txt

# ── Stage 2: runtime ─────────────────────────────────────────
FROM ${PYTORCH_GPU_IMAGE} AS runtime-gpu
FROM ${PYTORCH_CPU_IMAGE} AS runtime-cpu
FROM runtime-${VARIANT} AS runtime

# Runtime dependencies:
# - git: required by ComfyUI-Manager for node management
# - g++: required for C++ extensions (insightface, etc.) installed at runtime
# - libgl1, libglib2.0-0: required by OpenCV (Impact-Pack, ControlNet)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git libgl1 libglib2.0-0 g++ && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/comfyui-env /opt/comfyui-env
# Copy app including .git (shallow clone, ~few MB).
# ComfyUI-Manager requires .git for version detection and security scanning.
COPY --from=builder /app /app

ENV PATH="/opt/comfyui-env/bin:$PATH"

# ── Model directories ────────────────────────────────────────
RUN mkdir -p /app/models/text_encoders \
             /app/models/diffusion_models \
             /app/models/vae \
             /app/models/loras \
             /app/models/checkpoints \
             /app/models/clip \
             /app/models/clip_vision \
             /app/models/controlnet \
             /app/models/embeddings \
             /app/models/upscale_models \
             /app/models/ultralytics/segm \
             /app/models/ultralytics/bbox \
             /app/models/sams \
             /app/models/llm/GGUF \
             /app/models/LLM

# Backup custom_nodes for volume seeding
# (entrypoint can copy to empty volume on first run)
RUN cp -r /app/custom_nodes /app/custom_nodes_default

# Run as non-root for security
RUN useradd -m -s /bin/bash comfyui && \
    chown -R comfyui:comfyui /app /opt/comfyui-env
USER comfyui

WORKDIR /app
EXPOSE 8188

CMD ["/opt/comfyui-env/bin/python", "main.py", "--listen", "0.0.0.0", "--port", "8188", "--enable-manager"]
