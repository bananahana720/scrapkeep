# Spillway Drop gameplay findings (JL-27-A2, automated; not feel verdicts)

Written by the JL-27 writer in its handoff; saved verbatim by the coordinator because the harness refused the file write. Evidence paths are under `/home/andrew/Projects/scrapkeep-wt-JL-27/artifacts/local/tasks/JL-27/`.

These are automated observations from headless Godot 4.7.2 with the random and scripted arms, `--seed 1`, the arms re-deciding every 1 s, and the lab agent steering. They are not feel verdicts and not primary; JL-28 owns that. Epochs:
- **A1:** a struck enemy is dropped. Node 8e189bf, lab b16227e; `runs/arms`, `runs/repeat`.
- **A2:** `stage-threat-rule 2`. Node 41a5021, lab 8f5d20a; `runs/a2-arms`, `runs/a2-repeat`.

Labels: **observed** (counted from retained files), **inference** (reasoned from source or numbers), **unretained** (seen during development, output not kept). Paths are under `artifacts/local/tasks/JL-27/`.

**1. The ball dies in most trials, under both arms and both rules.**
- **Observed:** A1 138/160 deaths (86%, median 19.6–35.7 s); A2 129/160 (81%, median 19.6–40.1 s) (`logs-a2/11-a1-vs-a2.tsv`, `logs-a2/13-findings-a2.txt`, `logs/13-findings.txt`).
- **Observed:** rule 2 changed scripted kinematic most. In mid-climb, deaths fell 12→4 and successes rose 6→8. In flood-hatch, deaths fell 18→15 and successes rose 2→5. All rigid batches stay at 19–20/20 deaths in A2.
- **Observed:** outside stomp, holds lose 0.0–3.7 HP each. Kinematic stomp holds lose 3.4–5.6 HP (A2) and 3.7–7.2 (A1).
- **Observed:** HP lost while a struck enemy was within 6 m and no unstruck one within 10 m was 2–25% of the total in A1, when such enemies were hidden, and 1–16% in A2, when they are visible.
- **Inference:** rule 2 helps the scripted ladder because its stomp rung finishes the wounded chaser. Scripted kinematic stomp knocks rose 71→124 (mid-climb) and 102→136 (flood-hatch).
- **Inference:** the stomp rebound lands the ball inside the chaser's 2.6 m reach (`src/chaser.gd`, `src/player_ball.gd` `_on_enemy_touched`).
- **Inference:** rigid is also hurt by the stomp crediting and grounded flicker JL-13 reported. Rigid batches land 13–19 stomps against 65–136 in kinematic, and 26–30% of rigid stomp offers are gated out.

**2. The chute beats the bypass, and a chute climb works in both modes.**
- **Observed:** climbs by chute: A1 14/14, 10/11, 20/20, 6/6; A2 13/13, 11/12, 20/20, 6/6.
- **Observed:** with the director paused and the intent held, the chute climb takes 1600 ticks (kinematic) and 1236 (rigid); the bypass takes 2263 and 2985, 1.4–2.4× longer (`logs-a2/04-green-godot-jev_agent_test.log`).
- **Inference:** the bypass is the fallback, not the route (README question 3).
- **Caveat:** the scripted `kicker-at-speed` rung always picks the chute, and 1 s random holds rarely sustain the bypass.

**3. The bypass kerb stands between the ramp and every shelf.**
- **Observed (source):** a 6 m rise from 15.0 at x 132 to 21.0 at x 126 at z -8. The inner face is 1.2 m per m and runs along the deck from z -130 to 150 (`logs/16-bypass-kerb-profile.txt`, `src/terrain.gd` `_bypass`).
- **Unretained:** a slow rigid ball rode up the face and fell back for 30 s.
- **Observed:** with a jump when the ground ahead rises more than 2 m, the rigid bypass climb completes at tick 2985.

**4. The mid shelf has one clear east-west line from the ramp.**
- **Observed (source):** the east basin chute's channel (x 72–120) cuts the shelf from z 4 to the riser. The east bench (x 53–79, z -2.5 to 6.5) is a 3 m box the height field doesn't include, and it stands against the chute's top. Chute banks blend out 16 m past each end (`src/terrain.gd` `_chute`, `_build_props`).
- **Unretained:** legs to the first objective at (40, 0) dropped into the chute or stopped against the bench end.
- **Inference:** crossing from the bypass means using the band north of z ≈ -4 (`src/jev/geo.gd`).

**5. After death in the flood, the flood force persists.**
- **Observed:** every anomaly comes after death.
  - A1: 5 events in 4 trials. For example, trial 5 died at tick 1985 and went out of bounds at tick 2482, rising at 25 m/s at y 80 (`runs/arms/…flood-hatch-random-5f1e82af/trials/005/events.ndjson`).
  - A2: 6/6 trials, first anomaly 733–3780 ticks after death (`logs-a2/14-anomalies-vs-death.txt`).
- **Inference (source):** `src/stage.gd` returns at line 155 when the run is dead, before line 165 refreshes `player.external_accel`.

**6. The gate removes most ram offers, and many stomp offers in rigid.**
- **Observed (A2):**
  - `ram_target` survives in 1.5–15% of offers.
  - `stomp_target` survives in about 97–98% of offers in kinematic and 70–74% in rigid.
  - `spillway_gated_offer_share` is 0.14–0.16 in kinematic and 0.20–0.22 in rigid.
- **Inference:** ram's tier gate reads the previous hold's speed, the same shape as JL-21's F4. No Spillway option carries `requires_speed_ms`.

**Not findings:** flood-caught is confounded by deaths (rigid median death 22–26 s against the 23 s water peak). The repeat-pair counts are a determinism floor.
