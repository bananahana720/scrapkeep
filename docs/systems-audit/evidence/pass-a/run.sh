#!/bin/bash
# Pass A resource ledger: world 1 (dam, flume, Brindle) on the park table, one seed per process.
# Run from the repo root: docs/systems-audit/evidence/pass-a/run.sh <policy> <seed>...
# Output: artifacts/local/sysaudit/<policy>-<seed>/ (bots.ndjson, econ-<seed>.ndjson). Then:
#   python3 -I docs/systems-audit/evidence/pass-a/ledger.py artifacts/local/sysaudit
# One seed per process because bot_run forks multi-seed runs into children that run bot_run.gd
# itself, without this wrapper. The probe is copied into tools/ for the run and removed after.
G=${GODOT_BIN:-/opt/scrapkeep-toolchain/Godot_v4.7.2-stable_linux.x86_64}
p=$1; shift
here=$(dirname "$0")
probe=sketches/core-loop/tools/zz_sysaudit_econ_probe.gd
cp "$here/econ_probe.gd" "$probe"
trap 'rm -f "$probe" "$probe.uid"' EXIT
mkdir -p artifacts/local/sysaudit
status=0
for s in "$@"; do
  if ! timeout 1500 "$G" --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/zz_sysaudit_econ_probe.gd -- \
    --out="$PWD/artifacts/local/sysaudit/$p-$s" --policy="$p" --seeds="$s" --table=park --until=2 --panel-log=1 --qa-log=1 \
    > "artifacts/local/sysaudit/$p-$s.log" 2>&1; then
    echo "run.sh: $p seed $s exited nonzero; see artifacts/local/sysaudit/$p-$s.log" >&2
    status=1
  fi
done
exit $status
