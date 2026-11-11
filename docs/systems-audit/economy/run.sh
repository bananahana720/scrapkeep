#!/bin/bash
# Pass B economy sim: world 1 (dam, flume, Brindle) on the park table, one seed per process,
# JOBS processes at once. Run from a repo root (a worktree is best: a bot run reads the working
# tree as it starts, so leave src/ alone while it runs).
#   docs/systems-audit/economy/run.sh <out-dir> <first-seed> <count> <type>...
# type: rusher (skipper route, takes nothing), completionist (completionist route, takes
# nothing), minmax (skipper route plus the start pick, every tree offer and a Moss buy-out).
# Output: <out-dir>/<type>-<seed>/econ-<seed>.ndjson and bots.ndjson, one log per run.
G=${GODOT_BIN:-/opt/scrapkeep-toolchain/Godot_v4.7.2-stable_linux.x86_64}
out=$1; first=$2; count=$3; shift 3
JOBS=${JOBS:-4}
EXTRA=${EXTRA:-}  # extra bot_run flags for every run, for example --moss-scale=on
mkdir -p "$out"
one() {
  local type=$1 seed=$2 policy econ
  case $type in
    rusher) policy=skipper; econ=none ;;
    completionist) policy=completionist; econ=none ;;
    minmax) policy=skipper; econ=minmax ;;
  esac
  [ -s "$out/$type-$seed/bots.ndjson" ] && return 0
  timeout 1800 "$G" --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/sysaudit/econ_ledger.gd -- \
    --out="$out/$type-$seed" --policy=$policy --econ=$econ --seeds=$seed --table=park --until=2 --gate=1 $EXTRA \
    > "$out/$type-$seed.log" 2>&1 || echo "run.sh: $type $seed exited nonzero" >&2
}
export -f one; export G out EXTRA
for type in "$@"; do for ((s=first; s<first+count; s++)); do echo "$type $s"; done; done | xargs -P "$JOBS" -n 2 bash -c 'one "$0" "$1"'
