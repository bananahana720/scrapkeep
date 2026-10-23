#!/bin/bash
# Resume the B20 rest set: skip tests with a result line in results.txt.
O=/home/user/scrapkeep/artifacts/local/gate/w18/focused-B20; S=/tmp/claude-0/-home-user-scrapkeep/7e738075-88af-5134-95c5-df1ca3ee0b9d/scratchpad
for w in nB20 base; do git -C /home/user/wt/$w restore sketches/core-loop/assets sketches/core-loop/design-v3; done
for t in bot_park_stage3_break_test bot_skill_bar_test bot_world_arrivals_test char_bot_test crown_warden_bot_test highdraft_gate_bot_test highdraft_warden_bot_test loop_bot_test music_params_trace_game_test park_reactor_bot_hand_test park_reactor_boundary_test park_reactor_launch_test park_reactor_prelaunch_test park_reactor_repeat_test park_reactor_sheet_bot_test park_reactor_window_test pocket_entry_test pocket_line_clear_test posture_bands_mind_test posture_bands_reactor_test posture_bands_swarm_test posture_bands_test traversal_measure_test victory_lap_test waking_bot_fight_test; do
  grep -q "^$t:" $O/results.txt 2>/dev/null && continue
  s=$(date +%s); r=$(OUT=$O bash $S/classify3.sh /home/user/wt/nB20 /home/user/wt/base $t); echo "$r [$(($(date +%s)-s))s]" | tee -a $O/results.txt
done
for w in nB20 base; do git -C /home/user/wt/$w restore sketches/core-loop/assets sketches/core-loop/design-v3; done; echo FOCUSED-DONE
