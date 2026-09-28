#!/usr/bin/env bash
# Usage: gpu_job.sh <job-name> <command...>
# Shared-GPU etiquette: wait while any process holds more than 3000 MiB (60 s steps, 45 min cap),
# hold /tmp/scrapkeep-gpu.lock for the job, run in a memory-capped user scope, and log peak VRAM.
# Never signals another process.
set -uo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: gpu_job.sh <job-name> <command...>" >&2
  exit 64
fi

NAME="$1"
shift
LOG_DIR="${IMG3D_LOG_DIR:-$HOME/Projects/scrapkeep-worktrees/core-loop-v3-img3d/artifacts/local/img3d/logs}"
mkdir -p "$LOG_DIR"
WAIT_LOG="$LOG_DIR/gpu-waits.log"
PEAK_LOG="$LOG_DIR/gpu-peaks.tsv"
SAMPLES="$LOG_DIR/vram-$NAME.samples"

waited=0
while true; do
  busy=$(nvidia-smi --query-compute-apps=used_memory --format=csv,noheader,nounits | awk '$1 > 3000' | wc -l)
  if [ "$busy" -eq 0 ]; then
    echo "$(date -Is) $NAME clear after ${waited}s" >> "$WAIT_LOG"
    break
  fi
  if [ "$waited" -ge 2700 ]; then
    echo "$(date -Is) $NAME gave up after ${waited}s with $busy process(es) over 3000 MiB" >> "$WAIT_LOG"
    exit 75
  fi
  echo "$(date -Is) $NAME waiting: $busy process(es) over 3000 MiB" >> "$WAIT_LOG"
  sleep 60
  waited=$((waited + 60))
done

baseline=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1)
: > "$SAMPLES"
(
  while true; do
    nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1 >> "$SAMPLES"
    sleep 1
  done
) &
sampler=$!

start=$(date +%s)
flock /tmp/scrapkeep-gpu.lock \
  systemd-run --user --scope --quiet -p MemoryMax=28G -p MemorySwapMax=2G -- "$@"
status=$?
end=$(date +%s)

kill "$sampler"
wait "$sampler" 2>/dev/null

peak=$(sort -n "$SAMPLES" | tail -1)
if [ -z "$peak" ]; then
  peak=0
fi
if [ ! -f "$PEAK_LOG" ]; then
  printf 'date\tjob\texit\tseconds\tbaseline_mib\tpeak_total_mib\tpeak_job_mib\n' > "$PEAK_LOG"
fi
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(date -Is)" "$NAME" "$status" "$((end - start))" "$baseline" "$peak" "$((peak - baseline))" >> "$PEAK_LOG"
exit "$status"
