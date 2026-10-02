# Legibility spec for the click slice

This is the build spec for the two waves after A1. It answers playtest entry 10, where Andrew said the Warden fight, the harpoon latch, synergies, map mechanics and enemies all lack a visible "why". It supersedes the matching parts of [ALPHA-PLAN.md](ALPHA-PLAN.md) section M1 where they differ; the differences are listed under "Changes to the plan".

**How it was made.** Six read-only audits (enemies, world events, build systems, controls and HUD, harpoon and traversal, the Warden) judged what the player can see of each mechanic at `07d5a86`. One design lead wrote a spec from them. Two critics, a player walk-through and a builder check, both failed that draft and named fixes. This file is the draft with those fixes applied. Nothing here has been built or played. Claims about today's code come from the audits and carry their file references in the session's evidence folder (`artifacts/local/alpha/legibility/`).

**Status of every cut.** A cut makes the thing unreachable from the slice. Its code and tests stay on disk until Andrew has played checkpoint 1, so he can veto a cut by saying so. Deletion follows his verdict.

## 1. The rule

A thing shows its cause on the object you act on before you act, and its effect on that same object the instant it lands. Shape, colour, motion and sound carry it first. Words are three or fewer and appear only the first few times.

Every layer reads one row in one table. A mechanic that cannot be given a row with a cue for its cause and a cue for its effect leaves the slice.

### The colour law

One meaning per colour, enforced by a row test.

| Colour | Meaning | Where |
| --- | --- | --- |
| Hazard stripes (`Palette.HAZARD`) | This will hurt you | The floor belongs to it alone, plus the attacker's wind-up |
| Live (`Palette.live()`) | Your verb works on this right now | Hook brackets, the cable, the collar, an open core, a rim that will break |
| Amber (`Palette.AMBER`) | The world is offering or paying | Rides, landing rings, activity beams, rewards, things you now own |
| Slate (`Palette.SLATE`, new) | Not yet | Out of range, a glancing hit, a locked thing |
| Rust (`Palette.RUST`) | You lost something | A forced line break, scrap knocked off, a hull hit |

**The live colour is mint for every pilot in the slice.** The draft used each pilot's class colour. Both critics caught that this cannot hold. Measured colour distance (CIE76) from each class colour to the colours above and to the terrain:

| Pilot colour | Amber | Rust | Hazard | Sandstone | Brass |
| --- | --- | --- | --- | --- | --- |
| Sable, mint `8bf0d3` | 76 | 82 | 111 | 53 | 66 |
| Rivet, copper `b77843` | 23 | 20 | 44 | 20 | 32 |
| Kest, amber `e5a044` | 0 | 42 | 45 | 29 | 16 |

Kest's colour is amber itself, and Rivet's sits 20 from both rust and the sandstone he rolls on. Only mint is clear of the warm world. So the law reads the live colour through one accessor, `Palette.live(class_def)`, which returns mint for all three pilots today. A pilot's class colour stays for identity: the card, the shell, the pilot's own shots. A per-pilot live colour can drop in later through the same accessor. The row test requires every live colour to sit at least 35 from amber, rust, hazard, slate, the ancient blue and sandstone.

## 2. The grammar

Ten situations. Each has one source table.

| Situation | What it shows | Where | Source table |
| --- | --- | --- | --- |
| A verb is available (the press would succeed this tick) | A sand keycap plus the verb's glyph in the live colour. One word rides it until that verb's first success on the profile. At most two prompts at once. | At the thing the verb acts on | `src/core/bindings.gd` `VERBS` |
| A target can be hooked | Live corner brackets close on it and its cap pulses at 2 Hz. Out of range is a hollow slate ring with no sound. | On the target, mirrored by the reticle | `event_kinds.gd` `LINE_ROWS` |
| Something is active on you | A persistent object and a loop sound for as long as it is true: the taut cable and its hum for your line, a hazard binding line and a creak for a hostile hold, flakes and a rasp for wear | On the ball and along the line to the cause | `LINE_ROWS`, `STATE_ROWS` |
| A target is in a state | On the struck part: barb and collar for latched, a live rim and crack for will-break or open, slate for glancing, a flipped pose and star for interrupted. No floor rings. | On the enemy body. On the Warden, repeated once as the plate's state glyph. | `STATE_ROWS` |
| Something fired | A hit: sparks at the contact point sized by what it did. A synergy or map mechanic: two cause glyphs, an arrow, the effect glyph, in the row's own shape with its motif. | At the contact point or on the object. Never in the toast band. | `IMPACT` for hits, `CAUSE_ROWS` for the rest |
| Something failed | Always an answer: a slack line and a dull tick for a dry harpoon, slate sparks and a low clank for a glance, the cable snapping with a rust twang for a forced break. The failed verb's prompt returns for 3 s. | Where the action would have landed | `VERBS` field `fail`, `STATE_ROWS`, `LINE_ROWS` |
| A goal exists | A glyph, five words or fewer, a distance chevron. The same glyph on a world beacon and on the edge marker. | Objective plate, the beacon, the screen edge | `src/core/objectives.gd`, which absorbs `OBJECTIVE_SHORT` and the `objective` strings in `ROWS` |
| A threat is coming | The hazard floor telegraph with fill progress, the wind-up pose on the body, the row's warn sound. Unchanged. | The floor and the attacker | `ATTACK_ROWS`, `THREAT_ROWS` |
| An activity is on offer | A standing amber beam and ground ring from stage start with the family glyph on top. No timer and no toast. Its goal is a gauge on the object itself. | At the site | `ACTIVITY_ROWS` |
| A reward is paid | The part rises from the exact spot the goal completed, the won sound plays, and its glyph flies onto the ball with a two-word name. | The completion spot, then the ball | `LOOT_ROWS` |

**One rule per meaning.** The builder critic found the draft would give one harpoon bite three rows. So: `LINE_ROWS` replaces the `harpoon_bit` and `harpoon_smashed` rows in `ROWS`. `CAUSE_ROWS` is keyed by the ids in `synergies.gd` and holds presentation only; names are read from `synergies.gd`. `STATE_ROWS.held` replaces `hold_started`'s presentation. A test fails when one id has presentation in two tables.

## 3. The harpoon

Two keys for every pilot. Right mouse is the line: press bites, hold keeps it, release flings. Ctrl hauls it in: a smash on a body, a winch on the world.

| State | Sight | Sound | Prompt |
| --- | --- | --- | --- |
| Searching | A small sand cross at the aim point | None | None |
| Locked | Live brackets close on the target over 0.1 s. A post's cap pulses at 2 Hz. The reticle ring goes solid. | One soft lock tick, at most every 0.25 s | RMB keycap with the hook glyph beside the aim point. The word HOOK until the first bite. |
| Dry fire | A line darts 8 m and falls slack over 0.25 s. The reticle shakes 3 px. | A dull tick, about 14 dB under the bite. Never silent. | The RMB prompt returns for 3 s |
| Latched to the world | A cable mesh, 0.09 m radius and sagging while slack, 0.14 m and bright when taut, never under 5 px on screen at 45 m. An anchor ring on the post for the whole latch. | A clunk and a rope creak. A hum for as long as the line stands. | Ctrl keycap with the reel glyph at the anchor, shown if the line stands 1.5 s without a Ctrl press |
| Latched to a body | The hook head seats as a barb with a **steady** live collar that tightens as the gap closes. The cable stays taut and bright. The body leans toward the ball and drags sparks. About 40 ms of hit-stop on the bite. | A two-layer bite, louder than and distinct from the world clunk. A hum that climbs about an octave from 45 m to 3 m. | Ctrl keycap with the smash glyph at the bite point. The word SMASH until the first smash. Returns whenever a latch stands 1.5 s. |
| Smash committed | The cable flashes white and whips straight. The ball streaks in the live colour. | A whistle that rises over the haul | None |
| Smash lands | The camera kick and ring, centred on the contact point. The barb pops out. A live crack if it broke plate, slate sparks if it glanced. | A crack of its own over the boom, tuned a fifth below the bite so the two resolve as a pair | None |
| Rewinding | The hook head flies back and docks. The reticle ring redraws over the rewind. A kill fills it at once. | A dock click | None. A press here is a dry fire. |
| Let go | The cable retracts in 0.15 s. A fling chevron puffs along your velocity. | A zip | RMB with the fling arrow on the first three latches only |
| Broke | The cable snaps in two, tinted rust where it parted. Speed is kept. | A twang, lower and longer than the zip | None. The run log records the cause. |

Lock and latch differ in motion on purpose: lock pulses, latch is steady. His complaint was not knowing whether he is hooked, and two pulses in one colour read the same at speed.

The harpoon has no ability slot. Its readiness is the reticle ring.

**Ball states, in priority order.** Line on body, then line on world, then charging, then mounted, then air, then ground. A key means one verb in the highest state that holds. Slam and brake are unavailable while any line stands. The bindings test walks the combinations, since a world swing is also airborne.

## 4. The Warden fight

The slice Warden is the posture chassis and nothing else. In one line: hit it until it cracks open, then smash the core.

- **Posture** is a bar from 0 to 100. Each landed hit adds `base x clamp(punch / plating, 0.2, 1.5)`. Base is 30 for a ram or slam, 45 for a harpoon smash, 1.5 for a gun bolt and 3 on the part that is telegraphing. After 3 s with no gain it drains at 12 per second.
- **Stagger.** At 100 the Warden staggers for 4 s. The jaws spring at least 25 degrees apart and the core shows a live rim and takes harpoon brackets. Health can fall only now.
- **Health** is four chunks. One stagger removes at most one. A harpoon smash, or a ram at speed tier 2 or better into the core, shatters the whole chunk. A lesser hit leaves it cracked for the next stagger.
- **No wall.** A build at the 0.2 floor still fills posture, at 6 per ram.
- **A glance** is a hit whose multiplier sits on the 0.2 floor. Only that case gets slate sparks and the low clank.
- **The pulse** is unchanged and pauses during a stagger. It never changes planar velocity.
- **On the body.** Cracks spread across the jaw plates at 25, 50 and 75 posture and seal as it drains. No amber anywhere on the Warden. The live colour appears on it only while it is open.
- **The plate** sits top-centre, about 420 by 44 px at 1080p, from `warden_engaged`: a name of two words or fewer, four chunks, a posture bar, one state glyph. The 24-segment ring goes. The overhead diamond stays as a landmark.
- **Sound.** Each posture quarter raises the hit's note one step of a four-note phrase. The stagger lands the chord. A chunk shatters on a bass hit.
- **The objective line** is the fight's state: "Find the Warden", "Break its guard", "Smash the core", "Roll through a gate". "Grow, then return" appears only when posture has failed to reach 50 across 10 s of trying, never on a hit count. A matched build must never see it.

**Bands** (bots decide only whether the build is worth his time):

- A matched brawler breaks it in 60 to 150 s.
- The hold-fire camper cannot.
- A starting-size skipper takes at least 1.5 times the brawler's time, or fails. This is entry 8's "I could just go to the boss".
- 50 hits outside a stagger leave health unchanged.

## 5. Callouts and prompts

**Callout.** One form for every synergy and map mechanic. Two cause glyphs snap together, an arrow draws to the effect glyph, and a pulse in the row's own shape plays on the struck body. It runs 0.9 s. The name shows on the first three firings per profile. At most one per row per 4 s, one on screen in a fight and two when calm. Each row has a three-note motif. Picking up the completing part plays the first two notes and links the two glyphs at the ball. The first real firing lands the third note and queues the discovery card for the next calm moment (3 s with no telegraph and no damage).

**Prompt.** A sand keycap about 28 px tall plus the verb's glyph in the live colour. It exists only on ticks where the press would succeed, at the thing the verb acts on. At most two at once. It retires after three successes (five for the smash) and returns for 3 s after a failed press, after 90 s unused, and at the first availability of each run. A bar keycap hides while its own prompt is on screen. The brake has no prompt.

**Word budget, 25 in a fight.** The count includes prompts, the callout name, activity words and the part name. The test's fight case is the plate, two prompts, one named callout and one activity label.

## 6. Enemies

Six kinds on the Cable Reach, and every one has a built model on the visual branch.

| Kind | Role | Body cue | Wind-up cue |
| --- | --- | --- | --- |
| Chaser | Fodder that teaches the ram | A low wedge on claws, the smallest body | Squats and digs in while its lane fills. Its back shows live while a ram would break the lunge. |
| Lobber | Rewards speed: bat the shell home | A mortar cart with one fat barrel and a bulb | The bulb swells as it loads. The floor reticle stays hazard. The shell itself takes a live rim and a rising ping when you are fast enough to bat it. |
| Mag trapper | Bends your line | A squat body carrying a stack of discs, the tallest in its pack | Lifts a disc, the ring lands, field lines curve to its centre. Open stripes mean your size rolls through. |
| Winch drone (absorbs the hooker) | The one flying kind | A rotor above a brass drum | The drum spins up and a hazard lane shows the cable's path. The cable glows hotter as it strains. Snapping it slings you forward. |
| Deflector (absorbs the swatter) | A redirect that is an offer | A braced dish with a brass rim | Swings to face you. In the 0.45 s vault window its rim shows live and the Space prompt sits on the dish. |
| Plated brute (the elite; absorbs the miniboss) | A rehearsal for the Warden | The largest body, stacked plates you can count | Pads rise before the slam. A live crack shows on the next plate when your hit will break it, slate when it will glance. |

The bola thrower is a seventh card on Andrew's read sheet. He chooses whether it joins.

**Packs.** Run-down (three chasers, one lobber), Grounded (mag trapper, two lobbers), Rebound (deflector, two chasers), and the elite (plated brute with a winch drone). All present from the start. No tick unlocks and no build tilt, since neither can be perceived.

**Holds bend, within a bound.** The player critic caught that a pull is still steering against his will. So a hold may only apply after a telegraph the player could have dodged, it never lowers total speed, and it turns the ball's heading by at most 60 degrees per second. Both are tested. The mag pit loses its drag term. The gyro jammer is cut for a different reason: it scrambles input, which no dodge answers.

## 7. What leaves the slice

| What | Verdict | Why | Returns |
| --- | --- | --- | --- |
| Netcaster, gyro jammer, catch trap, ramp flipper, mind hand | Cut | Three stop the ball or take the steering. The ramp flipper is a map toy cast as an enemy. The mind hand reacts to a hidden tally. | Netcaster and ramp flipper as map toys in later worlds. Mind hand with a visible habit meter. |
| Hooker, swatter, miniboss | Merged into winch drone, deflector, plated brute | Each pair does one job | Hooker once the player's own harpoon reads |
| Bola thrower, swarm remnant, reactor relic, vault | Deferred | No model, another family, or a duplicate read | With their worlds |
| Flood, dust squall, cave-in, impact | Cut | No goal and no reward on a hidden clock. The flood brakes the ball. He entered 13 floods and won none. | Flood and squall as opt-in terrain in later worlds |
| Timed event offers ("incoming") | Replaced by standing activities | A toast on a clock for something optional | No |
| Hold the Relay, Scrap Stampede | Merged into the ambush altar and the hauler bounty | The relay pins the ball in a ring for 18 s | No |
| Bonus cores and the bet crate | Cut | A third resource with one jargon toast | M2, if they earn a visible socket |
| Barges and lifts on the main lines, thermals for non-Kest pilots, the sprint-only wall, two of three door valves | Simplified | Each is a dead stop or a mechanic with no visible link | With the worlds built around them |
| Bay toys and five of the shop's six verbs | Deferred | They compete with the one thing the bay is for | M2 |
| Synergies, 9 down to 5 | Simplified | Kept: Wrecking Ball, Tesla Pylon, Pinwheel, Shrapnel Bloom, Lightning Rod. Each rides a verb he already performs. | Later worlds |
| The discovery banner at pickup, four reward ceremony tiers | Simplified | The banner fires when the part is taken, not when the effect happens | No |
| The loot pool of about 90 rows, generated recipes, item procs | Simplified to about 12 authored parts, each with a visible effect | Too many rows for any part to be learned | Pool grows in M2 |
| The heft dial, punch and plating bars, the scrap number, core pips, the fight clock | Merged | Ball size and one armour bar carry it. Frees an estimated 8 to 12 fight words. | No |
| Shred, the 20 percent health chip, the amber and slate plating tint | Merged into posture | Three overlapping pressure models | No |
| Warden caps, guard rack, magnet tug, mind brace | Deferred | Seven rules on the first Warden he meets | The guard rack as the Reach's own lesson in M2 |
| Q reel, the mouse wheel, the C dash, RMB cancel, title L and G, dev keys in play | Cut | 24 inputs become 9 verbs | The wheel as a Sable upgrade |
| Shift's boost or burst swap | Merged | One key, one state, two outcomes on an invisible charge. Shift is each pilot's one go verb. | No |
| Harpoon lab modes, and the hold-to-reel against auto-winch comparison | Cut | A held body line already winches, so there is nothing to compare | No |
| The Hunt arm and the Duel arm as separate builds | Cut and folded | One fight built well. The Duel's arena furniture (swing pillars, ramps) goes into the Warden site in the zone retrofit. | Hunt as a world-two boss idea |
| Level-up perk pool, hot-wired Spark Tread, Sable's hook tree knobs | Deferred | A level-up opens the tree pick, so no twelfth growth system | M2, each with its own cue |

Growth systems to learn drop from 11 built plus 2 planned to 5: scrap as size, tree picks, parts, synergies, one relic.

## 8. Traversal measure

**Flow share.** A line-follower bot drives each pilot's authored line from the spawn to Warden engage, limited to a 150 ms reaction and one verb press per 0.4 s. Flow share is the fraction of ticks at or above speed tier 2 (16.1 m/s at cruise 14). Reported with it: dead stops (under tier 1 for more than 0.5 s without the brake, a mount or an interaction, or one contact that removes more than half of planar speed), the largest gap between hookable anchors, and time to the Warden.

**The bar**, per pilot over 8 seeds: median flow share 0.70 or more, no seed under 0.60, zero dead stops, largest anchor gap 40 m or less against the 45 m rope.

**Red first.** The measure runs on today's map before the retrofit. If today's map already clears 0.70 for a pilot, that pilot's bar becomes the baseline plus 0.15.

The same number is written to the run log from Andrew's own play.

## 9. Units

One owner per file within a wave. Every fence includes the tests that pin what the unit changes. Order of gates: wave A1, the visual merge (AR), G1, wave R1, B0b, B0a, wave R2, wave R3, then the checkpoint.

### Wave R1

| Unit | Goal | Writes | Proof |
| --- | --- | --- | --- |
| G1, opener, merged alone | The grammar as data, so every later unit reads frozen ids | `event_kinds.gd` (four row tables, harpoon rows moved into `LINE_ROWS`, boss rows `posture_step`, `stagger`, `chunk_shatter`), `game_events.gd` (`line_state_changed`, `verb_failed`, `cause_fired`, `posture_changed`), `palette.gd` (`SLATE`, `live()`), `bindings.gd` (the verb ids and intent field names only), two presentation stubs | A unit case over the rows: the colour law, the distance rule, names of three words or fewer, no id with presentation in two tables. No behaviour change. |
| C1 | Nine verbs and the prompt grammar | `bindings.gd`, `game.gd`, `key_glyphs.gd`, `ui_profile.gd`, `field_notes.gd` | The state table in priority order has one verb per key. A prompt shows only when the press would succeed. Removed keys have no handler. |
| C2 | Harpoon canon: one mode, one grammar, every state published, no silent press | `harpoon.gd`, `player_ball.gd`, `augments.gd`, `augment_kit.gd`, `intent.gd`, `tuning.gd`, the harpoon tests | A scripted test sees every `LINE_ROWS` state. A press with no aim emits `verb_failed`. Total speed after a bite, a commit, a let-go and a break is never below total speed before it. |
| HL, merged after C2 | The latch as a loud, persistent object | `line_view.gd`, `aim_reticle.gd`, `aim_style.gd`, `audio.gd`, `sfx_bank.gd` | The cable is at least 5 px wide at 45 m, computed. Lock and latch rows differ in motion. Bite, clunk and dry tick are three sound ids. Three stills for his glance. Two or three sketches of each motif as WAV files for his ear. |
| WY | Cause and effect where a synergy fires | `synergies.gd`, `build.gd`, `why_callout.gd`, `codex_banner.gd`, `vfx.gd`, `accretion.gd`, `build_sheet.gd` | Five live rows. Each firing emits `cause_fired` at the struck body. No banner at pickup. A row with no emitter fails. |
| TM | The traversal number, its baseline, the bots, the run-log fields | `tools/traversal_line.gd`, `tools/traversal_lines.json`, `tools/bot_driver.gd` (brawler, camper, skipper), `run_log.gd` | A baseline for three pilots on today's Reach with its commit. The rate limit is asserted. The dead-stop detector passes on synthetic traces. |
| ST, replaces S1, runs beside G1 | A stage table chosen when the game is built, and a one-stage slice table: the Cable Reach as stage 1 with slot-1 numbers and no boss | `stage_defs.gd`, `slice_defs.gd` (new), `context.gd`, the context build in `game.gd`, the table reads in `flow.gd`, `terrain.gd`, `world.gd`, `combat.gd`, `hud.gd`, `screens.gd` | A game on the slice table plays the Reach first and ends won at its gate. A game with no table chosen is unchanged, and no existing test is edited. |

### Between the waves

| Unit | Goal | Writes |
| --- | --- | --- |
| B0b, merged alone | Delete the laps and drop loops. First move the music, breath, discovery, telegraph and gun keys out of `loop_mode.gd` into `tuning.gd` rows. | `loop_mode.gd`, `warden_drop.gd`, `lap_course*.gd` (deleted), every `LoopMode` reader, about 22 tests |
| B0a, merged alone, Fable review | The posture chassis on slot 1 numbers | `warden.gd`, `boss_posture.gd` (new), `combat.gd`, the Warden fields in `stage_defs.gd` |

### Wave R2

| Unit | Goal | Writes |
| --- | --- | --- |
| B3 | The boss plate and the Warden's body states | `boss_plate.gd` (new), `warden_look.gd`, the boss notes in `audio.gd` |
| O1 | One objective board, and the HUD cut to two build readouts. Instantiates the plate. A two-word part name at the ball on pickup. | `objectives.gd` (new), `hud.gd`, `objective_view.gd`, `edge_markers.gd`, `run_status.gd`, `heft_dial.gd`, `callouts.gd`, `ability_bar.gd` |
| C5 | Enemy state on the body | `enemy.gd`, `counter.gd`, `status_marks.gd` (new), `vfx.gd`, `presentation.gd`. The plated brute stays uninterruptible; its plate cue answers "did it count". |
| EN | Six kinds, three packs and an elite from one source; holds within the bound | `roster.gd`, `director.gd`, `holds.gd`, `mag_trapper.gd`, `winch_drone.gd`, `deflector.gd` |
| Z3 | The Reach retrofit against the traversal bar, with a Warden site built for the ball | `map_gorge.gd`, `terrain.gd`, `stage_map.gd`, `contraptions.gd`, the gate placement in `build.gd` |

Z3 also fixes the bay: reward gates open at authored slots beside the Warden whatever the ball's position, and the bay docks in 16 of 16 seeds.

### Wave R3, before the sitting

Standing activities (Surge Run, ambush altar, cracked cache with the relic, hauler bounty). The parts pool cut to about 12. Per-kind counter cues with the wind-up rows. A level-up that opens the tree pick. The read sheet stills. The admission bands and the checkpoint script. The sitting sheet and the launcher fix.

## 10. Decisions made on Andrew's behalf

Each is worded so he can veto it.

1. The "your verb works" colour is mint for every pilot in the slice. Rivet and Kest keep their own colours for identity.
2. The harpoon is two keys: right mouse is the line, Ctrl hauls it in. Q, the wheel and the C dash are gone.
3. Rivet's and Kest's world lines swing on hold like Sable's, with Ctrl to winch.
4. One fight, built well. The Hunt and Duel arms are not built as separate variants. The sitting compares nothing; he plays one build.
5. The first Warden is the plain chassis. A harpoon smash or a fast ram into the open core shatters a whole chunk, so his favourite move is the finisher.
6. Six enemy kinds, all with models. Catch trap and gyro jammer do not return.
7. Holds may bend the ball's path within a bound but never slow it.
8. Flood, dust squall, cave-in and impact are out. The crater is fixed terrain.
9. Activities stand lit from the start, with no timers and no "incoming" toasts, and pay a part at the spot.
10. Five synergies, each with its own shape and three-note motif.
11. The heft dial, punch and plating bars, the scrap number and the fight clock leave the HUD.
12. Moss's shop is its shelf of three for the slice.
13. The cracked wall breaks for any pilot at cruise speed. The skylight door starts open.
14. Shift is one go verb per pilot. Nothing changes for Sable.
15. Cuts are unreachable now and deleted only after his verdict.

## 11. What only Andrew can decide

1. **The enemy read sheet, by eye.** Stills of the six kinds plus the bola card, each with its body cue and wind-up cue. Shown before wind-up work follows it.
2. **The motifs, by ear.** The boss's break phrase and the five synergy motifs, two or three short sketches each.
3. **Live colours for Rivet and Kest.** A swatch card when those pilots unlock in M2. Until then both use mint.

## 12. Risks, with the cheapest check for each

| Risk | Check |
| --- | --- |
| The latch still does not read at speed | The computed cable width and three stills, then the first five minutes of his sitting |
| Rivet and Kest get worse without plain boost and with swing-on-hold | Their flow share before and after C2. Fallback: restore hold-to-winch on the same binding row. |
| Cutting Q breaks Sable's Rope Anchor knob | C2 states whether the knob plants from the Ctrl winch or leaves the world-one profile |
| The chassis-only Warden is readable but dull | The brawler and skipper bands, then his sitting. Fallback: the guard rack as one extra posture source. |
| Six kinds feel thin after he praised the fuller mechanics | The bola card on the read sheet |
| Prompts nag | Prompts shown per minute in the run log. Aim for six or fewer after minute three. |
| The flow-share bar measures a bot | His own flow share at the sitting |
| The slice table hits a read that still assumes three stages by position | ST's review walks a slice run and lists every positional read; the bots in TM then run on the slice table |
| Several audit claims were never run | The traversal baseline and one run of the word-budget test before R1 is cut |

## Changes to the plan

- The fight axis and the harpoon-input axis are gone. There is no `--variant=` row.
- Units VH and VD are not built. PK is replaced by EN. TL is absorbed by TM. B0 splits into B0b and B0a. G1, HL, S1 and R3's units are new.
- The order is the one in section 9.
- S1 (reorder the stages so the Reach is first) is replaced by ST (a slice table chosen at launch). The plan puts the Spillway back as zone 1-1 in M2, so a reorder would rewrite about 35 stage-order tests twice. The sitting launches with `--table=slice`.
