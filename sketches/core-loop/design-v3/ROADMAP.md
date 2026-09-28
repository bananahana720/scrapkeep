# Roadmap to the final draft v2

Andrew, 2026-09-28: "shoot for the stars ... in a reasonable manner ... take this super serious mode ... have fun and let's try to cook something up that's like a well-polished final draft V2." The build is the core-loop sketch's v3 code line. The end state is one run you want to replay, one you'd show someone.

## The end in mind: definition of done

A build passes when every row holds on the same commit. The rows measure structure and polish; Andrew's play is the verdict.

| # | Area | Done means | Measured by |
| --- | --- | --- | --- |
| 1 | Why stay | The spine chosen at the lab sitting runs on all three stages. The camper cannot win, and the map is where power comes from. | LOOP-REDESIGN §4 bands at 16 seeds per policy, all green |
| 2 | The Warden | Each family reads closed, telegraph, open, punish and recover. Dodges, the open window and progress are unmistakable. | `warden_window_test`, `warden_impact_test`, a near-miss test, stills of each state |
| 3 | The snowball | Runs grow into readable chaos. Evolutions, the pick cadence, rule parts and bets all work, and run 20 differs from run 1. | SYSTEMS-CHAOS measures: distinct builds per 16 seeds, time to first evolution, picks per minute, power-curve bands |
| 4 | Discovery | The E interactables' five families live on every stage, each learnable by shape and sound. Secrets and treasure reward curiosity. | Interact tests, one playable of each family per stage, codex "found" logs |
| 5 | Feel | Every hit, kill, pickup, drop and dodge has layered feedback. Knockback differs by weapon and bombs satisfy. Momentum is never eaten. | W11 tests, feel profiles table, ball-velocity invariants |
| 6 | Readability | Threats stay readable in the densest late-run scene. The HUD's hierarchy and density are fixed. The fight HUD shows 25 words or fewer and calm screens 40 or fewer. Every key prompt is legible. | FEEL-READABILITY checks: threat visibility in dense stills, effect budget, word budgets, keycap test |
| 7 | Selling the pilot | Each class card makes you want that pilot. The Tab and help pages are pictures, not essays. | W12 stills, and Andrew's read |
| 8 | Sound | The music is revamped in theme and adaptive. The Warden fight, laps, drops and snowball are scored in the spill-B grammar. No gem is lost, and SFX stay in key. | AUDIO-V3 measures: beat-grid event log, voice and loudness budgets, the gem regression test |
| 9 | Look | Codex's Style A covers the heroes, Wardens, stage props and new interactables at a consistent level. | Codex captures, and stills against the atlas |
| 10 | Performance | Traversal, grown dense combat and boss peak each run at 1080p p99 ≤ 16.7 ms on Andrew's PC. | Native 120 s runs under a quiet GPU |
| 11 | Robustness | `sketch:smoke` is green, item fuzz runs 200 seeds with no anomalies, bots finish every stage without hangs, and restart is one key. | Smoke, fuzz and bot reports |
| 12 | Hand-off | A launch command, a one-page how-to-play in game, and a README. | Andrew launches it cold |

## Phases

| Phase | What happens | Gate out |
| --- | --- | --- |
| P0 Lab and designs (now) | L1 drop, L2 laps, L3 interact, W11 juice, W12 cards. The Systems and Chaos, Audio, and Feel and Readability leads write their designs and run spikes. | Lab merged; the bots show the camper fails in drop and laps |
| P1 The sitting | Andrew plays drop (both gun roles), laps, then v2, about 10 minutes each. This is playtest entry 9, one verdict per mode. | A spine chosen |
| P2 Meeting of minds | The three lead designs are reconciled against the chosen spine into one build plan, conflicts resolved, then shown to Andrew on one page. | Andrew's go |
| P3 Build | The spine goes to stages 2 and 3; then snowball systems, the audio revamp, the feel and HUD grammar, the full interactable set, and Codex's appearance for new props. Serial where seams collide. | Every DoD row except 10 and 12 green |
| P4 Harden and polish | Bots at 16 seeds, fuzz, native performance, captures, an alignment review, the fun-gate check, and a polish pass on the largest gaps. | Every row green |
| P5 Andrew plays the final draft | Playtest entry 10 and beyond, iterating on his verdict. | His verdict |

## Subtract to add (Andrew, 2026-09-28)

Andrew: "consider subtracting to add ... refine and slim down ... start trimming and slimming down and start shifting where we have to shift in terms of direction and approach". From here on:

1. **The design phase closes** when the in-flight design work lands: the Audio lead, the Codex Feel takeover, the Codex stages spec and the Codex systems review. No new design documents after that; only build notes.
2. **One design source.** A consolidation pass writes `DESIGN-V3.md`, the single canonical spec (target 400 lines or fewer), from the lab verdict plus LOOP-REDESIGN, SYSTEMS-CHAOS, AUDIO-V3, FEEL-READABILITY and STAGES-2-3-LOOPS.
   - Those files, the v2 ideation (`design-v2/I1` to `I3`, PROTOCOL, the primer boards) and DEMO-SPEC move to an `archive/` folder with a one-line pointer.
   - DESIGN-NOTES splits: the v1 and v2 notes go to an archive file, and v3 starts fresh.
3. **Build the minimum high-impact set first.** The spine, the Warden's reads, juice, the core interactables, a handful of evolutions (not 16), drop gates, the HUD fix, and the audio bed if its spike passes.
   - Deferred to a post-draft backlog unless the sitting says otherwise: meta progression, Tally, rule parts, cursed caches, blessed Wardens, the seed field, and the extra evolutions.
4. **Delete losers in code.** After the lab verdict, the unchosen loop mode, the v2 fallback paths and any system the spine makes redundant are removed, not left switchable.
5. **Fewer threads.** At most 5 Claude agents at once. Codex (Astra) takes consolidation, reviews and design so the Claude limit goes to building. One integration branch for v3.
6. **Worktree hygiene.** Merged or finished worktrees are archived (`artifacts/local` moved to `/home/andrew/Projects/scrapkeep/artifacts/local/core-loop-worktrees/`), then removed; branches are kept. 21 were removed on 2026-09-28.

## Rules that keep it reasonable

- Small waves, with results read before the next wave. The coordinator alone merges. The Codex track owns appearance.
- Nothing is called ready on tests alone. The fun gate (the camper fails, the map matters, the windows are legible) comes before Andrew's play.
- Andrew's design principles and rulings stand: momentum is sacred, quick restart, opt-in layers, readable caps, no reskins, spill-B music, gems never lost.
- Each lead's design names its measures. A system without a measure isn't done.
