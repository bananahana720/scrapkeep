#!/usr/bin/env bash
# Builds, checks and drives the packed Linux game (core-loop.x86_64), the thing Andrew installs.
# Usage: .agents/skills/scrapkeep-verify-build/scripts/build.sh <command>
#   export                       cut a cloud test build (node scripts/cloud/export-headless.mjs) and print its path
#   latest                       print the newest packed game this checkout holds
#   doctor [<packed game>]       is that build worth driving? (default: the newest) Changes nothing; it boots
#                                the build for two frames, headless, with a scratch save folder, to read its stamp
#   drive <steps file> [<evidence name>] [-- <game flags>]
#                                play a step file through the packed game (the game skill's driver)
#   cleanup [--stop <name>]      remove scratch save folders (and stop the named drive); evidence stays
# Env: VERIFY_BUILD_EXE=<packed game> picks a build (a PC package from npm run sketch:export, say);
#      GODOT_BIN for export. Evidence: artifacts/local/verify-build/<evidence name>/.
set -uo pipefail
skill_dir="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
repo="$(git -C "$skill_dir" rev-parse --show-toplevel)"
[ -n "$repo" ] || { echo "build: cannot find the repo from $skill_dir (git rev-parse failed)" >&2; exit 2; }
game_scripts="$repo/.agents/skills/scrapkeep-verify-game/scripts"
export VERIFY_GAME_EVIDENCE_ROOT="$repo/artifacts/local/verify-build"

latest() {
  if [ -n "${VERIFY_BUILD_EXE:-}" ]; then echo "$VERIFY_BUILD_EXE"; return; fi
  # Newest first; win-proof packs carry tools/ and are not the shipped recipe, so they never win.
  ls -t "$repo"/artifacts/local/cloud-export/*/core-loop.x86_64 "$repo"/artifacts/local/core-loop-export/*/core-loop.x86_64 2>/dev/null | grep -v -- '-win-proof/' | head -1
}

case "${1:-}" in
  export)
    [ -n "${GODOT_BIN:-}" ] || { echo "build: set GODOT_BIN (cloud: /opt/scrapkeep-toolchain/Godot_v4.7.2-stable_linux.x86_64)" >&2; exit 2; }
    (cd "$repo" && node scripts/cloud/export-headless.mjs) || exit 1
    echo "build: packed game $(VERIFY_BUILD_EXE= latest)"
    ;;
  latest)
    exe="$(latest)"; [ -n "$exe" ] || { echo "build: no packed game; run build.sh export" >&2; exit 1; }
    echo "$exe"
    ;;
  doctor)
    bad=0
    say() { printf '%-5s %s\n' "$1" "$2"; [ "$1" = FAIL ] && bad=1; return 0; }
    exe="${2:-$(latest)}"
    head="$(git -C "$repo" rev-parse HEAD)"
    say INFO "checkout $repo at ${head:0:8} on $(git -C "$repo" rev-parse --abbrev-ref HEAD)"
    if [ -z "$exe" ] || [ ! -x "$exe" ]; then say FAIL "no packed game${exe:+ at $exe}: run build.sh export, or set VERIFY_BUILD_EXE"; exit 1; fi
    say OK "packed game $exe ($(du -h "$exe" | cut -f1), built $(date -u -r "$exe" +%FT%TZ))"
    # The boot's save folder is scratch under artifacts/local/; without one the game would use the player's own.
    mkdir -p "$VERIFY_GAME_EVIDENCE_ROOT" && scratch="$(mktemp -d "$VERIFY_GAME_EVIDENCE_ROOT/doctor-boot.XXXXXX")" && [ -d "$scratch" ] || { say FAIL "could not make a scratch save folder under $VERIFY_GAME_EVIDENCE_ROOT"; exit 1; }
    stamp="$(cd "$(dirname "$exe")" && XDG_DATA_HOME="$scratch" XDG_CONFIG_HOME="$scratch" XDG_CACHE_HOME="$scratch" timeout 120 "$exe" --headless --quit-after 2 2>&1 | grep -m1 '^SCRAPKEEP_BUILD')"
    rm -rf "${scratch:?}"
    case "$stamp" in
      *"commit=$head"*) say OK "the build names this checkout's commit: $stamp" ;;
      "") say FAIL "the build printed no SCRAPKEEP_BUILD line in a headless boot" ;;
      *) say FAIL "the build is not this checkout's commit ${head:0:8}: $stamp" ;;
    esac
    case "$stamp" in *"dirty=true"*) say INFO "the build was cut from a tree with uncommitted changes" ;; esac
    if [ -d "$(dirname "$exe")/music_ace" ]; then say OK "music_ace is beside the game: the recorded band plays"; else say INFO "no music_ace beside the game: it plays the synth music (a cloud test build never has the stems)"; fi
    case "$exe" in */cloud-export/*) say INFO "a cloud test build: no stems, no Vulkan boss smoke, no tarball. Only npm run sketch:export on the PC cuts a package to ship" ;; esac
    if command -v xvfb-run >/dev/null || [ "${VERIFY_GAME_DISPLAY:-}" = 1 ]; then say OK "a display to draw on"; else say FAIL "no xvfb-run and VERIFY_GAME_DISPLAY=1 is not set"; fi
    exit $bad
    ;;
  drive)
    shift
    exe="$(latest)"; [ -n "$exe" ] && [ -x "$exe" ] || { echo "build: no packed game; run build.sh export" >&2; exit 2; }
    VERIFY_GAME_EXE="$exe" exec "$game_scripts/drive.sh" "$@"
    ;;
  cleanup)
    shift
    exec "$game_scripts/cleanup.sh" "$@"
    ;;
  *) sed -n 2,13p "${BASH_SOURCE[0]}"; exit 2 ;;
esac
