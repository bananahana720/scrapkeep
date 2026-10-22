# Lanes and sessions (22 Oct 2026, local coordinator)

This file lists the session behind each lane. [GRAPH.md](../coord/GRAPH.md) owns what each lane works on now, who owns which files and the test gates. Lane briefs follow [LANE-BRIEF.md](../coord/LANE-BRIEF.md). The live board is issue #241. Every ruling is posted there as a `COORDINATOR:` comment, and the lane that owns it also gets a direct message.

**Cloud lanes are one-way.** They take a direct message but can't reply to it, and they read the board only when they page it. A ruling can reach a lane late (Gate, World and Lighting each missed one on 22 Oct by 1 to 4 hours), so restate the head SHA in every message.

## Sessions (cloud lanes as listed in GRAPH.md; cap 11, ROADMAP plan 21 Oct)

| Role | Where | Session |
| --- | --- | --- |
| Coordinator | Claude Code on the PC | "Wave 18-21 roadmap and PR closes" |
| Gate + staging | cloud | "Scrapkeep w17: Gate + staging lane" |
| Systems | cloud | "Scrapkeep w17: Systems lane" |
| World | cloud | "Scrapkeep w17: World lane, restart" |
| Perf | cloud | "Scrapkeep w17: Perf lane" |
| Challenge | cloud | "Scrapkeep: Challenge lane, Souls-like difficulty" |
| Dressing | cloud | "Scrapkeep: Dressing lane, lived-in parks" |
| Lighting | cloud | "Scrapkeep w18: Lighting lane" |
| Systems B | Claude Code on the PC | "Scrapkeep w18: Systems B lane (PC)" |
| GPU bench | Claude Code on the PC | "Scrapkeep w18: GPU bench (4080 …)" |
| Render bench | Claude Code on the PC | "Scrapkeep w18: Render bench (RTX 3060)" |
| revive-228 | Claude Code on the PC | "Scrapkeep w18: revive #228 help and motion pack" |

The GPU bench pins to CCD0 (`taskset -c 0-7,16-23`). The render bench pins correctness jobs to CCD1 (`nice -n 10 taskset -c 8-15,24-31`).

## Paused until wave 19 (kept, not archived)

Animation, Grading, Effects, Challenge B (stages 4 to 6 and the replay ladder), Modeling and Ambient life. These are cloud lanes, reused in wave 19 by direct message.

## Finished, safe to archive (cloud, from the Claude Code session list)

Challenge B band shards 1 to 8, every "Challenge worker: …" row (baselines, sweeps, libraries, fast lanes), "Challenge writer: #104 grown posture reds" (#104 closed), "Challenge full gate bt5 head", "Scrapkeep Gate shard runner: wave 17 rest shard" and "Scrapkeep cloud environment setup". The coordinator can't archive cloud sessions from the PC, so Andrew does it from the sidebar.
