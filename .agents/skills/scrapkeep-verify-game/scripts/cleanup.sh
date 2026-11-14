#!/usr/bin/env bash
# Removes what finished or broken drives left behind (stale pid files, scratch save folders) and, only
# when asked, stops a running drive by its own pid file, never by name. Pictures, rows, logs and the
# copied saves stay. A drive that is still running is left alone unless it is named.
# Usage: .agents/skills/scrapkeep-verify-game/scripts/cleanup.sh [--stop <evidence name>]... [--stop-all] [<shared save folder to remove> ...]
#   --stop <evidence name>  stop that one running drive (yours)
#   --stop-all              stop every running drive under the evidence root (other agents' drives too)
set -uo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/common.sh"
stop=(); stop_all=0; shared=()
while [ $# -gt 0 ]; do
  case "$1" in
    --stop) [ $# -ge 2 ] || { echo "cleanup: --stop needs an evidence name" >&2; exit 2; }; stop+=("$2"); shift ;;
    --stop-all) stop_all=1 ;;
    *) shared+=("$1") ;;
  esac
  shift
done
wanted() { [ "$stop_all" = 1 ] && return 0; local name; for name in ${stop[@]+"${stop[@]}"}; do [ "$name" = "$1" ] && return 0; done; return 1; }
for folder in "$evidence_root"/*/; do
  [ -d "$folder" ] || continue
  folder="${folder%/}"; pidfile="$folder/drive.pid"
  if [ -f "$pidfile" ]; then
    if pid="$(ours "$pidfile")"; then
      if ! wanted "$(basename "$folder")"; then echo "cleanup: left running drive $pid alone ($folder); name it with --stop to stop it"; continue; fi
      kill -TERM "$pid" && echo "cleanup: stopped drive $pid ($folder)"
      # drive.sh copies the saves and removes its own pid file once the game is gone; give it time.
      for _ in $(seq 1 30); do [ -f "$pidfile" ] || break; sleep 1; done
      ours "$pidfile" >/dev/null && kill -KILL "$pid"
    fi
    rm -f "$pidfile"
  fi
  [ -d "$folder/home" ] && rm -rf "${folder:?}/home" && echo "cleanup: removed scratch save folder $folder/home"
done
for folder in ${shared[@]+"${shared[@]}"}; do
  case "$(readlink -f "$folder")" in
    "$evidence_root"/?*) rm -rf "${folder:?}" && echo "cleanup: removed shared save folder $folder" ;;
    *) echo "cleanup: left $folder alone (not under $evidence_root)" ;;
  esac
done
kept="$(find "$evidence_root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)"
echo "cleanup: $kept evidence folder(s) kept under $evidence_root"
