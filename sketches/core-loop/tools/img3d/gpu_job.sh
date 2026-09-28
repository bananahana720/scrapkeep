#!/usr/bin/env bash
# Usage: [GPU_NEED_MIB=12000] gpu_job.sh <job-name> <command...>
# Shared-GPU etiquette. Takes the shared lock first, then, while holding it, waits in 60 s steps
# until no process holds more than 3000 MiB and at least GPU_NEED_MIB is free (45 min cap).
# Runs the job in a memory-capped user scope, logs lock and wait events and the peak VRAM.
# Never signals another process.
#   GPU_NEED_MIB     free VRAM the job needs, default 12000 (TRELLIS v1); Qwen-Image-2.1 needs 8500
#   GPU_MAX_WAIT_S   cap for the lock wait and for the VRAM wait, each, default 2700
#   GPU_LOCK         lock path, default /tmp/scrapkeep-gpu.lock
#   IMG3D_LOG_DIR    log directory, default the worktree's artifacts/local/img3d/logs
set -uo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: gpu_job.sh <job-name> <command...>" >&2
  exit 64
fi

NAME="$1"
shift
NEED_MIB="${GPU_NEED_MIB:-12000}"
MAX_WAIT="${GPU_MAX_WAIT_S:-2700}"
LOCK="${GPU_LOCK:-/tmp/scrapkeep-gpu.lock}"
HERE="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${IMG3D_LOG_DIR:-$(cd "$HERE/../../../.." && pwd)/artifacts/local/img3d/logs}"
mkdir -p "$LOG_DIR"
WAIT_LOG="$LOG_DIR/gpu-waits.log"
PEAK_LOG="$LOG_DIR/gpu-peaks.tsv"
SAMPLES="$LOG_DIR/vram-$NAME.samples"

log() {
  echo "$(date -Is) $NAME $*" >> "$WAIT_LOG"
}

exec 9>>"$LOCK"
log "lock requested $LOCK"
lock_start=$(date +%s)
if flock -w "$MAX_WAIT" 9; then
  log "lock acquired after $(( $(date +%s) - lock_start ))s"
else
  log "gave up waiting ${MAX_WAIT}s for $LOCK"
  exit 75
fi

waited=0
while true; do
  busy=$(nvidia-smi --query-compute-apps=used_memory --format=csv,noheader,nounits | awk '$1 > 3000' | wc -l)
  free=$(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits | head -1)
  if [ "$busy" -eq 0 ] && [ "$free" -ge "$NEED_MIB" ]; then
    log "clear after ${waited}s: 0 processes over 3000 MiB, ${free} MiB free, need ${NEED_MIB}"
    break
  fi
  if [ "$waited" -ge "$MAX_WAIT" ]; then
    log "gave up after ${waited}s: $busy process(es) over 3000 MiB, ${free} MiB free, need ${NEED_MIB}"
    exit 75
  fi
  log "waiting: $busy process(es) over 3000 MiB, ${free} MiB free, need ${NEED_MIB}"
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
) 9>&- &
sampler=$!

start=$(date +%s)
systemd-run --user --scope --quiet -p MemoryMax=28G -p MemorySwapMax=2G -- "$@" 9>&-
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
flock -u 9
log "lock released, job exit $status"
exit "$status"
