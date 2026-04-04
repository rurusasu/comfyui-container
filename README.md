# comfyui-container

[![Build GPU](https://github.com/rurusasu/comfyui-container/actions/workflows/build-gpu.yml/badge.svg)](https://github.com/rurusasu/comfyui-container/actions/workflows/build-gpu.yml)
[![Build CPU](https://github.com/rurusasu/comfyui-container/actions/workflows/build-cpu.yml/badge.svg)](https://github.com/rurusasu/comfyui-container/actions/workflows/build-cpu.yml)
[![Lint](https://github.com/rurusasu/comfyui-container/actions/workflows/lint.yml/badge.svg)](https://github.com/rurusasu/comfyui-container/actions/workflows/lint.yml)
[![Security Scan](https://github.com/rurusasu/comfyui-container/actions/workflows/security.yml/badge.svg)](https://github.com/rurusasu/comfyui-container/actions/workflows/security.yml)
[![Docker Hub](https://img.shields.io/docker/pulls/rurusasu/comfyui-container)](https://hub.docker.com/r/rurusasu/comfyui-container)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Production-ready [ComfyUI](https://github.com/comfy-org/ComfyUI) Docker image with **ComfyUI-Manager** pre-installed. GPU and CPU variants available.

---

## CI Pipeline

Each variant (GPU / CPU) runs an independent 3-phase pipeline:

| Phase | Check | Tool | Description |
|-------|-------|------|-------------|
| **Build** | Docker build | [Buildx](https://github.com/docker/buildx) | Multi-stage image build with layer caching |
| **Build** | Smoke test | `python -c "import torch; import comfy"` | Verify PyTorch and ComfyUI load correctly |
| **Test** | Security scan | [Trivy](https://github.com/aquasecurity/trivy) | Container image vulnerability scan (CRITICAL/HIGH) |
| **Push** | Publish | [Docker Hub](https://hub.docker.com/r/rurusasu/comfyui-container) | Push image only after all checks pass |

Standalone workflows (run on every PR and push to main):

| Workflow | Tool | Description |
|----------|------|-------------|
| **Lint** | [hadolint](https://github.com/hadolint/hadolint) | Dockerfile static analysis |
| **Security** | [Trivy](https://github.com/aquasecurity/trivy) | Config + filesystem scan with SARIF upload to GitHub Security tab |

```
build → test → push
  │       │       │
  │       │       └─ Docker Hub publish
  │       └─ Trivy image scan
  └─ docker build + smoke test

lint (on PR / push to main)
  └─ hadolint

security (on PR / push to main / weekly)
  ├─ Trivy config scan → GitHub Security tab
  └─ Trivy filesystem scan → GitHub Security tab
```

---

## Available Tags

| Tag | Base | CUDA | Size |
|---|---|---|---|
| `comfyui-0.18.3-base-gpu` | PyTorch 2.11.0 | 13.0 + cuDNN 9 | ![Size](https://img.shields.io/docker/image-size/rurusasu/comfyui-container/comfyui-0.18.3-base-gpu) |
| `comfyui-0.18.3-base-cpu` | Python 3.12 + PyTorch (CPU) | - | ![Size](https://img.shields.io/docker/image-size/rurusasu/comfyui-container/comfyui-0.18.3-base-cpu) |

### Tag Convention

```
comfyui-{version}-{variant}-{platform}
```

- **version**: ComfyUI release (e.g. `0.18.3`)
- **variant**: `base` (Manager only) / `full` (planned: with popular nodes)
- **platform**: `gpu` / `cpu`

---

## Quick Start

### GPU (NVIDIA)

```bash
docker run -d --gpus all \
  -p 8188:8188 \
  -v $(pwd)/models:/app/models \
  -v comfyui-data:/app/custom_nodes \
  --name comfyui \
  rurusasu/comfyui-container:comfyui-0.18.3-base-gpu
```

### CPU

```bash
docker run -d \
  -p 8188:8188 \
  -v $(pwd)/models:/app/models \
  -v comfyui-data:/app/custom_nodes \
  --name comfyui \
  rurusasu/comfyui-container:comfyui-0.18.3-base-cpu
```

Open **http://localhost:8188** in your browser.

---

## Features

| Feature | Description |
|---|---|
| **ComfyUI-Manager** | Pre-installed and enabled. Install custom nodes from the web UI. |
| **GPU/CPU support** | Single Dockerfile, switch with `--build-arg VARIANT=gpu\|cpu` |
| **Non-root execution** | Runs as `comfyui` user (UID 1000) for security |
| **Runtime node install** | `g++`, `git`, OpenCV libs included for compiling C++ extensions at runtime |
| **Volume-friendly** | Mount models and custom_nodes externally; volume seeding on first run |
| **Multi-stage build** | Smaller final image with builder dependencies excluded |

---

## Volume Mounts

| Container Path | Purpose | Recommended |
|---|---|---|
| `/app/models` | Model files (checkpoints, LoRA, VAE, etc.) | Bind mount to host |
| `/app/custom_nodes` | Custom nodes installed via Manager | Named volume |
| `/app/output` | Generated images | Bind mount to host |
| `/app/input` | Input images for workflows | Bind mount to host |

### Model Directory Structure

```
models/
  checkpoints/        # SD, SDXL, Flux checkpoints
  loras/              # LoRA models
  vae/                # VAE models
  controlnet/         # ControlNet models
  clip/               # CLIP models
  clip_vision/        # CLIP Vision models
  text_encoders/      # Text encoder models
  diffusion_models/   # Diffusion models
  embeddings/         # Textual inversion embeddings
  upscale_models/     # Upscale models (ESRGAN, etc.)
  ultralytics/        # YOLO detection models
    bbox/
    segm/
  sams/               # SAM models
  llm/GGUF/           # LLM GGUF models
```

---

## Docker Compose

```yaml
services:
  comfyui:
    image: rurusasu/comfyui-container:comfyui-0.18.3-base-gpu
    ports:
      - "8188:8188"
    volumes:
      - ./models:/app/models
      - ./output:/app/output
      - comfyui-nodes:/app/custom_nodes
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    restart: unless-stopped

volumes:
  comfyui-nodes:
```

---

## Build Locally

```bash
# GPU
docker build --build-arg VARIANT=gpu -t comfyui:base-gpu .

# CPU
docker build --build-arg VARIANT=cpu -t comfyui:base-cpu .

# Specific ComfyUI version
docker build --build-arg VARIANT=gpu --build-arg COMFYUI_VERSION=v0.18.3 \
  -t comfyui:base-gpu .
```

### Build Args

| Arg | Default | Description |
|---|---|---|
| `VARIANT` | `gpu` | `gpu` or `cpu` |
| `COMFYUI_VERSION` | `v0.18.3` | ComfyUI git tag |
| `PYTORCH_GPU_IMAGE` | `pytorch/pytorch:2.11.0-cuda13.0-cudnn9-runtime` | GPU base image |
| `PYTORCH_CPU_IMAGE` | `pytorch/pytorch:2.11.0-cpu` | CPU base image |

---

## Architecture

```
┌─────────────────────────────────────────────┐
│  Stage 1: builder                           │
│  ┌────────────┐  ┌────────────────────────┐ │
│  │ ComfyUI    │  │ Python venv            │ │
│  │ git clone  │  │ requirements.txt       │ │
│  │ (pinned)   │  │ manager_requirements   │ │
│  └────────────┘  └────────────────────────┘ │
├─────────────────────────────────────────────┤
│  Stage 2: runtime                           │
│  ┌────────────────────────────────────────┐ │
│  │ PyTorch (GPU or CPU)                   │ │
│  │ + git, g++, libgl1, libglib2.0-0      │ │
│  │ + ComfyUI app + venv (from builder)    │ │
│  │ + ComfyUI-Manager                      │ │
│  │ + Volume seed backups                  │ │
│  │ + Non-root user (comfyui:1000)         │ │
│  └────────────────────────────────────────┘ │
│  EXPOSE 8188                                │
└─────────────────────────────────────────────┘
```

---

## Security

- Runs as non-root user (`comfyui`, UID 1000)
- ComfyUI version pinned to specific git tag
- [Trivy](https://github.com/aquasecurity/trivy) scans on every build (image) and PR (config + filesystem)
- Scan results uploaded to [GitHub Security tab](https://github.com/rurusasu/comfyui-container/security)
- ComfyUI-Manager is enabled by default, allowing runtime node installation via web UI. This is an accepted trade-off for usability. Disable with custom CMD if needed.

---

## Roadmap

- [ ] `full` variant with popular custom nodes pre-installed
- [ ] ARM64 support
- [ ] Slim variant without g++ (smaller image, no runtime compilation)

---

## Contributing

Issues and PRs welcome at [github.com/rurusasu/comfyui-container](https://github.com/rurusasu/comfyui-container).

## License

[MIT](LICENSE)
