#!/usr/bin/env bash
# #447 first real-GPU run: item_panels.py renders through cycles_device.use(), default SCRAPKEEP_CYCLES (auto),
# while the 4080 capture chain holds capture-active. A watchdog kills Blender at once if it shows on the 4080.
# Then the same recipe with SCRAPKEEP_CYCLES=cpu for the time comparison.
set -u
W=/home/andrew/scratch/w18/cycles447
B=$W/sketches/core-loop/tools/blender
O=$W/out
mkdir -p "$O"
ls -l /home/andrew/scratch/w18/gates/capture-active > "$O/capture-signal.txt" 2>&1
U0=$(nvidia-smi -i 0 --query-gpu=uuid --format=csv,noheader)
U1=$(nvidia-smi -i 1 --query-gpu=uuid --format=csv,noheader)
echo "4080 $U0 / 3060 $U1" >> "$O/capture-signal.txt"
run() {
  local tag=$1
  shift
  (
    while true; do
      nvidia-smi --query-compute-apps=gpu_uuid,pid,process_name,used_memory --format=csv,noheader | grep -i blender | sed "s/^/$(date -u +%T) /" >> "$O/$tag-gpu.txt"
      if nvidia-smi -i 0 --query-compute-apps=process_name --format=csv,noheader | grep -qi blender; then
        echo "$(date -u +%T) BLENDER ON 4080, killed" >> "$O/$tag-gpu.txt"
        pkill -x blender
      fi
      sleep 1
    done
  ) &
  local dog=$!
  local t0=$(date +%s.%N)
  env "$@" nice -n 10 taskset -c 8-15,24-31 blender -b --factory-startup --python-exit-code 1 -P "$B/item_panels.py" -- --out "$O/$tag-glb" --render "$O/$tag-png" > "$O/$tag.log" 2>&1
  local rc=$?
  local t1=$(date +%s.%N)
  kill "$dog"
  echo "$tag rc=$rc wall=$(echo "$t1 - $t0" | bc) s pngs=$(find "$O/$tag-png" -name '*.png' 2> /dev/null | wc -l)" >> "$O/status"
}
run auto SCRAPKEEP_CYCLES=auto
run cpu SCRAPKEEP_CYCLES=cpu
