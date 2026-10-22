#!/bin/bash
cd ~/scratch/w18/render
run() { # map sha out [poses]
  d=$HOME/scratch/w18/render/out/$3; mkdir -p $d
  extra=""; if [ -n "$4" ]; then extra="--poses=$4"; fi
  CLAUDE_OPEN_WAIT=1 timeout 700 claude-open godot --gpu-index 1 --path $HOME/scratch/w18/render/wt-$2/sketches/core-loop --resolution 1920x1080 --log-file $d/godot.log --script res://tools/park_props_audit.gd -- --map=park_$1 $extra --out=$d
  echo "$3 rc=$?"
}
run dam 2e08ecc4 dam-2e08ecc4
run dam f259e8cf dam-base-f259e8cf $HOME/scratch/w18/render/out/dam-2e08ecc4/park_dam/poses.json
run crown c6855d41 crown-c6855d41
run crown f259e8cf crown-base-f259e8cf $HOME/scratch/w18/render/out/crown-c6855d41/park_crown/poses.json
echo ALLDONE
