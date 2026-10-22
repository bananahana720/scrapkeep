#!/bin/bash
# #338 Sable paint chase stills at fa5b3911. Holds timing.lock for the whole job.
cd ~/scratch/w18/render
B=$HOME/scratch/w18/render/out/paintchase-fa5b3911
mkdir -p $B
exec 9>$HOME/scratch/w18/gates/timing.lock
flock -x 9
echo "start $(date -Is) (lock held)" > $B/timing.txt
W=$HOME/scratch/w18/render/wt-fa5b3911/sketches/core-loop
(cd $W && nice -n 10 taskset -c 8-15,24-31 godot --headless --editor --import --quit --gpu-index 1 > $B/import.log 2>&1; echo "import exit $?" >> $B/timing.txt)
for p in none paint_sable_lagoon paint_sable_violet paint_any_salt; do
  CLAUDE_OPEN_WAIT=1 timeout 300 claude-open nice -n 10 taskset -c 8-15,24-31 godot --gpu-index 1 --path $W --resolution 1280x720 --log-file $B/godot-$p.log --script res://tools/paint_chase.gd -- --out=$B --paint=$p
  echo "$p rc=$?" >> $B/timing.txt
done
# close-up lineup for reference (paint_still.gd, repo tool)
CLAUDE_OPEN_WAIT=1 timeout 300 claude-open nice -n 10 taskset -c 8-15,24-31 godot --gpu-index 1 --path $W --resolution 1500x620 --log-file $B/godot-lineup.log --script res://tools/paint_still.gd -- --out=$B/lineup.png --pilot=pylon_engineer --paints=none,paint_sable_lagoon,paint_sable_violet,paint_any_salt
echo "lineup rc=$?" >> $B/timing.txt
echo "end $(date -Is)" >> $B/timing.txt
