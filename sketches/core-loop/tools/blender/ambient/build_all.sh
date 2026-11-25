#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SKETCH="$(cd "$HERE/../../.." && pwd)"
OUT="${1:-$SKETCH/assets/models/ambient}"
mkdir -p "$OUT"
LOG="$(mktemp)"
for path in "$HERE"/*.py; do
  recipe="$(basename "$path" .py)"
  case "$recipe" in _*|registry_fragment) continue ;; esac
  blender -b --threads 2 --python-exit-code 1 -P "$path" -- --out "$OUT/$recipe.glb" 2>&1 | tee -a "$LOG" | grep -E "^AMBIENT_EXPORT|Error|Traceback" || true
  grep -q "Traceback" "$LOG" && { echo "recipe $recipe failed; see $LOG" >&2; exit 1; }
done
if [ "$OUT" = "$SKETCH/assets/models/ambient" ]; then
  python3 "$HERE/registry_fragment.py" "$LOG" > "$SKETCH/assets/registry.d/ambient_life.json"
  echo "wrote assets/registry.d/ambient_life.json"
fi
rm -f "$LOG"
