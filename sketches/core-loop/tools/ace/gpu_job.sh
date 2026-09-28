#!/usr/bin/env bash
# One guarded GPU job for the bed-lock sweep.
#   gpu_job.sh <log dir> <label> <command...>
# Waits (60 s steps, up to 30 tries) while any GPU process holds more than 3000 MiB, sets
# MAX_CUDA_VRAM to what the device can spare (capped at 12.5 GB, leaving 640 MiB), runs the
# command under a 28 GB RAM / 2 GB swap scope, samples nvidia-smi every 2 s into
# <label>.gpu.log and writes <label>.time.json (wall time, exit code, peak device MiB).
# Never kills anything.
set -uo pipefail
logs=$1
label=$2
shift 2
mkdir -p "$logs"
: > "$logs/$label.guard.log"
clear=0
for try in $(seq 1 30); do
	used=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1 | tr -d ' ')
	total=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1 | tr -d ' ')
	top=$(nvidia-smi --query-compute-apps=used_memory --format=csv,noheader,nounits | tr -d ' ' | sort -n | tail -1)
	if [ -z "$top" ]; then
		top=0
	fi
	echo "$(date -Is) try $try: device ${used}/${total} MiB, largest process ${top} MiB" >> "$logs/$label.guard.log"
	if [ "$top" -le 3000 ]; then
		clear=1
		break
	else
		sleep 60
	fi
done
if [ "$clear" -ne 1 ]; then
	echo "BLOCKED: a GPU process held more than 3000 MiB for 30 minutes" | tee -a "$logs/$label.guard.log"
	exit 3
fi
spare=$(( total - used - 640 ))
cap=$(awk -v s="$spare" 'BEGIN { c = s / 1024; if (c > 12.5) c = 12.5; printf "%.2f", c - 0.05 }')
echo "MAX_CUDA_VRAM=$cap (device ${used}/${total} MiB)" | tee -a "$logs/$label.guard.log"
( while true; do
	echo "$(date +%s) $(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1 | tr -d ' ')" >> "$logs/$label.gpu.log"
	sleep 2
done ) &
poll=$!
start=$(date +%s.%N)
MAX_CUDA_VRAM=$cap systemd-run --user --scope -p MemoryMax=28G -p MemorySwapMax=2G --setenv=MAX_CUDA_VRAM="$cap" \
	nice -n 10 env MAX_CUDA_VRAM="$cap" "$@" > "$logs/$label.log" 2>&1
rc=$?
end=$(date +%s.%N)
kill "$poll"
wait "$poll" 2> /dev/null
peak=$(awk '{ if ($2 > m) m = $2 } END { print m + 0 }' "$logs/$label.gpu.log")
wall=$(awk -v s="$start" -v e="$end" 'BEGIN { printf "%.1f", e - s }')
printf '{"label": "%s", "exit": %d, "wall_seconds": %s, "peak_device_mib": %d, "device_mib_at_start": %d, "max_cuda_vram_gb": %s}\n' \
	"$label" "$rc" "$wall" "$peak" "$used" "$cap" | tee "$logs/$label.time.json"
exit "$rc"
