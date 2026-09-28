#!/usr/bin/env bash
# One guarded GPU job: waits for gpu_guard.sh, polls nvidia-smi every 5 s into
# <log dir>/<label>.gpu.log while the job runs under a RAM cap, and writes
# <label>.time.json with the wall time, exit code and peak device MiB.
#   gpu_job.sh <log dir> <label> <command...>
set -uo pipefail
here=$(dirname "$(readlink -f "$0")")
logs=$1
label=$2
shift 2
mkdir -p "$logs"
if ! "$here/gpu_guard.sh" | tee "$logs/$label.guard.log"; then
	echo "BLOCKED: GPU busy, see $logs/$label.guard.log"
	exit 3
fi
: > "$logs/$label.gpu.log"
"$here/gpu_poll.sh" "$logs/$label.gpu.log" &
poll=$!
start=$(date +%s.%N)
systemd-run --user --scope -p MemoryMax=28G -p MemorySwapMax=2G nice -n 10 "$@" > "$logs/$label.log" 2>&1
rc=$?
end=$(date +%s.%N)
kill "$poll"
wait "$poll" 2> /dev/null
peak=$(awk '{ if ($2 > m) m = $2 } END { print m + 0 }' "$logs/$label.gpu.log")
base=$(awk 'NR == 1 { print $2 + 0 }' "$logs/$label.gpu.log")
wall=$(awk -v s="$start" -v e="$end" 'BEGIN { printf "%.1f", e - s }')
printf '{"label": "%s", "exit": %d, "wall_seconds": %s, "peak_device_mib": %d, "device_mib_at_start": %d}\n' \
	"$label" "$rc" "$wall" "$peak" "$base" | tee "$logs/$label.time.json"
exit "$rc"
