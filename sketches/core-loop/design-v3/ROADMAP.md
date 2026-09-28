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

## HUD look: scrapped together, clean to read (Andrew, 2026-09-28)

Andrew: the HUD should be "kind of like a um, hack together heads up display just in terms of art style ... that rough and uh, hacked together MacGyver type of feel and look. But still, obviously, be clean ... visually but also gameplay-wise, uh, functional." The interface is made by the same post-apocalyptic ball culture that scraps everything else together.

- **The rule: roughness lives on the frame, never on the information.** Panels read as salvaged plates, with rivets, an uneven bevel, and tape or a clamp at the joins. Labels are stamped or stencilled tags, and keycaps can look scavenged from mismatched sets.
- **Icons, numbers, key letters and threat glyphs stay crisp.** Wear and grime are low-contrast value shifts, never a new hue. The class colour stays the one "yours" accent, and red and HAZARD stripes stay hostile only.
- **One procedural helper** (`src/ui/scrap_frame.gd`: plate, rivets, tape, stamp tag), started by W12 on the class card and Tab pages. The HUD v3 build wave (FEEL-READABILITY F2) adopts it. The Codex track may supply painted Style A reference sheets for it.
- **Measure:** the word budget, glyph legibility at 1080p, and the density-governor stills are unchanged by the frame. A fight still reads at a glance.

## Waves to the final draft (set 2026-09-28)

| Wave | What | Status |
| --- | --- | --- |
| **A. Lab** | L1 drop, L2 laps, L3 interact, W11 juice, W12 cards and Tab, W13 ceremony. Merge into `proto/core-loop-v3`, run the fun gate (the camper fails), then Andrew's sitting. | Building |
| **B. Consolidate** | The lab verdict plus a one-page `DESIGN-V3.md`: fold in LOOP, SYSTEMS, STRATEGY-SPINE, AUDIO-V3, FEEL and STAGES; archive the rest; delete the losing loop mode and the v2 fallbacks. | After A |
| **C. Spine on all stages** | STAGES-2-3 build units (shared returns, gorge, weir, bot evidence); the Warden reads for the hive and mind families. | After B |
| **D. Systems core** | The strategy spine's minimal set (rarity ladder, 3 primes, 4 reactions, 2 persistent actors, channel mapping), drop gates, and 4 evolutions. | After B, parallel with C |
| **E. Feel and HUD** | F1 density governor, F2 HUD v3 in the scrapped-together look, F3 camera; synergy toasts become a glyph plus a name; visual accretion is capped. | After A, parallel with C and D |
| **F. Music and sound** | AU1 engine (window, pivot, pins), AU2 bank, AU3 wiring, AU4 measures. **ACE-Step beds: yes.** Andrew chose the hybrid in the blind A/B (2026-09-28) and asked for tighter production (the middle bars were choppy). Beds are made per stage, retimed per slice, glued and ducked under the engine kick. **Arrangement by area and flow:** each area and state (shelf, drop line, bowl, open window, bay, return) has its own percussion set and harmony layer, and melodies pop in and out on game events so every switch-up is understandable. | AU1 and the bed-tightening pass now; AU2 and AU3 after A |
| **G. World and environment** | Codex track: Style A scenery on all three stages around the loop geometry; Warden family looks; interactable props (the 27k-triangle plan); lore surfaced by callbacks and the codex. | After C geometry lands |
| **H. Performance and handoff** | CPU-side perf-lab (dense fights are CPU-bound, per STRESS-CAPTURE-1), native 1080p p99 of 16.7 ms or less, settings, Linux export, Andrew's early-access play. | Last |

## Look and performance target (Andrew, 2026-09-28)

Andrew: "keep iterating on it until it reaches maybe 80 to 90% of like the concept art at a playable frame rate at 60 FPS ... at 1080 ... at least 60 FPS on my setup as well ... I wouldn't want this game to be something that a mid-tier card or PC would be having a hard time to play."

- **Look:** Style A at 80 to 90 percent of the concept art (Codex's storyboards and key art in `design-v2/visual-development/` and `design-v3/storyboards/`), judged by Andrew side by side with in-game captures. The target is **look and feel only**: lighting, materials, palette, mood, silhouettes and atmosphere. UI, layouts, HUD elements or gameplay details drawn into the concept images are not specs (Andrew, 2026-09-28). UI follows its own rulings (the scrapped-together HUD, the word budgets).
- **Machines:**
  - Dev box: a Ryzen 9 5950X and an RTX 4080.
  - Mid-tier reference: a 6-core Zen 2 or Zen 3 class CPU and an RTX 3060-class card, at 1080p and 60 FPS.
- **Proxy budgets on the dev box.** These leave room for the mid-tier machine: roughly 1.5 times slower per CPU thread and 2.3 times slower on the GPU (an estimate, to be recalibrated if a mid-tier machine becomes available).
  - In the densest fight, at 1080p and the default preset: **CPU main thread p99 ≤ 10 ms**, **GPU p99 ≤ 7 ms**, and frame p99 ≤ 16.7 ms.
  - A lower preset must hold 60 on the mid-tier reference.
- **Starting point:** STRESS-CAPTURE-1's densest scene costs about 26 ms p50 on the CPU and 1.5 ms p99 on the GPU. The CPU is the binding constraint, so performance work moves from wave H to now.
- **Measured** with `tools/stress_capture.gd` (native) and a headless CPU benchmark on fixed scenes, before and after every optimisation. Keep a change only if it holds the look and the gameplay.

## Treasure-find ceremony (Andrew, 2026-09-28)

Andrew wants "fun uh, discovery sort of like treasure find ceremony when you find an item". He wants anticipation that builds, then a reveal that pays off when the item "changes the the way they play or makes them feel empowered". The ceremony pauses only "if it's I guess warranted if ... the area has calmed down after a boss fight".

- **Four tiers, scaled by rarity and context:**
  1. Common: in the flow.
  2. Rare: a flare plus a rising bell.
  3. Rare-plus, a first find or a completed synergy: a reveal card, and the partner glyph lights to tease the build.
  4. Ceremony (Warden break, the cage, caches, evolutions): a shaking and cracking crate with a drum and bell build, a burst, and the resolving chord.
- **The pause is calm-gated.** A ceremony queues until the area is safe, velocity is preserved, any input skips, and a "full / short" setting is available.
- **The payoff is felt.** The first time the new part fires, it flashes once with its own cue, so the reward connects to the change in play.
- Built as W13, `proto/core-loop-v3-ceremony`, on W11's juice. It maps to done-rows 3 (growth) and 5 (feel).

## Tool stack (checked 2026-09-28; research R3)

- **Keep:**
  - Godot 4.7.2. Upgrade to 4.8 only once it's stable and a lab verdict has landed.
  - Our headless tests and bots, GDScript synth, and Blender CLI recipes.
- **Trial when a wave needs it:**
  - Phantom Camera for F3 (the camera).
  - Debug Draw 3D, for drop-line and hit-predicate tuning.
  - A local run-telemetry writer. `run_log` already exists; extend it with death or hit positions for heatmaps before trying Talo.
  - TRELLIS.2 (MIT) plus Blender cleanup for Codex's prop pipeline, Hunyuan3D only after its licence is read.
- **Skip for now:** engine changes, paid pipelines, hosted analytics, and a save addon (the run is short and the settings store works).
- **Design references:** MDA to name what each system is for, Swink's *Game Feel* for momentum, and a five-question playtest sheet after each sitting (the core loop in one sentence, the best moment, the worst frustration, "again?", and ratings for difficulty, pacing and clarity).

## Rules that keep it reasonable

- Small waves, with results read before the next wave. The coordinator alone merges. The Codex track owns appearance.
- Nothing is called ready on tests alone. The fun gate (the camper fails, the map matters, the windows are legible) comes before Andrew's play.
- Andrew's design principles and rulings stand: momentum is sacred, quick restart, opt-in layers, readable caps, no reskins, spill-B music, gems never lost.
- Each lead's design names its measures. A system without a measure isn't done.
