#!/usr/bin/env bash

set -u
base="${1:-proto/alpha}"
repo="$(git rev-parse --show-toplevel)"
sketch="$repo/sketches/core-loop"
godot="${GODOT:-$(node "$repo/scripts/godot-home.mjs" --bin 2>/dev/null)}"
command -v "$godot" >/dev/null || { echo "compile_check: no Godot found; set GODOT or GODOT_BIN" >&2; exit 2; }
checked=0
bad=0
for f in $(git -C "$sketch" diff --name-only "$base"...HEAD -- . | grep '\.gd$'); do
  rel="${f#sketches/core-loop/}"
  if [ -f "$sketch/$rel" ]; then
    checked=$((checked + 1))
    out="$(timeout 60 "$godot" --headless --path "$sketch" --check-only --script "res://$rel" 2>&1)"
    if printf '%s\n' "$out" | grep -q -E 'Parse Error|Compile Error'; then
      bad=$((bad + 1))
      echo "BAD $rel"
      printf '%s\n' "$out" | grep -E 'Parse Error|Compile Error' | head -3
    fi
  fi
done
echo "compile_check: $checked checked, $bad bad (base $base)"
if [ "$checked" -eq 0 ]; then
  echo "compile_check: nothing selected; check the base ref" >&2
  exit 2
elif [ "$bad" -gt 0 ]; then
  exit 1
else
  exit 0
fi
