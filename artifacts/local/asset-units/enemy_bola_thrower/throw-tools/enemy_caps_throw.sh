#!/bin/bash
# Throw-state captures for the C13 Bola thrower: head (this branch) and base (int-pin2), paired.
# Each state is staged by --call chains from scratchpad/c13d/chain.sh (Node.set and set_indexed, no code change).
V=/home/andrew/Projects/scrapkeep/artifacts/local/visual-development
R=$V/asset-c13b
BASE=$V/int-pin2
CAP=$R/scratchpad/cap/cap.sh
G=/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64
D=$R/scratchpad/c13d
M=$R/artifacts/local/asset-units/enemy_bola_thrower/capture-throw
P="80,30.85065,-100"
STATES=${STATES:-"wind25 wind60 wind95 rel30 rel70 land"}
for st in $STATES; do
  mkdir -p $M/$st
  mapfile -t A < <($D/chain.sh $st)
  for tree in head base; do
    if [ $tree = head ]; then TR=$R; else TR=$BASE; fi
    $G --headless --path $TR/sketches/core-loop -s $D/probe2.gd -- "${A[@]}" 2>&1 | grep "^STATE" > $M/$st/readback-$tree.txt
    $CAP $TR $M/$st/$tree subject-black --spawn=bola_thrower@80,29.74855,-100 --subject=/root/Game/Spawn_bola_thrower --anchor=/root/Game/Spawn_bola_thrower --freeze=/root/Game/Spawn_bola_thrower=0,0,0:$P --centre=80,32.35065,-100 --cameras=asset-front30,asset-side30,asset-rear30 --mode=lit,subject-black "${A[@]}"
    echo "$st $tree $(cat $M/$st/$tree/exit.txt)"
  done
  $G --headless --path $R/sketches/core-loop --script res://tools/asset_capture.gd -- --pair --base=$M/$st/base --head=$M/$st/head --out=$M/$st/pair > $M/$st/pair.log 2>&1
  echo "$st pair exit=$?"
done
echo ALLDONE
