#!/bin/bash
# Job AT: PR 993 cutaway kit captures on stage 8dd574f5, Vulkan under headless gamescope on the 4080, silent. Holds during quiet timing.
W=/home/andrew/scratch/w40-pc
source /home/andrew/scratch/world1/env-pc.sh w40-at 1 1 >/dev/null
cd $W/at-tree
quiet_busy() { pgrep -f 'frame-log=1' -u $(id -u) >/dev/null || pgrep -f 'perf_bench.gd' -u $(id -u) >/dev/null; }
for i in 1 2; do while quiet_busy; do sleep 60; done; timeout 1200 nice -n 10 $GODOT_BIN --headless --editor --import --quit --path sketches/core-loop > $W/at-import-$i.log 2>&1; echo "at import $i exit=$? imported=$(ls sketches/core-loop/.godot/imported | wc -l) $(git rev-parse --short=8 HEAD)"; done
GS="gamescope --backend headless --prefer-vk-device 10de:2704 -W 1920 -H 1080 -w 1920 -h 1080 --"
out=$W/out-at; mkdir -p $out
cap() { while quiet_busy; do sleep 60; done; local tag=$1; shift
  timeout 900 $GS $GODOT_BIN --audio-driver Dummy --path sketches/core-loop --resolution 1920x1080 --script res://tools/ball_look_capture.gd -- --out=$out "$@" > $W/at-$tag.log 2>&1
  echo "$tag exit=$? $(date -u +%T)"; }
for p in pylon_engineer runner_gunner demolitions_caster tarn tally remembered_cannon; do
  for h in 1 5; do cap "$p-h$h" --ball-look=cutaway --pilot=$p --heft=$h; done
done
cap load-cutaway --ball-look=cutaway --pilot=pylon_engineer --heft=3 --load=40
cap load-today --pilot=pylon_engineer --heft=3 --load=40
cap paint --ball-look=cutaway --paint=d94f8a
cap game --ball-look=cutaway --game=1
# Item 4: a real run with the cutaway, filmed every second through stages 1 and 2, for chunk and plate pickups.
while quiet_busy; do sleep 60; done
timeout 2400 $GS $GODOT_BIN --audio-driver Dummy --path sketches/core-loop --resolution 1920x1080 --ball-look=cutaway \
  --self-play-film=$W/out-at/film --self-play-film-every=1 --self-play-until=3 > $W/at-film.log 2>&1
echo "film exit=$? $(date -u +%T)"
echo "done $(date -u +%FT%TZ)"
