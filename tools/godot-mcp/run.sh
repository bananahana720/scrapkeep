#!/usr/bin/env bash
# Starts the Godot MCP server (godot-mcp-runtime, MIT, pinned) for a Claude session.
# It lets a thread run the game, take screenshots, send input and read live values.
# Andrew approved it on 12 Nov 2026; .mcp.json at the repo root starts it.
#
# Godot: $GODOT_BIN, else `godot` on PATH, else the PC's recorded binary, else the cloud toolchain.
# Saves: user:// goes to a scratch folder under artifacts/local/, never Andrew's
# ~/.local/share/godot/app_userdata/core-loop (the PC lane's scratch-folder rule).
# Its launch and run_script prompts are off: a project thread has nobody to answer them.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo"
godot="${GODOT_BIN:-$(command -v godot || true)}"
for candidate in "$HOME/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64" /opt/scrapkeep-toolchain/Godot_v4.7.2-stable_linux.x86_64; do
  [ -n "$godot" ] && break
  [ -x "$candidate" ] && godot="$candidate"
done
[ -n "$godot" ] || { echo "godot-mcp: no Godot 4.7.2 found; set GODOT_BIN" >&2; exit 1; }
scratch="$repo/artifacts/local/godot-mcp"
mkdir -p "$scratch/data" "$scratch/config" "$scratch/cache"
export GODOT_MCP_DISABLE_ELICITATION=true GODOT_PATH="$godot"
export XDG_DATA_HOME="$scratch/data" XDG_CONFIG_HOME="$scratch/config" XDG_CACHE_HOME="$scratch/cache"
exec npx -y godot-mcp-runtime@4.0.1
