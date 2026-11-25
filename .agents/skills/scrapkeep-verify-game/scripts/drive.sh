#!/usr/bin/env bash
# Launches the game from source and plays one step file through it (drive.gd has the step list).
# Usage: .agents/skills/scrapkeep-verify-game/scripts/drive.sh [--offscreen] <steps file> [<evidence name>] [-- <game flags>]
#   --offscreen      force offscreen drawing (macOS: --embedded --rendering-driver metal; Linux: xvfb-run; default on macOS)
#   <evidence name>  a folder name under artifacts/local/verify-game/ (default: the step file's name and the time)
#   <game flags>     passed to the game after its own `--`, e.g. --table=park --no-intro --self-play-save=<name>
# Env: GODOT_BIN, VERIFY_GAME_OFFSCREEN=1, VERIFY_GAME_DISPLAY=1 (draw on $DISPLAY, not xvfb), VERIFY_GAME_TIMEOUT (wall seconds, default 1500),
#      VERIFY_GAME_EXE=<packed game> (drive an exported core-loop.x86_64, not the source; scrapkeep-verify-build
#      sets it), VERIFY_GAME_EVIDENCE_ROOT (default artifacts/local/verify-game), VERIFY_GAME_SIZE (default 1280x720), VERIFY_GAME_HOME=<dir> (a save folder kept and shared by several
#      drives, e.g. quit in one and continue in the next; without it each drive starts as a new player and
#      its save folder is copied to <evidence>/saves and removed).
# Exit: 0 every step passed (or the file's last step was `quits` and the game quit), 1 a step failed,
#       2 a bad flag or name, 3 the game quit by itself before the step file ended, 124 the wall timeout
#       (137 when it had to be killed), 143 the script was interrupted (Ctrl-C, cleanup.sh --stop). The display
#       wrapper has codes of its own: with no row passed, 1 can be a display that did not start; see game.log.
set -uo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/common.sh"
offscreen="${VERIFY_GAME_OFFSCREEN:-0}"
while [ $# -ge 1 ]; do
  case "$1" in
    --offscreen) offscreen=1; shift ;;
    *) break ;;
  esac
done
[ $# -ge 1 ] || { sed -n 2,15p "${BASH_SOURCE[0]}"; exit 2; }
steps="$(readlink -f "$1")"; shift
[ -f "$steps" ] || { echo "drive: no step file $steps" >&2; exit 2; }
name="$(basename "${steps%.*}")-$(date -u +%Y%m%dT%H%M%SZ)"
if [ $# -ge 1 ] && [ "$1" != "--" ]; then name="$1"; shift; fi
[ "${1:-}" = "--" ] && shift
# The name is one folder under the evidence root: no path, no leading dash (a game flag given without its `--`).
[[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || { echo "drive: bad evidence name '$name' (letters, digits, . _ - only; game flags go after --)" >&2; exit 2; }
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
home="$(canonical_path "$home")"
cp "$steps" "$out/steps.txt"
{
  echo "commit $(git -C "$repo" rev-parse HEAD) branch $(git -C "$repo" rev-parse --abbrev-ref HEAD)"
  echo "dirty $(git -C "$repo" status --porcelain -- sketches/core-loop | wc -l | tr -d ' ') path(s) under sketches/core-loop"
  if [ -n "$exe" ]; then echo "packed game $exe"; else echo "godot $("$godot" --version | head -1)"; fi
  echo "started $(date -u +%FT%TZ)"
  echo "game flags: $*"
} > "$out/identity.txt"
# The game's user:// goes under the evidence folder, never the player's own saves.
export XDG_DATA_HOME="$home/data" XDG_CONFIG_HOME="$home/config" XDG_CACHE_HOME="$home/cache"
if is_macos; then
  export HOME="$home"
fi
size="${VERIFY_GAME_SIZE:-1280x720}"
# One save folder name unless the caller names one (--self-play-save=<name>, to keep a save across two drives).
save=("--self-play-save=verify")
for flag in "$@"; do case "$flag" in --self-play-save=*) save=() ;; esac; done
if [ -n "$exe" ]; then launch=("$exe"); cd "$(dirname "$exe")"; else launch=("$godot" --path "$sketch"); fi
if is_macos; then
  flags=(--rendering-driver metal)
  if [ "${VERIFY_GAME_DISPLAY:-}" != 1 ] || [ "$offscreen" = 1 ]; then
    export SCRAPKEEP_OFFSCREEN=1
    flags+=(--embedded)
  fi
  game=("${launch[@]}" "${flags[@]}" --debug --skip-breakpoints --ignore-error-breaks --audio-driver Dummy --resolution "$size" --fixed-fps 30 --
    --self-play "--self-play-script=$skill_dir/scripts/drive.gd" "${save[@]}" "--drive-steps=$out/steps.txt" "--drive-out=$out" "$@")
  run=("${game[@]}")
else
  game=("${launch[@]}" --rendering-driver opengl3 --audio-driver Dummy --resolution "$size" --fixed-fps 30 --
    --self-play "--self-play-script=$skill_dir/scripts/drive.gd" "${save[@]}" "--drive-steps=$out/steps.txt" "--drive-out=$out" "$@")
  if [ -n "${DISPLAY:-}" ] && [ "${VERIFY_GAME_DISPLAY:-}" = 1 ] && [ "$offscreen" != 1 ]; then
    run=("${game[@]}")
  else
    run=(xvfb-run -a -s "-screen 0 ${size}x24" "${game[@]}")
  fi
fi
run_game "$out/drive.pid" "$out/game.log" "${VERIFY_GAME_TIMEOUT:-1500}" "${run[@]}"
# The game can quit itself with 0 (Quit in the pause menu, Esc on the title). That is a pass only when
# the step file said so with a last `quits` step; anywhere else it hid the steps that never ran.
if [ "$code" = 0 ] && ! grep -q "^drive: done\|^drive: awaiting the game's own quit" "$out/game.log"; then
  echo "drive: the game quit by itself after $(grep -c '^drive: ok ' "$out/game.log") of $(grep -cvE '^\s*(#|$)' "$out/steps.txt") steps" | tee -a "$out/game.log"
  code=3
fi
echo "finished $(date -u +%FT%TZ) exit $code" >> "$out/identity.txt"
grep '^drive: ' "$out/game.log" | tail -40
# The game's save folder is copied into the evidence before any scratch goes, so the side effects stay.
userdata="$(userdata_dir "$home")"
if [ -d "$userdata" ]; then
  rm -rf "${out:?}/saves" && cp -r "$userdata" "$out/saves" && rm -rf "${out:?}/saves/shader_cache" "${out:?}/saves/vulkan"
  list_files_written "$out/saves" > "$out/files-written.txt"
fi
[ -n "${VERIFY_GAME_HOME:-}" ] || rm -rf "${out:?}/home"
rm -f "$out/drive.pid"
echo "drive: exit $code, evidence in $out"
exit $code
