#!/usr/bin/env bash
# Stops the drives this checkout started (by their own pid files, never by name) and removes their
# scratch save folders. Pictures, rows, logs and the copied saves stay.
# Usage: .agents/skills/scrapkeep-verify-game/scripts/cleanup.sh [<shared save folder to remove> ...]
set -uo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/common.sh"
for pidfile in "$evidence_root"/*/drive.pid; do
  [ -f "$pidfile" ] || continue
  pid="$(cat "$pidfile")"
  if kill -0 "$pid" 2>/dev/null; then
    kill -TERM "$pid" && echo "cleanup: stopped drive $pid ($(dirname "$pidfile"))"
    for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
    kill -0 "$pid" 2>/dev/null && kill -KILL "$pid"
  fi
  rm -f "$pidfile"
done
for home in "$evidence_root"/*/home; do
  [ -d "$home" ] && rm -rf "$home" && echo "cleanup: removed scratch save folder $home"
done
for shared in "$@"; do
  case "$(readlink -f "$shared")" in
    "$evidence_root"/*) rm -rf "$shared" && echo "cleanup: removed shared save folder $shared" ;;
    *) echo "cleanup: left $shared alone (not under $evidence_root)" ;;
  esac
done
kept="$(find "$evidence_root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)"
echo "cleanup: $kept evidence folder(s) kept under $evidence_root"
