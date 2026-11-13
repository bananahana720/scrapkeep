#!/usr/bin/env bash
# Launches the game from source and plays one step file through it (drive.gd has the step list).
# Usage: .agents/skills/scrapkeep-verify-game/scripts/drive.sh <steps file> [<evidence name>] [-- <game flags>]
#   <evidence name>  a folder name under artifacts/local/verify-game/ (default: the step file's name and the time)
#   <game flags>     passed to the game after its own `--`, e.g. --table=park --no-intro --self-play-save=<name>
# Env: GODOT_BIN, VERIFY_GAME_DISPLAY=1 (draw on $DISPLAY, not xvfb), VERIFY_GAME_TIMEOUT (wall seconds, default 1500),
#      VERIFY_GAME_EXE=<packed game> (drive an exported core-loop.x86_64, not the source; scrapkeep-verify-build
#      sets it), VERIFY_GAME_EVIDENCE_ROOT (default artifacts/local/verify-game), VERIFY_GAME_SIZE (default 1280x720), VERIFY_GAME_HOME=<dir> (a save folder kept and shared by several
#      drives, e.g. quit in one and continue in the next; without it each drive starts as a new player and
#      its save folder is copied to <evidence>/saves and removed).
# Exit: the game's own: 0 every step passed, 1 a step failed, 2 a bad flag; 124 the wall timeout.
set -uo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/common.sh"
[ $# -ge 1 ] || { sed -n 2,8p "${BASH_SOURCE[0]}"; exit 2; }
steps="$(readlink -f "$1")"; shift
[ -f "$steps" ] || { echo "drive: no step file $steps" >&2; exit 2; }
name="$(basename "${steps%.*}")-$(date -u +%Y%m%dT%H%M%SZ)"
if [ $# -ge 1 ] && [ "$1" != "--" ]; then name="$1"; shift; fi
[ "${1:-}" = "--" ] && shift
out="$evidence_root/$name"
exe="${VERIFY_GAME_EXE:-}"
if [ -n "$exe" ]; then
  [ -x "$exe" ] || { echo "drive: no packed game at $exe" >&2; exit 2; }
  exe="$(readlink -f "$exe")"
else
  [ -n "$godot" ] && [ -x "$godot" ] || { echo "drive: no Godot; run doctor.sh" >&2; exit 2; }
  [ -d "$sketch/.godot/imported" ] || { echo "drive: project not imported; run doctor.sh" >&2; exit 2; }
fi
home="${VERIFY_GAME_HOME:-$out/home}"
mkdir -p "$out" "$home/data" "$home/config" "$home/cache"
home="$(readlink -f "$home")"
cp "$steps" "$out/steps.txt"
{
  echo "commit $(git -C "$repo" rev-parse HEAD) branch $(git -C "$repo" rev-parse --abbrev-ref HEAD)"
  echo "dirty $(git -C "$repo" status --porcelain -- sketches/core-loop | wc -l) path(s) under sketches/core-loop"
  if [ -n "$exe" ]; then echo "packed game $exe"; else echo "godot $("$godot" --version | head -1)"; fi
  echo "started $(date -u +%FT%TZ)"
  echo "game flags: $*"
} > "$out/identity.txt"
# The game's user:// goes under the evidence folder, never the player's own saves.
export XDG_DATA_HOME="$home/data" XDG_CONFIG_HOME="$home/config" XDG_CACHE_HOME="$home/cache"
size="${VERIFY_GAME_SIZE:-1280x720}"
# One save folder name unless the caller names one (--self-play-save=<name>, to keep a save across two drives).
save=("--self-play-save=verify")
for flag in "$@"; do case "$flag" in --self-play-save=*) save=() ;; esac; done
if [ -n "$exe" ]; then launch=("$exe"); cd "$(dirname "$exe")"; else launch=("$godot" --path "$sketch"); fi
game=("${launch[@]}" --rendering-driver opengl3 --audio-driver Dummy --resolution "$size" --fixed-fps 30 --
  --self-play "--self-play-script=$skill_dir/scripts/drive.gd" "${save[@]}" "--drive-steps=$out/steps.txt" "--drive-out=$out" "$@")
if [ -n "${DISPLAY:-}" ] && [ "${VERIFY_GAME_DISPLAY:-}" = 1 ]; then
  run=("${game[@]}")
else
  run=(xvfb-run -a -s "-screen 0 ${size}x24" "${game[@]}")
fi
timeout --signal=TERM --kill-after=20 "${VERIFY_GAME_TIMEOUT:-1500}" "${run[@]}" > "$out/game.log" 2>&1 &
pid=$!
echo "$pid" > "$out/drive.pid"
wait "$pid"
code=$?
rm -f "$out/drive.pid"
echo "finished $(date -u +%FT%TZ) exit $code" >> "$out/identity.txt"
grep '^drive: ' "$out/game.log" | tail -40
# The game's save folder is copied into the evidence before any scratch goes, so the side effects stay.
userdata="$home/data/godot/app_userdata/core-loop"
if [ -d "$userdata" ]; then
  rm -rf "$out/saves" && cp -r "$userdata" "$out/saves" && rm -rf "$out/saves/shader_cache" "$out/saves/vulkan"
  (cd "$out/saves" && find . -type f -printf '%p %s bytes\n' | sort) > "$out/files-written.txt"
fi
[ -n "${VERIFY_GAME_HOME:-}" ] || rm -rf "$out/home"
echo "drive: exit $code, evidence in $out"
exit $code
