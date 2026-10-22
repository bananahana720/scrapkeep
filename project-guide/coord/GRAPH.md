# Alpha workflow graph, waves 18 to 21

The one board for who owns what, which unit waits on which, and which test gates each unit must pass. Owner: the local coordinator (a Claude Code session on Andrew's PC). Lanes propose changes on the wave's Wave board issue (#241); only the coordinator edits this file. Rulings live in [DECISIONS.md](../handoff/DECISIONS.md); newest wins. Session names are in [THREADS.md](../handoff/THREADS.md).

Goal: a finished-feeling Linux alpha by the end of wave 21, judged by Andrew's one full playtest of the 11 areas. Last updated 2026-10-22 (wave 18 open; `main` promoted through #326, then #328 and #339; wave 19 leads with gameplay, map and music).

## Topology

```
                  local coordinator (Andrew's PC)
          graph, admission to main, check-ins, escalations
        ┌──────────┬───────────┬───────────┬───────────┐
   Gate + staging  Systems     World       Perf  Dressing  Lighting  Challenge  ...  ← cloud lanes (cap 11), each a sub-coordinator
   stage/alpha-wN  gameplay,   Blender,    freezes,        that fans out its own agents and workflows
   red team        shell       art, GLBs   frame cost
        └──────── PRs + receipts + Wave board issue ────────┘   ← GitHub is the bus
   GPU bench (4080)   Render bench (3060)   Music (ACE-Step)   Systems B   ← local sessions on the PC
```

CPU placement (22 Oct, DECISIONS section 10): CPU-only work (headless tests, `sketch:fast`, bots, replays, bands) runs in the cloud by default. The PC keeps 4080 timing, 3060 renders and local-state checks, and takes a CPU run only when the cloud can't.

## Ownership

| Thing | Owner | Others may |
| --- | --- | --- |
| `main`, stage-to-main promotion, cutting `stage/alpha-w<N>` | Coordinator | none |
| `stage/alpha-w<N>` stacking, gate receipts, row pins, red team persona | Gate lane | open PRs against it |
| DECISIONS.md, LESSONS.md, STATE.md, this file, ORCHESTRATOR and TRACKING records | Coordinator | propose rows on the Wave board issue |
| `src/`, `assets/`, `sketches/` units | the lane named on the unit below | nothing outside their units |
| Shared fold files (`registry.json`, attack ids E34+, row digests) | Gate lane re-folds at stack time | claim ids on the Wave board issue first |
| 4080 and its queue (`~/scratch/w17/gpu-queue.md`) | GPU bench session | append requests (via the Wave board for cloud lanes) |
| `scripts/music/mx`, radio and camp music | Music session | none |
| Andrew's taste calls | Andrew, through a coordinator pitch | never ask him directly |

## Escalation

Agent → its lane coordinator → local coordinator → Andrew. Local sessions message the coordinator. Cloud lanes comment on the Wave board issue with `NEEDS: <coordinator|gpu|andrew>`, one line of context, the options and their recommendation, then keep building on the recommendation. The coordinator answers on the issue and resolves or escalates.

## Test gates (22 Oct pace ruling, DECISIONS section 10)

Each PR runs focused tests on the feature it changes plus `npm run sketch:fast`, aiming at 10 minutes or less. The full gate runs once per promotion on the stage head, not per PR and not per batch.

1. Writer's own checks pass in its sandbox, with a focused test on the feature the PR changes. The receipt names the head SHA and nonzero test counts.
2. `npm run sketch:fast -- --base stage/alpha-w<N>` and an independent reviewer that is not the writer. No bot sweeps, medians, full-tier runs or personas per PR.
3. Widen only when a focused test points outside the unit or a shared contract changes. Park data changes then also run `run_tier_test`. Every merge check runs lint.
4. Stack onto the stage only with steps 1 to 3 green on that exact head.
5. Stage head, once per promotion: full gate (`npm run verify`, full tier, bot bands, GPU pass; sharded, at most 6 Godot lanes per 4 vCPU box) plus one rotating red team persona (`node scripts/redteam/run.mjs --persona=<id>`).
6. Promotion: coordinator merges the stage PR into main when step 5 is clean. A GPU red is a next-wave fix unless it crashes.
7. 4080 rows: one pair per side (base and PR), with a median only when the pair lands within 10% of the bar.
8. Wave close: five-persona red team sweep; export with `--win-proof`.

Known base reds and cloud-only false fails are listed in [STATE.md](../handoff/STATE.md); a fail needs a solo rerun before it counts.

## Wave 17

Closed 21 Oct and promoted in #116. See [BASELINE-2026-10-20.md](BASELINE-2026-10-20.md).

## Wave 18 (current), stage `stage/alpha-w18`, board #241

Opened 21 Oct about 21:00Z. The stage was fast-forwarded to main 9cd6805e (wave 17 plus #239). All PRs that targeted `stage/alpha-w17` now target w18. The first promotion landed 22 Oct as #326. A receipt on a pre-w18 head needs a re-gate. Lanes are the wave 17 cloud sessions, reused by direct message. Heads and holds are in [STATE.md](../handoff/STATE.md).

| Lane | Units, in order | Depends on | State |
| --- | --- | --- | --- |
| Gate + staging (cloud) | batch stacking (3 or 4 PRs per batch with no shared files, one fast lane per batch), promotion gates, restack #235 at 4b22b5fd, re-fold shared ids, base-red solo reruns | - | running |
| Systems (cloud) | weak points review and `touch_body`, park_cave_in teardown (the quarantine expires 29 Oct), deterministic warden_reactor and world_one_mass_r tests, Sable hard cell at about 120 s (CPU, cloud) | - | running |
| Challenge (cloud) | weak points 2a, 2b and 2c (crew_fitter), the swarm camper check, #312 contact | - | running |
| World (cloud) | sinkhole lava-channel bend (holds #317 and #327), then the #314 berm tint, park ground | - | running |
| Perf (cloud) | #325 worker races, cold-cache shader warm-up, the 210 ms stage-change frame, row 30b, the stage 2 arena A/B | - | running |
| Dressing (cloud) | the six park kits' row and yaw fixes (crown, sinkhole, pit, flume), #280 and its tools | 4080 cost rows | running |
| Lighting (cloud) | #284 dark live core, #297 impact frame box path, #270 day arc; single writer of `world_look.gd`, `time_sky.gdshader`, `arena_*_dress.gd` | gpu-render stills | running |
| Systems B (PC) | the periodic GATES hitch in stage 2 (finding runs on the 3060) | - | running |
| GPU bench (PC) | 4080 timing rows, one at a time, pinned to CCD0 | - | running |
| Render bench (PC, RTX 3060) | serves `NEEDS: gpu-render` stills and clips, plus correctness jobs pinned to CCD1 | - | running |
| revive-228 (PC) | merge the stage into #228, get a receipt | - | running |
| Music (PC) | heat remake PR; zero-placeholder `--win-proof` export | #225 for stems-sync | waiting on Andrew's click |
| Grading, Modeling, Animation, Effects, Challenge B, Ambient life (cloud) | paused until wave 19; Modeling holds the three Warden GLB rebuilds, the six landmarks soft toy and the anchor swap; Challenge B holds stages 4 to 6 to the DECISIONS section 5 skill bands and the HARD replay ladder | Lighting, Animation behaviour, Perf `density.gd` | paused (pacing, 21 Oct 23:35Z) |
| Promote w18 to main, cut `stage/alpha-w19` | Coordinator | stage head gate-clean, at least 3 new units | - |

## Waves 18 to 21 (refreshed at each wave cut)

Wave 19 leads with gameplay, map and music (DECISIONS section 10, 22 Oct). Asset work happens only where a gameplay unit needs it. The cards are in [ROADMAP.md](ROADMAP.md).

| Wave | Systems and Challenge | World and Perf | Music | Gate extra |
| --- | --- | --- | --- | --- |
| 18 | SR10 director cards; SI3 through #139; launch shell (AppImage pack, `.desktop`); title-intro wiring | dressing A park kits and anchor fields finish; dense fights; stage entry | heat remake; radio takes | base reds on `scratch/base-red-w16` (effbf2fc) |
| 19 | random terrain-driven mini-bosses per stage; risk-versus-reward lines; the earned retry item (drop `WORLD_RETRIES`) and the death-to-rolling restart time; Linker behaviour; pilot motion fixes | terrain and map units the mini-bosses and lines need; boss freeze; landmark GLBs and headframe only where a gameplay unit needs them | music in play: boss anthems and roaming ramp wired into the new fights | placeholder counts per lane |
| 20 | HELP and ACHIEVEMENTS refresh; FLASH-COMFORT; bug bar | remaining landmark GLBs and dressing; placeholder burn-down to zero; PERF-NIGHT on the 4080 after radio renders | radio and camp finish | frametime gate |
| 21 | ALPHA-RC AppImage release candidate | last art holes; final 4080 pass | final mix check | RC gate: `--win-proof` four proofs, five personas |

The budgeted plan with cut candidates is [ROADMAP.md](ROADMAP.md). The 20 Oct reconciliation of every open PR is summarised in [BASELINE-2026-10-20.md](BASELINE-2026-10-20.md).
