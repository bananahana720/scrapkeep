# Happy accidents

> **Historical snapshot (Oct 2026, 3-pilot `32dff63` era):** Early 200-seed fuzz notes; live fuzz and regression harnesses run via `scripts/redteam/` and `tests/`.

Andrew's rule (2026-09-27): "making sure we do things in a standardized manner so we wouldn't have any unforeseen bugs or hidden glitches or exploits ... But also exploits can be fun too if they're accidental in a fun way."

This file is where the two meet. The item fuzzer (`tools/item_fuzz.gd`, DESIGN-V2 section 7) plays random legal builds and lists anything that escapes an invariant or runs far past its peers. Andrew marks each line **KEEP** or **KILL**:

- **KEEP** promotes the combination to a named or unnamed synergy row.
- **KILL** becomes a bug card.

Nothing here is patched silently.

## Designed happy accidents (shipped)

These five are bounded on purpose. They are fun because they are rare and capped, not unlimited (I2 section 3).

| Part | Rarity | Trigger | What happens | The bound |
| --- | --- | --- | --- | --- |
| Scrap Geyser | rare | on_pickup | 4% of pickups burst nearby enemies outward, fast enough to pin | one burst per pickup, at most 6 enemies, 1 copy counts |
| Echo Charge | rare_plus | on_charge_release | 10% chance a release echoes as a smaller ring | one echo per release, 1 copy counts |
| Feedback Loop | rare, Kest | on_kill | a kill while cloaked extends the cloak 0.4 s | waits on combat's `extend_cloak`, so it is not offered yet |
| Momentum Thief | uncommon | on_damage_taken | a chip hit pushes you 5% faster | 5 copies at most, never past 40 m/s |
| Domino Wire | rare_plus | on_smash | after a smash, a pin has a 20% chance to fling its victim into the next enemy | chain depth 1, at most 3 per smash window |

## Fuzz anomalies for KEEP or KILL

**The run.** 200 seeds (1 to 200) of `tools/item_fuzz.gd` on `proto/core-loop-v2-loot` at 32dff63, 90 s each at `--fixed-fps 90`, in four slices. Receipts are under `artifacts/local/fuzz-{1-50,51-100,101-150,151-200}/` (`run.log`, `fuzz.ndjson`, `anomalies.md`).
- **Result.** 7 anomalies in 200 builds, and no softlocks, crashes or non-finite values. The only engine error was the ability bar's degenerate sweep polygon, which is already fixed on `proto/core-loop-v2` (f5fb32b).
- **Coverage.** 10 of 12 trigger kinds fired naturally in play. `on_smash` and `on_vault` never did, because the fuzz bot doesn't smash or vault. Those two triggers ran only by injection, so their parts are covered by the bus but not by play. This is a gap in the bot, not in the items.

Andrew rules on each line at the alpha play. The recommendation is the coordinator's default until then.

| # | Seeds | Class | What escaped | Common parts | Recommendation |
| --- | --- | --- | --- | --- | --- |
| A1 | 17, 29, 62, 149, 155 | Kest | Top speed of 60.3 to 70.4 m/s, against a 60 m/s ceiling (the highest any part names) | Every one has Jet Vent (cloak break fires a 14 m/s dash) with Scrap Gravity. Most also have Sunforged Core or Tempest Core. | **KEEP.** A cloak-break dash on top of a fast roll is the Ghost fantasy: vanish, then burst out faster than anything should go. It only overshoots by 1 to 17%. If it's kept, name it (a candidate is "Afterburn") and show it in the codex as a found synergy. |
| A2 | 187 | Rivet | Top speed of 85.9 m/s, 43% over the ceiling | Momentum Thief (chip hits add 5%, "never past 40 m/s"), Tumbler Bearing, Tempest Core, and Spiral Wave twice | **KEEP with a check.** Momentum Thief's own bound holds: it stops adding at 40 m/s. Something else carried the ball from there to 86 m/s, most likely landings chained with air jumps. At 86 m/s the ball covers about 0.95 m per physics tick. The ball runs continuous collision (`rigid_ball.gd`, `continuous_cd = true`), so static walls hold. The risk left is trigger areas, such as gates and pickups, that a ball this fast could skip in a single tick; the alpha play should watch for it. |
| A3 | 165 | Sable | Frame p99 at 16.9 ms, against a 16.7 ms budget | Two Frost Vanes, Shock Liner and Static Burr (many field effects at once) | **Not an item call.** The fuzz ran on a machine shared with three builds and a smoke run, so a 0.2 ms overshoot is within noise. The perf-lab pass in Wave 4 re-measures this build alone. |
