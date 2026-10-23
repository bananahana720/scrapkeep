#!/bin/bash
# Resumable full-gate shard: gate.sh <worktree> <list> <label> <chunk> [--bots]
# Skips tests already recorded PASS/FAIL in gate/full-<label>.log or gate/chunks/<label>-*.log.
W=$1; LIST=$2; LABEL=$3; CHUNK=$4; shift 4
G=/home/user/scrapkeep/artifacts/local/gate
export SMOKE_SLOTS=${SMOKE_SLOTS:-6}
cd $W || exit 2
n=0
while :; do
  [ -n "$MAXCHUNKS" ] && [ $n -ge $MAXCHUNKS ] && { echo "pause $LABEL after $n chunks $(date -u +%T)"; break; }
  n=$((n+1))
  done_set=$(cat $G/full-$LABEL.log $G/chunks/$LABEL-*.log 2>/dev/null | grep -oE '^(PASS|FAIL) sketches/core-loop res://tests/[A-Za-z0-9_]+\.gd' | sed -E 's#.*/##; s#\.gd$##' | sort -u)
  mapfile -t left < <(grep -vxF -f <(echo "$done_set"; echo __none__) $LIST | grep -v '^$')
  [ ${#left[@]} -eq 0 ] && { echo "done $LABEL $(date -u +%T)"; break; }
  args=(); for t in "${left[@]:0:$CHUNK}"; do args+=(--test "$t"); done
  log=$G/chunks/$LABEL-$(date -u +%H%M%S).log
  echo "run $LABEL $(git rev-parse --short=8 HEAD) $(date -u +%T) left=${#left[@]} chunk=${left[*]:0:$CHUNK}"
  node scripts/sketch-smoke.mjs --sketch core-loop "$@" "${args[@]}" > $log 2>&1
  echo "  exit=$? $(grep -cE '^PASS sketches/core-loop res://' $log) pass $(grep -cE '^FAIL sketches/core-loop res://' $log) fail"
  # a chunk that records nothing (crash before tests) would loop forever
  grep -qE '^(PASS|FAIL) sketches/core-loop res://' $log || { echo "  no results; stopping"; tail -5 $log; exit 3; }
done
