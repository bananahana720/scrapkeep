#!/bin/bash
cd ~/scratch/w18/render
W=$HOME/scratch/w18/render/wt-8564c0fd/sketches/core-loop
B=$HOME/scratch/w18/render/out/l7-8564c0fd
for r in 1 2 3; do
  for s in 6 1 3; do
    d=$B/r$r; mkdir -p $d
    CLAUDE_OPEN_WAIT=1 timeout 600 claude-open godot --gpu-index 1 --path $W --resolution 1920x1080 --log-file $d/godot-st$s.log --script res://tools/stress_capture.gd -- --out=$d --stage=$s
    echo "r$r st$s rc=$?"
  done
done
echo ALLDONE
