#!/usr/bin/env bash
# Rebuilds every ambient life GLB (each tools/blender/ambient/<kind>.py recipe present) and prints one AMBIENT_EXPORT row
# per file (sha256 included), then writes the registry fragment.
#   sketches/core-loop/tools/blender/ambient/build_all.sh [OUT_DIR]      (default: assets/models/ambient)
# Run it twice into two directories and compare the sha256 rows to prove the kit rebuilds byte-identically.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SKETCH="$(cd "$HERE/../../.." && pwd)"
OUT="${1:-$SKETCH/assets/models/ambient}"
mkdir -p "$OUT"
LOG="$(mktemp)"
for path in "$HERE"/*.py; do
  recipe="$(basename "$path" .py)"
  case "$recipe" in _*|registry_fragment) continue ;; esac
  # A recipe is named for its kind, and the record names the model <kind>.glb.
  blender -b --threads 2 --python-exit-code 1 -P "$path" -- --out "$OUT/$recipe.glb" 2>&1 | tee -a "$LOG" | grep -E "^AMBIENT_EXPORT|Error|Traceback" || true
  grep -q "Traceback" "$LOG" && { echo "recipe $recipe failed; see $LOG" >&2; exit 1; }
done
if [ "$OUT" = "$SKETCH/assets/models/ambient" ]; then
  python3 "$HERE/registry_fragment.py" "$LOG" > "$SKETCH/assets/registry.d/ambient_life.json"
  echo "wrote assets/registry.d/ambient_life.json"
fi
rm -f "$LOG"
