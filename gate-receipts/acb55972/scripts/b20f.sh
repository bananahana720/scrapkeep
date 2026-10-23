#!/bin/bash
# b20f.sh: after the B20 lane, the named bot set, then bot_driver readers the lane did not run.
S=/tmp/claude-0/-home-user-scrapkeep/7e738075-88af-5134-95c5-df1ca3ee0b9d/scratchpad; G=/opt/scrapkeep-toolchain/Godot_v4.7.2-stable_linux.x86_64
O=/home/user/scrapkeep/artifacts/local/gate/w18/focused-B20; mkdir -p $O
L=$(ls -t /home/user/scrapkeep/artifacts/local/gate/w18/fast-B20-*.log | head -1)
NAMED="bot_run_end_test alpha_bot_sweep_test bot_completionist_repeat_test bot_six_runner_gunner_test alpha_posture_bands_test bot_explorer_camp_path_test bot_relay_stake_test bot_posture_boss_test bot_stub_boss_test"
DEFER=""; for t in $(cat $S/readers-B20.txt); do grep -qE "^PASS tests/$t\.gd " $L && continue; case " $NAMED " in *" $t "*) continue;; esac; DEFER="$DEFER $t"; done
echo "deferred readers:$DEFER"
cd /home/user/wt/base && git restore sketches/core-loop 2>/dev/null; git ls-files --others --exclude-standard | grep '\.uid$' | xargs -r rm; git fetch -q origin stage/alpha-w18; git checkout -q --detach origin/stage/alpha-w18 && echo "base $(git rev-parse --short=8 HEAD)" && (cd sketches/core-loop && timeout 1500 $G --headless --import --path . >/dev/null 2>&1)
OUT=$O bash $S/classify3.sh /home/user/wt/nB20 /home/user/wt/base $NAMED $DEFER
git -C /home/user/wt/nB20 restore sketches/core-loop/assets sketches/core-loop/design-v3; git -C /home/user/wt/base restore sketches/core-loop/assets sketches/core-loop/design-v3; echo FOCUSED-DONE
