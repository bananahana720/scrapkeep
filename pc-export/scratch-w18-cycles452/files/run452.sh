#!/usr/bin/env bash
# #452 on the PC after the clean 4080 reruns: auto picks the 4080 alone below 2e9 sample-pixels, tandem above;
# render_pre re-decides per render (checked by creating capture-active between views of one long job).
set -u
W=/home/andrew/scratch/w18/cycles452
B=$W/sketches/core-loop/tools/blender
GLB=$W/sketches/core-loop/assets/models/warden_swarm.glb
O=$W/out
G=/home/andrew/scratch/w18/gates
mkdir -p "$O"
until [ -f /home/andrew/scratch/w18/t453/done ] && [ ! -e "$G/capture-active" ]; do sleep 30; done
flock "$G/timing.lock" true
run() {
  local tag=$1 mode=$2 size=$3 samples=$4
  ( while true; do nvidia-smi --query-compute-apps=gpu_uuid,process_name --format=csv,noheader | grep -i blender | sed "s/^/$(date -u +%T) /" >> "$O/$tag-gpu.txt"; sleep 1; done ) &
  local s=$!
  local t0=$(date +%s%N)
  SCRAPKEEP_CYCLES=$mode nice -n 10 taskset -c 8-15,24-31 blender -b --factory-startup --python-exit-code 1 -P "$B/glb_stills.py" -- \
    --glb "$GLB" --out "$O/$tag" --size "$size" --samples "$samples" --views front,side,three-quarter,rear > "$O/$tag.log" 2>&1
  local rc=$?
  local t1=$(date +%s%N)
  kill "$s"
  echo "$tag mode=$mode size=$size samples=$samples rc=$rc wall_ms=$(( (t1 - t0) / 1000000 )) cards=$(cut -d' ' -f2 "$O/$tag-gpu.txt" 2> /dev/null | sort -u | tr -d ',' | tr '\n' ' ')" >> "$O/status"
}
run small-auto auto 1920 256
for n in 1 2 3; do
  run "big-auto-$n" auto 3840 512
  run "big-4080-$n" 4080 3840 512
done
# Mid-job: start a big auto job, create capture-active once its first view has been written, then compare cards per view.
( until [ -n "$(find "$O/midjob" -name '*.png' 2> /dev/null | head -1)" ]; do sleep 1; done; echo "midjob marker $(date -u +%T)" > "$G/capture-active"; echo "marker set $(date -u +%T)" >> "$O/status" ) &
m=$!
run midjob auto 3840 512
kill "$m" 2> /dev/null
rm -f "$G/capture-active"
grep -n "cycles_device" "$O/midjob.log" >> "$O/status"
echo done >> "$O/status"
