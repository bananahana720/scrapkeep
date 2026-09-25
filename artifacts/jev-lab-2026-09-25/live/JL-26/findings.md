# Cable Bench gameplay findings (JL-26-A2, automated; not feel verdicts)

Written by the JL-26 writer in its handoff; saved verbatim by the coordinator because the harness refused the file write. Paths are relative to `/home/andrew/Projects/scrapkeep-wt-JL-26/artifacts/local/tasks/JL-26/`.

These come from automated headless trials. They are not feel verdicts, and none is a pre-registered comparison; JL-28 owns that.
- **A1:** lab 6478f7d, Node 0a50dee, stage-threat-rule 1 (knocked foes dropped). Records in `runs/final`.
- **A2:** lab 7d5adda, Node 0a50dee (launch path identical to 42fd4ce), stage-threat-rule 2 (only dead or freed foes dropped). Records in `a2/runs/final`.
- Both: seed 1, 20 trials per cell, D 90, k 26. Paths are relative to `artifacts/local/tasks/JL-26/`.

**1. Knocking a foe usually costs the ball HP.**
About half of all knocks, and most rams, come within 3 ticks of a foe's contact hit on the ball.
- A2 kinematic: 513/1025 (0.50); rams 92/148, stomps 421/877.
- A2 rigid: 120/241 (0.50); rams 22/26, stomps 98/215.
- A1: 561/948 (0.59) kinematic, 127/246 (0.52) rigid.
- *Inference, from source:* `foe.gd:120-124` damages the ball whenever centre distance is under body_radius + 1.5 (2.5 m for a chaser). A ball touching a chaser's capsule is within about 2 m, so a ram (a side contact at fast tier, `player_ball.gd:154`) is nearly always inside that radius, and a stomp from above is borderline.
- Caveat: this is a tick coincidence, and another foe nearby could land the hit (inference). It holds under both threat rules.
- Evidence: `a2/logs/31-a2-findings.txt`, `logs/15-final-findings.txt`, `calibrate/findings.mjs`. Hit ticks come from `scenario_result.hit_log` (a foe's contact cooldown restarting); knock ticks come from `events.ndjson`.

**2. Rigid climbs road 0 slower than kinematic, near chaser speed (7 m/s).**
Stage-run road-0 planar speed:
- A2 rigid: mean 7.0 m/s, median 7.1, 48% of 4046 samples under 7 m/s.
- A2 kinematic: mean 10.5, median 9.7, 11% of 3979.
- A1: rigid 6.9 (0.48), kinematic 10.6 (0.11).
- A2 mean end in stage-run: rigid 60.3 s (random) and 46.8 s (scripted); kinematic 91.0 s and 96.3 s.
- Caveat: the arms' choices drive these speeds, including detours. This is not a controlled push-only probe, so how much comes from rigid physics alone is *inference*.
- Evidence: `a2/logs/31-a2-findings.txt`, `logs/15-final-findings.txt`, `a2/logs/30-a1-vs-a2.tsv`.

**3. No trial reached the forge on the full stage, so the cache-vs-clock question went unobserved.**
- Stage-run: 0/80 in A1 and in A2; every trial ended at 0 HP.
- A2 median end 42–93 s; mean tier at end 1.45–2.65.
- 12.3–14.8 chaser contact hits per trial (A1 13.6–15.7).
- Caches opened per trial 0–0.2; scrap 18–50.
- The ball is scrapped before the forge, so the "one more cache" decision never arises. That points at the arms and the steering (the ladder attacks whenever a foe is in reach), not at the stage being unwinnable for a person (*inference*).
- Evidence: `a2/logs/33-a2-compare.tsv`, `logs/14-final-compare.tsv`, `a2/logs/30-a1-vs-a2.tsv`.

**4. The forge charge at tier 1 was never survived.**
- Forge-charge: 0/80 in A1 and A2; all scrapped.
- Miniboss contact hits (20 HP each) per trial: A2 2.45–3.30, A1 2.50–3.35. Chaser hits: A2 5.8–8.8.
- The charge starts about 1.5–1.8 s in; trials end at a median of 16–28 s.
- The steering circles 18 m from the rig inside the 30 m ring (`jev_agent.gd` `_ring`), and the arms still choose attacks and caches.
- A person kiting the miniboss is untested; the cause is *inference*.
- Evidence: `a2/logs/30-a1-vs-a2.tsv`, `a2/logs/33-a2-compare.tsv`.

**5. A committed kicker run-up arrives far faster than the README's 26 m/s.**
- Every ledge visit arrived by air: A2 32, A1 35.
- Peak planar speed in the 3 s before landing:
  - kinematic 38–45 m/s (A2 stage-run scripted 38.4–44.6, bench-one scripted 41.5–44.6)
  - rigid about 35 m/s (34.7–35.1)
- The steering boosts on every aligned tick over a 60 m run-up (11 m/s per boost), and rigid keeps about 5/7 of each (*inference*, `tuning.gd:18`).
- README: "26 m/s clears the gap" (`README.md:85`). The ledge is reachable, and a bot overshoots the needed speed.
- Scripted ledge visits per bench-one trial: kinematic 0.50 (A2) and 0.60 (A1); rigid 0.15 and 0.20.
- Evidence: `a2/logs/32-a2-ledge.txt`, `logs/17-final-ledge.txt`, `calibrate/ledge.mjs`.

**6. The stomp and ram gates remove more offers in rigid.**
Share of offers the gate kept, A2:
- stomp: kinematic 3760/3860 (0.974), rigid 2539/3191 (0.796)
- ram: kinematic 1001/4773 (0.210), rigid 335/3586 (0.093)
- A1 is similar: stomp 3577/3664 and 2533/3180; ram 1006/4705 and 355/3598.

Readings:
- Stomp needs grounded or an air jump. The rigid shortfall fits JL-13's rigid ground-flag flicker (*inference*).
- Ram needs fast tier (16.1 m/s) at decision time. It is mostly gated but still reachable, so it is not the JL-21 F4 case of an option that can never pass.
- Evidence: `a2/logs/31-a2-findings.txt`, `logs/15-final-findings.txt`.

**Instrument note: repeat pairs.**
- A1: 120/120 in both modes (`logs/18`).
- A2: kinematic 360/360; rigid 119, 119 and 118 of 120 (`a2/logs/20-22`), with the same success in all pairs.
- So rigid is not exactly reproducible on Cable Bench; the floor is about 1 in 120 per pair, as in ball-lab's JL-21 F2.
