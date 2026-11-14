# Shared by doctor.sh, drive.sh and cleanup.sh: where the repo, the game and Godot are.
skill_dir="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
repo="$(git -C "$skill_dir" rev-parse --show-toplevel)"
[ -n "$repo" ] || { echo "verify-game: cannot find the repo from $skill_dir (git rev-parse failed)" >&2; exit 2; }
sketch="$repo/sketches/core-loop"
godot="${GODOT_BIN:-}"
for candidate in "$(command -v godot || true)" "$HOME/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64" /opt/scrapkeep-toolchain/Godot_v4.7.2-stable_linux.x86_64; do
  [ -n "$godot" ] && break
  [ -n "$candidate" ] && [ -x "$candidate" ] && godot="$candidate"
done
# Evidence is scratch, and the scripts delete scratch folders inside it, so it stays under artifacts/local/.
evidence_root="$(readlink -m "${VERIFY_GAME_EVIDENCE_ROOT:-$repo/artifacts/local/verify-game}")"
case "$evidence_root" in
  "$repo"/artifacts/local/?*) ;;
  *) echo "verify-game: VERIFY_GAME_EVIDENCE_ROOT must be a folder under $repo/artifacts/local/, not $evidence_root" >&2; exit 2 ;;
esac
# A pid file holds "<pid> <the process's start time>", so a pid the system gave to another process
# after ours ended is never taken for ours.
started_at() { sed 's/.*) //' "/proc/$1/stat" 2>/dev/null | cut -d' ' -f20; }
write_pid() { echo "$1 $(started_at "$1")" > "$2"; }
# ours <pid file>: prints the pid and returns 0 only when that same process is still running.
ours() {
  local pid start
  [ -f "$1" ] && read -r pid start < "$1" || return 1
  [ -n "$pid" ] && [ -n "$start" ] && [ "$(started_at "$pid")" = "$start" ] && echo "$pid"
}
# run_game <pid file> <log> <wall seconds> <command ...>: runs the command under a wall timeout, in a process
# group of its own, and sets $code to how it ended. Ctrl-C or a TERM to the calling script stops the game
# too ($code 143) and the script goes on to keep its evidence. Whatever is left of the group afterwards (a
# display, a game slow to stop) gets 20 seconds and is then killed by its group, never by name.
run_game() {
  local pidfile="$1" log="$2" limit="$3" last; shift 3
  game_pid=""; interrupted=0
  trap 'interrupted=1; [ -n "$game_pid" ] && kill -TERM "$game_pid" 2>/dev/null' INT TERM
  timeout --signal=TERM --kill-after=20 "$limit" "$@" > "$log" 2>&1 &
  game_pid=$!
  write_pid "$game_pid" "$pidfile"
  # A trapped signal ends a wait early, so wait again until the timeout process is really gone.
  while :; do wait "$game_pid"; code=$?; kill -0 "$game_pid" 2>/dev/null || break; done
  wait "$game_pid" 2>/dev/null; last=$?; [ "$last" = 127 ] || code=$last
  for _ in $(seq 1 20); do pgrep -g "$game_pid" > /dev/null || break; sleep 1; done
  pgrep -g "$game_pid" > /dev/null && kill -KILL -- "-$game_pid" 2>/dev/null
  trap - INT TERM
  [ "$interrupted" = 1 ] && code=143
  return 0
}
