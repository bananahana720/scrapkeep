#!/bin/bash
# Capture this unit's enemy at base (integration pin int-pin2, d70ef7a) and head, then pair.
# Two paired passes: intact, and stripped through the real event (on_struck with a full result).
V=/home/andrew/Projects/scrapkeep/artifacts/local/visual-development
CAP=$V/asset-c15/scratchpad/cap/cap.sh
G=/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64
BASE=$V/int-pin2
R=$V/asset-c15
P="80,29.74855,-100"
kind=plated_brute
C=$R/artifacts/local/asset-units/enemy_plated_brute/capture
mkdir -p $C
ARGS=(--spawn=$kind@$P --subject=/root/Game/Spawn_$kind --anchor=/root/Game/Spawn_$kind --freeze=/root/Game/Spawn_$kind=0,0,0:$P --centre=80,31.24855,-100 --cameras=asset-front30,asset-side30,asset-rear30,asset-use6 --mode=lit,subject-black,assembly-black)
STRIP=(--call=/root/Game/Spawn_$kind:on_struck:2:'["x","y",{"full":true}]')
for pass in intact stripped; do
  extra=()
  if [ "$pass" = stripped ]; then extra=("${STRIP[@]}"); fi
  $CAP $R $C/head-$pass assembly-black "${ARGS[@]}" "${extra[@]}"; echo "head-$pass $(cat $C/head-$pass/exit.txt)"
  $CAP $BASE $C/base-$pass assembly-black "${ARGS[@]}" "${extra[@]}"; echo "base-$pass $(cat $C/base-$pass/exit.txt)"
  $G --headless --path $R/sketches/core-loop --script res://tools/asset_capture.gd -- --pair --base=$C/base-$pass --head=$C/head-$pass --out=$C/pair-$pass > $C/pair-$pass.log 2>&1
  echo "pair-$pass exit=$?"
done
