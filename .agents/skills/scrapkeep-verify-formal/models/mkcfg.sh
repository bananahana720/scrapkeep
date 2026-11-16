#!/bin/bash
# Writes one TLC config beside RunFlow.tla.
# usage: mkcfg.sh <name> "<rules to check, space separated>" [Constant=VALUE ...]
# Every guard constant defaults to TRUE (the guard is in place). Name the ones a config turns off.
# LaunchLands and WardenGoneOpens are rules about time (PROPERTIES); the rest are INVARIANTS.
name=$1
rules=$2
shift 2
declare -A c=(
  [Stages]=2 [MaxRuns]=2 [Store]=TRUE
  [UntakeOnRetry]=TRUE [UntakeOnEnd]=TRUE [UntakeOnNewRun]=TRUE
  [VanishGuard]=TRUE [EndGuard]=TRUE [BusyRefuses]=TRUE [SwipeOwnsKeys]=TRUE [StageOutlastsSwipe]=TRUE
)
for kv in "$@"; do
  key=${kv%%=*}
  if [ -z "${c[$key]}" ]; then
    echo "mkcfg: unknown constant $key" >&2
    exit 2
  fi
  c[$key]=${kv#*=}
done
inv=""
tmp=""
for r in $rules; do
  if [ "$r" = LaunchLands ] || [ "$r" = WardenGoneOpens ]; then
    tmp="$tmp $r"
  else
    inv="$inv $r"
  fi
done
{
  echo "SPECIFICATION Spec"
  echo "CONSTANTS"
  for key in Stages MaxRuns Store UntakeOnRetry UntakeOnEnd UntakeOnNewRun VanishGuard EndGuard BusyRefuses SwipeOwnsKeys StageOutlastsSwipe; do
    echo "  $key = ${c[$key]}"
  done
  echo "INVARIANTS TypeOK$inv"
  if [ -n "$tmp" ]; then
    echo "PROPERTIES$tmp"
  fi
} > "$(dirname "$0")/$name.cfg"
