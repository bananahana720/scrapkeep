#!/usr/bin/env bash
# Usage: fetch_licenses.sh
# Saves every license and model-card source that README.md quotes, plus a Hugging Face gate check,
# to artifacts/local/img3d/licenses/ with a sha256 manifest. Network only; no GPU.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORKTREE="$(cd "$HERE/../../../.." && pwd)"
OUT="$WORKTREE/artifacts/local/img3d/licenses"
IMG3D="$HOME/.local/share/img3d"
mkdir -p "$OUT"
LOG="$OUT/fetch.log"
echo "fetched $(date -Is)" > "$LOG"

SOURCES=(
  "trellis2_LICENSE.txt https://raw.githubusercontent.com/microsoft/TRELLIS.2/main/LICENSE"
  "trellis2_README.md https://raw.githubusercontent.com/microsoft/TRELLIS.2/main/README.md"
  "trellis2-4B_api.json https://huggingface.co/api/models/microsoft/TRELLIS.2-4B"
  "trellis2-4B_pipeline.json https://huggingface.co/microsoft/TRELLIS.2-4B/resolve/main/pipeline.json"
  "trellis1_LICENSE.txt https://raw.githubusercontent.com/microsoft/TRELLIS/main/LICENSE"
  "trellis1_README.md https://raw.githubusercontent.com/microsoft/TRELLIS/main/README.md"
  "trellis-image-large_api.json https://huggingface.co/api/models/microsoft/TRELLIS-image-large"
  "dinov3_LICENSE.md https://raw.githubusercontent.com/facebookresearch/dinov3/main/LICENSE.md"
  "dinov3-vitl16_api.json https://huggingface.co/api/models/facebook/dinov3-vitl16-pretrain-lvd1689m"
  "rmbg2_api.json https://huggingface.co/api/models/briaai/RMBG-2.0"
  "birefnet_api.json https://huggingface.co/api/models/ZhengPeng7/BiRefNet"
  "u2net_LICENSE.txt https://raw.githubusercontent.com/xuebinqin/U-2-Net/master/LICENSE"
  "rembg_LICENSE.txt https://raw.githubusercontent.com/danielgatis/rembg/main/LICENSE.txt"
  "hunyuan3d-2.1_LICENSE.txt https://raw.githubusercontent.com/Tencent-Hunyuan/Hunyuan3D-2.1/main/LICENSE"
  "hunyuan3d-2.1_README.md https://raw.githubusercontent.com/Tencent-Hunyuan/Hunyuan3D-2.1/main/README.md"
  "hunyuan3d-2.0_LICENSE.txt https://raw.githubusercontent.com/Tencent-Hunyuan/Hunyuan3D-2/main/LICENSE"
  "hunyuan3d-2.0_README.md https://raw.githubusercontent.com/Tencent-Hunyuan/Hunyuan3D-2/main/README.md"
)

failed=0
for entry in "${SOURCES[@]}"; do
  name="${entry%% *}"
  url="${entry#* }"
  if curl -fsSL --retry 2 -o "$OUT/$name" "$url"; then
    echo "ok $name $url" >> "$LOG"
  else
    echo "FAILED $name $url" >> "$LOG"
    failed=$((failed + 1))
  fi
done

LOCAL=(
  "trellis2_clone_LICENSE.txt $IMG3D/trellis2/LICENSE"
  "trellis1_clone_LICENSE.txt $IMG3D/trellis1/LICENSE"
  "flexicubes_vendored_LICENSE.txt $IMG3D/trellis1/trellis/representations/mesh/flexicubes/LICENSE.txt"
  "dinov2_hub_LICENSE.txt $IMG3D/torch-hub/hub/facebookresearch_dinov2_main/LICENSE"
  "dinov2_hub_LICENSE_CELL_DINO_MODELS.txt $IMG3D/torch-hub/hub/facebookresearch_dinov2_main/LICENSE_CELL_DINO_MODELS"
  "dinov2_hub_LICENSE_XRAY_DINO_MODEL.txt $IMG3D/torch-hub/hub/facebookresearch_dinov2_main/LICENSE_XRAY_DINO_MODEL"
)
for entry in "${LOCAL[@]}"; do
  name="${entry%% *}"
  src="${entry#* }"
  if cp "$src" "$OUT/$name"; then
    echo "ok $name $src" >> "$LOG"
  else
    echo "FAILED $name $src" >> "$LOG"
    failed=$((failed + 1))
  fi
done

qwen_license=$(find "$HOME/.cache/huggingface/hub/models--Qwen--Qwen-Image-2.1/snapshots" -maxdepth 2 -name LICENSE | head -1)
if [ -n "$qwen_license" ]; then
  cp -L "$qwen_license" "$OUT/qwen-image-2.1_LICENSE.txt"
  echo "ok qwen-image-2.1_LICENSE.txt $qwen_license" >> "$LOG"
else
  echo "FAILED qwen-image-2.1_LICENSE.txt not found in the HF cache" >> "$LOG"
  failed=$((failed + 1))
fi

"$IMG3D/venv-trellis1/bin/python" - > "$OUT/hf_auth_check.txt" 2>&1 <<'PY'
import datetime
import huggingface_hub
from huggingface_hub import auth_check, model_info

print("checked", datetime.datetime.now().astimezone().isoformat(), "huggingface_hub", huggingface_hub.__version__)
print("token present:", huggingface_hub.get_token() is not None)
for repo in ("facebook/dinov3-vitl16-pretrain-lvd1689m", "briaai/RMBG-2.0", "microsoft/TRELLIS.2-4B", "microsoft/TRELLIS-image-large"):
    try:
        gated = model_info(repo).gated
    except Exception as exc:
        gated = f"model_info failed: {type(exc).__name__}"
    try:
        auth_check(repo)
        verdict = "ACCESS OK"
    except Exception as exc:
        verdict = f"{type(exc).__name__}: {str(exc).splitlines()[0]}"
    print(f"{repo}\tgated={gated}\t{verdict}")
PY
echo "auth_check exit $?" >> "$LOG"

(cd "$OUT" && sha256sum -- *.txt *.md *.json | grep -v ' fetch.log$' > SHA256SUMS)
if [ "$failed" -eq 0 ]; then
  echo "all sources saved to $OUT"
else
  echo "$failed source(s) failed, see $LOG" >&2
  exit 1
fi
