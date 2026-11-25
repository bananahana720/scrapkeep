#!/usr/bin/env bash
# Films the repo's own bot playing a whole run through the launched game, menus pressed as keys, with
# any launch switches the caller adds (the sitting launch, a look switch). For flows too long to script
# as steps. The bot's saves go to a scratch folder under the evidence, never the player's own.
# Usage: .agents/skills/scrapkeep-verify-game/scripts/bot-run.sh [--offscreen] <evidence name> [-- <game flags>]
#   default goal: the run is won (--self-play-until=win); a flag given after -- wins over a default,
#   e.g. -- --profile=sitting   or   -- --self-play-until=2 --ball-look=cutaway
# Env: GODOT_BIN, VERIFY_GAME_OFFSCREEN=1, VERIFY_GAME_TIMEOUT (wall seconds, default 7000: a software renderer takes about four
#      wall seconds a game second, so run it in the background).
# Evidence: <evidence>/film/ (the kept frames and film.ndjson, what the game knew at each), game.log,
#      identity.txt, saves/ (run.json, runs.ndjson).
# Exit: the bot's own: 0 the goal was reached, 1 the run ended first, 3 a stall; 2 a bad argument or no
#       Godot; 124 the wall timeout (137 when it had to be killed); 143 the script was interrupted (Ctrl-C,
#       cleanup.sh --stop). The display wrapper has codes of its own: a 1 or 3 with no `self-play:` line in
#       game.log is a display that did not start, not the bot.
set -uo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/common.sh"
while [ $# -ge 1 ]; do
  case "$1" in
    --offscreen) shift ;;
    *) break ;;
  esac
done
[ $# -ge 1 ] || { sed -n 2,15p "${BASH_SOURCE[0]}"; exit 2; }
name="$1"; shift
[ "${1:-}" = "--" ] && shift
[[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || { echo "bot-run: bad evidence name '$name' (letters, digits, . _ - only; game flags go after --)" >&2; exit 2; }
[ -n "$godot" ] && [ -x "$godot" ] || { echo "bot-run: no Godot; run doctor.sh" >&2; exit 2; }
[ -d "$sketch/.godot/imported" ] || { echo "bot-run: project not imported; run doctor.sh" >&2; exit 2; }
out="$evidence_root/$name"
home="$out/home"
mkdir -p "$out/film" "$home/data" "$home/config" "$home/cache"
home="$(canonical_path "$home")"
{
  echo "commit $(git -C "$repo" rev-parse HEAD) branch $(git -C "$repo" rev-parse --abbrev-ref HEAD)"
  echo "dirty $(git -C "$repo" status --porcelain -- sketches/core-loop | wc -l | tr -d ' ') path(s) under sketches/core-loop"
  echo "godot $("$godot" --version | head -1)"
  echo "started $(date -u +%FT%TZ)"
  echo "game flags: $*"
} > "$out/identity.txt"
export XDG_DATA_HOME="$home/data" XDG_CONFIG_HOME="$home/config" XDG_CACHE_HOME="$home/cache"
if is_macos; then
  export HOME="$home"
  export SCRAPKEEP_OFFSCREEN=1
  run=("$godot" --embedded --rendering-driver metal --debug --skip-breakpoints --ignore-error-breaks --audio-driver Dummy --resolution 1280x720 --fixed-fps 30 --path "$sketch" --
    --self-play --self-play-seed=1 --self-play-policy=skipper --self-play-keys=1 --self-play-eyes=1 --self-play-watch=1
    --self-play-save=verify-bot --self-play-stall=600 "--self-play-film=$out/film" --self-play-until=win --self-play-hold=5 "$@")
else
  # The red team's film flags (scripts/redteam/lib.mjs filmArgs); the caller's flags come last and win.
  run=(xvfb-run -a -s "-screen 0 1280x720x24"
    "$godot" --rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 --fixed-fps 30 --path "$sketch" --
    --self-play --self-play-seed=1 --self-play-policy=skipper --self-play-keys=1 --self-play-eyes=1 --self-play-watch=1
    --self-play-save=verify-bot --self-play-stall=600 "--self-play-film=$out/film" --self-play-until=win --self-play-hold=5 "$@")
fi
run_game "$out/drive.pid" "$out/game.log" "${VERIFY_GAME_TIMEOUT:-7000}" "${run[@]}"
echo "finished $(date -u +%FT%TZ) exit $code" >> "$out/identity.txt"
grep '^self-play: ' "$out/game.log" | tail -12
userdata="$(userdata_dir "$home")"
if [ -d "$userdata" ]; then
  rm -rf "${out:?}/saves" && cp -r "$userdata" "$out/saves" && rm -rf "${out:?}/saves/shader_cache" "${out:?}/saves/vulkan"
  list_files_written "$out/saves" > "$out/files-written.txt"
fi
rm -rf "${out:?}/home"
rm -f "$out/drive.pid"
echo "bot-run: exit $code, $(ls "$out/film" | grep -c '\.jpg$') pictures, evidence in $out"
exit $code
