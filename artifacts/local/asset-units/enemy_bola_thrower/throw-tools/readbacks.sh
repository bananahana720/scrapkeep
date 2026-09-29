#!/bin/bash
V=/home/andrew/Projects/scrapkeep/artifacts/local/visual-development
R=$V/asset-c13b
G=/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64
M=$R/artifacts/local/asset-units/enemy_bola_thrower/capture-throw
for st in wind25 wind60 wind95 rel30 rel70 rel95 land; do
  mapfile -t A < <($R/scratchpad/c13d/chain.sh $st)
  for tree in head base; do
    if [ $tree = head ]; then TR=$R; else TR=$V/int-pin2; fi
    $G --headless --path $TR/sketches/core-loop -s $R/scratchpad/c13d/probe2.gd -- "${A[@]}" 2>&1 | grep "^STATE" > $M/$st/readback-$tree.txt
  done
done
echo RBDONE
