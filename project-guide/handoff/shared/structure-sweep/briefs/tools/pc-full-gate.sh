#!/bin/bash -l
# Full gate of the sweep's integration tip on the Linux PC ("ahana"), with the
# same full gate of its base on main to compare against, band for band.
# The Mac's fast lane leaves the tests past its time budget, the bot shards and
# the band reads unread; this reads them, on a machine no writer uses.
#
# Run on the PC, from anywhere (copy this file there first):
#   nohup bash -l pc-full-gate.sh <base full SHA on main> <tip full SHA> > /dev/null 2>&1 < /dev/null &
# (without the last redirect an ssh that started it does not return).
# To be told when it ends, from the Mac: ssh -n ahana 'tail --pid=<its pid> -f /dev/null'.
# Logs: ~/scratch/entropy-gate/base.log and tip.log, each ending in "exit N".
# Receipts: ~/scratch/entropy-gate/w48-<head8>/. The tip's compare.md holds
# every band against the base, run for run.
# Safe to rerun: the gate runner skips a step that already finished.
#
# The tip may be a full SHA or a branch name on origin (for example
# entropy/gate). A branch is read when the tip pass starts, so a long base pass
# does not leave the tip pass testing a commit that has since been replaced.
# The commit tested is written to ~/scratch/entropy-gate/tip.sha.
# WAIT_PID=<pid> waits for that process (a base pass already running) first.
# SKIP_BASE=1 skips the base pass and reuses its receipts.
set -u
base="$1"
tip="$2"
root="$HOME/scratch/entropy-gate"
tree="$HOME/Projects/scrapkeep-entropy-gate"
budget="${GATE_BUDGET:-20}"
mkdir -p "$root"
cd "$tree" || exit 2
export GODOT_BIN=/usr/bin/godot XDG_DATA_HOME="$tree/artifacts/local/test-home"

gate() {
  head="$1"
  log="$2"
  shift 2
  git fetch -q origin
  git checkout -q --detach "$head" || { echo "exit checkout" >>"$log"; return 1; }
  npm ci --silent >/dev/null 2>&1
  node scripts/gate/pc.mjs run --wave 48 --head "$head" --root "$root" --budget "$budget" "$@" >"$log" 2>&1
  echo "exit $?" >>"$log"
}

if [ -n "${WAIT_PID:-}" ]; then
  tail --pid="$WAIT_PID" -f /dev/null
fi
if [ -z "${SKIP_BASE:-}" ]; then
  gate "$base" "$root/base.log"
fi
git fetch -q origin
tip_sha="$(git rev-parse --verify -q "$tip^{commit}" || git rev-parse --verify -q "origin/$tip^{commit}")"
if [ -z "$tip_sha" ]; then
  echo "exit no such tip: $tip" >"$root/tip.log"
  exit 2
fi
echo "$tip_sha" >"$root/tip.sha"
gate "$tip_sha" "$root/tip.log" --base "$root/w48-$(printf %.8s "$base")" --tally
