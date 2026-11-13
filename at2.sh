#!/bin/bash
# Job AT item 4: a real self-play run with the cutaway ball, filmed every second to stage 3, for chunk and plate pickups.
W=/home/andrew/scratch/w40-pc
source /home/andrew/scratch/world1/env-pc.sh w40-at2 1 1 >/dev/null
cd $W/at-tree
GS="gamescope --backend headless --prefer-vk-device 10de:2704 -W 1920 -H 1080 -w 1920 -h 1080 --"
out=$W/out-at/film; mkdir -p $out
timeout 3600 $GS $GODOT_BIN --audio-driver Dummy --resolution 1920x1080 --fixed-fps 30 --path sketches/core-loop -- --ball-look=cutaway \
  --self-play --self-play-seed=1 --self-play-policy=skipper --self-play-keys=1 --self-play-eyes=1 --self-play-watch=1 \
  --self-play-save=at2-$(date +%s) --self-play-stall=600 --self-play-film=$out --self-play-film-every=1 --self-play-film-live=1 --self-play-until=3 --self-play-hold=3 > $W/at2-film.log 2>&1
echo "film exit=$? frames=$(ls $out | wc -l) $(date -u +%T)"
