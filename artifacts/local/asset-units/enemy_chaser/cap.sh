#!/bin/bash
# usage: cap.sh <outname>   holds the GPU lock for the whole native run
R=/home/andrew/Projects/scrapkeep/artifacts/local/visual-development/asset-c10
G=/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64
out=$R/artifacts/local/asset-units/enemy_chaser/$1
rm -rf "$out"; mkdir -p "$out"
export XDG_CONFIG_HOME=$R/scratchpad/c10/xdg/c XDG_DATA_HOME=$R/scratchpad/c10/xdg/d XDG_CACHE_HOME=$R/scratchpad/c10/xdg/k
uptime > "$out/load-before.txt"
CLAUDE_OPEN_WAIT=1 flock /tmp/scrapkeep-gpu.lock /home/andrew/.local/bin/claude-open $G --log-file $out/godot.log --path $R/sketches/core-loop --display-driver x11 --audio-driver Dummy --script $R/scratchpad/c10/c10_capture.gd -- --out=$out > "$out/run.log" 2>&1
echo "exit=$?" >> "$out/run.log"
uptime > "$out/load-after.txt"
ls "$out" | wc -l
