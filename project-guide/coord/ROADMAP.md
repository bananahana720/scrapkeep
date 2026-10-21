# Roadmap, waves 18 to 21

Written 20 Oct 2026 after the [baseline](BASELINE-2026-10-20.md). It is linked from [GRAPH.md](GRAPH.md), which stays the live board. The goal and acceptance are in [DECISIONS.md](../handoff/DECISIONS.md) section 1. Andrew plays once at the end of wave 21. The sitting passes with 11 areas marked and none "Not yet", no open blocker, frame times in budget and zero placeholders.

## Budget

- **Two sources.** The account's weekly limit resets on 22 Oct and then weekly. About $100 of cloud credits remain after the baseline. The weekly limit is the main fuel. Credits cover overflow and urgent fixes only.
- **Calibration.** Wave 17's five Opus lane threads cost about $115 in one night (Perf $28, Systems B $36, Challenge $23, World-2 $13, parent $15).
- **Model mix (Andrew, 20 Oct).** Use Sonnet 5.5 everywhere it can go. Opus 5.5 medium is only for the stage promotion gate. A Sonnet lane costs an estimated one third of an Opus lane, so a five-lane wave runs about $35 to $45. ASSERTED (unverified). Measure it with `get_session` usage at the end of wave 18 and correct this line.
- **Rule.** Any wave that would draw more than $50 of credits stops and asks before its third lane starts.

## Carry-over into wave 18 (from the baseline)

| Unit | Lane | What it needs |
| --- | --- | --- |
| #175, #184, #207, #217, #232, #238 (Systems B w18 chain) | Systems B | Gate each head, then re-record `run_tier_test` pins once on the stage after #214 lands |
| Sable hard cell (#149) | Systems B | Rerun the capped rows at about 120 s; author no pack until that reads |
| #234 Warden spawn ring and the ruling 15 c′ mobs-connect half | World-2, Challenge | #234 alone makes the `posture_bands_swarm` camper break the hive and slows grown past 45 s; land it with the Warden-fight packs and re-pin the swarm bands once |
| #191, #208, #209, #237 (skill bands to Spillway) | Challenge | Gate #191 and #208, re-gate #209, then stack #237 |
| #220, #235 (dressing foundation, entry frames) | Dressing, Perf | Gate #220, then stack #235 |
| #204, #206, #224 | World, Gate | Re-gate on the current stage (their PASS names an older SHA) |
| #173, #222, #223, #225 to #228, #230 | Gate | Fast lane plus an independent reviewer, then stack |
| #214, #219 islands rows and flush liners | World | `audio_bake_cancel` FX-2 re-entry sees the bake already finished; make the test independent of park bake timing, or ask why the liners finish it early, then stack |
| #231 item-fuzz speed cap | Systems | Spawned enemies entering physics where they stand pushes Tally's `bot_brindle_short` heft from 1.30 to 1.36 (limit 1.30); fix or re-pin with a ruling, then stack |
| #137 Rivet slope budget | Perf, GPU bench | Waits on #73's 4080 carve check; rebase onto the stage then |
| ParkProps timing and the 4080 run | GPU bench | Queue rows for #235 and #236 |
| `scratch/local-*` branches | Coordinator | Triage from the PC inventory |

## Waves

| Wave | Must land | Lanes (Sonnet writers) | Gate extra | Est. credits |
| --- | --- | --- | --- | --- |
| 18 | Carry-over above. SR10 director cards. SI3 stage modifiers. Launch shell (AppImage, `.desktop`). Title-intro wiring. Dressing A. Anchor fields. Dense fights and stage entry perf. | Gate, Systems B, Challenge, Perf (4) | Base reds on `scratch/base-red-w16` | $0 to $20 (weekly limit first) |
| 19 | Camp hub follow-through. Linker behaviour. Six landmark GLBs. P4 to P6. Headframe. Boss freeze. Ambient life starts. | Gate, Systems, World, Perf (4) | Placeholder counts per lane | $0 to $25 |
| 20 | HELP and ACHIEVEMENTS refresh. FLASH-COMFORT. Bug bar. Placeholder burn-down to zero. PERF-NIGHT on the 4080 after the radio renders. | Gate, Systems, World, Content (4) | Frametime gate | $10 to $30 |
| 21 | ALPHA-RC AppImage. Last art holes. Final 4080 pass. Sitting Kit page. | Gate, World, Perf (3) | RC gate with `--win-proof` four proofs and five personas | $10 to $25 |

The total is $20 to $100. It fits only if each wave's first half runs on the weekly limit. If a wave closes short, the cut candidates below go first.

## Cut candidates, in order

Each one would need Andrew's call. None is cut yet.

1. **Ambient life (critters and locals).** It adds feel and is not on the 11-area acceptance list. Cost to the sitting: parks feel emptier.
2. **HARD tier replay ladder.** Keep the skill bands, which are needed for boss tuning, and drop the ladder. Cost: no post-win difficulty climb.
3. **Dressing beyond hero props.** One prop kit per park instead of 12 or more kinds. Cost: less lived-in parks.
4. **Gamepad polish.** Already optional per ruling.

The following do not cut, because the acceptance gate needs them: zero placeholders, frame times in budget, the AppImage launch, all six dressed parks playable title to end, and the 81 radio takes.

## Fixed dates

- 22 Oct, 10 pm Phoenix time. The weekly limit resets, and wave 18 lanes start.
- End of wave 21. Andrew's one sitting.
