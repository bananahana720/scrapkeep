#!/bin/bash
# Pass A resource ledger: world 1 (dam, flume, Brindle) on the park table, one seed per process.
# Run from the repo root: docs/systems-audit/evidence/pass-a/run.sh <policy> <seed>...
# Output: artifacts/local/sysaudit/<policy>-<seed>/ (bots.ndjson, econ-<seed>.ndjson). Then:
#   python3 -I docs/systems-audit/evidence/pass-a/ledger.py artifacts/local/sysaudit
# One seed per process because bot_run forks multi-seed runs into children that run bot_run.gd
# itself, without this wrapper.
set -e
G=${GODOT_BIN:-/opt/scrapkeep-toolchain/Godot_v4.7.2-stable_linux.x86_64}
p=$1; shift
here=$(dirname "$0")
cp "$here/econ_probe.gd" sketches/core-loop/tools/zz_sysaudit_econ_probe.gd
mkdir -p artifacts/local/sysaudit
for s in "$@"; do
  timeout 1500 "$G" --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/zz_sysaudit_econ_probe.gd -- \
    --out="$PWD/artifacts/local/sysaudit/$p-$s" --policy="$p" --seeds="$s" --table=park --until=2 --panel-log=1 --qa-log=1 \
    > "artifacts/local/sysaudit/$p-$s.log" 2>&1 || true
done
