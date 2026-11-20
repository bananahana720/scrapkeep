#!/bin/bash
# Writes one TLC config beside RunFlow.tla.
# usage: mkcfg.sh <name> "<rules to check, space separated>" [Constant=VALUE ...]
# Every guard constant defaults to TRUE (the guard is in place). Name the ones a config turns off.
# A new constant goes in two places: the CONSTANTS block of RunFlow.tla and the keys list and c_ defaults below.
# LaunchLands and WardenGoneOpens are rules about time (PROPERTIES); the rest are INVARIANTS.
name=$1
rules=$2
shift 2
# Plain variables, not an associative array, so the system bash 3.2 on macOS runs it.
keys="Stages MaxRuns RunLast Store UntakeOnRetry UntakeOnEnd UntakeOnNewRun VanishGuard EndGuard BusyRefuses SwipeOwnsKeys StageOutlastsSwipe"
c_Stages=2 c_MaxRuns=2 c_RunLast=6 c_Store=TRUE
c_UntakeOnRetry=TRUE c_UntakeOnEnd=TRUE c_UntakeOnNewRun=TRUE
c_VanishGuard=TRUE c_EndGuard=TRUE c_BusyRefuses=TRUE c_SwipeOwnsKeys=TRUE c_StageOutlastsSwipe=TRUE
for kv in "$@"; do
  key=${kv%%=*}
  case " $keys " in
    *" $key "*) printf -v "c_$key" '%s' "${kv#*=}" ;;
    *)
      echo "mkcfg: unknown constant $key" >&2
      exit 2
      ;;
  esac
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
  for key in $(printf '%s\n' $keys | sort); do
    v="c_$key"
    echo "  $key = ${!v}"
  done
  echo "INVARIANTS TypeOK$inv"
  if [ -n "$tmp" ]; then
    echo "PROPERTIES$tmp"
  fi
} > "$(dirname "$0")/$name.cfg"
