# Attack ids (E-numbers) registry (historical wave 17 snapshot)

> **Superseded historical record (17 Oct `#241`):** Live E-numbers on `main` (`E01`–`E27`, `E30`–`E40`) are owned directly in `sketches/core-loop/src/core/event_kinds.gd`, `sketches/core-loop/src/combat/telegraph_record.gd`, and `sketches/core-loop/design-v3/LEGIBILITY.md`. Do not read the table below as current `main` free IDs.

Owner: local coordinator. One E-number per attack kind, in
`src/combat/telegraph_record.gd`, `src/core/event_kinds.gd` and the design-v3/LEGIBILITY.md
section 2 table. Claim a number here BEFORE you add it to a branch, and post the claim on the Wave board issue (#241). Rule for collisions: the earliest commit that added the id keeps it; later
claims renumber to the next free id. The Gate lane re-folds the registry when it stacks PRs and renumbers any collision.

**Gate placeholder rule (22:12Z 17 Oct):** a PR that adds an E-row fills every field before
it goes to the Gate lane: pose, warn, release and floor set (floor is L, H, B or none), never
`EventKinds.PLACEHOLDER`, and its `open` list empty. Re-pin `event_kinds.ATTACK_ROWS` in
content_registry.gd with a dated note in the same commit.

On origin/main: E01, E02, E05 to E24 (E03 and E04 are unused; leave them alone).

| Id | Kind | PR | Branch | First commit with it | Status |
|---|---|---|---|---|---|
| E25 | splitter_pod (Splitter pod fuse blast) | #60 | claude/splitter-3mgbv8 | e3bab24a, 17:59Z 17 Oct | keeps E25 |
| E26 | dispatcher (Dispatcher tube drop) | #59 | claude/dispatcher-0owqx5 | 3b3d9e35, 18:59Z, as E25 | done, #59 head 1df9f47d |
| E27 | jolt_layer (Jolt layer mat) | #65 | claude/project-thread-azoily | f094aa92, 20:30Z, as E25 | done, #65 at b7364f96 (pose and floor filled) |
| E28 | free | | | | |
| E29 | free | | | | |
| E30 | pit_jaw (Pit jaw bite) | #69 | claude/project-thread-h6c20i | fa0bca00, 20:36Z | pose and floor filled at 1b7e94a4 |
| E31 | prop_crew (Prop crew roof drop) | #71 | claude/prop-crew-events-fzz0ti | 76f368aa | claimed |
| E32 | ballast_heavy (Ballast heavy brace slam) | #72 | claude/highdraft-roster-b2p1pg | renumbered from E31, 21:40Z 17 Oct | claimed |
| E33 | gap_net (Gap net charge) | #72 | claude/highdraft-roster-b2p1pg | renumbered from E32, 21:40Z 17 Oct | claimed |
| E34+ | free | | | | claim the next free id here first |

Checked 20:40Z 17 Oct by grepping every origin branch's telegraph_record.gd and event_kinds.gd
for E25 and up. Only the four ids above are in use beyond main.
