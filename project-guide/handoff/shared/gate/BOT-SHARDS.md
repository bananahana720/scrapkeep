# Gate: bot-tier shards

> **Historical archive (waves 18–21):** This note preserves the retired 3-shard cloud split, board issue `#241` workflow, and retired lesson 21 cloud list. For active shard and gate execution on flat `main` (`Mac Studio` Gate / `ahana`), use [GATE.md](../../GATE.md) and `scripts/gate/pc.mjs` / `scripts/gate/shard.mjs`.

The Gate lane splits the bot tier into shards so each fits the cloud box (4 vCPU, 15 GB, 2 h background cap). Each shard runs on the exact commit the Gate lane names, in a cloud lane's own checkout. Shards don't push, comment on PRs or fix anything. They report the result to the Gate lane through a receipt comment on the PR or a comment on board issue #241.

## Run a shard

Run one command from the repo root. Pass tests by base name, not `res://` path:

`node scripts/sketch-smoke.mjs --sketch core-loop --bots --test <a> --test <b> ...`

Example: `--test bot_six_tally_test`. Redirect the output to a file under `artifacts/local/` and read the exit code.

## Shards

- shard-1: bot_six_pilots_test, bot_six_tally_test, bot_six_tarn_test, alpha_posture_bands_test, posture_bands_flume_test
- shard-2: bot_six_demolitions_caster_test, bot_six_remembered_cannon_test, bot_six_runner_gunner_test, bot_skill_bar_test, posture_bands_swarm_test
- shard-3: park_reactor_fight_test, pocket_entry_test, restart_latency_test, run_save_interrupt_test, run_tier_test

Known cloud-only false fails (child timeouts, frame budgets, running as root) are judged by the Gate lane, not the shard. See lesson 21 in [LESSONS.md](../../LESSONS.md).
