#!/usr/bin/env bash
set -uo pipefail
out=$1
seed=$2
policy=$3
seconds=${4:-120}
godot="$(node "$(dirname "${BASH_SOURCE[0]}")/../../../../scripts/godot-home.mjs" --bin)" || exit 2
project="$HOME/Projects/scrapkeep-worktrees/core-loop-v3/sketches/core-loop"
mkdir -p "$out"
rm -f "$out/capture.json"
exec 9>/tmp/scrapkeep-gpu.lock
flock 9
clear=0
for try in $(seq 1 45); do
	top=$(nvidia-smi --query-compute-apps=used_memory --format=csv,noheader,nounits | tr -d ' ' | sort -n | tail -1)
	if [ -z "$top" ]; then
		top=0
	fi
	if [ "$top" -le 3000 ]; then
		clear=1
		break
	else
		echo "$(date +%T) GPU busy (largest process ${top} MiB), waiting" >> "$out/guard.log"
		sleep 60
	fi
done
if [ "$clear" -ne 1 ]; then
	echo "BLOCKED: GPU busy for 45 minutes" | tee -a "$out/guard.log"
	exit 3
fi
CLAUDE_WS=10 claude-open "$godot" --path "$project" --script res://tools/alpha_capture.gd -- --out="$out" --seed="$seed" --policy="$policy" --seconds="$seconds"
limit=$(( seconds + 240 ))
waited=0
while [ ! -f "$out/capture.json" ]; do
	if [ "$waited" -ge "$limit" ]; then
		echo "TIMEOUT: no capture.json after ${limit}s"
		exit 4
	else
		sleep 5
		waited=$(( waited + 5 ))
	fi
done
sleep 2
cat "$out/capture.json" | head -c 400
echo
ls "$out" | wc -l
