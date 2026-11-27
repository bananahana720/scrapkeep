# Roadmap to the exported alpha: historical milestone definitions

> **Historical (3 Oct).** The live roadmap is [project-guide/handoff/ROADMAP.md](../../../project-guide/handoff/ROADMAP.md); rulings are in [project-guide/handoff/DECISIONS.md](../../../project-guide/handoff/DECISIONS.md).

Written 3 October 2026 from the approved refinement of [ALPHA-PLAN](ALPHA-PLAN.md), the owner interview (`OWNER-INTERVIEW-2026-10-02.md`, archived in git history), [LEGIBILITY](LEGIBILITY.md) and playtest entry 11. The former world-one limit and alternative-loop queue below are preserved as historical direction, not assignments.

## Definition of done

One exported Linux alpha with Spillway Works, Dig and Highdraft in that fixed order; two zones and a world boss each; six Wardens, Brindle, Waking and Mind. Mind ends the run. Six full pilots, one assembled combat companion, a between-run camp, and a 30-to-45-minute victorious run. No free retry (22 Oct ruling): a death restarts at world 1, and a rare earned item can save one death (details to come, DECISIONS 22 Oct). Free unfinished-zone quit/crash replay from the saved entrance. No permanent combat-stat boosts.

| Checkpoint | Delivery | Acceptance |
| --- | --- | --- |
| Cable Reach | One readable posture fight, meaningful growth, activities and flowing harpoon traversal | Checked candidate, existing bot bands and performance evidence; Andrew's sitting verdict before any later-world map or encounter |
| World one | Spillway plus Cable Reach, two Wardens, Brindle, rescue progression, rewards and durable run continuity | Complete world-one run; saves, retries, one-time rewards and existing profile migrations checked |
| New pilots and companion | Tarn first, Tally next, cannon last; reused six probes; one modular SPIL-9 | Each full kit/tree/model/animation/sound; three module pairs useful and legible; no extra revival |
| Three-world greybox | Four later zones, Breach and Lift, six new enemy kinds, four Wardens, Waking and Mind | Complete campaign without boss stubs; every pilot traverses both later mechanics |
| Dressed campaign and camp | Approved world art, animation, effects, music/lore; camp menu; optional for the alpha (cut, W18-R1): five menu stations, skee-ball, pet/toys, ghost/medals and enemy sandbox | Captures and frame times on the same build; in-play look/audio verdict; launch budgets checked |
| Exported alpha | Achievements, cosmetics, codex, discoveries/recipes, ending, how-to-play and bundled assets/music | Fresh-profile unlock sequence, another run with cannon, cold Linux launch and durable resume |

## Content and progression

| Pilot | Unlock |
| --- | --- |
| Sable | Initially available |
| Rivet | World-one rescue quest |
| Tarn | Defeat Brindle |
| Kest | Dig rescue quest |
| Tally | Return one ledger leaf from each world to Moss; collection spans runs |
| Remembered cannon | Defeat Mind once |

Unlocks become selectable next run; existing earned profile unlocks remain. The three existing pilots are still starters in today's data until the unlock achievements are wired.

One binary tree per pilot has four connected picks and sixteen endpoints; world one opens depths one/two and later worlds depths three/four. Preserve Path/Relic/Parts and the two initial evolutions. Rarity is Common/Rare/Relic/Evolved plus hot-wired. Cogs spend, scrap supplies size and armour, cores stay zone-local. Three companion module families fit two unordered sockets on one SPIL-9 chassis; run loot and intermission reconfiguration form the assembly loop.

## Execution and evidence

Continue proto/alpha; coordinator-only serial integration and canonical records. Recover the pending gamepad-menu fix at 286327f before replacement work. Existing rock/terrain candidates remain scoped experiments until their selected pieces pass admission; do not merge an old probe branch wholesale into the current slice. Preserve their sources and receipts.

Use small waves within ORCHESTRATOR's eight-delegate ceiling (up to five writers, three reviewers or verifiers), as the alpha program waves have since EV-0599. Pin delegates by the active Codex map, preserving the stricter project judgment rules and approved GPT-6.1 Sol high asset/animation lane. Shared gate once per combined candidate; serialize GPU work.

Current state (TRACKING EV-0625, proto/alpha d03422d after wave 20, 6 October 2026): six of six pilots playable, three of three worlds complete in bot play, Cable Reach sitting passed (EV-0624), exported build with win proof each wave; the multi-hour alpha sitting is pending. Dressed campaign and camp, and Exported alpha, are the open checkpoints; HANDOFF.md holds the per-wave record. No reliable overall percentage. The old 235-unit/11-to-14-day estimate is retired; recount bounded remaining units after recovery. Report built, integrated, automated and human-accepted separately.

The Cable Reach miss policy remains one correction round of at most ten units and a second sitting; further work needs a re-plan. Optional extras are additional lounge games/decorations. Production migration, dependencies/services, more worlds and a boss after Mind are outside this alpha.

## Historical roadmap (28 September 2026)

The following preserves the earlier design and its observations. Its old scope, phases, assignments, model pins and deferred roster do not override the current roadmap above.

### Historical roadmap to the final draft v2

Andrew, 2026-09-28: "shoot for the stars ... in a reasonable manner ... take this super serious mode ... have fun and let's try to cook something up that's like a well-polished final draft V2." The build is the core-loop sketch's v3 code line. The end state is one run you want to replay, one you'd show someone.

## The end in mind: definition of done

**The milestone is the end of world one** (Andrew, 2026-09-28): stages 1 to 3, their three Wardens, and Brindle, the world boss. Scope is locked there. Every system is fleshed out in full detail to the depth a player can reach by Brindle, and no deeper:
- The kit tree gets only the tiers reachable in world one, fully detailed for all three pilots. The 8- and 16-way end variations stay unbuilt.
- The same applies to evolutions, hot-wired parts, discovery cards, interactables and enemy reads: world one's set is complete and polished, with nothing stubbed for later worlds.
- Assets and animation can keep being tweaked in place after this.

When every row holds, we stop, reassess, re-baseline, and set direction for what follows. A build passes when every row holds on the same commit. The rows measure structure and polish; Andrew's play is the verdict.

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
| P5 Andrew plays the final draft | Playtest entry 10 and beyond, iterating on his verdict, through world one to Brindle. | His verdict, then a re-baseline and the direction for after world one |

## Subtract to add (Andrew, 2026-09-28)

Andrew: "consider subtracting to add ... refine and slim down ... start trimming and slimming down and start shifting where we have to shift in terms of direction and approach". From here on:

1. **The design phase closes** when the in-flight design work lands: the Audio lead, the Codex Feel takeover, the Codex stages spec and the Codex systems review. No new design documents after that; only build notes.
2. **One design source.** A consolidation pass writes `DESIGN-V3.md`, the single canonical spec (target 400 lines or fewer), from the lab verdict plus LOOP-REDESIGN, SYSTEMS-CHAOS, AUDIO-V3, FEEL-READABILITY and STAGES-2-3-LOOPS.
   - Those files, the v2 ideation (`design-v2/I1` to `I3`, PROTOCOL, the primer boards) and DEMO-SPEC move to an `archive/` folder with a one-line pointer.
   - DESIGN-NOTES splits: the v1 and v2 notes go to an archive file, and v3 starts fresh.
3. **Build the minimum high-impact set first.** The spine, the Warden's reads, juice, the core interactables, a handful of evolutions (not 16), drop gates, the HUD fix, and the audio bed if its spike passes.
   - Deferred to a post-draft backlog unless the sitting says otherwise: meta progression, Tally, rule parts, cursed caches, blessed Wardens, the seed field, and the extra evolutions.
4. **Delete losers in code.** After the lab verdict, the unchosen loop mode, the v2 fallback paths and any system the spine makes redundant are removed, not left switchable.
5. **Sustainable threads.** Revised 2026-09-28 for throughput on Sonnet 5.5: at most 8 Claude delegates at once (5 writers, 3 verifiers or gates), per ORCHESTRATOR's review lane. Sonnet builds, a Sonnet verifier returns receipts, Opus gates, and Fable joins for consequential seams. Codex (Astra) takes consolidation, reviews and design. One integration branch for v3; the coordinator merges serially.
6. **Worktree hygiene.** Merged or finished worktrees are archived (`artifacts/local` moved into the main checkout's `artifacts/local/core-loop-worktrees/` archive), then removed; branches are kept. 21 were removed on 2026-09-28.

## HUD look: scrapped together, clean to read (Andrew, 2026-09-28)

Andrew: the HUD should be "kind of like a um, hack together heads up display just in terms of art style ... that rough and uh, hacked together MacGyver type of feel and look. But still, obviously, be clean ... visually but also gameplay-wise, uh, functional." The interface is made by the same post-apocalyptic ball culture that scraps everything else together.

- **The rule: roughness lives on the frame, never on the information.** Panels read as salvaged plates, with rivets, an uneven bevel, and tape or a clamp at the joins. Labels are stamped or stencilled tags, and keycaps can look scavenged from mismatched sets.
- **Icons, numbers, key letters and threat glyphs stay crisp.** Wear and grime are low-contrast value shifts, never a new hue. The class colour stays the one "yours" accent, and red and HAZARD stripes stay hostile only.
- **One procedural helper** (`src/ui/scrap_frame.gd`: plate, rivets, tape, stamp tag), started by W12 on the class card and Tab pages. The HUD v3 build wave (FEEL-READABILITY F2) adopts it. The Codex track may supply painted Style A reference sheets for it.
- **Measure:** the word budget, glyph legibility at 1080p, and the density-governor stills are unchanged by the frame. A fight still reads at a glance.

## Waves to the final draft (set 2026-09-28)

| Wave | What | Status |
| --- | --- | --- |
| **A. Lab** | L1 drop, L2 laps, L3 interact, W11 juice, W12 cards and Tab, W13 ceremony. Merge into `proto/core-loop-v3`, run the fun gate (the camper fails), then Andrew's sitting. | Merged at ac0311e (192 smoke PASS, three verifiers PASS, fun gate held: the camper deals 0 in drop mode). Andrew's sitting next |
| **B. Consolidate** | The lab verdict plus a one-page `DESIGN-V3.md`: fold in LOOP, SYSTEMS, STRATEGY-SPINE, AUDIO-V3, FEEL and STAGES; archive the rest; delete the losing loop mode and the v2 fallbacks. | After A |
| **C. Spine on all stages** | STAGES-2-3 build units (shared returns, gorge, weir, bot evidence); the Warden reads for the hive and mind families. | After B |
| **D. Systems core** | The strategy spine's minimal set (rarity ladder, 3 primes, 4 reactions, 2 persistent actors, channel mapping), drop gates, and 4 evolutions. | After B, parallel with C |
| **E. Feel and HUD** | F1 density governor, F2 HUD v3 in the scrapped-together look, F3 camera; synergy toasts become a glyph plus a name; visual accretion is capped. | After A, parallel with C and D |
| **F. Music and sound** | **Full ACE-Step** (Andrew, blind pack 2, 2026-09-28: all three full-ACE takes beat the hybrid, which he'd liked, and the ten-layer and two-layer hybrids had failed). The synth engine composes guides, and ACE-Step performs and produces them, so drums and bass always come from one performance. **Dynamics are the runtime's job:** the Warden's held breath takes the drums and bass stems out and thins the rest, and the drop brings every stem back on the next beat. ACE ignores a guide's dynamics (Slice 0 round 1: 18 of 18 takes). The runtime sequencer PoC (`proto/core-loop-v3-seq` 43453ab) mixes stems sample-accurately, makes the landing audible at a 67 ms mean (the old engine took 183 ms), and has zero skips at a 3072-frame queue. Sound effects stay synth and keyed (AU2 bank merged). **Arrangement by area and flow:** each area and state (shelf, drop line, bowl, open window, bay, return) has its own percussion set and harmony layer, and melodies pop in and out on game events, so every switch-up is understandable. Restraint: density is earned by the game, not the default. | Slice 0 round 2 (blind pack 3) now; the sequencer rewrite and AU3 wiring after Andrew's pack-3 verdict |
| **G. World and environment** | Codex track: Style A scenery on all three stages around the loop geometry; Warden family looks; interactable props (the 27k-triangle plan); lore surfaced by callbacks and the codex; pilot reactions (below). | Look pass 1 committed in the visual clone (3fa27b4): GPU p99 1.7 ms, fidelity 28 to 76 of 100, and the gap is geometry. Look pass 2 (strata, water, instanced props, the Warden form, the bay) and the image-to-3D trial (`proto/core-loop-v3-img3d`) are running |
| **H. Performance and handoff** | CPU perf-lab, native 1080p p99 of 16.7 ms or less, settings, Linux export, Andrew's early-access play. The binding constraint is found (`perf-lab/ledger.md` on `proto/core-loop-v3-perf`, 288eb21): telegraphs rebuild their mesh every frame (about 0.35 ms each). Fixes run in order: E1 static telegraph geometry with a shader-driven fill (about 10 ms), E2 one enemy snapshot per tick (about 1 ms), E3 HUD redraw on change (about 0.5 ms). E1 follows F1a because both edit `threat_grammar.gd`. | Now, alongside E |

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

## Pilot reactions (Andrew, 2026-09-28)

Andrew: "the pilot should react to the player's actions, achievements, or failures". The pilots are characters, built up as we go.

- **One reaction table** (`src/presentation/pilot_reactions.gd`) maps each event to a clip, a priority and a cooldown, with per-class overrides.
  - A higher priority interrupts a lower one, and cooldowns stop spam.
  - Missed-drop and evolution rows wait for their events.
- **Clips are made with the keyframe pipeline** (mesh, rig, imagegen keyframes in three views, then Blender posing), on the shared 25-bone pilot rig:
  - `drop_land`: exists, about 2.2 s.
  - `big_cheer`: Warden break and stage clear.
  - `wince`: a hit.
  - `slump`: death.
  - `phew`: a near miss.
- **Rules:**
  - Poses read from the rear chase camera: bigger, side-on, breaking the hull's outline.
  - Length follows what the motion must communicate, and only impacts are fast.
  - Reactions are cosmetic and never touch the ball.
  - The bar is "good enough, not overly complex".
- The table and wiring are WIP 0a07aaf on `codex/pilot-reactions` in the visual clone, and the four clips landed at b6a595e. New clips follow the split below: Codex draws the keyframes, Sonnet agents pose and export them in Blender.

## Feedback and discovery (Andrew, 2026-09-28)

Andrew wants feedback solid enough for an alpha in a game about timing, dodging and reading 3D space from different perspectives. These are standing principles on top of everything else.

- **Attacks read through the attacker first.** Every attack, whether enemy, Warden or the player's own, is announced by its body and its sound: a wind-up pose, a charge glow, an audible inhale or ratchet, then the strike and the recovery. The floor marking becomes **support, not the message**: a thin, translucent red haze or projection line that traces where the hit lands. RR-01 still holds: the haze draws from the same committed geometry that deals the damage. This extends principle 15 (wind-ups mapped onto the telegraph, strike and recovery keys) to every attacker. E1's static geometry with a shader-driven fill makes the thinner haze a shader change rather than a rebuild.
- **First discovery explains itself; repeats just pop.** The first time a player finds a synergy, item, interactable or reaction, a picture card shows what it does: a short looping animation of the thing working, plus a name and at most a few words. It follows the ceremony's calm gate. It pauses only when the area is calm; mid-fight it lands in place as a glyph and the card waits for the next calm moment. Any input skips it, and velocity is kept. After that, triggers are a quick glyph-plus-name pop (wave E's toast). This reconciles FEEL-READABILITY §5 ("learn by experimenting, the codex names it after the fact"): the player still discovers by doing, and the card celebrates and explains what they just did rather than instructing in advance.
- **Progression gets a ceremony.** Unlocking an area or a pilot, and completing a branch of the upgrade tree, get their own celebration tier on W13's ceremony, with its own cue in the spill-B grammar.
- **The codex is browsable from the home menu.** Each entry has a short description, its known synergies and its interactions, and fills in as the player discovers them.
- **Double-edged items.** Parts with tremendous upside and a real downside, which can make or ruin a run, including a forced skip when you need something else, and mutated starting seeds. The working name is **hot-wired parts** (salvage culture, not "cursed"). These are the existing cursed caches, rule parts and seed-field ideas, now wanted by Andrew.
- **Alpha scope: introductory level** (Andrew, 2026-09-28). The alpha is the start of the game, world one up to its boss, so everything is built for what a first-time player meets there.
  - **In the alpha:**
    - Attack reads through the attacker, for world one's enemies and its Warden.
    - First-discovery picture cards, for world one's synergies, items, interactables and reactions.
    - Two or three hot-wired parts in wave D, pitched as a first taste: the upside is obvious, the downside is readable and survivable, and the forced-skip tension appears once.
  - **After the alpha, as principles until then:** progression ceremonies for unlocks and tree branches, the home-menu codex (the in-run Tab codex stays), more hot-wired parts, and mutated starting seeds.

## Scrap is size, and every system earns its place (Andrew, 2026-09-28)

**The finding.** Scrap drove almost no decisions. Every pickup silently raised two numbers, the wallet and mass (`run_state.gd:98-104`). Spending the wallet kept mass, so it cost nothing felt (`:25-26`, `:177-181`). Free picks arrive at about 2.5 to 3 a minute (`SYSTEMS-CHAOS.md`, archived in git history), so buying was rarely a real choice. Andrew: "what's the point of me accumulating this currency?"

**The ruling.**
- **Scrap is your size:** the Katamari number that already drives punch against plating, the magnet and the heft class.
- **The wallet as a second number goes.**
- **Scrap also gets a benefit that is easy to understand and fits the theme.** The lead candidate is **durability**: scrap is armour plating on the ball, a hit knocks scrap loose as a spill you can roll back up (Sonic's rings, in scrap), and a big ball is a tough ball. Playing clean keeps you big, and greed and recovery become decisions.
- **Durability is temporary health, and rolling wears it** (Andrew, 2026-09-28, which settles the lead candidate). Scrap is a temporary health layer over the hull. Hits knock it loose as a spill you can roll back up, and friction slowly wears it down as you roll ("your ball will wear, so rolling can be a way to slowly take it down, kind of like a temporary health boost"). This engages proactive, aggressive play: keep collecting to stay big, tough and punchy. The harmonization, so rolling never feels like punishment: wear strips only the scrap layer, never the hull, and it is slow at a cruise. How wear scales with speed, skids and wall scrapes is for the design run to tune, and a play test settles it.
  - **Class thresholds need hysteresis.** Wear drains size continuously, so a class drops only a margin below its threshold. Otherwise the transformation flickers at a boundary.
- **One pilot, several ways to play** (Andrew, 2026-09-28). A scrap-hungry juggernaut suits Sable, but no pilot is locked to one fantasy. Sable can also play as a ninja platformer, or as a massive cannonball, the Indiana Jones boulder launching off walls at speed. World one's kit-tree tiers should give each pilot at least two distinct play identities, each fun on its own. That's the expression dimension of the audit.
- **Mass is stored momentum; each pilot cashes it in their own verb** (Andrew, 2026-09-28, extended from his Sable idea).
  - **Handling stays size-neutral by default,** which keeps the 2026-09-26 spine rule and readability.
  - **Each pilot's kit tree turns mass into their signature move:**
    - Sable's slingshot, vault and wall rebounds return more speed the bigger she is, until she's a rolling boulder beam off the walls.
    - Rivet's sprint and ground smash hit harder with weight.
    - Kest's payloads blast bigger.
    
    The Rivet and Kest lines are extensions for the design run to test.
  - **Bulk penalties are opt-in only,** on hot-wired parts (for example, heavy plating: more durability, less air control). Each pilot's line can cancel or flip one; Sable's grapple and vault line cancels the mobility ones.
  - **The general pattern for capstones and hot-wired parts is inversion:** a skill that turns a state's cost into its upside. The audit should find where else that pattern applies. Wear feeding a spark trail is one candidate.
- **Cogs are the currency, and their job is agency against RNG** (Andrew, 2026-09-28, who delegated the design to the coordinator: "I can let you be proactive and you can take the wheels on that"). The design:
  - **Two resources, two jobs, never confused.** Scrap is what you wear: size, durability and momentum. Cogs are what you spend: choice. They differ in every layer. Scrap chunks stick to the hull with a crunch, and cogs clink into a counter with a bright pitched tick that rises in a quick run as you vacuum a stream. The existing shop cog glyph (`shop_tile.gd:139`) is the icon.
  - **Satisfying in volume.** Kills, crates and breakables burst cogs in small, numerous pieces. The magnet vacuums them from a small radius, and **the magnet grows with heft**, so being big also means hoovering more; parts can widen it further. Collection is always on the move.
  - **Loot is common and never wasted.** Buff parts drop often. Any part you don't want, or a pick you skip, recycles into cogs on the spot. That softens the forced-skip tension of hot-wired parts, and a hot-wired part recycles for a lot of cogs, so "take the money" is a real gamble.
  - **Where cogs buy agency.** All of it is on the move or in calm:
    - **Staples.** Moss's shelf always stocks a small, known set per world, so a build can be planned around them.
    - **Fabricator hoops.** Roll through to buy at full speed.
    - **Reroll** a pick.
    - **Hold** a pick for later.
    - **Steer.** Pay to bias the next pick toward a tag.
  - **Pseudo-random with a floor.** Item pools are seeded per world. Each tag's weight rises every pick it misses, until it appears (bad-luck protection), so a run can't be starved of what a build needs.
  - **What it serves.** Strategy (staples and steering), risk (spend now or save, recycle or keep), gambling (rerolls and the hot-wired payout), performance (clean, fast play hoovers more), mastery (known staples enable planned routes), expression (steering toward an identity) and feel (the vacuum stream).
  - **In code, it's mostly a split.** `run_state.gd` already separates the wallet (`scrap`) from `mass`. The wallet becomes `cogs`, and pickups split into scrap pieces (mass only) and cog drops (wallet only), in place of `add_scrap` raising both (`:98-104`).
    - Blast radius: `run_state.gd`, `build/scrap_field.gd`, `build/fabricators.gd`, `build/shop.gd`, `ui/shop_tile.gd`, the HUD wallet readout, the items with scrap effects (`build/items.gd:65,183,196`, `build/parts.gd:116`), each enemy's `scrap_value`, the summary stats, and codex text. Warden theft keeps taking mass.
    - It builds in wave D, after the purpose audit and the lab sitting, since the free-pick cadence depends on the loop.
- **Thresholds transform the ball** (Andrew: "if you collect a certain amount of scrap, you transform in a certain way ... your sprite gets bigger, or details morph and get layered on magically"). Each heft class (I to V, `HEFT_CLASS_AT` in `run_state.gd:15`, announced by `heft_class_changed`) becomes a visible transformation moment. The shell grows, new salvaged details layer onto the hull, and there's a short ceremony beat with its own cue. This is on the W13 ceremony and calm-gated like the rest. The spine rule holds: growth shows in the shell, while the collider and handling stay the same. Losing a class (a theft, or a durability hit) visibly sheds a layer, so the ball's look is always an honest read of its size. The art follows the asset split: Codex draws each class's silhouette and detail sheet, and Sonnet builds them.
- **Open for the design run:**
  - the wear curve (cruise, speed, skids, wall scrapes) and the class hysteresis margin;
  - the cog prices, drop rates and the steering cost, tuned against the chosen loop's free-pick cadence;
  - whether a voluntary melt of weight into a part in Moss's calm bay earns its place.

**The purpose audit landed** (`research/PURPOSE-AUDIT-1.md`, archived in git history; Codex, 2026-09-28).
- **Recommendation: Option A, recoverable plating over the hull.** Scrap absorbs damage before the hull, and a hit spills 75% as at most six recoverable clusters ahead of the ball's line. Wear is slow and quiet. There is one damage order (mitigation, then scrap, then hull). Recovered scrap never retriggers pickup bonuses. The hidden 0.2 heft per part goes (`run_state.gd:120-121`), so size comes from scrap alone.
- **Its biggest risk is a downward spiral.** One hit cuts protection, punch, contact advantage and magnet reach at once, and wear drains the same pool. Any build of Option A must tune against that.
- **Crowded areas to resolve in `DESIGN-V3.md`:**
  - build growth, with seven sources all saying "your build changed";
  - time pressure, where five systems could turn exploration into debt;
  - reward currencies. The audit argues for no wallet, which predates the cog ruling. Scrap, cores and cogs must justify three resources, or cogs absorb the cores' role.
  - celebration, where everything wants the same attention;
  - defence, which needs one damage order.
- **Thin areas:** skill-based recovery, comparable personal bests, deliberate build correction (Moss's job), and one good small wager.
- **The next step is a flag-gated durability prototype on a fixed three-minute route with three variants:** hull only, armour without wear, and armour with wear. Andrew plays it and judges recovery against chore, and whether wear changes routes.

**The purpose audit.** Every world-one system is scored on the dimensions it serves: strategy, risk, gambling, performance and skill, personal-best mastery, expression, discovery, spectacle and feel, pacing, momentum cost and readability cost. For each system, it names the decision it hands the player. A system that serves no dimension, or duplicates another, is merged or cut; one that serves several is protected. The audit feeds `DESIGN-V3.md` in wave B, and loop-dependent verdicts wait for the lab sitting.

## Harpoon and winch, the shared verb (Andrew, 2026-09-30)

Andrew wants every pilot to carry a right-click harpoon on a winch, fired from the front of the gyro, as the game's identity. He listed its jobs:
- reel yourself to surfaces: escape, hang from overhangs, pull-vault over walls;
- pull, drag, whip and throw enemies;
- latch a boss and winch-launch a smash onto its open core.

It is skill-based but feasible: a skill shot, or a soft-lock while RMB is held. He left the system design to us.
- **Scaling.** The base harpoon is modest. Pulling enemies in, whips, throws and the juiced versions come from upgrades, items, and unlocks earned over runs.
- **The base verb, from the first run.** Harpoon an enemy and winch yourself in for a directed smash. That is the risk-reward: a careless commit lands you in the crowd, and only a ready dash gets you out.

**The pattern, one abstraction up.** A line joins two bodies, the winch shortens it, and the looser end travels.
- **Fixed ends** (world, the Warden, a mounted ball) pull you in. A footed enemy counts as fixed while your ball is loose, so the base verb falls out of the law.
- **Pulling enemies to you is the earned layer.** It comes from a brace upgrade, the heft tiers, or both; the prototype tests which.
- **What flows along the line is each pilot's own.** Sable, the winch master, sends motion (swing, pay-out, pylon mount, Coil Hook). Rivet sends force (tow, whip, throw into pins). Kest sends payloads (stickies ride the line; claymore jump or hang).
- **Canon.** The Fleet's anti-ball harpoons are salvaged and turned on them (T7). T6's "the fox winches" becomes mastery: every ball carries a line, and only Sable's sings. The player's line never takes the Fleet's HAZARD stripes or its crack-and-creak sound.

**Rulings, 2026-09-30:**
- At the Warden the harpoon is a **drop finisher**, not a fourth spine. Off a lip or shelf, you hook the open core and winch-smash down. From the bowl floor it clanks for 0, so the camper still fails.
- **The lab sitting (Part 1) comes first** on the unchanged build. The harpoon builds in parallel as a flag-gated prototype (`proto/core-loop-v3-harpoon`, flags `--harpoon=shot|lock`, `--harpoon-pull=self|heft`, `--harpoon-keys=shift|keep`, all off by default). It is played as Part 3 of `LAB-SITTING.md` and gets its own playtest entry.

**After that verdict:** the full program is canon and spec, the chassis line, the input grammar, the Warden per family, brace and heft tiers, pilot flavours, Fleet counterplay, items and a hot-wired drum, stage hard points, presentation, and deleting the losers. It folds into `DESIGN-V3.md` in wave B; this is not a separate design doc.

**Parked:** co-op tugs and griefing (TADR-005 keeps co-op out of scope), rope wrapping around geometry, cross-run unlocks (meta is deferred), and Kest's claymore against blink as her escape.

## Tool stack (checked 2026-09-28; research R3)

- **Keep:**
  - Godot 4.7.2. Upgrade to 4.8 only once it's stable and a lab verdict has landed.
  - Our headless tests and bots, GDScript synth, and Blender CLI recipes.
- **Trial when a wave needs it:**
  - Phantom Camera for F3 (the camera).
  - Debug Draw 3D, for drop-line and hit-predicate tuning.
  - A local run-telemetry writer. `run_log` already exists; extend it with death or hit positions for heatmaps before trying Talo.
  - Image-to-3D. The tools and results are in `proto/core-loop-v3-img3d` 829e549, `tools/img3d/TRIAL.md`.
    - **TRELLIS v1 (MIT) works:** 6 to 11 s per mesh on the 4080, cleaned to budget in Blender.
      - Props come out clean.
      - The Warden matches the concept from the front but is one fused mesh, so it's useful only as per-part sculpt detail on the jointed Blender kit.
      - The cliff reads as stacked masonry, not eroded sandstone, so it's promising but not proven. It needs a scored in-engine test and a lip-fold fix before any kit use.
    - **TRELLIS.2** is blocked: its DINOv3 encoder is gated (a manual Hugging Face approval for Andrew) and it wants 24 GB.
    - **Hunyuan3D** has territorial limits in its licence, so skip it.
    - **Reference images must be commercially clean.** Qwen-Image-2.1 is non-commercial, so use Codex imagegen references for anything that ships.
- **Skip for now:** engine changes, paid pipelines, hosted analytics, and a save addon (the run is short and the settings store works).
- **Design references:** MDA to name what each system is for, Swink's *Game Feel* for momentum, and a five-question playtest sheet after each sitting (the core loop in one sentence, the best moment, the worst frustration, "again?", and ratings for difficulty, pacing and clarity).

## Rules that keep it reasonable

- Small waves, with results read before the next wave. The coordinator alone merges.
- **Risk tolerance, measured only where it changes a decision** (Andrew, 2026-09-28). The Sonnet lane is a risk-based bet. It is fine while nothing game-breaking ships and tech debt stays manageable. The coordinator fills one row of `tools/coordinator/lane-ledger.tsv` per merged unit, from what the lane already produces. Each measure has a trigger:
  1. **Escapes.** A merged unit that turns v3 smoke red, hangs a bot, or breaks something Andrew hits in play. The tolerance is none of the game-breaking kind. One escape pauses new units until its root cause is known, and the units after it get a Fable seam review.
  2. **Gate overturns.** The verifier passed the unit and the Opus gate failed it on the diff itself (cause `writer` or `verifier-miss` below), whichever model verified. If more than 1 in 5 of the last units are overturned, verification moves back to Opus (it did, 2fbec92). Every gate FAIL or BLOCKED also gets a `gate_fail_cause` in the ledger: `writer` (a defect in the diff), `verifier-miss` (the verifier marked the failing criterion ok), `brief` (the packet or fence was wrong), `owner` (a call only Andrew can make), `env` (machine or tooling); only the first two count as overturns. Until 2026-09-29 the column was filled only for Sonnet verifiers, so sfx's Opus-verifier miss read as no overturn.
  3. **Open debt.** The debt the gate names in PASS+NOTES that isn't fixed before merge. If more than 5 notes are open, or the count grows two waves in a row, a subtract pass runs before new units.
  4. **Speed and spend.** The build-to-merge hours against today's Opus units (M0, ACE, E1), and delegate cost per unit and per 100 changed lines by role and model from the historical local hook `workflow-cost.py --since <date> --project-substr scrapkeep --ledger <this ledger> --repo <v3>`. The coordinator's own tokens are not counted. Until 2026-09-29 the delegate ledger recorded no workflow agent at all (0 of 947; they live one directory deeper), so this measure could not fire before then; 947 rows were backfilled. Output tokens for workflow agents are a lower bound (transcripts save usage mid-stream); input, cache and agent-minutes are exact. If Sonnet units aren't faster or cheaper after about 5 merges, the trial isn't buying anything, and that's reported to Andrew.
  5. **Writer A/B, pre-registered 2026-09-29.** Unit size confounds every comparison so far (Sonnet units are breadth slices; the three Opus units were large), and only one Opus unit has a changed-line count. So the next three matched pairs of asset units (same ASSETS.md category and budget) are built one by the Opus writer and one by the Sonnet writer, both at medium, through the same Opus verifier and gate, with Codex judging the look blind to the writer. Measured per pair: first-pass gate verdict, fix rounds, gate_fail_cause, Codex score, cache writes and agent-minutes per 100 changed lines. Decision rule, set before any result: Sonnet stays the default writer unless Opus wins first-pass gate or Codex score in at least two of three pairs; Opus becomes the default for that unit class only if it also costs under 2x Sonnet's cache writes per 100 lines. The result goes to Andrew either way.
  6. **Batched wave review, pre-registered 2026-09-29 (Andrew: slim review, more Sonnet, wider Opus scope).** Per-lane review (one Opus verifier with its own full smoke, one Opus gate, per unit) took 66% of delegate cache writes and 67% of agent-minutes on 2026-09-29 (`workflow-cost.py`, review share line), and the verifiers' smokes queued behind one another on the machine lock. The trial (Andrew's shape, 2026-09-29): up to five Sonnet writers (or Codex GPT-6.1 Sol builds) build in parallel against a checkable definition of done per unit; one Opus integrator verifies each unit, merges them into a candidate branch, fixes small inconsistencies there as separate tested commits, and runs one smoke on the candidate; one read-only Opus gate is the send-off; gate findings loop back to the integrator at most twice, then go to Andrew (`wave.js` in the coordinator's workflow scratch). The coordinator still admits the candidate into the integration branch. The integrator both fixes and verifies, so the gate stays independent of it and judges its fix commits too. Quality guards stay per unit: every unit's own tests and at least one broken rule per new test are rerun, captures are opened, and consequential units still get a Fable reviewer. An optional first step, one read-only Opus spec agent per wave, turns each brief into a checkable definition of done, the outputs the writer returns and the premise checks (Andrew: 'dictate the outputs'). The headline metric is how often the first gate fails a unit (Andrew, 2026-09-29), reported by every wave with loops used, escapes and review share. Decision rule, set before any result: after two waves, batching stays if the first gate fails at most 1 unit in 5, escapes are 0 and review share falls at least 20 points below 66%; any escape traced to a batched-review miss returns that unit class to per-lane review, and the result goes to Andrew either way.
     - **Result after two waves (v3w1, v3w2; 5 units merged, 1 stopped on the brief):** the first gate failed 0 of 5; no escapes; smokes 185/185 and 187/187. Review share (integrator plus gate) was 47% of cache writes and 49% of agent-minutes, falling 19 and 18 points, short of the 20-point bar; counting the spec agent as review, 65%. Per merged unit, review cost 133k cache writes and 9.4 agent-minutes against 322k and 35 per lane (59% and 73% lower; with the spec agent, 185k and 11 minutes). Each wave took about 40 minutes of wall time for two or three units. Share barely moved because the writers got cheaper as well.
     - **Andrew's ruling, 2026-09-29:** batching stays the default, and later waves are measured by review cost per merged unit instead of review share. This measure was chosen after seeing the results, not before. The other two guards stay as written: the first gate fails at most 1 unit in 5, and any escape traced to a batched-review miss returns that unit class to per-lane review.
- **Assets and animation: Codex designs, Sonnet builds** (Andrew, 2026-09-28). Codex owns art direction and makes the clear keyframes, three-view reference sheets, painted textures and the visual layout of how each mesh is built and moves. Sonnet agents implement them as Blender CLI recipes, meshes, rigs, poses and Godot wiring. The guardrail is rendered evidence: rear chase-camera stills and recipe checks go through the Opus gate, and Andrew judges the look.
- Nothing is called ready on tests alone. The fun gate (the camper fails, the map matters, the windows are legible) comes before Andrew's play.
- Andrew's design principles and rulings stand: momentum is sacred, quick restart, opt-in layers, readable caps, no reskins, spill-B music, gems never lost.
- Each lead's design names its measures. A system without a measure isn't done.
