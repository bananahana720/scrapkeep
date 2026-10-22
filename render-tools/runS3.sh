#!/bin/bash
# #325 stress run 2: exact flags, stems synced. Holds timing.lock for the whole run, so a timed run cannot start under it.
cd ~/scratch/w18/render
B=$HOME/scratch/w18/render/out/stress-run2
mkdir -p $B
exec 9>$HOME/scratch/w18/gates/timing.lock
echo "waiting for timing.lock $(date -Is)" > $B/timing.txt
flock -x 9
echo "start $(date -Is) (lock held)" >> $B/timing.txt
one() { # name sha run
  d=$B/$1/r$3; mkdir -p $d
  s=$(date +%s)
  ( cd $HOME/scratch/w18/render/wt-$2 && nice -n 19 taskset -c 8-15,24-31 godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/bot_run.gd -- --out=$d --policy=random --seeds=2867 --pilot=runner_gunner --bot-audit=1 --bot-profile=1 > $d/run.log 2>&1; echo $? > $d/exit.txt )
  echo $(( $(date +%s) - s )) > $d/wall.txt
}
for r in 1 2 3 4 5 6 7 8 9 10; do
  one head 83c01ee1 $r &
  one base 644e68b9 $r &
  wait
  echo "pair $r done $(date -Is)" >> $B/timing.txt
done
echo "end $(date -Is)" >> $B/timing.txt
echo ALLDONE
