#!/bin/bash
# Job AZ (widened): six Tripo pilots (PR 1006) on stage/alpha-w40 af9e4f32e. RTX 4080, headless
# gamescope, silent, cutaway passed explicitly. Pauses during any quiet timing. gs-reaper.sh kills a
# gamescope that hangs after Godot exits.
W=/home/andrew/scratch/w40-pc
source /home/andrew/scratch/world1/env-pc.sh w40-az 1 1 >/dev/null
cd $W/az2-tree
quiet_busy() { pgrep -f 'frame-log=1' -u $(id -u) >/dev/null || pgrep -f 'perf_bench.gd' -u $(id -u) >/dev/null || pgrep -f 'yard_drive.gd' -u $(id -u) >/dev/null; }
for i in 1 2; do
  while quiet_busy; do sleep 60; done
  timeout 1200 nice -n 10 $GODOT_BIN --headless --editor --import --quit --path sketches/core-loop > $W/az2-import-$i.log 2>&1
  echo "az import $i exit=$? imported=$(ls sketches/core-loop/.godot/imported | wc -l) $(git rev-parse --short=9 HEAD)"
done
O=$W/out-az2
run() { while quiet_busy; do sleep 60; done; local tag=$1 w=$2 h=$3; shift 3
  timeout --kill-after=30 900 gamescope --backend headless --prefer-vk-device 10de:2704 -W $w -H $h -w $w -h $h -- \
    $GODOT_BIN --audio-driver Dummy --path sketches/core-loop --resolution ${w}x${h} "$@" > $W/az2-$tag.log 2>&1
  echo "$tag exit=$? $(date -u +%T)"; }
for p in runner_gunner pylon_engineer demolitions_caster tarn tally remembered_cannon; do
  for m in tripo authored; do
    if [ "$m" = tripo ]; then M=(--models=tripo); else M=(); fi
    mkdir -p $O/$m/shots $O/$m/ball
    run "$p-$m-shots" 1280 720 --ball-look=cutaway "${M[@]}" --script res://tools/tripo_pilot_shots.gd -- --out=$O/$m/shots --pilot=$p "${M[@]}"
    run "$p-$m-ball" 1920 1080 --script res://tools/ball_look_capture.gd -- --out=$O/$m/ball --ball-look=cutaway --pilot=$p "${M[@]}"
  done
done
for po in runner_gunner:outfit_rivet_hood tarn:outfit_tarn_steady_cap tally:outfit_tally_eyeshade; do
  p=${po%%:*}; o=${po#*:}
  run "$p-tripo-outfit" 1920 1080 --script res://tools/ball_look_capture.gd -- --out=$O/tripo/ball --ball-look=cutaway --pilot=$p --outfit=$o --models=tripo
done
echo "done $(date -u +%FT%TZ)"
