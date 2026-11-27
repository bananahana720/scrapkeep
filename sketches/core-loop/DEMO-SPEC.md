# Core-loop demo spec: gating, growth and engagement

> **Historical / Superseded spec (26 Sep 2026):** Later integration in [CONTRACTS.md](CONTRACTS.md), [design-v3/](design-v3/README.md), and `src/core/alpha_defs.gd` / `park_defs.gd` owns the live three-world alpha rules. Kept as historical baseline.

Status: accepted by Andrew on 2026-09-26 through the /tree keystone and three follow-up questions. The reconciled design panel (three lenses and a reconciler, workflow wf_3df50518-763) is the source. Where the panel and Andrew differed, Andrew's answer wins (cores). This file owns the demo's progression rules. CONTRACTS.md owns the seams.

## Thesis

The demo has one demand and one growth number, and every mechanic feeds one of them.

- **Growth is heft.** Scrap you roll up becomes mass. Parts add more.
  - Spending never lowers mass: a purchase compacts scrap into a part.
  - Only a crane theft removes mass. It is telegraphed, and you can chase it down to get the mass back.
  - Heft never changes handling.
- **The demand is punch against plating.**
  - Punch is the per-hit damage of whatever you do: a ram, stomp or slam hits for heft times its force, and a shot hits for the gun's damage after parts.
  - Every threat that matters has plating. A hit at or above the plating lands in full. A hit below it chips 20%, clanks, and bounces you as it does today.
- **Each stage's beacon is clamped by one Warden**, visible from the 14 m entry drop.
  - The Warden holds the stage's core. Breaking it is the stage's only MUST. The beacon charge shown is how much of the Warden is broken.
  - Events and vaults drop bonus cores. Each one overcharges the beacon, so its reward gates offer higher tiers.
- **As heft grows, fodder that used to bounce you gets rolled up with no speed loss.** That is the Katamari moment.
- **Brindle uses the same grammar with fixed HP.** A grown ball routs him. A ball that beelined through the stages has to earn it through weak points.

The stage reads as a descent in open terrain: see the lock, roll the line, grow, break the lock, launch.

## Andrew's decisions (2026-09-26)

| Question | Recommended | Andrew picked |
| --- | --- | --- |
| Growth currency (tree keystone) | Both, layered: mass and cores | Both, layered |
| How cores work, after the panel warned about checklists | Warden core plus bonus cores | Warden core plus bonus cores |
| Punch below plating | Chip at 20% | Chip at 20% |
| Physical growth | Shell grows, collider stays the same | Shell grows, collider stays the same |

He took the recommended option all four times. The skeptic lens flags this as recommend-first bias (R-22), so the entry-7 playtest also asks the rival questions: was the Warden a chore, and did growth feel like enough growth?

## Rules

- **Heft.** `heft = 1 + mass/450 + 0.2 * parts`, with classes I to V starting at 1.0, 1.5, 2.2, 3.2 and 4.6. The mass divisor was 150 until the wave-3b tuning pass, which moved it to 450 so a skipper leaves stage 3 near heft 3 (DESIGN-NOTES, Feedback loop).
  - Mass is separate from the scrap wallet. `add_scrap` raises both, `spend_scrap` lowers only the wallet, and `lose_scrap` lowers mass.
  - Heft never changes RigidBody mass, radius, torque or air control (TADR-008 line 40).
- **Plating.** Punch at or above plating deals full damage. Below it, the hit deals 20% and emits `strike_deflected`.
  - Plated targets are tinted amber when your `punch_now()` beats their plating, and slate when it doesn't. The tint reads the same function the strike does.
- **Warden.** One per stage, immobile, clamped to the beacon mast.
  - Plating 45 / 80 / 140 and HP 800 / 2200 / 7500 for stages 1 to 3, from the wave-3b tuning pass (7500 since pass 8, with shred) (the starting values were 30 / 60 / 95 and 400 / 700 / 1000).
  - Every 6 s it telegraphs for 2 s, then pulses you straight up by 10 m/s. The pulse never pushes you sideways and never pins you.
  - Each stage adds one lesson: stage 1 is plain plating, stage 2 adds vent caps that stomps and slams go through, and stage 3 adds a magnet that you can shoot to drop its plating to 0 for 3 s.
  - Breaking it fires `beacon_unsealed` and opens the gates, wherever the ball is. There is no presence charge while sealed.
- **Cores (Andrew's layer).**
  - The Warden's core is the required one. Breaking the Warden consumes it straight into the beacon.
  - Winning a participatory event and breaking a vault each grant one bonus core, through `run.add_core(source, at)`, which publishes `core_gained`.
  - Bonus cores are stage-scoped: they are reset at `stage_entered` and held in the stage-start snapshot.
  - At the gates, overcharge sets the offer tier:
    - 0 bonus cores: gate tiers are common or uncommon.
    - 1 bonus core: uncommon or rare.
    - 2 or more: rare or rare-plus.
  - The HUD shows a small core pip row beside the objective.
- **Engagement tiers per stage.**
  - MUST: the Warden.
  - SHOULD: scrap lines and the fabricator on the fall line, the participatory event (a milestone rare-plus part and a bonus core, with a plated miniboss at 1.25 times the Warden's plating), and a plated vault off the line (plating equal to the next Warden's, a rare part and a bonus core).
  - COULD: the secrets that the drained basin reveals.
- **Growth moments.**
  - Crush pass-through: the ram threshold drops to CRUISE, and a crush takes no knock and no hit-stop.
  - The ball stays at 0.95 of its speed or more through a crush.
  - Reaching a new heft class plays a rising three-note stinger on the next beat.
- **Director honesty.**
  - Enemy HP comes from stage threat only.
  - The time tier is clamped at +2 and announced with `threat_rose`.
  - 60% of spawns land ahead of the ball.
- **Layout.** A fall line runs from the high spawn to the low beacon, and the beacon is visible from the drop.
  - The SHOULD content sits within 25 m of the line.
  - The event and the vault sit 40 m or more off it, with a downhill return.
  - The beacon sits on a banked berm.
  - There are at most 3 sky pillars.
- **Objective line.**
  - It reads: `Break the Warden at the beacon (240 m). Punch 48 / plating 60. Slam its vent caps.`
  - The word "optional" is banned. SHOULD targets go in the hold-Tab notes.
- **Brindle.**
  - Fixed HP. The part-count scaling was struck as rubber-banding.
  - Hull plating is 120. Magnets take weapon hits at plating 0, and caps take stomps and slams at plating 0.
  - The phase-3 charge clash needs 150 punch. The eject scooter has plating 0.
  - Crane catches call `lose_scrap(amount, at, "crane")`, and the spill trail pays the mass back.
  - The arena entry shows a readout: hull plating against your punch.
  - The boss death screen adds T, which replays stage 3 from its start.
- **Rejected.**
  - Key or fuse collection gates (R-27).
  - Kill-all gates (R-28).
  - Hit-stop on crushes (R-29).
  - Growing the ball's mass (R-05).
- **Parked until play.** The Hauler, the Brass Klaxon, Keeper affixes, sluice-gate shortcuts, the landing crater, camera pull-back, and the element answer to plating (R-23).

## Synergies: shown, discoverable, and accidental (Andrew, 2026-09-26)

Andrew's words: "I love synergies. I love accidental ones as well as ones that could be explicitly told to the player. Maybe as a form of goal setting and creating some excitement, and it could be discoverable as well. So they won't. They can be shown to exist, and maybe can make some coherent sense for the player to be willing to experiment and try to combine things."

- **Coherent through tags.** Every part carries 1-2 tags from one small vocabulary:
  - frost, arc, kinetic
  - split, spiral, chain
  - anchor, speed, mass

  Synergies are built from tag pairs, so combining things makes sense before you try it.
- **Named synergies are shown to exist.** There are about 8 in the demo. The hold-Tab codex lists all of them as hint cards:
  - An undiscovered card shows one ingredient's icon, plus a clue built from the other ingredient's tag (for example, "Chain Arc + something that splits").
  - A discovered card shows both parts and what the synergy does.
  - Reward gates and fabricators mark an offer that would complete a synergy ("* completes Storm Lattice *"), or one that is a known ingredient ("* ingredient: ??? *").
- **Discovery is a moment.** The first time a named synergy activates:
  - `synergy_discovered(id)` fires on the bus.
  - A critical stinger lands on the beat, a banner appears, and a ring is added to the ball.
  - The codex entry is saved across runs to `user://codex.json`. This is the demo's only meta-progression.
- **Accidental synergies come from the systems.** The element table and tag rules resolve unnamed combinations. Examples:
  - frost followed by kinetic shatters
  - arc on water electrifies
  - a spiral carrying chain links its arcs

  The first time an unnamed interaction fires, it is logged to the codex's "Found" list as a plain description, with no name.
- **Balance and clarity.** Principle 4's visual caps apply to every synergy effect. A synergy changes behaviour, never just a percentage.

### The codex as a treasure hunt (Andrew, 2026-09-26)

Andrew's words: "a different layer of treasure hunt where um, it allows the player to engage with the world, engage with the enemies or uh, NPCs or if it ends up being multiplayer, multiplayer combinations that uh, kind of add and also track for um, logging ... both yeah, developmental feature, but then also yeah, something that is exposed to the players ... in a friendly UI and and well-designed manner."

- **Categories.** Every codex entry has one category: `build` (part synergies), `world` (terrain and element tricks), `enemy` (enemy interactions), or the reserved `npc` and `coop`. The demo is solo and offline (TADR-004), but each entry carries a `participants` list, so co-op entries fit the same schema later.
- **One registry, one owner per category.** Each owner declares its entries (id, category, name, hint, clue, text) through `ctx.codex.declare(entry)` at setup and fires discovery through the codex mutators. Owners by category:
  - B owns `build`.
  - A owns `enemy`. Examples: a deflected lobber shell kills its own lobber, a frozen chaser shatters on a ram, and a turret kill during a slingshot.
  - D owns `world`. Examples: luring enemies into electrified flood water, riding a surge through a gate at blazing speed, and bouncing a Warden pulse into a stomp.
- **The treasure payoff.** The first discovery in a run bursts scrap at the spot (20 x stage). That feeds heft, so exploring feeds growth.
- **Player UI.** The hold-Tab codex page gets category tabs, hint cards and a completion percentage per category. Discovered cards show what was combined and when. The page is designed rather than just listed: each category has its own colour and icon from `event_kinds`.
- **Developer log.** Every discovery and every found interaction appends one line to `user://codex-log.ndjson`, recording `run_id`, stage, stage time in ticks, category, id, `participants`, the build's part ids and heft. The same data feeds the UI and the log, so the two cannot disagree.

## Music: level themes and boss tiers (Andrew, 2026-09-26)

Andrew's words, after hearing the band preview: "the audio is amazing. I just would want something that's like ... intense, like, climactic and and dramatic uh music for like maybe something catered to the mini bosses something catered to the uh main level bosses and then something catered to the final boss and each of these kind of like obviously take sound influences and patterns that were done from the the level ... themes that are level based so they all have like either both like instrumental and rhythmic and and melodic patterns ... And then the final boss will have his own set of everything ... epic and um, kind of like, like dance floor-esque ... Euro club ... electro dance hall music ... funky and, but it's yeah, it has that jazzy feel. And yeah, it's like thumping."

- **Level themes.** Each stage owns a palette, a groove and a motif. They share one harmonic language, jazzy extended chords.
  - Spillway: D Dorian, electric piano, and a flowing arpeggio motif. This is the current band.
  - Sluice: clavinet funk riff, brass stabs, and a mechanical syncopated groove.
  - Weir: organ, a talkbox-style lead, and a halfpipe call-and-response.
- **Boss tiers borrow from their level.**
  - Miniboss: the level motif in an intense variation, with a minor reharmonisation, a denser top and a riser into each attack.
  - Warden, the level boss: the level theme rebuilt as a thumping four-on-the-floor Euro-club and electro-house arrangement, with funk bass, sidechain pump and filtered jazzy chord stabs. `beacon_unsealed` hits the drop.
  - Brindle has his own full set: brass fanfare, anvil and industrial percussion, and a dramatic mode.
    - Phase 1 (the magnet) quotes Weir's motif, phase 2 (the caps) quotes Sluice's, and phase 3 (the charge) quotes Spillway's.
    - The music replays the run in reverse, because each stage taught one of his phases. The victory resolves home.
- **Transitions.** Moving from exploration to a boss is a metric modulation: a half-note triplet at 172 becomes the quarter note at 129. The alternative, four-on-the-floor held at 172, is rendered too, so Andrew can pick by ear.
- **Triggers.**
  - The miniboss track starts on `enemy_spawned` with kind `miniboss`.
  - The Warden track starts on `warden_engaged(stage)`, which the spine publishes the first time the ball enters the sealed beacon ring or lands a hit on the Warden.
  - Brindle's tracks follow `boss_arena_entered` and `boss_phase_changed` (wave 4).
  - Each boss track returns to the level theme on the kill, through a cadence.

## Design feedback loop (Andrew, 2026-09-26)

Andrew's words: "details and connections that are plotted out and though it could be hard to manage and may lead to like let's say balancing issues ... that could kind of be fed into a sort of feedback loop to make sure things integrate in a well-designed manner ... where the game designs kind of clicks and feels like there's engagement with purpose."

1. **Run log.** At run end or death, the spine appends one record to `user://runs.ndjson`. It holds:
   - `run_id`, class and the outcome
   - per stage: ticks to Warden break, heft at exit, parts at exit, bonus cores, deaths (with position), and events joined and won
   - the codex ids discovered this run
   - the Brindle phase reached

   The codex log (above) shares the `run_id`.
2. **Bot runs.** Scripted demo runs in headless mode, driven the way `sketches/ball-lab`'s lab drives its arms, produce logs in bulk before Andrew plays. They cover three policies: a skipper, a completionist and a random driver.
3. **Balance report.** `tools/balance_report` reads both logs and prints per-stage bands. It flags:
   - Warden break time outside 10 to 90 s
   - heft at stage exit outside the curve from `build_power_curve_test`
   - a synergy found in more than 60% of runs, or in none
   - a codex entry never discovered
   - a death cluster at one position

   It writes `artifacts/local/balance-<date>.md`. It reports and never tunes: tuning stays a human-approved edit to `stage_defs`, the heft constants or the catalogue.
4. **Coherence check.** A test fails the build when:
   - a part has no tag or verb
   - a codex entry has no owner, clue or category
   - an event kind has no sound
   - a mechanic's DESIGN-NOTES line names no stage demand
5. **The loop.** Bots run, the report flags, tuning is edited, bots run again, then Andrew plays and his verdict becomes a playtest entry. The report is rerun after every tuning pass.

## Biases the panel named, and their counters

- **Consensus from a shared brief.** Counter: relationship tests. A run that only sits in the beacon ring cannot clear, and a power-curve test checks the build bands.
- **Recommend-first.** Counter: log each decision, and put the rival questions to Andrew in the entry-7 playtest.
- **Supply-side scope creep.** Counter: add a demand-first rule to CONTRACTS.
- **Test-passing equals fun.** Counter: a green run is never reported as feel.
- **False precision in the numbers.** Counter: every number here is a starting value. Tuning edits only `stage_defs`, the heft constants and the part catalogue.

## Change requests

The per-owner list, with acceptance tests, is in the reconciler output (`reconciled.json`, `change_requests`). Beyond that list, cores add:

- **Spine.** `run.add_core`, `bonus_cores`, `core_gained(source, at, count)` with its event_kinds row, and the snapshot.
- **B.** The gate tier reads `bonus_cores`. Vault and event rewards also call `add_core`.
- **C.** A core-socket sound and flash.
- **D.** The event win calls `add_core("event", at)`.
