# Gate receipts: promotion candidate acb55972

The candidate is `stage/alpha-w18` = `acb55972`, with tree `00e47c1c51ec`. It holds promotion items 1 to 4 (#241 6356590453) plus #361 and #366. The full gate stopped at the account-switch handoff on 23 Oct 2026 at about 15:41Z.

## Contents

- `gate-logs.tar.xz` holds two sets of logs:
  - `w18/`: the fast-lane logs for B11 to B20 and the solo focused logs (`focused-B12` to `focused-B20`, with B20's `results.txt`);
  - `chunks/candnb-*.log`: the non-bot full-gate chunks run on the candidate.
- `receipts/`: the `sketch:fast` receipts for batches B11 to B20.
- `cand-nonbot.txt` lists all 978 non-bot tests. `cand-nonbot-left.txt` lists the 555 still to run.
- `cand-bots.all.txt` lists the 29 bot-tier tests. `cand-bots.split.txt` shows how they split across the 6 shards (sorted index mod 6, plus 1).
- `scripts/` holds the gate scripts. `gate.sh` runs resumable chunks. `classify3.sh` does solo reruns, on the head and then on the base. `bands.sh` runs the band reads ×3. `cand.sh` is the full-gate driver.

## Resume the non-bot full gate

Run this in a worktree at `acb55972` that has been freshly imported:

```bash
SMOKE_SLOTS=6 bash scripts/gate.sh <worktree> cand-nonbot-left.txt candnb 120
```

`gate.sh` writes its chunk logs to `/home/user/scrapkeep/artifacts/local/gate/chunks/`, which is hardcoded. Adjust `G` on a new box.

The equivalent harness call is `node scripts/sketch-smoke.mjs --sketch core-loop --test <name> ...`, run over the names in `cand-nonbot-left.txt`.

`SMOKE_SLOTS=6` on 4 vCPUs causes load timeouts. Solo-rerun every FAIL before calling it red. Also run `gate.sh` as a harness-tracked background task. A detached `nohup` job was killed by the idle container reclaim.

## Still to run after the non-bot chunks

1. Persona `cautious`. Rotation: speedrunner in w17, first-timer at this wave's first gate.
   `node scripts/redteam/run.mjs --wave=18 --persona=cautious --slots=2`
2. Band reads, 3 solo passes at `--fixed-fps 90`: alpha_posture_bands, alpha_posture_bands_w23, posture_bands_flume, posture_bands_swarm, posture_bands, skill_band. Use `scripts/bands.sh`.
3. Solo reruns of every FAIL, on the candidate and on base `66749800`. Use `scripts/classify3.sh <head-wt> <base-wt> <tests...>`.
