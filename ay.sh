#!/bin/bash
# Job AY: cutaway as the default ball look on stage 7dd3c197d (PR 1002). Stills on the RTX 4080 under
# headless gamescope, silent; stills pause during any quiet timing; then a frame-time read in a quiet slot
# (load <= 8, Tctl < 88) with job AL's bot_run --frame-log method, 1 cold + 1 warm run, until stage 3.
W=/home/andrew/scratch/w40-pc
source /home/andrew/scratch/world1/env-pc.sh w40-ay 1 1 >/dev/null
cd $W/ay-tree
quiet_busy() { pgrep -f 'frame-log=1' -u $(id -u) >/dev/null || pgrep -f 'perf_bench.gd' -u $(id -u) >/dev/null; }
for i in 1 2; do
  while quiet_busy; do sleep 60; done
  timeout 1200 nice -n 10 $GODOT_BIN --headless --editor --import --quit --path sketches/core-loop > $W/ay-import-$i.log 2>&1
  echo "ay import $i exit=$? imported=$(ls sketches/core-loop/.godot/imported | wc -l) $(git rev-parse --short=9 HEAD)"
done
out=$W/out-ay; mkdir -p $out/ball $out/ui
GS="gamescope --backend headless --prefer-vk-device 10de:2704 -W 1920 -H 1080 -w 1920 -h 1080 --"
cap() { while quiet_busy; do sleep 60; done; local tag=$1; shift
  timeout 900 $GS $GODOT_BIN --audio-driver Dummy --path sketches/core-loop --resolution 1920x1080 --script res://tools/ball_look_capture.gd -- --out=$out/ball "$@" > $W/ay-$tag.log 2>&1
  echo "$tag exit=$? $(date -u +%T)"; }
for p in pylon_engineer runner_gunner demolitions_caster tarn tally remembered_cannon; do
  cap "$p" --ball-look=cutaway --pilot=$p
  cap "$p-shade-cut" --ball-look=cutaway --pilot=$p --shade=1
  cap "$p-shade-today" --ball-look=today --pilot=$p --shade=1
  cap "$p-glance" --ball-look=cutaway --pilot=$p --glance=1
done
while quiet_busy; do sleep 60; done
timeout 900 $GS $GODOT_BIN --audio-driver Dummy --path sketches/core-loop --resolution 1920x1080 --script res://tools/ui_capture.gd -- --out=$out/ui --size=1920x1080 > $W/ay-ui.log 2>&1
echo "ui_capture exit=$? $(date -u +%T)"
while quiet_busy; do sleep 60; done
timeout 900 $GS $GODOT_BIN --audio-driver Dummy --path sketches/core-loop --resolution 1920x1080 --script res://tools/ui_screens_capture.gd -- --out=$out/ui --screens=camp-customize > $W/ay-uiscreens.log 2>&1
echo "ui_screens exit=$? $(date -u +%T)"
# Frame time, quiet slot.
for r in 1 2; do
  while true; do
    t=$(sensors | awk '/Tctl/{gsub(/[+°C]/,"",$2); print int($2)}'); l=$(cut -d' ' -f1 /proc/loadavg)
    if [ "$t" -lt 88 ] && awk "BEGIN{exit !($l <= 8)}" && ! quiet_busy; then break; fi
    echo "hold timing $r Tctl=$t load=$l $(date -u +%T)"; sleep 60
  done
  echo "timing $r start Tctl=$t load=$l 4080=$(nvidia-smi -i 0 --query-gpu=utilization.gpu --format=csv,noheader,nounits)% $(date -u +%T)"
  timeout 1800 $GS $GODOT_BIN --audio-driver Dummy --path sketches/core-loop --resolution 1920x1080 --script res://tools/bot_run.gd -- \
    --out=$out/time-$r --policy=skipper --seeds=1 --table=park --threaded-stages=1 --warm-band=1 --frame-log=1 --frame-split=1 --until=3 > $out/time-$r.log 2>&1
  echo "timing $r exit=$? Tctl=$(sensors | awk '/Tctl/{print $2}') load=$(cut -d' ' -f1 /proc/loadavg) $(date -u +%T)"
done
echo "done $(date -u +%FT%TZ)"
