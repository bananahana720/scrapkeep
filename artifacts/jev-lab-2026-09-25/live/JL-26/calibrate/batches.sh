#!/usr/bin/env bash
# JL-26 retained batches: every scenario x arm x mode, 20 trials, seed 1, all in
# parallel. Usage: batches.sh <pass-name>   (writes runs/<pass-name>, logs/<pass-name>/)
set -u
pass="$1"
node_wt=/home/andrew/Projects/scrapkeep-wt-JL-26
sketch=/home/andrew/Projects/scrapkeep-lab-cable-bench/sketches/cable-bench
task="$node_wt/artifacts/local/tasks/JL-26"
root="$task/runs/$pass"
logs="$task/logs/$pass"
mkdir -p "$root" "$logs"
pids=()
names=()
for scenario in stage-run bench-one forge-charge; do
  for arm in random scripted; do
    for mode in rigid kinematic; do
      name="$scenario-$arm-$mode"
      node "$node_wt/scripts/lab/godot-launch.mjs" "$scenario" --arm "$arm" -n 20 --seed 1 \
        --mode "$mode" --call-cap 20000 --sketch "$sketch" --root "$root" > "$logs/$name.log" 2>&1 &
      pids+=("$!")
      names+=("$name")
    done
  done
done
status=0
for i in "${!pids[@]}"; do
  if wait "${pids[$i]}"; then
    echo "${names[$i]} exit=0"
  else
    code=$?
    echo "${names[$i]} exit=$code"
    status=1
  fi
done
exit "$status"
