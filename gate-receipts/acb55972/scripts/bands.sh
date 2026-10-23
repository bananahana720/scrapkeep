#!/bin/bash
# Band reads x3 on the candidate, solo, --fixed-fps 90 (classify3's verdict passes it; bot children pass it too). Resumable.
G=/opt/scrapkeep-toolchain/Godot_v4.7.2-stable_linux.x86_64; W=/home/user/wt/cand
O=/home/user/scrapkeep/artifacts/local/gate/w18/bands-acb55972; mkdir -p $O
for r in 1 2 3; do for t in alpha_posture_bands_test alpha_posture_bands_w23_test posture_bands_flume_test posture_bands_swarm_test posture_bands_test skill_band_test; do
  grep -q "^$t run$r:" $O/results.txt 2>/dev/null && continue
  s=$(date +%s); XDG_DATA_HOME=$(mktemp -d) timeout 2400 $G --headless --fixed-fps 90 --path $W/sketches/core-loop --script res://tests/$t.gd > $O/$t.run$r.log 2>&1; c=$?
  echo "$t run$r: exit=$c $(grep -E "^$t: (PASS|FAIL)" $O/$t.run$r.log | tail -1) [$(( $(date +%s)-s ))s]" | tee -a $O/results.txt
done; done
git -C $W restore sketches/core-loop/assets sketches/core-loop/design-v3; echo BANDS-DONE
