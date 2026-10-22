# Lanes and sessions (22 Oct 2026, 16:15Z, local coordinator)

Ownership, units and test gates are in [GRAPH.md](../coord/GRAPH.md), and lane briefs follow [LANE-BRIEF.md](../coord/LANE-BRIEF.md). The live board is issue #241. Every ruling is posted there as a `COORDINATOR:` comment, and the lane that owns it also gets a direct message. The 18 Oct roster is in git history.

**Cloud lanes are one-way.** They take a direct message but can't reply to it, and they read the board only when they page it. A ruling can reach a lane late (Gate, World and Lighting each missed one on 22 Oct by 1 to 4 hours), so restate the head SHA in every message.

## Active lanes (cap 7 cloud lanes, raised 19 Oct)

| Role | Where | Session | Owns now (22 Oct) |
| --- | --- | --- | --- |
| Coordinator | Claude Code on the PC | "Wave 18-21 roadmap and PR closes" | board #241, admission and promotion to main, records, escalations to Andrew |
| Gate + staging | cloud | "Scrapkeep w17: Gate + staging lane" | `stage/alpha-w18`, batch stacking (3 or 4 PRs per batch with no shared files, one fast lane per batch), promotion gates |
| Systems | cloud | "Scrapkeep w17: Systems lane" | weak points review and `touch_body`, park_cave_in teardown (the quarantine expires 29 Oct), deterministic warden_reactor and world_one_mass_r tests |
| World | cloud | "Scrapkeep w17: World lane, restart" | sinkhole lava-channel bend (holds #317 and #327), then the #314 berm tint, park ground |
| Perf | cloud | "Scrapkeep w17: Perf lane" | #325 worker races, cold-cache shader warm-up, the 210 ms stage-change frame, row 30b, the stage 2 arena A/B |
| Challenge | cloud | "Scrapkeep: Challenge lane, Souls-like difficulty" | weak points 2a, 2b and 2c (crew_fitter), the swarm camper check, #312 contact |
| Dressing | cloud | "Scrapkeep: Dressing lane, lived-in parks" | the six park kits' row and yaw fixes (crown, sinkhole, pit, flume), #280 and its tools |
| Lighting | cloud | "Scrapkeep w18: Lighting lane" | #284 dark live core, #297 impact frame box path, #270 day arc |
| Systems B | Claude Code on the PC | "Scrapkeep w18: Systems B lane (PC)" | the periodic GATES hitch in stage 2 (finding runs on the 3060) |
| GPU bench | Claude Code on the PC | "Scrapkeep w18: GPU bench (4080 …)" | 4080 timing rows, one at a time, pinned to CCD0 (`taskset -c 0-7,16-23`) |
| Render bench | Claude Code on the PC | "Scrapkeep w18: Render bench (RTX 3060)" | 3060 stills, plus correctness jobs pinned to CCD1 (`nice -n 10 taskset -c 8-15,24-31`) |
| revive-228 | Claude Code on the PC | "Scrapkeep w18: revive #228 help and motion pack" | merges the stage into #228, gets a receipt |

## Paused until wave 19 (kept, not archived)

Animation, Grading, Effects, Challenge B (worlds 4-6 and the replay ladder), World (Blender, art) and Ambient life. These are cloud lanes, reused in wave 19 by direct message.

## Finished, safe to archive (cloud, from the claude.ai/code session list)

Challenge B band shards 1 to 8, every "Challenge worker: …" row (baselines, sweeps, libraries, fast lanes), "Challenge writer: #104 grown posture reds" (#104 closed), "Challenge full gate bt5 head", "Scrapkeep Gate shard runner: wave 17 rest shard" and "Scrapkeep cloud environment setup". The coordinator can't archive cloud sessions from the PC, so Andrew does it from the sidebar.
