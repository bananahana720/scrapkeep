#!/bin/bash -l
# Run named tests alone, one at a time, on one commit on the Linux PC ("ahana").
# For settling a red the full gate reported: is it red on the sweep's newest tip,
# and is it red on main too? A test that fails here on main as well is not the
# sweep's red; a test that passes here on the tip was fixed since or was load.
#
# Run on the PC (copy this file there first), with no full gate running:
#   nohup bash -l pc-named.sh <label> <full SHA> <runs per test> <test name>... > /dev/null 2>&1 < /dev/null &
# A test name has no folder and no .gd, as in world1_run_test.
# Log: ~/scratch/entropy-gate/named-<label>.log, one line per run
#   <UTC time> <sha8> <test> run <n>: exit <code> in <seconds>s
# then the test's FAIL lines, and a last line "done". Each run's full output is
# in ~/scratch/entropy-gate/named-<label>/<test>-<n>.log.
# Safe to rerun: it appends to the log and overwrites a run's output file.
set -u
label="$1"
sha="$2"
runs="$3"
shift 3
root="$HOME/scratch/entropy-gate"
tree="$HOME/Projects/scrapkeep-entropy-gate"
out="$root/named-$label"
log="$root/named-$label.log"
mkdir -p "$out"
cd "$tree" || exit 2
export GODOT_BIN=/usr/bin/godot XDG_DATA_HOME="$tree/artifacts/local/test-home"
git fetch -q origin
git checkout -q --detach "$sha" || { echo "exit checkout $sha" >>"$log"; exit 1; }
npm ci --silent >/dev/null 2>&1
for test in "$@"; do
  n=1
  while [ "$n" -le "$runs" ]; do
    start=$(date +%s)
    node scripts/sketch-smoke.mjs --sketch core-loop --test "$test" >"$out/$test-$n.log" 2>&1
    code=$?
    echo "$(date -u +%H:%M:%SZ) $(printf %.8s "$sha") $test run $n: exit $code in $(( $(date +%s) - start ))s" >>"$log"
    grep -E -- "-> FAIL|^FAIL |timed out|TIME-OUT" "$out/$test-$n.log" | cut -c1-400 | head -8 >>"$log"
    n=$((n + 1))
  done
done
echo "done" >>"$log"
