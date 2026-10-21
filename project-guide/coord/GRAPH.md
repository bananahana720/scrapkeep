# Alpha workflow graph, waves 17 to 21

The one board for who owns what, which unit waits on which, and which test gates each unit must pass. Owner: the local coordinator (a Claude Code session on Andrew's PC). Lanes propose changes on the wave's Wave board issue; only the coordinator edits this file. Rulings live in [DECISIONS.md](../handoff/DECISIONS.md); newest wins.

Goal: a finished-feeling Linux alpha by the end of wave 21, judged by Andrew's one full playtest of the 11 areas. Last updated 2026-10-21 21:15Z (wave 18 opened).

## Topology

```
                  local coordinator (Andrew's PC)
          graph, admission to main, check-ins, escalations
        ┌──────────┬───────────┬───────────┬───────────┐
   Gate + staging  Systems     World       Perf  Dressing  Life  Challenge  ← cloud lanes (max 7), each a sub-coordinator
   stage/alpha-wN  gameplay,   Blender,    freezes,        that fans out its own agents and workflows
   red team        shell       art, GLBs   frame cost
        └──────── PRs + receipts + Wave board issue ────────┘   ← GitHub is the bus
   GPU bench (4080)   Music (ACE-Step)   Systems B (w18)   Content (w20)   ← local sessions on the PC
```

Local CPU budget (19 Oct, still in force): the CPU shed lane (Systems B and Challenge sweeps sent to the PC) at most 12 concurrent Godot, Content 8, all at nice 10 through `cpuq`; the GPU bench times runs only below a 1-minute load of 40, interleaving base and PR runs.

## Ownership

| Thing | Owner | Others may |
| --- | --- | --- |
| `main`, stage-to-main promotion, cutting `stage/alpha-w<N>` | Coordinator | none |
| `stage/alpha-w<N>` stacking, gate receipts, row pins, red team persona | Gate lane | open PRs against it |
| DECISIONS.md, LESSONS.md, STATE.md, this file, ORCHESTRATOR and TRACKING records | Coordinator | propose rows on the Wave board issue |
| `src/`, `assets/`, `sketches/` units | the lane named on the unit below | nothing outside their units |
| Shared fold files (`registry.json`, attack ids E34+, row digests) | Gate lane re-folds at stack time | claim ids on the Wave board issue first |
| 4080 and `~/scratch/w17/gpu-queue.md` | GPU bench session | append requests (via the Wave board for cloud lanes) |
| `scripts/music/mx`, radio and camp music | Music session | none |
| Andrew's taste calls | Andrew, through a coordinator pitch | never ask him directly |

## Escalation

Agent → its lane coordinator → local coordinator → Andrew. Local sessions message the coordinator. Cloud lanes comment on the Wave board issue with `NEEDS: <coordinator|gpu|andrew>`, one line of context, the options and their recommendation, then keep building on the recommendation. The coordinator answers on the issue and resolves or escalates.

## Test gates (every unit)

1. Writer's own checks pass in its sandbox; receipt names the head SHA and nonzero test counts.
2. `npm run sketch:fast -- --base stage/alpha-w<N>` (after #106 lands; until then `npm run sketch:smoke` plus the tiers the unit touches) and an independent reviewer that is not the writer.
3. Park data changes also run `run_tier_test`; every merge check runs lint.
4. Stack onto the stage only with steps 1 to 3 green on that exact head.
5. Stage head: full gate (sharded, at most 6 Godot lanes per 4 vCPU box) plus one rotating red team persona (`node scripts/redteam/run.mjs --persona=<id>`).
6. Promotion: coordinator merges the stage PR into main when step 5 is clean. GPU bench checks the promoted head; a GPU red is a next-wave fix unless it crashes.
7. Wave close: five-persona red team sweep; export with `--win-proof`.

Known base reds and cloud-only false fails are listed in [STATE.md](../handoff/STATE.md); a fail needs a solo rerun before it counts.

## Wave 17 (closed 21 Oct, promoted in #116), stage `stage/alpha-w17`

| Unit | Lane | Depends on | State |
| --- | --- | --- | --- |
| Full gate plus persona on stage 1a7a7299 (#116 verdict about 03:30Z) | Gate | - | running |
| Stack #151 radio pack, #152 launch shell, #153 Splitter cue, #154 Warden GLBs, #155 SPIL-9 marks, #143 landforms part 2 | Gate | fast-lane PASS on the named heads | ready |
| #106 fast lane without the WIP self-play commits; self-play in its own Perf PR | Gate, Perf | - | in progress |
| Music levels and Ogg-vs-manifest export check | Music | - | in progress |
| #104 Overpowered pays; grown-pilot ratio reds (Mind, hive, reactor) | Challenge (from Perf, 19 Oct) | - | needs fix |
| #73 Rivet carve; #146 dense fights; #147 boss-freeze profiler; launch title (Andrew's option A: 2D title in about 2 s, 3D crossfades in) | Perf, GPU bench | - | in progress |
| Hook-out hold break, nemesis column, answer weighting, #145 bot hands | Systems | - | in progress |
| Promote #116 to main, cut `stage/alpha-w18` | Coordinator | gate + persona clean | done 21 Oct: main 16df22d0, see BASELINE-2026-10-20.md |

## Wave 18 (current), stage `stage/alpha-w18`, board #241

Opened 21 Oct about 21:00Z. The stage was fast-forwarded to main 9cd6805e (wave 17 plus #239). All 21 PRs that targeted `stage/alpha-w17` now target w18 with unchanged diffs. A receipt on a pre-w18 head needs a re-gate. Lanes are the wave 17 cloud sessions, reused by direct message. Unit lists are refreshed from the intake (BASELINE refresh).

| Lane (session) | Units, in order | Depends on | State |
| --- | --- | --- | --- |
| Gate + staging (cloud c9e5b1) | re-gate and stack #173, #222 to #228, #230, #204, #206, #240; re-fold shared ids; base-red solo reruns; check the ObjectDB leak rise from #240 | - | briefed |
| Systems (cloud 3c55bb), owns Systems B | #207 → #232 → #238 into the #175 chain with #184 and #217, then #175 onto w18; run_tier re-pin once after #214; SR10, SI3, launch shell, title-intro wiring | #214 for the re-pin; Sable rerun on the PC | briefed |
| Challenge (cloud 76a049) | #191 → #208 → #209 → #237; #234 with the c′ mobs half and a swarm re-pin; caster stage-3 stall; boss and mob tuning to section 5 | #191, #208, #209, #237 conflict with w18 (intake) | briefed |
| World (cloud b10865) | #214 → #219 after GPU rows 24 and 25; #242 scatter keep-out; #243 cloud_wash_west; islands burn-down on the whole-rect ruling; anchor fields | GPU rows 24, 25 | running |
| Perf (cloud bbb17f) | #231 heft fix or re-pin ask; #235 after #220; #137 after GPU row 23; dense fights | #220, GPU rows 23, 26, 27 | briefed |
| Dressing (cloud c2965c) | #220 re-gate; Dressing A park kits, one PR per park | - | briefed |
| GPU bench (PC, card to start) | queue rows 23 to 27 | - | waiting on Andrew's click |
| Music (PC, card to start) | heat remake PR; zero-placeholder `--win-proof` export (queue row 7) | #225 for stems-sync | waiting on Andrew's click |
| CPU shed (PC, coordinator) | Sable hard cell at about 120 s; CPU-bound sweeps that lanes post as `NEEDS: coordinator (cpu)` | Systems posts the command | waiting |
| Promote w18 to main, cut `stage/alpha-w19` | Coordinator | stage head gate-clean, at least 3 new units | - |

## Pulled forward (19 Oct)

| Unit | Lane | State |
| --- | --- | --- |
| SR10 director cards, SI3 stage modifiers (skipper-pair HOLD under test), Dispatcher and Splitter packs, nemesis packs, title intros | Systems B | in progress |
| Linker follow-through; FLASH-COMFORT | Systems | in progress |
| Six landmarks soft-toy pass; sinkhole trestle (ruled option a); anchor-kit soft toy; sinkhole (24) and islands (19) greybox | World | in progress |
| Crown (10) and pit (6) greybox; then the Sitting Kit page for the wave 21 playtest | Content | in progress |
| Lived-in parks: per-park prop kits (12+ kinds, 2 to 3 variants, hero props up to about 20k tris with LODs), clustered vignettes, one PR per park | Dressing (cloud) | starting |
| Ambient life: critters and locals per world, pooled and capped, flee combat, no enemy palette, sight and sound from one record | Life (cloud) | starting |
| Difficulty: Novice, Learner and Expert skill-band bots, a band-table harness, per-world boss and mob tuning to the DECISIONS section 5 targets, the HARD tier grown into a replay ladder, and #104 (taken from Perf) | Challenge (cloud) | starting |
| Comps difficulty reference from the decompiled Isaac, Roboquest, Gunfire and RoR2 data (research/comps/difficulty/) | Study (PC) | in progress |
| 4080 triangle-cost A/B for #154 and #143 (queue row 8); full-stem `--win-proof` export (row 7) | GPU bench | running / blocked on Music |

Placeholders: 60 at 1a7a7299, down from 1,442 at wave 15; 59 of them are park greybox rows.

## Waves 18 to 21 (refreshed at each wave cut)

| Wave | Systems | World | Perf | Gate extra |
| --- | --- | --- | --- | --- |
| 18 | SR10 director cards; SI3 through #139; launch shell (AppImage pack, `.desktop`); title-intro wiring | dressing A; anchor fields | dense fights; stage entry | base reds on `scratch/base-red-w16` (effbf2fc) |
| 19 | camp hub (#111 follow-through); Linker behaviour | six landmark GLBs; P4 to P6; headframe | boss freeze | placeholder counts per lane |
| 20 | HELP and ACHIEVEMENTS refresh; FLASH-COMFORT; bug bar | placeholder burn-down to zero | PERF-NIGHT on the 4080 after radio renders | frametime gate |
| 21 | ALPHA-RC AppImage release candidate | last art holes | final 4080 pass | RC gate: `--win-proof` four proofs, five personas |

Source plan: [PLAN-w16-plus.md](PLAN-w16-plus.md); where it differs from the 17 to 18 Oct handoff, the handoff wins. The budgeted plan with wave 17 carry-over and cut candidates is [ROADMAP.md](ROADMAP.md) (20 Oct); the 20 Oct reconciliation of every open PR is [BASELINE-2026-10-20.md](BASELINE-2026-10-20.md).

## PC queue

GPU bench works `~/scratch/w17/gpu-queue.md` on device 0 (RTX 4080) only. Last results: `~/scratch/w17/gpuwin-results.md` (#73 p3 carve max 8.15 ms at 705535c9 with p1 not firing; stage 6 Mind p99 29.98 ms; cold boot 8.9 to 9.7 s, warm 5.3 s; Sable/Cannon idle export failed rc=1). Music works the radio takes and the camp split; the take count (81 vs 56) is confirmed by the Music session against the pack log.
