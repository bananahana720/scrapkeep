# Shared by doctor.sh, drive.sh, bot-run.sh and cleanup.sh: where the repo, the game and Godot are.
is_macos() { [ "$(uname -s)" = "Darwin" ]; }
canonical_path() {
  if readlink -m "$1" 2>/dev/null; then return 0; fi
  python3 -c 'import os, sys; print(os.path.realpath(os.path.abspath(sys.argv[1])))' "$1"
}
skill_dir="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
repo="$(git -C "$skill_dir" rev-parse --show-toplevel)"
[ -n "$repo" ] || { echo "verify-game: cannot find the repo from $skill_dir (git rev-parse failed)" >&2; exit 2; }
sketch="$repo/sketches/core-loop"
godot="${GODOT_BIN:-}"
for candidate in \
  "$(command -v godot || true)" \
  "$HOME/Applications/Godot_4.7.2.app/Contents/MacOS/Godot" \
  "$HOME/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64" \
  /opt/scrapkeep-toolchain/Godot_v4.7.2-stable_linux.x86_64; do
  [ -n "$godot" ] && break
  [ -n "$candidate" ] && [ -x "$candidate" ] && godot="$candidate"
done
# Evidence is scratch, and the scripts delete scratch folders inside it, so it stays under artifacts/local/.
evidence_root="$(canonical_path "${VERIFY_GAME_EVIDENCE_ROOT:-$repo/artifacts/local/verify-game}")"
case "$evidence_root" in
  "$repo"/artifacts/local/?*) ;;
  *) echo "verify-game: VERIFY_GAME_EVIDENCE_ROOT must be a folder under $repo/artifacts/local/, not $evidence_root" >&2; exit 2 ;;
esac
# Where Godot writes user:// for a given scratch home. On macOS Godot ignores XDG_DATA_HOME and
# uses $HOME/Library/Application Support/Godot/app_userdata/core-loop (scripts/godot-home.mjs).
userdata_dir() {
  local h="$1"
  if is_macos; then
    if [ -d "$h/Library/Application Support/Godot/app_userdata/core-loop" ]; then
      echo "$h/Library/Application Support/Godot/app_userdata/core-loop"
    else
      echo "$h/Library/Application Support/godot/app_userdata/core-loop"
    fi
  else
    echo "$h/data/godot/app_userdata/core-loop"
  fi
}
list_files_written() {
  local dir="$1"
  python3 -c '
import os, sys
root = sys.argv[1]
rows = []
for base, _, files in os.walk(root):
    for f in files:
        p = os.path.join(base, f)
        rel = "./" + os.path.relpath(p, root).replace(os.sep, "/")
        rows.append(f"{rel} {os.path.getsize(p)} bytes")
for row in sorted(rows):
    print(row)
' "$dir"
}
# A pid file holds "<pid> <the process's start time>", so a pid the system gave to another process
# after ours ended is never taken for ours.
started_at() {
  if [ -r "/proc/$1/stat" ]; then
    sed 's/.*) //' "/proc/$1/stat" 2>/dev/null | cut -d' ' -f20
  else
    ps -o lstart= -p "$1" 2>/dev/null | tr -s ' ' '_' | sed 's/^_//;s/_$//'
  fi
}
write_pid() { echo "$1 $(started_at "$1")" > "$2"; }
# ours <pid file>: prints the pid and returns 0 only when that same process is still running.
ours() {
  local pid start
  [ -f "$1" ] && read -r pid start < "$1" || return 1
  [ -n "$pid" ] && [ -n "$start" ] && [ "$(started_at "$pid")" = "$start" ] && echo "$pid"
}
group_alive() {
  local pgid="$1"
  if pgrep -g "$pgid" >/dev/null 2>&1; then return 0; fi
  ps -Ao pgid= 2>/dev/null | awk -v g="$pgid" '$1 == g { found=1; exit } END { exit !found }'
}
# run_game <pid file> <log> <wall seconds> <command ...>: runs the command under a wall timeout, in a process
# group of its own, and sets $code to how it ended. Ctrl-C or a TERM to the calling script stops the game
# too ($code 143) and the script goes on to keep its evidence. Whatever is left of the group afterwards (a
# display, a game slow to stop) gets 20 seconds and is then killed by its group, never by name.
run_game() {
  local pidfile="$1" log="$2" limit="$3" last; shift 3
  game_pid=""; interrupted=0; code=1
  trap 'interrupted=1; [ -n "$game_pid" ] && kill -TERM "$game_pid" 2>/dev/null' INT TERM
  timeout --signal=TERM --kill-after=20 "$limit" "$@" > "$log" 2>&1 &
  game_pid=$!
  write_pid "$game_pid" "$pidfile"
  # A signal that landed before the pid was known stopped nothing yet.
  [ "$interrupted" = 1 ] && kill -TERM "$game_pid" 2>/dev/null
  # A trapped signal ends a wait early, so wait again until the timeout process is really gone.
  while :; do
    wait "$game_pid" 2>/dev/null; last=$?
    [ "$last" = 127 ] && break  # already collected: nothing more to wait for
    code=$last
    kill -0 "$game_pid" 2>/dev/null || { wait "$game_pid" 2>/dev/null; last=$?; [ "$last" = 127 ] || code=$last; break; }
  done
  for _ in $(seq 1 20); do group_alive "$game_pid" || break; sleep 1; done
  group_alive "$game_pid" && kill -KILL -- "-$game_pid" 2>/dev/null
  trap - INT TERM
  # cleanup.sh --stop signals the game, not this script, and leaves a note beside the pid file to say so.
  [ -f "$pidfile.stop" ] && { interrupted=1; rm -f "$pidfile.stop"; }
  [ "$interrupted" = 1 ] && code=143
  return 0
}
