#!/usr/bin/env bash
# Render every storyboard frame into ./renders (Cycles, CPU). 20 frames.
set -euo pipefail
cd "$(dirname "$0")"
OUT=${OUT:-renders}
ARGS=(--out "$OUT" --scale "${SCALE:-0.85}" --samples "${SAMPLES:-24}")
for b in dam penstock headframe sinkhole islands spire camp; do
  blender -b -P blockout.py -- --only "$b" "${ARGS[@]}"
done
blender -b -P blockout.py -- --only headframe --variant B --views play "${ARGS[@]}"
blender -b -P blockout.py -- --only sinkhole --variant B --views play "${ARGS[@]}"
blender -b -P blockout.py -- --only islands --variant B --views play "${ARGS[@]}"
blender -b -P blockout.py -- --only spire --variant B --views hero,play "${ARGS[@]}"
blender -b -P blockout.py -- --only camp --variant B --views hero "${ARGS[@]}"
