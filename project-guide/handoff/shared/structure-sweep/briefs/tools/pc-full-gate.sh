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

gate "$base" "$root/base.log"
gate "$tip" "$root/tip.log" --base "$root/w48-$(printf %.8s "$base")" --tally
