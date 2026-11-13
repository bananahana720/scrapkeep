# Shared by doctor.sh and drive.sh: where the repo, the game and Godot are.
skill_dir="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
repo="$(git -C "$skill_dir" rev-parse --show-toplevel)"
sketch="$repo/sketches/core-loop"
godot="${GODOT_BIN:-}"
for candidate in "$(command -v godot || true)" "$HOME/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64" /opt/scrapkeep-toolchain/Godot_v4.7.2-stable_linux.x86_64; do
  [ -n "$godot" ] && break
  [ -n "$candidate" ] && [ -x "$candidate" ] && godot="$candidate"
done
evidence_root="${VERIFY_GAME_EVIDENCE_ROOT:-$repo/artifacts/local/verify-game}"
