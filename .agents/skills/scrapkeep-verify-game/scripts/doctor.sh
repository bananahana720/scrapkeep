#!/usr/bin/env bash
# Read-only: is this checkout worth driving? Prints one line a check and exits 1 on any FAIL.
# Usage: .agents/skills/scrapkeep-verify-game/scripts/doctor.sh
set -uo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/common.sh"
bad=0
say() { printf '%-5s %s\n' "$1" "$2"; [ "$1" = FAIL ] && bad=1; return 0; }

say INFO "checkout $repo at $(git -C "$repo" rev-parse --short=8 HEAD) on $(git -C "$repo" rev-parse --abbrev-ref HEAD)"
dirty="$(git -C "$repo" status --porcelain -- sketches/core-loop | wc -l)"
say INFO "$dirty uncommitted path(s) under sketches/core-loop (the proof covers the tree as it stands, so name them)"

if [ -n "$godot" ] && [ -x "$godot" ]; then
  version="$("$godot" --version 2>/dev/null | head -1)"
  case "$version" in 4.7.2.stable*) say OK "Godot $version at $godot" ;; *) say FAIL "Godot is '$version', the game is pinned to 4.7.2.stable ($godot)" ;; esac
else
  say FAIL "no Godot 4.7.2 found: set GODOT_BIN (cloud: tools/cloud/setup.sh installs it)"
fi

if [ -d "$sketch/.godot/imported" ]; then
  say OK "project imported ($(ls "$sketch/.godot/imported" | wc -l) files in .godot/imported)"
else
  say FAIL "project not imported: run  \"\$GODOT_BIN\" --headless --path sketches/core-loop --import  (up to three tries, see Launch)"
fi

if grep -q '^McpBridge' "$sketch/project.godot" 2>/dev/null; then
  say FAIL "project.godot carries the Godot MCP's McpBridge autoload: another session is running the game here; stop it (stop_project) or use another worktree"
else
  say OK "no McpBridge autoload in project.godot"
fi

if [ -n "${DISPLAY:-}" ] && [ "${VERIFY_GAME_DISPLAY:-}" = 1 ]; then
  say OK "drawing on the machine's own display $DISPLAY (VERIFY_GAME_DISPLAY=1)"
elif command -v xvfb-run >/dev/null; then
  say OK "xvfb-run found: each drive draws on a display of its own"
else
  say FAIL "no xvfb-run, and VERIFY_GAME_DISPLAY=1 is not set: nothing to draw on"
fi

running=0
for pidfile in "$evidence_root"/*/drive.pid; do
  [ -f "$pidfile" ] || continue
  if pid="$(ours "$pidfile")"; then running=$((running + 1)); say INFO "a drive is running: pid $pid, $(dirname "$pidfile")"; fi
done
say OK "$running drive(s) running from this checkout (each has its own display and save folder, so more than one is safe; each wants about two cores)"
say INFO "saves go to <evidence>/home, never ~/.local/share/godot/app_userdata/core-loop"
exit $bad
