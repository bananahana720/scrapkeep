#!/bin/bash
# Rerun s1 until 3 strong runs (s1 candidate_pixels >= 50000, valid) per stage, 8 tries max incl. the 3 earlier runs.
cd ~/scratch/w18/render
W=$HOME/scratch/w18/render/wt-8564c0fd/sketches/core-loop
B=$HOME/scratch/w18/render/out/l7-8564c0fd
strong() { python3 -I -c "
import json,sys,glob
n=0
for f in sorted(glob.glob('$B/r*/stress-st$1.json')):
    s=[x for x in json.load(open(f))['scenes'] if x['scene']=='s1'][0]['p1_edges']
    if s['valid'] and s['candidate_pixels']>=50000: n+=1
print(n)"; }
tries() { ls $B/r*/stress-st$1.json | wc -l; }
for round in 1 2 3 4 5; do
  for s in 6 1 3; do
    if [ "$(strong $s)" -lt 3 ] && [ "$(tries $s)" -lt 8 ]; then
      r=$(( $(tries $s) + 1 ))
      d=$B/rs${s}_$r; mkdir -p $d
      CLAUDE_OPEN_WAIT=1 timeout 600 claude-open godot --gpu-index 1 --path $W --resolution 1920x1080 --log-file $d/godot-st$s.log --script res://tools/stress_capture.gd -- --out=$d --stage=$s
      echo "st$s try$r rc=$? strong=$(strong $s) tries=$(tries $s)"
    fi
  done
done
echo "FINAL st6 strong=$(strong 6) tries=$(tries 6); st1 strong=$(strong 1) tries=$(tries 1); st3 strong=$(strong 3) tries=$(tries 3)"
echo ALLDONE
