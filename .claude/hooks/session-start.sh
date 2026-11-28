#!/bin/bash
# Cloud sessions only: install the pinned native toolchain so headless Godot tests,
# bot runs, Linux exports and Blender recipes run in the container.
# tools/cloud/setup.sh owns the toolchain (Godot 4.7.2, templates, Blender 5.2.2 via bpy) and
# is a no-op when the environment's setup script already cached it; scripts/cloud/blender
# wraps bpy as a `blender` command.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

repo="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
# shellcheck source=../../tools/cloud/godot-version.env
. "$repo/tools/cloud/godot-version.env"
SCRAPKEEP_SETUP_STRICT=1 bash "$repo/tools/cloud/setup.sh"
godot="/opt/scrapkeep-toolchain/Godot_v${GODOT_VERSION}_linux.x86_64"

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
