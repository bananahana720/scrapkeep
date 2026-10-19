# Alpha workflow graph, waves 17 to 21

The one board for who owns what, which unit waits on which, and which test gates each unit must pass. Owner: the local coordinator (a Claude Code session on Andrew's PC). Lanes propose changes on the wave's Wave board issue; only the coordinator edits this file. Rulings live in [DECISIONS.md](../handoff/DECISIONS.md); newest wins.

Goal: a finished-feeling Linux alpha by the end of wave 21, judged by Andrew's one full playtest of the 11 areas. Last updated 2026-10-18 20:55Z.

## Topology

```
                  local coordinator (Andrew's PC)
          graph, admission to main, check-ins, escalations
        ┌──────────┬───────────┬───────────┬───────────┐
   Gate + staging  Systems     World       Perf          ← cloud lanes (max 4), each a sub-coordinator
   stage/alpha-wN  gameplay,   Blender,    freezes,        that fans out its own agents and workflows
   red team        shell       art, GLBs   frame cost
        └──────── PRs + receipts + Wave board issue ────────┘   ← GitHub is the bus
   GPU bench (4080)   Music (ACE-Step)   Systems B (w18)   Content (w20)   ← local sessions on the PC
```

Local CPU budget (19 Oct): Systems B at most 12 concurrent Godot, Content 8, all at nice 10 through `cpuq`; the GPU bench times runs only below a 1-minute load of 40, interleaving base and PR runs.

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

## Wave 17 (current), stage `stage/alpha-w17`, PR #116

| Unit | Lane | Depends on | State |
| --- | --- | --- | --- |
| Full gate plus persona on stage 1a7a7299 (#116 verdict about 03:30Z) | Gate | - | running |
| Stack #151 radio pack, #152 launch shell, #153 Splitter cue, #154 Warden GLBs, #155 SPIL-9 marks, #143 landforms part 2 | Gate | fast-lane PASS on the named heads | ready |
| #106 fast lane without the WIP self-play commits; self-play in its own Perf PR | Gate, Perf | - | in progress |
| Music levels and Ogg-vs-manifest export check | Music | - | in progress |
| #104 Overpowered pays; grown-pilot ratio reds (Mind, hive, reactor) | Perf | - | needs fix |
| #73 Rivet carve; #146 dense fights; #147 boss-freeze profiler; launch title (Andrew's option A: 2D title in about 2 s, 3D crossfades in) | Perf, GPU bench | - | in progress |
| Hook-out hold break, nemesis column, answer weighting, #145 bot hands | Systems | - | in progress |
| Promote #116 to main, cut `stage/alpha-w18` | Coordinator | gate + persona clean | waiting |

## Pulled forward (19 Oct)

| Unit | Lane | State |
| --- | --- | --- |
| SR10 director cards, SI3 stage modifiers (skipper-pair HOLD under test), Dispatcher and Splitter packs, nemesis packs, title intros | Systems B | in progress |
| Linker follow-through; FLASH-COMFORT | Systems | in progress |
| Six landmarks soft-toy pass; sinkhole trestle (ruled option a); anchor-kit soft toy; sinkhole (24) and islands (19) greybox | World | in progress |
| Crown (10) and pit (6) greybox; then the Sitting Kit page for the wave 21 playtest | Content | in progress |
| 4080 triangle-cost A/B for #154 and #143 (queue row 8); full-stem `--win-proof` export (row 7) | GPU bench | running / blocked on Music |

Placeholders: 60 at 1a7a7299, down from 1,442 at wave 15; 59 of them are park greybox rows.

## Waves 18 to 21 (refreshed at each wave cut)

| Wave | Systems | World | Perf | Gate extra |
| --- | --- | --- | --- | --- |
| 18 | SR10 director cards; SI3 through #139; launch shell (AppImage pack, `.desktop`); title-intro wiring | dressing A; anchor fields | dense fights; stage entry | base reds on `scratch/base-red-w16` (effbf2fc) |
| 19 | camp hub (#111 follow-through); Linker behaviour | six landmark GLBs; P4 to P6; headframe | boss freeze | placeholder counts per lane |
| 20 | HELP and ACHIEVEMENTS refresh; FLASH-COMFORT; bug bar | placeholder burn-down to zero | PERF-NIGHT on the 4080 after radio renders | frametime gate |
| 21 | ALPHA-RC AppImage release candidate | last art holes | final 4080 pass | RC gate: `--win-proof` four proofs, five personas |

Source plan: [PLAN-w16-plus.md](PLAN-w16-plus.md); where it differs from the 17 to 18 Oct handoff, the handoff wins.

## PC queue

GPU bench works `~/scratch/w17/gpu-queue.md` on device 0 (RTX 4080) only. Last results: `~/scratch/w17/gpuwin-results.md` (#73 p3 carve max 8.15 ms at 705535c9 with p1 not firing; stage 6 Mind p99 29.98 ms; cold boot 8.9 to 9.7 s, warm 5.3 s; Sable/Cannon idle export failed rc=1). Music works the radio takes and the camp split; the take count (81 vs 56) is confirmed by the Music session against the pack log.
