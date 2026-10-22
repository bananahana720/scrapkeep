#!/bin/bash
cd ~/scratch/w18/render
for s in 522a0fe2 a161a1b0; do
  W=$HOME/scratch/w18/render/wt-$s/sketches/core-loop
  d=$HOME/scratch/w18/render/out/ps2r-$s; mkdir -p $d/arc $d/basalt
  CLAUDE_OPEN_WAIT=1 timeout 900 claude-open godot --gpu-index 1 --path $W --resolution 1920x1080 --log-file $d/arc/godot.log --script res://tools/day_arc_capture.gd -- --out=$d/arc
  echo "$s arc rc=$?"
  CLAUDE_OPEN_WAIT=1 timeout 600 claude-open godot --gpu-index 1 --path $W --resolution 1920x1080 --log-file $d/basalt/godot.log --script res://tools/park_props_audit.gd -- --map=park_sinkhole --poses=$HOME/scratch/w18/render/out/vig/poses-basalt-801-803.json --draws=0 --out=$d/basalt
  echo "$s basalt rc=$?"
done
