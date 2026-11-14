#!/bin/bash
# Job BP: ram-order fix 9be7a06d5, learner1 w1clear seed 40322, 6 traced launches at once, nice 10, beside other jobs.
W=/home/andrew/scratch/w41-pc
source /home/andrew/scratch/world1/env-pc.sh w41-bp 1 1 >/dev/null
export GODOT_BIN
cd $W/bp
nice -n 10 node scripts/import-stamp.mjs import > $W/bp-import.log 2>&1
echo "import exit=$? $(date -u +%T)"
node scripts/import-stamp.mjs check; echo "check exit=$?"
one() { local rep=$1
  source /home/andrew/scratch/world1/env-pc.sh w41-bp-$rep 1 1 >/dev/null
  local O=$W/out-bp/$rep; mkdir -p $O
  cd $W/bp
  timeout 1800 nice -n 10 $GODOT_BIN --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/band_trace.gd -- \
    --out=$O --policy=skipper --seeds=40322 --table=park --gate=1 --qa-log=1 --trace-ticks=1 \
    --band=learner --attempt=1 --cell=w1clear --until=2 --fight-limit=240 --stage-limit=600 --ticks=156600 > $O/log.txt 2>&1
  echo "rep$rep exit=$? $(date -u +%T)"
}
echo "start $(date -u +%T)"
for r in 1 2 3 4 5 6; do one $r & done
wait
echo "done $(date -u +%FT%TZ)"
