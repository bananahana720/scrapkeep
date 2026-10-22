#!/bin/bash
cd ~/scratch/w18/render
W=$HOME/scratch/w18/render/wt-0334a88a/sketches/core-loop
B=$HOME/scratch/w18/render/out/noonfog-0334a88a
for v in "base:" "e05:0.5,0.25,1" "e035:0.35,0.25,1" "nofog:0.75,0.25,0"; do
  id=${v%%:*}; mkdir -p $B/$id
  SK_STOP=4 SK_FOG=${v#*:} CLAUDE_OPEN_WAIT=1 timeout 600 claude-open env SK_STOP=4 SK_FOG=${v#*:} godot --gpu-index 1 --path $W --resolution 1280x720 --log-file $B/$id/godot.log --script res://tools/day_arc_capture.gd -- --out=$B/$id
  echo "$id rc=$?"
done
echo ALLDONE
