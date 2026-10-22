#!/bin/bash
cd ~/scratch/w18/render
W=$HOME/scratch/w18/render/wt-95430451/sketches/core-loop
B=$HOME/scratch/w18/render/out/noonsweep-95430451
for v in "base:" "amb06:SK_AMB=0.6" "amb03:SK_AMB=0.3" "expo085:SK_EXPO=0.85" "expo07:SK_EXPO=0.7" "white4:SK_WHITE=4" "white8:SK_WHITE=8"; do
  id=${v%%:*}; e=${v#*:}; mkdir -p $B/$id
  CLAUDE_OPEN_WAIT=1 timeout 600 claude-open env SK_STOP=3 $e godot --gpu-index 1 --path $W --resolution 1920x1080 --log-file $B/$id/godot.log --script res://tools/day_arc_capture.gd -- --out=$B/$id
  echo "$id rc=$?"
done
echo ALLDONE
