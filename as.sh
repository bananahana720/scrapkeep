#!/bin/bash
# Job AS: PR 990 ball looks on stage 6d4320b8, ball_look_capture.gd on the real (Vulkan) renderer under headless gamescope on the 4080, silent.
# Holds while a quiet-slot timing or perf_bench run is going.
W=/home/andrew/scratch/w40-pc
source /home/andrew/scratch/world1/env-pc.sh w40-as 1 1 >/dev/null
cd $W/as-tree
quiet_busy() { pgrep -f 'frame-log=1' -u $(id -u) >/dev/null || pgrep -f 'perf_bench.gd' -u $(id -u) >/dev/null; }
for i in 1 2; do while quiet_busy; do sleep 60; done; timeout 1200 nice -n 10 $GODOT_BIN --headless --editor --import --quit --path sketches/core-loop > $W/as-import-$i.log 2>&1; echo "as import $i exit=$? imported=$(ls sketches/core-loop/.godot/imported | wc -l) $(git rev-parse --short=8 HEAD)"; done
GS="gamescope --backend headless --prefer-vk-device 10de:2704 -W 1920 -H 1080 -w 1920 -h 1080 --"
out=$W/out-as; mkdir -p $out
for look in cutaway today; do
  for g in 0 1; do
    while quiet_busy; do sleep 60; done
    extra=""; if [ "$g" = "1" ]; then extra="--game=1"; fi
    timeout 900 $GS $GODOT_BIN --audio-driver Dummy --path sketches/core-loop --resolution 1920x1080 \
      --script res://tools/ball_look_capture.gd -- --out=$out --ball-look=$look $extra > $W/as-$look-game$g.log 2>&1
    echo "$look game=$g exit=$? $(date -u +%T)"
  done
done
echo "done $(date -u +%FT%TZ)"
