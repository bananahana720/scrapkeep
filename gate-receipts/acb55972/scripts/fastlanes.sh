#!/bin/bash
# fastlanes.sh <pr>...: sketch:fast on each trial-merge worktree /home/user/wt/f<pr>, serially.
D=/home/user/scrapkeep/artifacts/local/gate/w18
for p in "$@"; do
  case $p in [a-z]*) w=/home/user/wt/$p; p=${p#?};; *) w=/home/user/wt/f$p;; esac; cd $w || continue
  [ -d sketches/core-loop/.godot ] || cp -a /home/user/wt/w18/sketches/core-loop/.godot sketches/core-loop/
  (cd sketches/core-loop && timeout 1500 /opt/scrapkeep-toolchain/Godot_v4.7.2-stable_linux.x86_64 --headless --import --path . >/dev/null 2>&1); git restore sketches/core-loop/assets sketches/core-loop/design-v3 2>/dev/null
  h=$(git rev-parse --short=8 HEAD); log=$D/fast-$p-$h.log
  [ -f $log ] && grep -qE '^sketch:fast (ok|pass)' $log && { echo "$p skip (done)"; continue; }
  echo "$p start $h $(date -u +%T)"
  node scripts/sketch-fast.mjs --base origin/stage/alpha-w18 --budget 600 --receipt w18-$p-$h > $log 2>&1
  echo "$p exit=$? $(tail -1 $log | cut -c1-200)"
  git restore sketches/core-loop/assets sketches/core-loop/design-v3 2>/dev/null
done
