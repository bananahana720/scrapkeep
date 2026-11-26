# Scrapkeep alpha design

The game in one line (Andrew, 9 November 2026, ruling cj): A crew of loose cannons, bulls in the Foreman's china shop, take their world back from a machine that believes life can be run perfectly. The story facts and what each system means are in the [Story map](STORY-MAP.md); this page owns how the game plays.

Current gameplay design after checkpoint 1, as of base `981214373fecdad3c53be83b242993b62a1aa5ef`.
Refresh: written against base `981214373fecdad3c53be83b242993b62a1aa5ef` before wave 3 landed. Wave 3 added the boss contract, the alpha table, the entrance document, the rarity ladder, the companion model, the guard-rack burst, hero asset guards, wind-up rows, lore rows, Spillway zone 1-1 and the nightly runner.
Playtest entry 12 (`docs/playtests/PLAYTEST-LOG.md#12-checkpoint-1-the-cable-reach-first-human-play`, archived in git history) and EV-0624 record the verdict.
[Decision trail](../../../docs/decisions.tsv) row numbers below are physical file lines, including its header.
The later 4 October UTC rulings win over the 3 October plans' pending-sitting text.
[ALPHA-PLAN](ALPHA-PLAN.md) refinements at lines 63–72 win over its historical unit tables.
The [Bible](../../../BIBLE.md) owns the shared identity; this document states the alpha's current gameplay.
The [contracts](../CONTRACTS.md) own module interfaces; [design notes](../DESIGN-NOTES.md) record implementation choices.

## What the game is in five lines

Scrapkeep is a solo action roguelite with action-RPG combat in open zones.
The pilot stays inside a rolling scrap ball with a protected, readable cockpit.
Momentum, rebounds and the harpoon turn terrain into movement and attacks.
Scrap, chosen upgrades and found equipment build combat power during each run.
Exploration, readable machinery and surprising combinations give the next run a reason to exist.

## The run shape

Every run starts in Spillway Works, continues through the Dig, and ends in the Highdraft.
Each world has two big zones, two Wardens and one world boss.
The world bosses are Brindle, the Waking and the Mind.
The Mind ends the run.
A winning run targets 30 to 45 minutes; a longer sitting can include several runs.
The camp is between runs only.
A zone's workshop intermission is distinct from the camp.
There is no free retry (DECISIONS, 22 Oct). A death ends the run and starts a new one at world 1, unless the player holds the rare earned Spare Frame, which once per run leaves a killing hit at 20% hull.
Quit or crash during an unfinished zone replays its saved entrance free.
Stable offers and seed choices survive reload.
A spent Spare Frame, terminal outcomes and settled permanent rewards cannot roll back.
Transient zone acquisitions rewind to the entrance snapshot.
These are the target rules in decision rows 173 and 176 and [ALPHA-PLAN's run rulings](ALPHA-PLAN.md#rulings-andrew-2026-10-01).
Durable run continuity remains planned at this base.

## The ball and its nine verbs

Rigid-body rolling is the movement baseline.
Growth changes the visible shell and punch, while ordinary collision size and handling stay fixed.
A hot-wired part may carry an explicit handling tradeoff.
[Bindings](../src/core/bindings.gd) is the single table for these nine verbs.
Prompts and keycaps read the active bindings and last input device.

| Verb | Keyboard or mouse | Gamepad | Meaning |
| --- | --- | --- | --- |
| Roll | W A S D or arrows | Left stick | Drive the ball. |
| Look | Mouse | Right stick | Aim and turn the camera. |
| Jump | Space | A | Jump, double jump, or mounted slingshot. |
| Fire | Left mouse | Right trigger | Use the pilot's repeatable weapon. |
| Harpoon | Right mouse | Left trigger | Bite, keep the line, then fling on release. |
| Haul | Ctrl | X | Smash a hooked body or winch a world line. |
| Boost | Shift | B | Use the pilot's go move. |
| Special | F | Left bumper | Use or release the pilot's special. |
| Interact | E | Y | Use a device, mount when available, or dismount. |

Without a line, haul brakes on the ground and slams in the air.
A held body line reels the ball toward its target before haul commits the smash.
State priority is body line, world line, charging, mounted, air, then ground.
The current bindings retain right-mouse charge cancellation; the older cut list is stale.
Pause and restart are separate system actions outside the nine verbs.
P or Escape pauses; holding R starts a new run at world 1 with the same pilot, at the same cost as a death.
Start and right bumper provide their gamepad counterparts.

## The harpoon and the hook chain

Every pilot carries the soft-lock harpoon.
Decision row 180 controls the post-sitting order: chain first, skill-shot window second, later-world enemy answers afterward.
[HOOK-CHAIN](HOOK-CHAIN.md) retains the detailed chain contract and its decided calls.
A chain is a sequence of airborne harpoon bites.
An enemy bite adds one combo link.
A surface bite is a pivot that preserves the chain without raising the combo.
Two consecutive surface pivots without an enemy end it.
Ground contact ends it.
Letting go grants 0.8 seconds of airborne grace to bite again.
A dry fire ends it and costs a 0.6-second harpoon cooldown with a dull tick.
A press during rewind is refused without counting as a miss.
A chained smash pays damage × `1 + 0.3 × (combo − 1)`, capped at combo six and ×2.5.
Combo one keeps the plain smash's damage.
Only the chained enemy receives that multiplier.
The shockwave, bystanders and slam strength keep the plain smash's values.
The payout is damage, never Scrap.
One player chain state feeds the counter, collar rings, sound, log and discovery.
The counter appears from combo two, beside the ability bar.
The collar gains one ring per link up to six.
Bite pitch rises one rung of the pentatonic per link beyond the first and returns to the root on smash.
An ending chain sounds only if it reached combo two.
The run log records chains, best combo and misses, including arena play.
The first combo of three opens the Chain codex discovery.
Combo knock and shake scaling remains a presentation target.
The post-chain bot check allows at most 10% more skipper smash damage per fight.
It requires an explorer best-combo median of at least two across sixteen seeds.
The skill-shot window's timing is undecided; the coordinator proposes it and Andrew judges it in play.
The Dig's drill crew and the Highdraft's line cutter are planned enemy-side answers.

## The posture fight and the boss contract

The accepted Warden fight is posture; Hunt, Duel, drop and laps are historical alternatives.
[Boss posture](../src/combat/boss_posture.gd) owns the pure rule.
Hits fill the bar to 100.
The Warden then staggers for four seconds.
Its health has four chunks.
A lesser contact cracks the open core for a later stagger.
A shattering contact removes one chunk and closes the opening.
Decision rows 106–110 govern eligible contacts, reset behavior, crack timing, quarantine and the historical admission exception.
Rows 111–112 govern glances and the shatter frame.
These rulings take precedence over older health-chip and shred descriptions.
The contact gain for one physics frame is the largest gain, rather than the sum.
The hit that fills posture cannot also shatter in that frame.
The slice overrides the generic rule with plating 110, curve two and `ram_shatters = false`.
Thus its fast ram cracks, while its harpoon smash shatters.
[LEGIBILITY](LEGIBILITY.md#4-the-warden-fight) gives the gain, drain and calibrated fight bands.
Decision rows 140, 143 and 145 own the growth sweep, repeatability and seed-specific comparisons.
The later row 144 wins over row 141: health count uses four ground arcs that mirror the boss plate.
The body still shows opening jaws, posture cracks and a breaking segment.
This is a specific exception to the older no-floor-state-ring rule.
The fight objective changes with the authoritative boss state.
All bosses must show preparation, commitment, vulnerability and recovery through their working parts.
Telegraphs and damage consume the same committed geometry.
Later world bosses are capped at Brindle's phase count.
The M2 posture contract must reach both world-one Wardens and Brindle before it scales to later bosses.
That conversion and its frozen contract tests remain planned.
The Mind's responses must be bounded and telegraphed.

## Activities, signposting and the objective plate

The Cable Reach has an ambush altar, cracked cache and hauler bounty.
They stand from drop-in and have no offer timer.
The altar rewards killing its three enemies, the cache rewards a cruise-speed ram or sufficient slam, and the bounty rewards defeating its brute.
Each pays a part at the completion site and 180 Scrap.
Decision row 181 requires visible direction from drop-in after the sitting exposed their invisibility.
[Objectives](../src/core/objectives.gd) supplies the plate's glyph and words, capped at five words.
[Edge markers](../src/ui/edge_markers.gd) points at offscreen goals and unfinished activity sites.
The Warden is the plate's goal from the drop, with the metres to it; a side site takes the row only while the ball is at one it has started, by its own verb ("Clear the camp", "Break the ambush", "Hold the relay", "Outrun the surge", "Break the bounty hauler"; a drawn pocket by its name). A finished goal is ticked on the plate for 1.6 s before the next one shows (10 Nov 2026; before that the row named the site ahead on the ball's way, and on the film's bot it changed six times on the dam road with nothing done).
During the fight it says "Break its guard" or "Smash the core". A mounted reactor Warden and each of Brindle's phases have one row for the whole loop ("Ride the water sheet up", "Latch on, shoot, smash core", "Shoot magnets, then cockpit", "Slam caps, then cockpit", "Bait into walls, then cockpit", "Ram the Admiral's scooter"), and the thing the next move is on wears brackets and a tag. [LEGIBILITY](LEGIBILITY.md), the objective line, owns these rules.
"Grow, then return" requires ten seconds of sustained trying without reaching half posture.
After the break it says "Roll through a gate".
Activity markers hide during engagement and disappear when their site is done.
Their amber comes from the activity row.
The intended site-specific marker shape is still owed.
[LEGIBILITY](LEGIBILITY.md#1-the-rule) supplies the shared colour and cause grammar.
Mint means the player's verb works now; amber means an offer or payment.
Slate means not yet; rust means loss; hazard stripes mean damage is coming.
Mechanics show their cause on the acted-on object and their effect there when it lands.
Synergy callouts show two cause glyphs, an arrow and an effect glyph.
First-use cards wait for calm; repeat synergies draw no discovery banner under decision row 133.
The HUD retains health, armour, speed, ability bar, objective and key prompts.
Fight text stays within 25 words; calm screens within 40.
The slice's six enemy kinds have distinct silhouettes and wind-ups.
The full alpha adds combat challenges, contraption puzzles, secrets and character quests.

## Progression

One binary tree belongs to each pilot.
Four connected picks select a route through thirty nodes to sixteen endpoints.
Growth opens picks at safe moments, rather than on elapsed time.
World one caps depth at two; the Dig and Highdraft open depths three and four.
Decision row 175 and the 3 October refinements win over the Bible's historical four-tree scheme.
Path is the pilot's chosen kit route.
Relics rewrite a slot and come from map discoveries.
Parts stack compatible tags into synergies and evolutions.
Common, Rare, Relic and Evolved are the target rarity labels.
The hot-wired stripe marks an explicit tradeoff across that ladder.
Scalar-only effects belong in Common.
Evolution must change the preferred route, target order or action sequence.
Pinball Hull and Meteor Frame are the initial evolution set in [STRATEGY-SPINE](STRATEGY-SPINE.md#7-minimum-build-order-and-exact-files).
Its older Rare-plus vocabulary is superseded by the 3 October refinement.
Scrap supplies size and temporary armour.
Cogs are the spend currency.
Cores stay zone-local and reset on entry to the next zone.
The slice currently cuts bonus-core activities; their full-alpha reward role is undecided until the coordinator settles rewards.
No permanent combat-stat boosts survive a run.
Discoveries, learned recipes and earned options persist as knowledge and unlocks.
Prices, Cog drop rates and final reward pacing are undecided; the coordinator tunes them before rewards freeze and Andrew judges play.
Reloads cannot award another pick for a rewarded growth step.

| Required pilot | Alpha unlock | Kit direction |
| --- | --- | --- |
| Sable | Initially available | Winch, vault and pylon movement. |
| Rivet | World-one rescue | Sprint, gun and force. |
| Tarn | Defeat Brindle | Articulated claw melee. |
| Kest | Dig rescue | Payloads, glide and demolition. |
| Tally | Return three ledger leaves to Moss, one from each world across runs | Gather, Link and Balance Due cards. |
| Remembered cannon | Defeat the Mind | Boss-mirror cannon with lane, split-lane, rush and plate families. |

Decision row 174 and [ROADMAP's unlock table](ROADMAP.md#content-and-progression) own the required roster.
Newly earned pilots become selectable next run.
Existing earned profile unlocks survive migration.
At this base Sable, Rivet and Kest are all starters until their unlock achievements exist.

### Tally's program cards

A program card is a fixed program in one of three reader bays under the weapon slot, not a slot, part or item.
Three starting cards ship in fixed bays, keeping the [Bible's](../../../BIBLE.md#4-characters) selection with 1, 2 and 3.
In play only, those keys or D-pad left, up and right select a bay instantly and free, and LMB/RT runs it at the aim point.
Selecting never refills pressure or cancels an effect, and bay 1 starts selected.
Pressure is three shared charges that start full; a run costs one, and invalid aim costs none.
Rolling at speed tier 1 or above restores one every 2 s; each distinct ram, stomp, slam or harpoon smash restores one, up to 3; standing restores none.
Shared fire recovery is 0.4 s, and a dry reader leaves movement, boost and the harpoon usable.
Numbers are tuning-owned probe values from the approved kit sheet, PLAYTEST-LOG entry 11.

| Bay/key | Card | Effect | Cost |
| --- | --- | --- | --- |
| 1 | Gather | Plate within 30 m pulls ordinary enemies within 4 m for 4 s; never the player or a Warden; no damage. | 1 charge; one plate |
| 2 | Link | Clips the first enemy hit within 30 m and two neighbours within 9 m for 4 s; the next direct hit arcs once to each other clip, then the group is spent. | 1 charge; one group |
| 3 | Balance Due | Capacitor within 30 m discharges once in a 3 m radius; punch scales with launch speed at release; clips carry it. | 1 charge |

| Slot | Ability id | Key | Rule |
| --- | --- | --- | --- |
| weapon | `ledger_reader` | LMB/RT | Routes to `gather_plate`, `link_clips` or `balance_due`. |
| movement | `flywheel_surge` | Shift/B | Rearward steam surge along travel; 4 s; no pressure. |
| special | `plate_return` | F/LB | Recalls the plate along an 8 m aimed corridor, nudging gathered enemies; 6 s; no plate means no spend. |
| smash | `stamp_slam` | Ctrl/X, air, no line | Flavour "stamp"; each accepted contact restores one charge; line smash and winch win. |

The pilot id is "tally" ([class rows](../src/core/class_def.gd), [slots](../src/core/ability_state.gd)).
Programs grant no synergy tags; real events do.
Every program effect and `plate_return` is noncontact forever: it fills Warden guard and never damages the open core.
Only a ram at speed tier 2 or above, or a harpoon smash, breaks a chunk, so standing off cannot win.
Beating world N's boss finds ledger leaf N, with no pickup; the profile keeps it across runs.
On the next entry to Moss's shop, Moss takes every carried leaf with a ledger line.
Each returned leaf emits the existing `world_fact` signal once, kind "ledger_returned"; no bus signal is added.
The [achievement](../src/core/achievements.gd) row `ledger_balanced` ("Ledger Balanced", count 3, reward pilot "tally") unlocks Tally next run; a world returns once, so three means three worlds.
Card finds, swaps and tags, full transmog and tree names below depth 2 are deferred.

DECISIONS (veto list, 2026-10-05):
- D1 Program card means a kit card; ledger leaf means only the unlock item.
- D2 Fixed cards: 1 Gather, 2 Link, 3 Balance Due.
- D3 Selection as above.
- D4 Pressure as above.
- D5 Card effects at kit-sheet probe values.
- D6 Slot ids as above.
- D7 Channels per STRATEGY-SPINE §2.
- D8 Program effects stay noncontact against Wardens.
- D9 A boss win finds that world's leaf, without pickup.
- D10 Moss's shop takes the leaves; `ledger_balanced` counts three.
- D11 Alpha transmog: the selected card stands raised, the others flat.
- D12 Mulberry #906681 is cloth only; mint is ready; slate is a failed press; orange-red is threat.
- D13 Corner Plate, Line Feed, Spring Vent and Through Feed sit at tree depth 2.
- D14 (worker) Bay keys do nothing while the field-notes key is held; its pages use the D-pad.
- D15 (worker) Balance Due shows its 3 m footprint in neutral sand before release.

## The SPIL-9 companion

One SPIL-9 hover chassis has two unordered module sockets.
Run loot supplies the chassis and modules.
Acquiring a piece does not equip it automatically.
Assemble or reconfigure at intermission using any two different families.
The three families are conductive primer, ram brace and escape corridor.
They provide priming, brief defensive support and clutch escape.
Escape acts after a survived low-hull hit.
It never revives, spends a retry or refills one.
No new combat key or companion health economy is added.
Body gestures and chirps show ready and spent states.
Companion effects cannot trigger recursive procs.
The camp pet is separate.
Decision row 177 and [ALPHA-PLAN's companion refinement](ALPHA-PLAN.md#current-alpha-refinements-3-october-2026) control this planned system.
Module numbers and recovery timing are undecided; the coordinator authors them and Andrew judges usefulness in play.

## The camp

Reuse the approved layout for a small walkable camp between runs.
Its required stations are the launch gate, pilot lockers, Moss, achievements and settings.
It includes one skee-ball lane, a pet with toys, time-trial ghost and medals, and an any-enemy sandbox.
Target rolling from entry to launch within five seconds, or using a shortcut within two.
Interim menus must support unlocks, ledger returns and companion assembly before the full camp exists.
A rescue site or workshop within a zone is not this between-run camp.
The 3 October refinement wins over M2's older "one camp per zone" line.
Additional lounge games and decorative expansion are optional.

## World and story

Reuse the approved Arizona landform keyframes, enemy read sheets and terrain probes.
Spillway Works combines sandstone water corridors, rollable slopes and authored rock landmarks.
The rebuilt Spillway absorbs the Weir's halfpipe, mesa and causeway; the Cable Reach is its second zone.
The Dig is underground, with Breach opening marked floors and walls through slams.
The Highdraft is a floating flotilla, with Lift connecting thermals, moving islands and harpoon swings.
A Highdraft fall lands on a net deck instead of killing the pilot.
The later-zone names and exact layouts are undecided; the coordinator authors them within these world mechanics.
Enemy homes are breakable side goals.
Breaking one stops that kind's stage arrivals and pays Scrap.
Short, skippable Moss and crew exchanges, field notes and item text carry story.
The ancient catastrophe stays ambiguous.
Settlements, maintained paths and repaired tools show people still working in the world.
The [Bible's world section](../../../BIBLE.md#2-world--lore) supplies that identity without fixing a single catastrophe explanation.

## Look and audio targets

Approved Sol concept keyframes are the look bar, superseding older stills under the 3 October refinement.
Concept layouts and painted HUD details do not invent gameplay rules.
Reuse rigs, recipes, terrain work and accepted music gems.
Each enemy's silhouette and wind-up must explain its mechanic from the chase camera.
Shared rock strata and simple collision follow the latest terrain rulings in decision rows 163 and 168.
[FEEL-READABILITY](FEEL-READABILITY.md) supplies the retained momentum, threat priority and comfort constraints.
Threat edges, the ball and committed targeting stay readable through cosmetic effects.
Damage taken never shakes the camera.
One impact table and one hit-stop budget coordinate feedback without changing ball velocity.
ACE performs the music; synth composes guides and keyed sound effects.
Runtime controls dynamics, stem gains, transitions and the response to gameplay.
The later full-ACE decision in [ROADMAP](ROADMAP.md#waves-to-the-final-draft-set-2026-09-28) wins over [AUDIO-V3](AUDIO-V3.md)'s hybrid-bed proposal.
Keep the jazzy EDM drive, character motifs, musical payoffs and accepted gems.
Danger cues answer immediately and outrank celebration.
Stage and boss rows select music under decision row 169.
The target is 60 FPS at 1080p on a mid-range PC.
The dev-box proxy limits are CPU main-thread p99 10 ms, GPU p99 7 ms and frame p99 16.7 ms.
These proxy budgets are targets, not a hardware-support claim.
Quiet-GPU native traversal, dense combat and boss runs measure performance.
Andrew's play and listening settle look, feel and audio acceptance.
Checkpoint 1's choppiness occurred during concurrent GPU work and does not qualify performance.

## The test method in ten lines

1. Lint checks source contracts before the executable gate.
2. Pure unit and table cases validate rules, references and reachable content in one process.
3. Writers run only the named tests nearest their assigned change.
4. New tests name their rule and show a broken-rule mutant red, then the restored rule green.
5. Tests step frames or simulation time instead of reading the wall clock.
6. The integrator runs one full smoke per combined wave through `sketch:gate`.
7. Runner receipts bind the tree, results, check counts, skips, asset presence and timings.
8. Repeatable bots, restart sweeps and calibrated bands retain every numerical threshold and establish bounded automatic evidence.
9. Native captures and quiet-GPU performance runs establish presentation and timing evidence.
10. Andrew's play and listening remain the acceptance verdict; [TESTING](TESTING.md) retains measurements and decision row 178 controls calibration.

## What is built versus planned at the wave 11 candidate (047c51c)

This is a source and record inventory, not a fresh runtime or performance qualification.
[Lane ledger](../tools/coordinator/lane-ledger.tsv) records integrated units and their historical checks.
[ALPHA-PLAN's milestones](ALPHA-PLAN.md#program-shape) define completion beyond those units.
Decision row 179 and playtest entry 12 supersede both plans' pending-checkpoint wording.
Andrew accepted the hooking, slam, enemy reads and refined boss fight in the Cable Reach sitting.
He requested a fuller three-world game after rating difficulty 2/5, pacing 3/5 and clarity 4/5.
That verdict does not accept the later chain changes or complete the alpha.

| Area | Built or integrated at this base | Planned or still owed |
| --- | --- | --- |
| Click slice, M1 | One Cable Reach zone, posture Warden, twelve offered parts, five synergies, three standing activities; checkpoint 1 accepted by Andrew. | Harder and longer campaign; renewed performance measurement on a quiet GPU. |
| Hook chain | Ledger HC1, HC2 and HC3: state, damage payout, miss cooldown, counter, collar, sound, log and Chain discovery integrated. | Live-contact payout evidence, post-chain bot bands, combo-four still, shared-clock digit pulse and combo knock/shake feel. |
| Signposting and prompts | Ledger AS: unfinished-site markers and activity-first plate; RL: prompt rising-edge logging. | Site-specific marker shape, rendered marker evidence and a real-run prompt-count check. |
| World structure | Three worlds, six named zones: [alpha table rows 1 to 6](../src/core/alpha_defs.gd) (`spillway`, `reach`, `dig`, `dig_deep`, `highdraft`, `highdraft_crown`), [boss rows](../src/core/worlds.gd) for Brindle, the Waking and the Mind (all `built`), lazy terrain and music routing. See CONTRACTS for the per-boss modules, breach plates, net deck and row-level packs. | Hand play of worlds two and three; dressing beyond greybox; final audio by ear. |
| Worlds, M2 | World one is Spillway and the Cable Reach with Brindle on the posture rule; world two is the Dig and the deep Dig with the Waking over three floors; world three is Highdraft and its crown with the Mind. Relic caches sit on the world-two and world-three maps (`relic_spot`). | Andrew's play through all three worlds to RUN COMPLETE. |
| Pilots and growth | [Pilot rows](../src/core/class_def.gd) expose three playable starters; tree machinery, armour, parts and synergies exist; six relics per world with one relic cache on each world-2 and world-3 map (wave 11). | Tarn, Tally and cannon probes/full kits; unlock sequence; depth/content completion; evolutions and rarity migration. |
| Economy and persistence | [Run state](../src/core/run_state.gd) snapshots and a [run store](../src/core/run_store.gd) that resumes at worlds two and three; profile and settings stores exist. | Hand check of resume and restart across the three worlds; a kept copy of a replaced run (wave 12). |
| Input and assets | Rebinding, settings pages, gamepad menu handling and asset budgets are integrated. | Physical controller acceptance, remaining glyph surfaces and campaign asset production. |
| Companion and camp, M4 | Supporting profile/menu infrastructure exists. | SPIL-9 assembly/combat, full camp, recreation, ghost/medals and sandbox. |
| Presentation and export | Existing models, rigs, wind-ups, ACE routing and a Linux export recipe exist; boss music sections, a world-entry stinger and final world 2 and 3 lore rows landed in wave 11. | Dressed Dig/Highdraft, ending, complete bundled package and cold-launch full-run acceptance. |

The full [stage table](../src/core/stage_defs.gd) still lists three world-one stages with plating fights.
The [slice table](../src/core/slice_defs.gd) is the one-zone posture proof.
The catalogue still contains `uncommon` and `rare_plus`; the wallet still uses `scrap`.
These compatibility remnants do not change the current target design.
Finish world one alongside new-kit probes, settle persistence and companion before rewards freeze, then build later-world greybox, dress worlds and camp, and cold-export.
No overall completion percentage or delivery date is established.

## Disposition of every file in design-v3

This inventory includes subdirectories, hidden files and this document.
"Current spec, kept" preserves the gameplay summary or its program, detailed contract and measurement references.
"Superseded by this document, to archive" retires design authority while preserving historical sources and evidence.
The coordinator's later archive unit performs the moves and repairs incoming links.

| File | Disposition | Reason |
| --- | --- | --- |
| [ALPHA-PLAN.md](ALPHA-PLAN.md) | current spec, kept | Authorized scope and milestone definitions remain the program reference. |
| [AUDIO-V3.md](AUDIO-V3.md) | superseded by this document, to archive | Hybrid and deleted-loop proposals lose to the later ACE decision. |
| [DESIGN-V3.md](DESIGN-V3.md) | current spec, kept | Single current gameplay design after the sitting. |
| [E1-DENSITY.md](E1-DENSITY.md) | superseded by this document, to archive | Historical optimization evidence remains preserved. |
| [FEEL-READABILITY.md](FEEL-READABILITY.md) | superseded by this document, to archive | Retained constraints are summarized; old HUD and loop proposals are historical. |
| `HANDOFF.md` (archived in git history) | superseded by this document, to archive | Old handoff status is replaced by the base-bound inventory above and [STATE.md](../../../project-guide/handoff/STATE.md). |
| [HOOK-CHAIN.md](HOOK-CHAIN.md) | current spec, kept | Detailed chain contract retains decided calls and unfinished acceptance work. |
| [LEGIBILITY.md](LEGIBILITY.md) | superseded by this document, to archive | Accepted grammar is consolidated with later rulings and the sitting verdict. |
| [LOOP-REDESIGN.md](LOOP-REDESIGN.md) | superseded by this document, to archive | Drop and laps alternatives were retired. |
| `OWNER-INTERVIEW-2026-10-02.md` (archived in git history) | superseded by this document, to archive | Accepted answers now live in the current run, camp and progression rules. |
| [ROADMAP.md](ROADMAP.md) | current spec, kept | Completion checkpoints and required unlock sequence remain useful. |
| `archive/STAGES-2-3-LOOPS.md` (archived in git history) | superseded by this document, to archive | Historical world-one loop layouts do not define the three-world alpha. |
| [STRATEGY-SPINE.md](STRATEGY-SPINE.md) | superseded by this document, to archive | Retained build relationships are consolidated; old rarity labels are superseded. |
| `archive/STRESS-CAPTURE-1.md` (archived in git history) | superseded by this document, to archive | Historical stress evidence is preserved without claiming current performance. |
| `archive/SYSTEMS-CHAOS.md` (archived in git history) | superseded by this document, to archive | Older systems proposals no longer provide independent alpha scope. |
| [TESTING.md](TESTING.md) | current spec, kept | Historical runner measurements explain the current test method. |
| [TRAVERSAL.md](TRAVERSAL.md) | superseded by this document, to archive | Historical line measurements remain evidence, not a second design. |
| `research/CODEX-REVIEW-1.md` (archived in git history) | superseded by this document, to archive | Historical research informs the consolidated rules; it grants no scope. |
| `research/CODEX-REVIEW-2-systems.md` (archived in git history) | superseded by this document, to archive | Historical research informs the consolidated rules; it grants no scope. |
| `archive/research/PURPOSE-AUDIT-1.md` (archived in git history) | superseded by this document, to archive | Historical research informs the consolidated rules; it grants no scope. |
| `archive/research/R1-why-stay-and-windows.md` (archived in git history) | superseded by this document, to archive | Historical research informs the consolidated rules; it grants no scope. |
| `archive/research/R2-five-games-replay-juice.md` (archived in git history) | superseded by this document, to archive | Historical research informs the consolidated rules; it grants no scope. |
| `archive/research/R3-adaptive-music.md` (archived in git history) | superseded by this document, to archive | Historical research informs the consolidated rules; it grants no scope. |
| `archive/research/R3-tools-and-expertise.md` (archived in git history) | superseded by this document, to archive | Historical research informs the consolidated rules; it grants no scope. |
| [research/attack-reads/ATTACK-READS.md](research/attack-reads/ATTACK-READS.md) | superseded by this document, to archive | Historical research informs the consolidated rules; it grants no scope. |
| [research/build-systems/BUILD-SYSTEMS.md](research/build-systems/BUILD-SYSTEMS.md) | superseded by this document, to archive | Historical research informs the consolidated rules; it grants no scope. |
| `archive/research/economy/ECONOMY.md` (archived in git history) | superseded by this document, to archive | Historical research informs the consolidated rules; it grants no scope. |
| `archive/stages/stage2.svg` (archived in git history) | superseded by this document, to archive | Diagram of the retired world-one loop layout. |
| `archive/stages/stage3.svg` (archived in git history) | superseded by this document, to archive | Diagram of the retired world-one loop layout. |
| [storyboards/.gitignore](storyboards/.gitignore) | superseded by this document, to archive | Archive it with the historical storyboard package rules. |
| [storyboards/CRITIQUE.md](storyboards/CRITIQUE.md) | superseded by this document, to archive | Historical storyboard guidance or review evidence stays with its package. |
| [storyboards/HANDOFF.md](storyboards/HANDOFF.md) | superseded by this document, to archive | Historical storyboard guidance or review evidence stays with its package. |
| [storyboards/PROP-APPEARANCE.md](storyboards/PROP-APPEARANCE.md) | superseded by this document, to archive | Historical storyboard guidance or review evidence stays with its package. |
| [storyboards/VIEWED-IMAGES.md](storyboards/VIEWED-IMAGES.md) | superseded by this document, to archive | Historical storyboard guidance or review evidence stays with its package. |
| [storyboards/build_package.py](storyboards/build_package.py) | superseded by this document, to archive | Historical storyboard packaging tool, preserved with its package. |
| [storyboards/catalog.json](storyboards/catalog.json) | superseded by this document, to archive | Historical storyboard inventory and provenance remain with the package. |
| [storyboards/index.html](storyboards/index.html) | superseded by this document, to archive | Older concept review page is superseded by the approved Sol look bar. |
| [storyboards/manifest.json](storyboards/manifest.json) | superseded by this document, to archive | Historical storyboard inventory and provenance remain with the package. |
| `storyboards/prompts/01-entry-v1.txt` (pruned provenance entry) | superseded by this document, to archive | Historical image prompt preserves provenance for an older concept round. |
| `storyboards/prompts/01-entry-v2.txt` (pruned provenance entry) | superseded by this document, to archive | Historical image prompt preserves provenance for an older concept round. |
| `storyboards/prompts/02-chute-v1.txt` (pruned provenance entry) | superseded by this document, to archive | Historical image prompt preserves provenance for an older concept round. |
| `storyboards/prompts/03-window-v1.txt` (pruned provenance entry) | superseded by this document, to archive | Historical image prompt preserves provenance for an older concept round. |
| `storyboards/prompts/03-window-v2.txt` (pruned provenance entry) | superseded by this document, to archive | Historical image prompt preserves provenance for an older concept round. |
| `storyboards/prompts/04-impact-v1.txt` (pruned provenance entry) | superseded by this document, to archive | Historical image prompt preserves provenance for an older concept round. |
| `storyboards/prompts/04-impact-v2.txt` (pruned provenance entry) | superseded by this document, to archive | Historical image prompt preserves provenance for an older concept round. |
| `storyboards/prompts/04-impact-v3.txt` (pruned provenance entry) | superseded by this document, to archive | Historical image prompt preserves provenance for an older concept round. |
| `storyboards/prompts/05-return-v1.txt` (pruned provenance entry) | superseded by this document, to archive | Historical image prompt preserves provenance for an older concept round. |
| `storyboards/prompts/05-return-v2.txt` (pruned provenance entry) | superseded by this document, to archive | Historical image prompt preserves provenance for an older concept round. |
| `storyboards/prompts/05-return-v3.txt` (pruned provenance entry) | superseded by this document, to archive | Historical image prompt preserves provenance for an older concept round. |
| `storyboards/prompts/06-choice-v1.txt` (pruned provenance entry) | superseded by this document, to archive | Historical image prompt preserves provenance for an older concept round. |
| `storyboards/prompts/06-choice-v2.txt` (pruned provenance entry) | superseded by this document, to archive | Historical image prompt preserves provenance for an older concept round. |
| `storyboards/prompts/07-warden-states-v1.txt` (pruned provenance entry) | superseded by this document, to archive | Historical image prompt preserves provenance for an older concept round. |
| `storyboards/prompts/07-warden-states-v2.txt` (pruned provenance entry) | superseded by this document, to archive | Historical image prompt preserves provenance for an older concept round. |
| `storyboards/prompts/08-interactables-v1.txt` (pruned provenance entry) | superseded by this document, to archive | Historical image prompt preserves provenance for an older concept round. |
| `storyboards/prompts/08-interactables-v2.txt` (pruned provenance entry) | superseded by this document, to archive | Historical image prompt preserves provenance for an older concept round. |
| `storyboards/prompts/09-anticipation-v1.txt` (pruned provenance entry) | superseded by this document, to archive | Historical image prompt preserves provenance for an older concept round. |
| `storyboards/prompts/09-anticipation-v2.txt` (pruned provenance entry) | superseded by this document, to archive | Historical image prompt preserves provenance for an older concept round. |
| `storyboards/prompts/10-sable-v1.txt` (pruned provenance entry) | superseded by this document, to archive | Historical image prompt preserves provenance for an older concept round. |
| `storyboards/prompts/11-rivet-v1.txt` (pruned provenance entry) | superseded by this document, to archive | Historical image prompt preserves provenance for an older concept round. |
| `storyboards/prompts/11-rivet-v2.txt` (pruned provenance entry) | superseded by this document, to archive | Historical image prompt preserves provenance for an older concept round. |
| `storyboards/prompts/12-kest-v1.txt` (pruned provenance entry) | superseded by this document, to archive | Historical image prompt preserves provenance for an older concept round. |
| `storyboards/prompts/12-kest-v2.txt` (pruned provenance entry) | superseded by this document, to archive | Historical image prompt preserves provenance for an older concept round. |
| [storyboards/verification/package-checks.json](storyboards/verification/package-checks.json) | superseded by this document, to archive | Historical package check receipt, not current gameplay acceptance. |
