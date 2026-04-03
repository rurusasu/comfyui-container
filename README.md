# comfyui-container

ComfyUI + Manager の Docker イメージ。GPU/CPU 両対応。

## Tags

| Tag | 内容 |
|---|---|
| `comfyui-0.18.3-base-gpu` | CUDA runtime + ComfyUI + Manager |
| `comfyui-0.18.3-base-cpu` | CPU only + ComfyUI + Manager |

## Quick Start

```bash
# GPU
docker run --gpus all -p 8188:8188 \
  -v ./models:/app/models \
  rurusasu/comfyui-container:comfyui-0.18.3-base-gpu

# CPU
docker run -p 8188:8188 \
  -v ./models:/app/models \
  rurusasu/comfyui-container:comfyui-0.18.3-base-cpu
```

`http://localhost:8188` にアクセス。

## Features

- **ComfyUI-Manager** 有効 — Web UI からカスタムノードをインストール可能
- **non-root** ユーザーで実行
- **g++** 同梱 — C++ 拡張を使うノード（insightface 等）もランタイムインストール可能
- **volume mount** でモデルを外部管理

## Build Locally

```bash
# GPU
docker build --build-arg VARIANT=gpu -t comfyui:base-gpu .

# CPU
docker build --build-arg VARIANT=cpu -t comfyui:base-cpu .
```

## License

MIT
