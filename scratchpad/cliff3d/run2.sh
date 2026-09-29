#!/bin/bash
G=/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64
H=/home/andrew/Projects/scrapkeep/artifacts/local/visual-development/geo-cliff3
B=/home/andrew/Projects/scrapkeep/artifacts/local/visual-development/int-pin2
S=$H/scratchpad/cliff3d
SH=/root/Game/Stage1/SpillwayScenery/SandstoneShoulders
export XDG_CONFIG_HOME=$S/xdg/c XDG_DATA_HOME=$S/xdg/d XDG_CACHE_HOME=$S/xdg/k
cp $H/sketches/core-loop/tools/asset_capture.gd $B/sketches/core-loop/tools/asset_capture.gd
for n in base head; do
  if [ "$n" = base ]; then T=$B; else T=$H; fi
  out=$S/cap/$n/clay-e1
  mkdir -p $out
  CLAUDE_OPEN_WAIT=1 flock /tmp/scrapkeep-gpu.lock /home/andrew/.local/bin/claude-open $G --log-file $out/godot.log --path $T/sketches/core-loop --display-driver x11 --audio-driver Dummy --script res://tools/asset_capture.gd -- --out=$out --subject=$SH --clay=$SH --mode=lit --exposure=1.0 --cameras=launch,overview > $out/run.log 2>&1
  echo "$out exit $?" >> $S/progress2.log
done
git -C $B checkout -- sketches/core-loop/tools/asset_capture.gd
echo restored >> $S/progress2.log
