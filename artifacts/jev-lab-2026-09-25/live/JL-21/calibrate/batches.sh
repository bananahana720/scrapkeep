#!/usr/bin/env bash
# JL-21 comparison, repeat and D/k sweep batches through godot-launch.mjs.
# Usage: batches.sh arms|repeat|sweep-a|sweep-b
R=artifacts/local/tasks/JL-21/runs
run() {
  node scripts/lab/godot-launch.mjs "$@" --call-cap 5000
  echo "exit $? $*"
}
case "$1" in
  arms|repeat)
    for mode in kinematic rigid; do
      for s in run-to-pad bench-climb dummy-knock pillar-weave; do
        for arm in scripted random; do
          run $s --arm $arm -n 20 --seed 1 --mode $mode --root $R/$1
        done
      done
    done
    ;;
  sweep-a|sweep-b)
    if [ "$1" = "sweep-a" ]; then pairs="45:0 45:26"; else pairs="90:0 90:54"; fi
    for pair in $pairs; do
      for s in run-to-pad dummy-knock pillar-weave; do
        for arm in scripted random; do
          run $s --arm $arm -n 20 --seed 1 --mode kinematic --snapshot-every ${pair%%:*} --hold-ticks ${pair##*:} --root $R/sweep
        done
      done
    done
    ;;
esac
