# CLAUDE.md

Claude Code 向けのプロジェクトガイド。

## プロジェクト概要

ComfyUI の本番向け Docker イメージ。GPU/CPU 両対応のマルチステージビルド。

- **リポジトリ**: `rurusasu/comfyui-container`
- **Docker Hub**: `rurusasu/comfyui-container`
- **ライセンス**: MIT

## ディレクトリ構成

```
.
├── docker/
│   ├── Dockerfile             # メインのマルチステージビルド定義
│   └── docker-compose.yaml    # Docker Compose サービス定義
├── .hadolint.yaml             # hadolint 設定（ignore ルール）
├── .dockerignore
├── .github/
│   ├── workflows/
│   │   ├── build-gpu.yml      # GPU イメージ: build → test → push
│   │   ├── build-cpu.yml      # CPU イメージ: build → test → push
│   │   ├── lint.yml           # hadolint (PR / push to main)
│   │   └── security.yml       # Trivy スキャン (PR / push / weekly)
│   └── actions/
│       ├── docker-build-push/ # Buildx ビルド + Docker Hub push
│       └── free-disk-space/   # CI ランナーのディスク確保
├── README.md
└── CLAUDE.md
```

## Dockerfile アーキテクチャ

- **ARG `VARIANT`**: `gpu` / `cpu` でベースイメージを切り替え
- **Stage 1 (builder)**: ComfyUI クローン + Python venv + pip install
- **Stage 2 (runtime)**: ランタイム依存のみ + venv/app コピー + 非 root ユーザー
- GPU: `pytorch/pytorch:2.11.0-cuda13.0-cudnn9-runtime`
- CPU: `python:3.13-slim`

## ビルドコマンド

```bash
# GPU (docker compose)
docker compose -f docker/docker-compose.yaml up --build

# GPU (docker build)
docker build -f docker/Dockerfile --build-arg VARIANT=gpu -t comfyui:base-gpu .

# CPU
docker build -f docker/Dockerfile --build-arg VARIANT=cpu -t comfyui:base-cpu .

# バージョン指定
docker build -f docker/Dockerfile --build-arg VARIANT=gpu --build-arg COMFYUI_VERSION=v0.18.3 -t comfyui:base-gpu .
```

## Lint / テスト

```bash
# Dockerfile lint
hadolint docker/Dockerfile

# smoke test (ビルド後)
docker run --rm comfyui:base-gpu \
  python -c "import torch; import comfy; print(f'torch={torch.__version__} comfy=ok')"
```

## CI/CD パイプライン

### ビルドワークフロー (`build-gpu.yml` / `build-cpu.yml`)

トリガー: タグ push (`v*`) / workflow_dispatch

```
build → test → push
  │       │       │
  │       │       └─ Docker Hub publish
  │       └─ Trivy image scan (CRITICAL/HIGH)
  └─ docker build + smoke test
```

### Lint (`lint.yml`)

トリガー: PR / push to main → hadolint

### Security (`security.yml`)

トリガー: PR / push to main / 毎週月曜 09:00 UTC → Trivy config + fs スキャン → GitHub Security tab (SARIF)

## コーディング規約

### Dockerfile

- `# syntax=docker/dockerfile:1.7` を先頭に維持
- `apt-get` は必ず `--no-install-recommends` + `rm -rf /var/lib/apt/lists/*`
- `pip install` は必ず `--no-cache-dir`
- レイヤー数を最小限にする（関連する RUN は `&&` で統合）
- hadolint で警告ゼロを維持（ignore は `.hadolint.yaml` で管理、理由をコメント）

### GitHub Actions

- Actions のバージョンはメジャーバージョンで固定（例: `actions/checkout@v6`）
- composite action は `.github/actions/` 以下に配置
- ジョブの責務を分離（build / test / push）

### Git

- コミットメッセージ: [Conventional Commits](https://www.conventionalcommits.org/) 形式
  - `feat:`, `fix:`, `chore:`, `ci:`, `docs:`, `perf:`, `refactor:`, `test:`
- ブランチ: `feature/*`, `fix/*`, `docs/*`
- Issue ごとにブランチを作成し PR でマージ

## 注意事項

- `.hadolint.yaml` の ignore ルール (DL3006, DL3008, DL3059) は意図的。変更前にコメントを確認
- ComfyUI-Manager は `.git` ディレクトリに依存するため、app コピー時に `.git` を含める
- `g++` はランタイムでカスタムノードのC++拡張をコンパイルするために必要
- 非 root ユーザー `comfyui` (UID 1000) で実行
