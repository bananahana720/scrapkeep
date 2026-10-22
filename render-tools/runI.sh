#!/bin/bash
cd ~/scratch/w18/render
W=$HOME/scratch/w18/render/wt-23eeecab/sketches/core-loop
for v in "audit:" "spots:--poses=$HOME/scratch/w18/render/out/vig/poses-islands.json"; do
  id=${v%%:*}; x=${v#*:}; d=$HOME/scratch/w18/render/out/islands-$id-23eeecab; mkdir -p $d
  CLAUDE_OPEN_WAIT=1 timeout 700 claude-open godot --gpu-index 1 --path $W --resolution 1920x1080 --log-file $d/godot.log --script res://tools/park_props_audit.gd -- --map=park_islands $x --out=$d
  echo "$id rc=$?"
done
