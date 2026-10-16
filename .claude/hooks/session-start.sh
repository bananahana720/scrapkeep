#!/bin/bash
# Cloud sessions only: install the pinned native toolchain so headless Godot tests,
# bot runs, Linux exports and Blender recipes run in the container.
# Godot 4.7.2 and its templates use the same URLs and hashes as .github/workflows/native-smoke.yml.
# Blender 5.2.2 LTS comes from the bpy wheel on PyPI (download.blender.org is outside the
# default network policy); scripts/cloud/blender wraps it as a `blender` command.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

repo="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
toolchain=/opt/scrapkeep-toolchain
godot="$toolchain/Godot_v4.7.2-stable_linux.x86_64"
templates="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/4.7.2.stable"
release=https://github.com/godotengine/godot/releases/download/4.7.2-stable

mkdir -p "$toolchain"

if ! printf '%s  %s\n' 8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e "$godot" | sha256sum --check --status 2>/dev/null; then
  curl --fail --silent --show-error --location --retry 3 --output "$toolchain/editor.zip" "$release/Godot_v4.7.2-stable_linux.x86_64.zip"
  printf '%s  %s\n' 9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65 "$toolchain/editor.zip" | sha512sum --check --quiet
  python3 -I -c 'import sys, zipfile; from pathlib import Path; p = Path(sys.argv[2]); p.write_bytes(zipfile.ZipFile(sys.argv[1]).read(p.name)); p.chmod(0o755)' "$toolchain/editor.zip" "$godot"
  rm -f "$toolchain/editor.zip"
  printf '%s  %s\n' 8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e "$godot" | sha256sum --check --quiet
fi

if [ ! -x "$templates/linux_release.x86_64" ] || [ ! -x "$templates/linux_debug.x86_64" ]; then
  curl --fail --silent --show-error --location --retry 3 --output "$toolchain/templates.tpz" "$release/Godot_v4.7.2-stable_export_templates.tpz"
  printf '%s  %s\n' ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079 "$toolchain/templates.tpz" | sha512sum --check --quiet
  mkdir -p "$templates"
  python3 -I -c '
import sys, zipfile
from pathlib import Path
out = Path(sys.argv[2])
with zipfile.ZipFile(sys.argv[1]) as archive:
    for name in ["version.txt", "linux_debug.x86_64", "linux_release.x86_64"]:
        (out / name).write_bytes(archive.read("templates/" + name))
        (out / name).chmod(0o755)
' "$toolchain/templates.tpz" "$templates"
  rm -f "$toolchain/templates.tpz"
fi

if ! python3 -I -c 'import bpy, sys; sys.exit(bpy.app.version_string != "5.2.2 LTS")' 2>/dev/null; then
  python3 -m pip install --quiet --disable-pip-version-check --root-user-action=ignore bpy==5.2.2
fi

# Godot sizes its worker pool from the CPU count. On this 4 vCPU container the game's
# low-priority audio tasks starve and audio_rescue_test, audio_achievement_test and
# audio_bake_cancel_test hang at quit or race. A larger pool matches Andrew's machine.
# override.cfg is read only by local runs, kept out of git and out of export packs.
override="$repo/sketches/core-loop/override.cfg"
if [ ! -f "$override" ]; then
  printf '; Written by .claude/hooks/session-start.sh for cloud sessions only.\n[threading]\n\nworker_pool/max_threads=16\n' > "$override"
fi
exclude="$(git -C "$repo" rev-parse --path-format=absolute --git-path info/exclude)"
mkdir -p "$(dirname "$exclude")"
grep -qxF sketches/core-loop/override.cfg "$exclude" 2>/dev/null || echo sketches/core-loop/override.cfg >> "$exclude"

cd "$repo"
# npm ci keeps package-lock.json untouched; npm install rewrites it and dirties the tree.
if [ ! -f node_modules/.package-lock.json ] || [ package-lock.json -nt node_modules/.package-lock.json ]; then
  npm ci --no-audit --no-fund --loglevel=error
fi

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  {
    echo "export GODOT_BIN=$godot"
    echo "export PATH=$repo/scripts/cloud:\$PATH"
  } >> "$CLAUDE_ENV_FILE"
fi

echo "scrapkeep cloud toolchain: $("$godot" --headless --version 2>/dev/null | tail -1), $(python3 -I -c 'import bpy; print("Blender " + bpy.app.version_string)' 2>/dev/null)"
