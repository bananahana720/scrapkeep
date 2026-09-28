#!/usr/bin/env bash
# Usage: run_trial.sh <raw_stem> <budget> <size_m> <size_axis> [clean_blender.py flags...]
# Example: run_trial.sh cliff_b_s3 3000 8.0 x --tile-axis x
# Cleans artifacts/local/img3d/raw/<raw_stem>_raw.glb in Blender, then renders its turntable,
# chase still and contact sheet. Blender runs headless in a 20G memory scope with CPU Cycles only.
set -uo pipefail

if [ "$#" -lt 4 ]; then
  echo "usage: run_trial.sh <raw_stem> <budget> <size_m> <size_axis> [clean_blender.py flags...]" >&2
  exit 64
fi

NAME="$1"
BUDGET="$2"
SIZE="$3"
SIZE_AXIS="$4"
shift 4

HERE="$(cd "$(dirname "$0")" && pwd)"
WORKTREE="$(cd "$HERE/../../../.." && pwd)"
EVIDENCE="$WORKTREE/artifacts/local/img3d"
mkdir -p "$EVIDENCE/clean" "$EVIDENCE/renders" "$EVIDENCE/logs"

BLENDER=(systemd-run --user --scope --quiet -p MemoryMax=20G -- blender -b --factory-startup)

start=$(date +%s)
if "${BLENDER[@]}" --python "$HERE/clean_blender.py" -- \
    --in "$EVIDENCE/raw/${NAME}_raw.glb" --out "$EVIDENCE/clean/$NAME.glb" \
    --budget "$BUDGET" --size "$SIZE" --size-axis "$SIZE_AXIS" "$@" \
    > "$EVIDENCE/logs/clean-$NAME.log" 2>&1; then
  echo "clean $NAME ok in $(( $(date +%s) - start ))s"
else
  echo "clean $NAME failed, see $EVIDENCE/logs/clean-$NAME.log" >&2
  exit 1
fi
grep -o 'CLEAN_JSON .*' "$EVIDENCE/logs/clean-$NAME.log" | cut -c12- >> "$EVIDENCE/clean/clean.jsonl"

start=$(date +%s)
if "${BLENDER[@]}" --python "$HERE/turntable_blender.py" -- \
    --in "$EVIDENCE/clean/$NAME.glb" --out-dir "$EVIDENCE/renders" --name "$NAME" \
    > "$EVIDENCE/logs/turntable-$NAME.log" 2>&1; then
  echo "turntable $NAME ok in $(( $(date +%s) - start ))s"
else
  echo "turntable $NAME failed, see $EVIDENCE/logs/turntable-$NAME.log" >&2
  exit 1
fi

montage "$EVIDENCE/renders/${NAME}"_tt_[0-7].png -tile 8x1 -geometry 300x300+2+2 "$EVIDENCE/renders/${NAME}_tt_sheet.png"
