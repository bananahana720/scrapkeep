#!/bin/bash
cd ~/scratch/w18/render
for s in fe09d434 5019d775; do
  d=$HOME/scratch/w18/render/out/pg-$s/edge; mkdir -p $d
  cp tools/edge_capture.gd wt-$s/sketches/core-loop/tools/edge_capture.gd
  CLAUDE_OPEN_WAIT=1 timeout 600 claude-open godot --gpu-index 1 --path $HOME/scratch/w18/render/wt-$s/sketches/core-loop --resolution 1920x1080 --log-file $d/godot.log --script res://tools/edge_capture.gd -- --out=$d --stage=3
  echo "$s rc=$?"
done
