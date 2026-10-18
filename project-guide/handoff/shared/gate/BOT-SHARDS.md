# Cloud gate: bot-tier shards for integration build cd06fdd6

The cloud gate thread built one integration build: origin/main cf63e622 plus draft PRs #13-#36 (all except #12), with the #15/#16 spawn-meta overlap resolved by keeping both lines. Each shard runs five bot-tier tests on that exact commit and writes a receipt here.

## Steps (in a fresh cloud session of bananahana720/scrapkeep)
1. `git fetch origin main && git bundle verify /mnt/project-files/gate/int-cd06fdd6.bundle`
2. `git fetch /mnt/project-files/gate/int-cd06fdd6.bundle HEAD:refs/gate/int && git worktree add --detach ../gate-int refs/gate/int && cd ../gate-int && git rev-parse --short HEAD` (must print cd06fdd6), then `ln -s ../scrapkeep/node_modules node_modules`.
3. Run your shard, one command:
   `node scripts/sketch-smoke.mjs --sketch core-loop --bots --test <a> --test <b> ... (base names, e.g. `--test bot_six_tally_test`) > /mnt/project-files/gate/shard-<N>.txt 2>&1; echo exit=$? >> /mnt/project-files/gate/shard-<N>.txt`
4. Tell the cloud gate thread it is done (cross-session message via the project coordinator). Don't push, don't comment on PRs, don't fix anything.

## Shards
- shard-1: bot_six_pilots_test, bot_six_tally_test, bot_six_tarn_test, alpha_posture_bands_test, posture_bands_flume_test
- shard-2: bot_six_demolitions_caster_test, bot_six_remembered_cannon_test, bot_six_runner_gunner_test, bot_skill_bar_test, posture_bands_swarm_test
- shard-3: park_reactor_fight_test, pocket_entry_test, restart_latency_test, run_save_interrupt_test, run_tier_test

Known cloud-only false fails (child timeouts, frame budgets, running as root) are judged by the gate thread, not the shard.
