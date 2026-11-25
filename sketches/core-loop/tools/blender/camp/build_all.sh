#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SKETCH="$(cd "$HERE/../../.." && pwd)"
OUT="${1:-$SKETCH/assets/models/camp}"
mkdir -p "$OUT"
LOG="$(mktemp)"
for recipe in plaza moss gate_lockers stations dressing skee pet practice; do
  blender -b --threads 2 --python-exit-code 1 -P "$HERE/$recipe.py" -- --out-dir "$OUT" 2>&1 | tee -a "$LOG" | grep -E "^CAMP_EXPORT|Error|Traceback" || true
  grep -q "Traceback" "$LOG" && { echo "recipe $recipe failed; see $LOG" >&2; exit 1; }
done
if [ "$OUT" = "$SKETCH/assets/models/camp" ]; then
  python3 "$HERE/registry_fragment.py" "$LOG" > "$SKETCH/assets/registry.d/camp.json"
  echo "wrote assets/registry.d/camp.json"
fi
rm -f "$LOG"
