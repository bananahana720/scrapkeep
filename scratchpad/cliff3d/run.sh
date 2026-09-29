#!/bin/bash
G=/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64
H=/home/andrew/Projects/scrapkeep/artifacts/local/visual-development/geo-cliff3
S=$H/scratchpad/cliff3d
SC=/root/Game/Stage1/SpillwayScenery
SH=$SC/SandstoneShoulders
DAMA=$SC/DamDetail,$SC/LanternLenses,$SC/DamAndLedgeDressing
DAMB=$SC/DamDetail,$SC/LanternLenses
export XDG_CONFIG_HOME=$S/xdg/c XDG_DATA_HOME=$S/xdg/d XDG_CACHE_HOME=$S/xdg/k
job() { # tree out args...
  local T=$1 out=$2; shift 2
  mkdir -p "$out"
  CLAUDE_OPEN_WAIT=1 flock /tmp/scrapkeep-gpu.lock /home/andrew/.local/bin/claude-open $G --log-file $out/godot.log --path $T/sketches/core-loop --display-driver x11 --audio-driver Dummy --script res://tools/asset_capture.gd -- --out=$out "$@" > $out/run.log 2>&1
  echo "$out exit $?" >> $S/progress.log
}
for n in base head; do
  if [ "$n" = base ]; then T=/home/andrew/Projects/scrapkeep/artifacts/local/visual-development/int-pin2; else T=$H; fi
  O=$S/cap/$n
  job $T $O/dam-a --subject=$DAMA --mode=subject-context-depth --cameras=launch,overview
  job $T $O/dam-b --subject=$DAMB --mode=subject-context-depth --cameras=launch,overview
  job $T $O/g01 --subject=$SH --mode=subject-context-depth --cameras=launch,overview
  job $T $O/clay --subject=$SH --clay=$SH --mode=lit --cameras=launch,overview
  while read name box; do
    job $T $O/$name --subject=$SH --mode=subject-context-depth --cameras=launch,overview --aabb=$box --isolate=$SH --isolate-rest
  done < $S/units2.boxes
  while read name box; do
    job $T $O/$name --subject=$SH --mode=subject-black --cameras=ortho-front,ortho-side,ortho-top --aabb=$box --isolate=$SH
  done < $S/families.boxes
done
echo ALLCAP >> $S/progress.log
