#!/bin/bash
cd ~/scratch/w18/render
for pair in "pit c371b7c4" "sinkhole 7f32f0db"; do
  set -- $pair; m=$1; s=$2
  d=$HOME/scratch/w18/render/out/vig-$m-$s; mkdir -p $d
  CLAUDE_OPEN_WAIT=1 timeout 600 claude-open godot --gpu-index 1 --path $HOME/scratch/w18/render/wt-$s/sketches/core-loop --resolution 1920x1080 --log-file $d/godot.log --script res://tools/park_props_audit.gd -- --map=park_$m --poses=$HOME/scratch/w18/render/out/vig/poses-$m.json --out=$d
  echo "$m rc=$?"
done
