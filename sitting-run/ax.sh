#!/bin/bash
# Job AX: rendered error census, sitting run on 9602dbd5 (PR 1001). bot-run.sh's flags, but Vulkan on the 4080 under headless gamescope instead of xvfb+opengl3. Silent. Holds during quiet timing.
W=/home/andrew/scratch/w40-pc
source /home/andrew/scratch/world1/env-pc.sh w40-ax 1 1 >/dev/null
cd $W/ax-tree
quiet_busy() { pgrep -f 'frame-log=1' -u $(id -u) >/dev/null || pgrep -f 'perf_bench.gd' -u $(id -u) >/dev/null; }
for i in 1 2; do
  while quiet_busy; do sleep 60; done
  timeout 1200 nice -n 10 $GODOT_BIN --headless --editor --import --quit --path sketches/core-loop > $W/ax-import-$i.log 2>&1
  echo "ax import $i exit=$? imported=$(ls sketches/core-loop/.godot/imported | wc -l) $(git rev-parse --short=8 HEAD)"
done
out=$W/out-ax/sitting-run
bhome=$out/home
mkdir -p $out/film $bhome/data $bhome/config $bhome/cache
{ echo "commit $(git rev-parse HEAD)"; echo "dirty $(git status --porcelain -- sketches/core-loop | wc -l)"; echo "godot $($GODOT_BIN --version | head -1)"; echo "renderer vulkan, RTX 4080, headless gamescope"; echo "started $(date -u +%FT%TZ)"; } > $out/identity.txt
while quiet_busy; do sleep 60; done
XDG_DATA_HOME=$bhome/data XDG_CONFIG_HOME=$bhome/config XDG_CACHE_HOME=$bhome/cache timeout --kill-after=20 7000 \
 gamescope --backend headless --prefer-vk-device 10de:2704 -W 1280 -H 720 -w 1280 -h 720 -- \
 $GODOT_BIN --audio-driver Dummy --resolution 1280x720 --fixed-fps 30 --path sketches/core-loop -- \
  --self-play --self-play-seed=1 --self-play-policy=skipper --self-play-keys=1 --self-play-eyes=1 --self-play-watch=1 \
  --self-play-save=verify-bot --self-play-stall=600 --self-play-film=$out/film --self-play-until=win --self-play-hold=5 --profile=sitting \
  > $out/game.log 2>&1
code=$?
echo "finished $(date -u +%FT%TZ) exit $code" >> $out/identity.txt
grep '^self-play: ' $out/game.log | tail -12
echo "ax exit=$code"
