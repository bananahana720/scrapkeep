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
  read -r pid start < "$1" 2>/dev/null || return 1
  [ -n "$pid" ] && [ -n "$start" ] && [ "$(started_at "$pid")" = "$start" ] && echo "$pid"
}
