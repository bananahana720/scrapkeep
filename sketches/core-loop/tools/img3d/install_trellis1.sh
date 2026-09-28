#!/usr/bin/env bash
# Installs microsoft/TRELLIS (v1) for mesh-only inference with no source-built CUDA extensions.
# Everything lands under ~/.local/share/img3d; weights go to the default Hugging Face cache.
set -euo pipefail

ROOT="$HOME/.local/share/img3d"
REPO="$ROOT/trellis1"
VENV="$ROOT/venv-trellis1"
UV="$HOME/.local/bin/uv"
export UV_CACHE_DIR=/tmp/uv-cache

mkdir -p "$ROOT"
if [ -d "$REPO/.git" ]; then
  echo "repo present: $REPO"
else
  git clone --recursive https://github.com/microsoft/TRELLIS.git "$REPO"
fi

if [ -x "$VENV/bin/python" ]; then
  echo "venv present: $VENV"
else
  "$UV" venv --python 3.10 "$VENV"
fi

PIP=("$UV" pip install --python "$VENV/bin/python")

"${PIP[@]}" torch==2.6.0 torchvision==0.21.0 --index-url https://download.pytorch.org/whl/cu124
"${PIP[@]}" xformers==0.0.29.post3 --index-url https://download.pytorch.org/whl/cu124
"${PIP[@]}" spconv-cu124
"${PIP[@]}" kaolin==0.18.0 -f https://nvidia-kaolin.s3.us-east-2.amazonaws.com/torch-2.6.0_cu124.html
"${PIP[@]}" pillow imageio imageio-ffmpeg tqdm easydict opencv-python-headless scipy ninja \
  rembg onnxruntime trimesh open3d xatlas pymeshfix igraph "transformers<5" huggingface_hub safetensors "numpy<2"
"${PIP[@]}" "git+https://github.com/EasternJournalist/utils3d.git@9a4eb15e4021b67b12c460c7057d642626897ec8"

"$VENV/bin/python" - <<'EOF'
import torch, xformers, spconv, kaolin
print("torch", torch.__version__, "cuda", torch.version.cuda, "available", torch.cuda.is_available())
print("xformers", xformers.__version__, "spconv", spconv.__version__, "kaolin", kaolin.__version__)
EOF
