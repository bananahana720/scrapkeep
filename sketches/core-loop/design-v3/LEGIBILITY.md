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

Sand (`Palette.SAND`) is neutral ink and carries no meaning: keycaps, the searching cross, a posture step. Rows name it as the role `neutral`.

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
| A verb is available (the press would succeed this tick) | A sand keycap plus the verb's glyph in the live colour. One word rides it until that verb's first success on the profile; E (mount; it shows only where the ball would mount) and Space, whose reading changes with the ball's state (jump, double jump and slingshot), say that reading until the prompt first retires. At most two prompts at once. | At the thing the verb acts on | `src/core/bindings.gd` `VERBS` |
| A target can be hooked | Live corner brackets close on it and its cap pulses at 2 Hz. Out of range is a hollow slate ring with no sound. | On the target, mirrored by the reticle | `event_kinds.gd` `LINE_ROWS` |
| Something is active on you | A persistent object and a loop sound for as long as it is true: the taut cable and its hum for your line, a hazard binding line and a creak for a hostile hold, flakes and a rasp for wear | On the ball and along the line to the cause | `LINE_ROWS`, `STATE_ROWS` |
| A target is in a state | On the struck part: barb and collar for latched, a live rim and crack for will-break or open, slate for glancing, a flipped pose and star for interrupted. No floor rings. | On the enemy body. On the Warden, repeated once as the plate's state glyph. | `STATE_ROWS` |
| Something fired | A hit: sparks at the contact point sized by what it did. A synergy or map mechanic: two cause glyphs, an arrow, the effect glyph, in the row's own shape with its motif. | At the contact point or on the object. Never in the toast band. | `IMPACT` for hits, `CAUSE_ROWS` for the rest |
| Something failed | Always an answer: a slack line and a dull tick for a dry harpoon, slate sparks and a low clank for a glance, the cable snapping with a rust twang for a forced break. The failed verb's prompt returns for 3 s. | Where the action would have landed | `VERBS` field `fail`, `STATE_ROWS`, `LINE_ROWS` |
| A goal exists | A glyph, five words or fewer, a distance chevron. The same glyph on a world beacon and on the edge marker. In view, the thing the goal names wears brackets and a tag; a finished goal is ticked (the objective line, below). | Objective plate, the beacon, the screen edge | `src/core/objectives.gd`, which absorbs `OBJECTIVE_SHORT` and the `objective` strings in `ROWS` |
| A threat is coming | The hazard floor telegraph with fill progress, the wind-up pose on the body, the row's warn sound. Unchanged. While the ball stands where the hit will land, a hazard diamond with a bang stands over the ball and fills with the same progress (`src/ui/danger_mark.gd`, from the dodge watch's `standing_in`): a camera inside a floor mark sees its rails and no edge. Which way is safe is still open: readers of the diamond alone knew they were in danger but not which way was safe, and a small bone chevron beside it pointing the shortest way out (`near_miss.way_out`) failed its blind read (0 of 9 answers named the way, 10 Nov 2026). | The floor and the attacker; over the ball while it stands in the mark | `ATTACK_ROWS`, `THREAT_ROWS` |
| An activity is on offer | A standing amber beam and ground ring from stage start with the family glyph on top. No timer and no toast. Its goal is a gauge on the object itself. | At the site | `ACTIVITY_ROWS` |
| A reward is paid | The part rises from the exact spot the goal completed, the won sound plays, and its glyph flies onto the ball with a two-word name. | The completion spot, then the ball | `LOOT_ROWS` |

**Defence bars (SG7).** Three bar classes, each with one regen rule and one existing palette row, so a bar's look predicts how to attack it. The table lives in `src/core/defence_bars.gd` (`CLASSES`, `STATES`); `tests/defence_bars_test.gd` holds it. Every defence state maps to exactly one class, no two classes share a colour, and no class takes a colour-law row other than its own (the shield takes slate, "not yet") or the `weak_point_opened` colour.

| Class | Colour (`Palette`) | Pattern cue | Rule | What the player reads |
| --- | --- | --- | --- | --- |
| Armour | `BRASS` | Segmented blocks | Breaks at zero, never regenerates | Break it once and it stays broken |
| Shield | `SLATE` | Hollow outline | Regenerates after a declared delay (`SHIELD_REGEN_DELAY`, then `SHIELD_REGEN_PER_S` of max per second, `src/core/defence_bars.gd`) | Burst it before it recovers |
| Health | `SAND` (neutral ink) | Solid fill | No regeneration, no break state | Just damage |

The pattern cue carries the class for a colour-blind player. At the 150 m read distance the pattern is under a pixel, so colour alone must separate the classes there: the test makes a modeled colour read at the 150 m haze start value (`HAZE_MIX`; no frame is read) and requires each bar's class. The rendered 150 m still, read blind, belongs to the SG-LOOK legibility unit. Start values (delay, rate, haze) sit in named constants citing `comps/gunfire/enemies-and-bosses.md`.

**One rule per meaning.** The builder critic found the draft would give one harpoon bite three rows. So: `LINE_ROWS` replaces the `harpoon_bit` and `harpoon_smashed` rows in `ROWS`. `CAUSE_ROWS` is keyed by the ids in `synergies.gd` and holds presentation only; names are read from `synergies.gd`. `STATE_ROWS.held` replaces `hold_started`'s presentation. A test fails when one id has presentation in two tables.

**Telegraph timing.** A boss hazard warns for at least 1.0 s (`src/boss/hazard.gd:19`). Pack kinds set their own warning, 0.6 to 1.4 s today: seven sit under 1.0 s (bola thrower 0.6, chaser 0.6, line cutter 0.6, kite drone 0.8, swatter 0.8, deflector 0.9, lamp swarm 0.9; for example `src/combat/bola_thrower.gd:35`, `src/combat/chaser.gd:12`), and the longest is the mind hand at 1.4 (`src/combat/mind_hand.gd:26`). A charge longer than 3 s belongs to a Warden or a miniboss. Warning time is a per-kind choice read against these numbers, never derived from an attack's size or damage. The warn sound, the wind-up pose and the floor fill start on the same tick, and damage comes only from the committed telegraph, only inside its live window (`src/combat/telegraph.gd:6-10`). Feedback is bounded: camera shake never exceeds the active camera row's `shake_cap` (1.2, and 0.6 in a Warden fight, `chase_camera.gd:27-29`), and hitstop stays inside its row's clamp (`juice.gd:355`). `tests/telegraph_timing_test.gd` holds each line for the Warden kinds from wave 13; the pack kinds' rows join it in the next wave.

**Pack telegraph record (SQ1).** Every pack-kind attack has one row in `src/combat/telegraph_record.gd`: pre-shoot, recovery, cooldown, radius, marker class and band class. The marker class is read from the committed geometry: a **circle** for an area (a ring, or a swatter's wedge), a **line** for a lunge or a lane, **text** for a delayed hit (no pack kind draws one yet). The band class is read from the attack type: an **area burst** (a ring or a wave, 0.25 to 0.5 s), a **projectile** (0.75 s) or a **ray** (a lane, 1 to 2.5 s); these are Roboquest's bands as starts (`comps/roboquest/enemies-and-telegraphs.md:57-60`). A pre-shoot outside its band stays where it is with a reason logged in its row; none sits under the 0.4 s reaction floor, and no warn moved to fit a band. All 23 pack kinds read `TelegraphRecord.RECOVERY` for a 0.75 s standing tail with no new warning or attack. Counter attacks recover after their live phase, the chaser after its lunge, the lobber after shell release, and a free swarm remnant after its dive. Warden attacks, including Hive guard dives, keep their timing on `WARDEN_EXCEPTIONS`. `tests/telegraph_timing_pack_test.gd` measures this list over 50 solo spawns per kind (lead at least 0.4 s, telegraph and damage areas overlapping at least 95 percent); `tests/pack_telegraph_record_test.gd` holds it equal to the record and measures each kind's recovery before and after.

| Attack | Kind | Marker | Band | Pre-shoot (s) | Band read | Recovery (s) |
| --- | --- | --- | --- | --- | --- | --- |
| E01 | `chaser` | line | ray | 0.60 | logged: a lunge, one roll leaves the lane | 0.75 |
| E02 | `lobber` | circle | projectile | 1.90 | logged: the ring stands for the shell's whole arc | 0.75 |
| E05 | `mag_trapper` | circle | area_burst | 1.10 | logged: a hold | 0.75 |
| E06 | `hooker` | line | ray | 1.00 | in band | 0.75 |
| E07 | `netcaster` | circle | area_burst | 1.20 | logged: a hold | 0.75 |
| E08 | `bola_thrower` | circle | projectile | 0.60 | logged: the bola still flies 1.3 s to its ring | 0.75 |
| E09 | `plated_brute` | circle | area_burst | 1.10 | logged: no interrupt, the read replaces it | 0.75 |
| E10 | `deflector` | line | ray | 0.90 | logged: a brace that turns the ball | 0.75 |
| E11 | `winch_drone` | line | ray | 1.00 | in band | 0.75 |
| E12 | `gyro_jammer` | circle | area_burst | 1.00 | logged: a hold | 0.75 |
| E13 | `swatter` | circle | area_burst | 0.80 | logged: a hold | 0.75 |
| E14 | `ramp_flipper` | circle | area_burst | 1.00 | logged: a hold | 0.75 |
| E15 | `catch_trap` | circle | area_burst | 1.00 | logged: a hold | 0.75 |
| E16 | `reactor_relic` | circle | area_burst | 2.40 | logged: no interrupt, a 5 s crater | 0.75 |
| E17 | `swarm_remnant` | line | ray | 1.20 | in band | 0.75 |
| E18 | `mind_hand` | line | ray | 1.40 | in band | 0.75 |
| E19 | `burrower` | circle | area_burst | 1.00 | logged: a floor burst that a bank, a wall or the air escapes | 0.75 |
| E20 | `drill_crew` | circle | area_burst | 1.20 | logged: no interrupt | 0.75 |
| E21 | `lamp_swarm` | circle | area_burst | 0.90 | logged: a wave whose front runs outward | 0.75 |
| E22 | `line_cutter` | circle | projectile | 0.60 | logged: the cutter still flies 1.1 s to its ring | 0.75 |
| E23 | `anchor_crew` | line | ray | 1.00 | in band | 0.75 |
| E24 | `kite_drone` | circle | area_burst | 0.80 | logged: no interrupt, then a 0.7 s dive | 0.75 |
| E25 | `splitter_pod` | circle | area_burst | 1.00 | logged: a fuse, the second is the time to roll out; the spent husk crumbles after recovery | 0.75 |
| E26 | `dispatcher` | circle | projectile | 1.20 | logged: a 0.45 s suck-up, then the pod flies 0.75 s to its ring | 0.75 |
| E27 | `jolt_layer` | circle | area_burst | 1.00 | logged: a field that pulses, each pulse led by its own 0.5 s fill | 0.75 |
| E31 | `prop_crew` | circle | area_burst | 1.00 | logged: player-started, a ram on the prop drops the roof once | 0.75 |
| E30 | `pit_jaw` | circle | area_burst | 1.00 | logged: a hold | 0.75 |
| E32 | `ballast_heavy` | circle | area_burst | 1.10 | logged: the brace is the ram window | 0.75 |
| E33 | `gap_net` | line | ray | 1.00 | in band | 0.75 |
| E40 | `boom_tender` | line | ray | 1.10 | in band | 0.75 |

## 3. The harpoon

Two keys for every pilot. Right mouse is the line: press bites, hold keeps it, release flings. A line held on a body reels the ball in, as it did in the build he played. Ctrl hauls it in: a smash on a body, a winch on the world. With no line standing, Ctrl is the brake on the ground and the slam in the air, and plays no refusal.

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

- **Posture** is a bar from 0 to 100. Each landed hit adds `base x clamp(punch / plating, 0.2, 1.5) ^ curve`, with `curve` 1 unless the stage row's `posture` dictionary says otherwise. The row may also carry `ram_shatters` (default true: a ram at speed tier 2 or better shatters an open core) and nothing else yet: only `curve`, `ram_shatters` and the plating (`warden_plating`) are supported row keys, because the boss plate and the weak-point event read the other constants; a missing key keeps the constant. Base is 30 for a ram or slam, 45 for a harpoon smash, 1.5 for a gun bolt and 3 on the part that is telegraphing. After 3 s with no gain it drains at 12 per second.
- **Stagger.** At 100 the Warden staggers for 4 s. The jaws spring at least 25 degrees apart and the core shows a live rim and takes harpoon brackets. Health can fall only now.
- **Health** is four chunks. One stagger removes at most one, and a shatter closes the Warden at once. A harpoon smash, or a ram at speed tier 2 or better into the core, shatters the whole chunk. A lesser contact leaves it cracked for the next stagger; a second lesser contact in the same opening does nothing more. A hit at the glance floor counts as any other contact here. While it is open, a contact anywhere on the Warden is a hit on the core. Guns, blasts and synergy strikes fill posture but cannot crack or shatter the core, and no path other than this rule can lower its health.
- **One gain per frame from contacts.** A smash landing strikes several times in one physics frame; contact gains in a frame take the largest, not the sum. The hit that fills the bar cannot also shatter, and contacts in the frame a chunk shatters gain nothing.
- **No wall.** A build at the 0.2 floor still fills posture: 6 per ram at curve 1, 1.2 at the slice's curve 2.
- **A glance** is a hit whose multiplier sits on the 0.2 floor. Only that case gets slate sparks and the low clank.
- **The pulse** is unchanged and pauses during a stagger. A charge in flight when the stagger begins is cancelled. It never changes planar velocity. The reactor's own window after a pulse does not open, and shred does not build.
- **On the body.** Cracks spread across the jaw plates at 25, 50 and 75 posture and seal as it drains. No amber anywhere on the Warden. The live colour appears on it only while it is open.
- **The plate** sits top-centre, about 420 by 44 px at 1080p, from `warden_engaged`: a name of two words or fewer, four chunks, a posture bar, one state glyph. The 24-segment ring goes. The overhead diamond stays as a landmark.
- **Sound.** Each posture quarter raises the hit's note one step of a four-note phrase. The stagger lands the chord. A chunk shatters on a bass hit.
- **The objective line** is the fight's state: "Find the Warden", "Break its guard", "Smash the core", "Roll through a gate". "Grow, then return" appears only when posture has failed to reach 50 across 10 s of trying, never on a hit count. A matched build must never see it.
- **The goal changes only when the player does something, and it says what they did** (10 Nov 2026, after the second first-timer film: PF-11, PF-17, PF-23). Its rules live in `src/core/objectives.gd`, and the HUD and the markers only read them (the detour row's pick of cage or nearest site is `hud.detour_reading`, since it reads the world):
  - *The Warden is the stage's goal from the drop*, with the metres to it. A side site takes the row only while the ball is at one it has started (`activities.at_hand`: within 80 m, the camp's ring entered, the relay held, the hauler met, the surge begun or its water carrying the ball), by its own verb and with no metres, and keeps it until it is finished or the ball is 100 m away, so the goal never flickers at the edge of a site's reach; a cache and a trade spot never take it, since neither is started by an act. The row never names a site because of where the ball is heading.
  - *A detour is on offer under the goal* (12 Nov 2026, gameplay critique finding 8, W1-69). While the row is "Find the Warden", a second row on the same plate, with a smaller glyph and all of it at `UiTokens.QUIET_ALPHA`, names the stage's caged pilot by its own prompt ("Free the runner") while one waits, else the nearest side site not yet started by its verb, each with its metres and in its own marker's glyph and colour (the cage's ally green, the site's amber). The cage gets an edge chevron like a site's. The goal row never changes for it: a detour is offered, never steered to. Once the Warden is engaged the row and the detour chevrons go, so a fight keeps its word budget (`Objectives.DETOUR_UNDER`).
  - *A finished goal is ticked.* For `Objectives.Done.SECONDS` (1.6 s of play) the plate shows a tick and what was done ("Camp cleared", "Relay held", "Gamble taken", "Yard open", "Clamp open", "Warden broken"), or a cross and what was lost ("Relay lost", "Surge lost"), in the plate's own place, so it takes no new screen and sits under the Warden's or the boss's bar exactly as the goal does. The next goal changing under it takes it down at once. What an act opened never covers the act: the yard and the clamp are ticked only on a plate with no tick on it, and the clamp only in the fight.
  - *One row a fight phase.* A row is the phase's whole loop and holds while the loop turns: "Ride the water sheet up" at the dam; "Latch on, shoot, smash core" at the flume; "Shoot magnets, then cockpit", "Slam caps, then cockpit" and "Bait into walls, then cockpit" for Brindle's three phases (his cockpit opens and shuts in 0.2 to 4 s, faster than a row can be read). The plate draws the steps already done dim (`Objectives.STEPS`, the step the mark is on), and while the cockpit is open the row's glyph turns to the cockpit's; the words stay. From a Scuttle charge's tell to the end of its run the cockpit is not open, so nothing sends the player at it (PF-18).
  - *The plate is the plan; the mark is the next move, on the thing itself.* A thing the row names wears four corner brackets in the row's colour and a one or two word tag while it is in view between the top and bottom bands (`Objectives.TAGS`: MAGNET, VENT CAP, COCKPIT, SCOOTER; RIDE UP or WATER SOON at the foot of the dam's sheet; LATCH ON, SHOOT, CORE on the flume's Warden). Things that touch on the screen share one pair of brackets, every pair wears the tag where it has room (over the brackets, else under, and never over another mark; the tags count in the HUD's word budget), and brackets at the rim of their room slide into it while the thing stays inside them. Out of view it goes to the rim of the play view as any marker does. The fight's driver says where its things are (`boss.plate_targets()`, `warden_reactor.plate_targets()`).

**Bands** (bots decide only whether the build is worth his time):

- A grown ball (class III, 540 scrap at the start) breaks it in 25 to 45 s of fighting, counted from the later of its turn and its first contact on the Warden.
- A small ball (class I) takes at least 2.0 times that, at most 150 s, and still breaks it. A class II ball sits strictly between. This is entry 8's "I could just go to the boss": still possible, now the slow, hard road.
- The hold-fire camper cannot.
- 50 hits outside a stagger leave health unchanged.

**First and second measurements: superseded.** Unit B0a (the skipper and brawler both fought 28 to 34 s) and unit BN (24 cells, no pass, the brawler's heft at the first strike 1.04 to 1.10) used a fight clock that counted the skipper's roll and a "grown" bot that could not grow, because it does not know the map's activities. Neither is evidence for a pick.

**Third measurement** (unit BT, 2026-10-02, `tools/posture_sweep.md`, data in `tools/posture_sweep.tsv` and `tools/posture_sweep_runs.tsv`): the arms differ by the ball's starting scrap (small 0, mid 225, grown 540, plus a camper), 16 cells of plating 70, 90, 110, 130, `curve` 1, 2 and `ram_shatters` true, false, five seeds each, every run in its own process so it repeats exactly. Four cells pass every band; the pick is **plating 110, `curve` 2, `ram_shatters` false**: grown 25.5 s, mid 44.9 s, small 91.8 s, the camper never, a small-to-grown ratio of 3.59, and the same on a second run. The slice row carries it. `tests/posture_bands_test.gd` holds it.

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
| Timed event offers ("incoming") | Replaced by standing activities | A toast on a clock for something optional. Built (`world/activities.gd`): on the Reach an ambush altar (an 8 m ring, three enemies, a part at the altar when all three are dead), a cracked cache (a wall a ram at 0.85 x cruise or a slam that lands at cruise speed or faster breaks, a part on the pedestal) and a hauler bounty (one plated brute that wakes within 30 m or when hit, walks home once the ball is 40 m off, drops a part where it falls) each stand lit from the stage's first frame under an amber column, with a glyph, a ring and one word within 30 m. No timer, no key, no toast; the pay is a pickup the ball rolls over, one part and 180 scrap (the rule's `pay.scrap`), so three activities lift the ball two heft classes. | No |
| Hold the Relay, Scrap Stampede | Merged into the ambush altar and the hauler bounty | The relay pins the ball in a ring for 18 s. The standing ambush has no clock and no hold, and the bounty's brute is not on the director's cap. | No |
| Bonus cores and the bet crate | Cut | A third resource with one jargon toast | M2, if they earn a visible socket |
| Barges and lifts on the main lines, thermals for non-Kest pilots, the sprint-only wall, two of three door valves | Simplified | Each is a dead stop or a mechanic with no visible link | With the worlds built around them |
| Bay toys and five of the shop's six verbs | Deferred | They compete with the one thing the bay is for | M2 |
| Synergies, 9 down to 5 | Simplified | Kept: Wrecking Ball, Tesla Pylon, Pinwheel, Shrapnel Bloom, Lightning Rod. Each rides a verb he already performs. | Later worlds |
| The discovery banner at pickup, four reward ceremony tiers | Simplified | The banner fires when the part is taken, not when the effect happens | No |
| The loot pool of about 90 rows, generated recipes, item procs | Simplified to about 12 authored parts, each with a visible effect | Too many rows for any part to be learned | Pool grows in M2 |
| The heft dial, punch and plating bars, the scrap number, core pips, the fight clock | Merged | Ball size and one armour bar carry it. Frees an estimated 8 to 12 fight words. | No |
| Shred, the 20 percent health chip, the amber and slate plating tint | Merged into posture | Three overlapping pressure models | No |
| Warden caps, guard rack, magnet tug, mind brace | Caps, magnet tug and mind brace retired by F6 (2026-10-04); the guard rack burst stays | Seven rules on the first Warden he meets | The guard rack as the Reach's own lesson in M2 |
| Q reel, the mouse wheel, the C dash, RMB cancel, title L and G, dev keys in play | Cut | 24 inputs become 9 verbs | The wheel as a Sable upgrade |
| Shift's boost or burst swap | Merged | One key, one state, two outcomes on an invisible charge. Shift is each pilot's one go verb. | No |
| Harpoon lab modes, and the hold-to-reel against auto-winch comparison | Cut | A held body line already winches, so there is nothing to compare | No |
| The Hunt arm and the Duel arm as separate builds | Cut and folded | One fight built well. The Duel's arena furniture (swing pillars, ramps) goes into the Warden site in the zone retrofit. | Hunt as a world-two boss idea |
| Level-up perk pool, hot-wired Spark Tread, Sable's hook tree knobs | Deferred | A level-up opens the tree pick, so no twelfth growth system | M2, each with its own cue |

Growth systems to learn drop from 11 built plus 2 planned to 5: scrap as size, tree picks, parts, synergies, one relic.

## 8. Traversal measure

**Flow share.** A line-follower bot drives each pilot's authored line from the spawn to Warden engage, limited to a 150 ms reaction and one verb press per 0.4 s. Flow share is the fraction of ticks at or above speed tier 2 (16.1 m/s at cruise 14). Reported with it: dead stops (under tier 1 for more than 0.5 s without the brake, a mount or an interaction, or one contact that removes more than half of planar speed), the largest gap between hookable anchors, and time to the Warden.

**The bar**, per pilot over 8 seeds: median flow share 0.70 or more, no seed under 0.60, zero dead stops, largest anchor gap 40 m or less against the 45 m rope.

**Red first.** The measure runs on today's map before the retrofit. Where today's map already clears 0.70 for a pilot, that pilot's bar is the larger of 0.70 and its baseline median minus 0.03: no regression. The first baseline came back at 0.89 to 0.94 for all three pilots, because the Reach is a nine-second straight shot from the spawn to the Warden. Flow share cannot tell a better Reach from that one, so the retrofit unit is judged on the authored line as well: how long it is and which verbs it chains. `TRAVERSAL.md` holds the numbers.

The same number is written to the run log from Andrew's own play.

## 9. Units

One owner per file within a wave. Every fence includes the tests that pin what the unit changes. Order of gates: wave A1, the visual merge (AR), G1, wave R1, B0b, B0a, wave R2, wave R3, then the checkpoint.

### Wave R1

| Unit | Goal | Writes | Proof |
| --- | --- | --- | --- |
| G1, opener, merged alone | The grammar as data, so every later unit reads frozen ids | `event_kinds.gd` (four row tables, harpoon rows moved into `LINE_ROWS`, the posture facts `posture_step`, `open`, `chunk_shatter` in `STATE_ROWS`), `game_events.gd` (`line_state_changed` with a break cause, `verb_failed` with a reason, `cause_armed`, `cause_fired`, `posture_changed`), `palette.gd` (`SLATE`, `live()`), `bindings.gd` (the verb ids and intent field names only). No stubs: the unit that draws a thing creates its file. | A unit case over the rows: the colour law, the distance rule, names of three words or fewer, no id with presentation in two tables. No behaviour change. |
| C1 | Nine verbs and the prompt grammar | `bindings.gd`, `game.gd`, `key_glyphs.gd`, `ui_profile.gd`, `field_notes.gd` | The state table in priority order has one verb per key. A prompt shows only when the press would succeed. Removed keys have no handler. |
| C2 | Harpoon canon: one mode, one grammar, every state published, no silent press | `harpoon.gd`, `player_ball.gd`, `augments.gd`, `augment_kit.gd`, `intent.gd`, `tuning.gd`, the harpoon tests | A scripted test sees every `LINE_ROWS` state. A press with no aim emits `verb_failed`. Planar speed after a bite, a let-go and a break is never below planar speed before it, and total speed after a smash commit is never below total speed before it. The reel on a held body line is the rope's own pull. |
| HLv, after C2 | The latch you can see | `line_view.gd` (new), `presentation.gd`, `juice.gd`, `aim_reticle.gd`, `aim_style.gd`, the drawing removed from `player_ball.gd` | The cable is at least 5 px wide at 45 m, computed. Lock pulses and latch is steady, read from the rows. The harpoon's readiness is its own reticle ring beside the special's. Three stills for his glance. |
| HLs, after C2 and WY1 | The latch you can hear, the fail cue per verb, and the synergy notes | `audio.gd`, `sfx_bank.gd`, `tools/sound_sketches.gd` (new) | Bite, clunk and dry tick are three sounds. The hum stops within a tick of the line ending. Two notes on armed and the third at the first firing. Sketches as WAV files for his ear. |
| WY1 | The slice's five synergies, and a fact for every firing | `synergies.gd`, `build.gd`, `build_sheet.gd`, `parts.gd`, the synergy list on both stage tables, `reward_ceremony.gd` | Five live rows on the slice. Each firing emits `cause_fired` at the struck body. Discovery at the first firing, and again after a retry rewinds it. |
| WY2, after WY1 | The callout that shows why a synergy fired | `why_callout.gd` (new), `hud.gd` (create and count it), `vfx.gd`, `codex_banner.gd` | One form for every row, from the synergy data. The name on the first three firings. No banner at pickup. The card waits for a calm moment. |
| TM | The traversal number, its baseline, the bots, the run-log fields | `tools/traversal_line.gd`, `tools/traversal_lines.json`, `tools/bot_driver.gd` (brawler, camper, skipper), `run_log.gd` | A baseline for three pilots on today's Reach with its commit. The rate limit is asserted. The dead-stop detector passes on synthetic traces. |
| ST, replaces S1, runs beside G1 | A stage table chosen when the game is built, and a one-stage slice table: the Cable Reach as stage 1 with slot-1 numbers and no boss | `stage_defs.gd`, `slice_defs.gd` (new), `context.gd`, the context build in `game.gd`, the table reads in `flow.gd`, `terrain.gd`, `world.gd`, `combat.gd`, `hud.gd`, `screens.gd` | A game on the slice table plays the Reach first and ends won at its gate. A game with no table chosen is unchanged, and no existing test is edited. |

### Between the waves

| Unit | Goal | Writes |
| --- | --- | --- |
| B0b, merged alone | Delete the laps and drop loops. First move the music, breath, discovery, telegraph and gun keys out of `loop_mode.gd` into `tuning.gd` rows. | `loop_mode.gd`, `warden_drop.gd`, `lap_course*.gd` (deleted), every `LoopMode` reader, about 22 tests |
| B0a, merged alone, Fable review | The posture chassis on slot 1 numbers, chosen by the stage row's `warden_fight` and set on the slice table only | `warden.gd`, `boss_posture.gd` (new), `combat.gd` (`resolve`, `strike`, the Warden spec), one field in `player_ball.gd`, the Warden fields in `slice_defs.gd` |

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
16. A line held on a body reels the ball in, as in the build he played, and Ctrl commits the smash. The first build of the harpoon rules had dropped the reel; it is back so the approach to the move he called super fun is unchanged. The other choice is no pull until Ctrl.
17. Ctrl with no line is the brake or the slam and plays no "can't" sound.
18. The traversal bar is "no regression" on flow share, plus zero dead stops and anchors within 40 m. The retrofit is judged on the authored line's length and the verbs it chains, and on his play.
19. The lock's brackets are drawn once, on the target in the world. The reticle is a dot while a line stands.
20. Death drops the line.
21. A prompt that returns lasts at most 3 s of "you could press this now". Sable keeps her mount and slingshot prompts.
22. Cause glyphs are one fixed set: bolt for arc, disc for kinetic, core for mass, bar for anchor, chevron for speed, wave for spiral, diamond for split.
23. Not built in wave R1 and still owed: right mouse still cancels a charge; the ability bar does not yet hide a keycap while its prompt shows; there is no "let go to fling" prompt; a latched body does not yet lean or drag sparks.
24. The new Warden fight is on the slice only. Which rule a Warden uses is one field on its stage row; the three-stage game keeps today's fight until he has played the new one.
25. Guns fill the guard bar but cannot hurt an open core. Only a ram, stomp, slam or harpoon smash cracks or shatters a chunk. Without this a player who only shoots from range could win.
26. A shatter closes the Warden at once, and breaking its guard cancels a pulse it was charging.
27. A crack pays off only the next time the Warden opens. Bouncing on an open core twice does not shatter it; a smash or a fast ram does.
28. The fight's numbers are not final. Bots show a starting ball breaks this Warden as fast as a grown one, so they will be tuned before he plays, after the new map exists.
29. Enemies arrive as three whole packs drawn without repeats, with no hidden unlock clock. The plated brute and a winch drone arrive once per stage as the third arrival.
30. A hold can bend the ball's path by at most 60 degrees a second and can never slow it. The winch drone's cable snaps past 19 m/s and kicks the ball forward.
31. The slice has no timed events and no vault. Standing activities replace them in the wave after.
32. The objective line reads "Find the Warden", "Break its guard" (or the mounted Warden's own road: the dam's sheet, the flume's line), "Smash the core" or "Roll through a gate". "Grow, then return" shows only after ten seconds of trying leave the guard under half.
33. The scrap number shows only where it is spent. The core pips and first-run sentence callouts are gone with the dial, bars and clock.
34. The map retrofit is a new map file used by the slice only. The three-stage game keeps today's Reach until he has played the new one.
35. Devices belong to a map. The Reach has none until the standing-activities unit places its own.
36. Still owed after wave R2: a hooked enemy leaning toward the ball, hit reactions and each kind's wind-up pose (Sol, one unit per slice enemy).
37. On the Reach the reward gates stand in three fixed slots south of the Warden and open from either side; the workshop bay always docks behind them.
38. No tunnel on an authored line has a roof (w1 and e1 on the Reach).
39. The Reach is in with Kest under his flow-share bar, stated as a miss. The first three seconds on the east lines are a drop and a level roll; the spawn launch (unit ZL) is the fix, with all three lines retuned around it.
40. Surge run is parked for the slice: three standing activities (altar, cache, bounty), not four.
41. In a Warden fight a first find shows its name only. Its card waits for the shared gate. A repeat shows nothing in either discovery mode, and a card or banner that is up when the fight goes live closes.
42. The enemy read sheet is rendered from built wind-up poses and shown after the wind-up wave, not drawn before it. Owner may veto any kind's pose.
43. On the read sheet: the six poses go in as they are; the chaser gets a larger rear-up and, if a state row already means "a hit now breaks this attack", that mark; the warning walls and rings are judged at the sitting; the mag trapper's lifted disc gets a visible link; the brute's arms stay joined to its raised pads. Owner may veto any of these.
44. The Warden's body does not carry its health count. Two rounds put four segments on its jaws, and both times a blind judge could not count them: the chase camera sees the jaws end-on from the front, and light bands on a dark striped body read as panel lines. Neither round is admitted; both branches are kept. The count moves to four lit arcs on the ground round the Warden's foot, which mirror the boss plate's pips and read their colours from it. The body keeps what reads: the jaws splay open, and a segment breaks off on a shatter.
45. The plated brute and the mag trapper each draw one more piece than their old ceiling, for the arm links and the disc link. Cheap at slice enemy counts. Owner may veto.
46. The slice Warden is plating 110, curve 2, and a ram cracks but never shatters an open core. Picked by the written sweep rule and confirmed on the merged wave with growth pays in: a class III ball breaks it in about 25 s, a class I ball in about 86 s, a ranged camper never. A later change to scrap or the map reruns the sweep; it does not move the bands.
47. The beacon is slate while sealed and amber once open, on the ring, the bulb, the edge marker and the HUD row. Mint stays the one colour for "your verb works now".
48. The slice offers twelve parts, each tied to one of its five synergies, and no generated or milestone parts. Reaching a new heft class for the first time opens one upgrade pick once the ball is grounded and no Warden fight is live. A retry keeps the picks and the rewarded class it paid for.
49. Item 45 is half retired: the brute's arms are part of its body mesh, so it is back to three draws. The mag trapper keeps its extra draw for the disc link.
50. The checkpoint script prints the plan lines it cannot check as by-hand rows, and its summary says "bots and fixed checks pass" rather than ADMIT, so it never claims a review or a play verdict.

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
| A starting ball breaks the Warden as fast as a grown one (measured in B0a) | The bands unit's sweep over the gain curve, the contact base, the plating and what shatters, on the retrofitted map |
| The chassis-only Warden is readable but dull | The brawler and skipper bands, then his sitting. Fallback: the guard rack as one extra posture source. |
| Six kinds feel thin after he praised the fuller mechanics | The bola card on the read sheet |
| Prompts nag | Prompts shown per minute in the run log. Aim for six or fewer after minute three. |
| The flow-share bar measures a bot | His own flow share at the sitting |
| The slice table hits a read that still assumes three stages by position | ST's review walks a slice run and lists every positional read; the bots in TM then run on the slice table |
| Several audit claims were never run | The traversal baseline and one run of the word-budget test before R1 is cut |

## 13. Words and screen structure: no slop (ruling cx)

Andrew, 10 Nov 2026: "be sure to un-slop any ui/ux facing gameplay or menu design or text. Im looking at the way anything is presented to the player at all interactions and navigation. Im talkin eyebrow texts, headings and sub heading removals or redesign, and other ways to communicate info to the human".

This section binds every screen, card, tip, toast, caption, prompt and menu in every world. It covers structure as much as wording. The voice in [TONE-BIBLE.md](TONE-BIBLE.md) stays: a joke or an in-world line the tone bible supports is not slop, and neither is a term the game has taught or a number a build choice needs.

**Carrier order.** Before writing a word, ask what should carry the fact. Use the first that works: position, shape, colour (the colour law in section 1), an icon from `src/ui/icons.gd` or a keycap from `src/ui/key_glyphs.gd`, motion, sound, and only then a word. A word never restates what a mark on the same screen already says.

**Structure patterns to remove.**

| Code | Pattern |
| --- | --- |
| S1 | An eyebrow: a small label above a heading that names the category of the thing below it |
| S2 | A heading that restates the screen the player just chose, or a subheading that restates the heading |
| S3 | Heading, subheading and body where one line would do; a section title over a single item |
| S4 | A label and colon that restates the value beside it, or a label on something whose icon, position or colour already says it |
| S5 | A hint, footer or helper line that explains an obvious control, repeats on every screen or never goes away |
| S6 | Words carrying what a shape, colour, icon, bar, position, motion or sound already carries or could carry better |
| S7 | Two voices at once, or one fact shown in two places on one screen |
| S8 | Navigation that names one action two ways (Back, Return, Close), a confirm step that protects nothing, a menu level that holds one item, a label that names the system instead of what the player gets |

**Wording patterns to remove.**

| Code | Pattern |
| --- | --- |
| W1 | Puffery used as filler: epic, ultimate, powerful, unleash, master, legendary |
| W2 | Generic game filler where nothing needs saying: Welcome, Get ready, Good luck, Are you sure? |
| W3 | A line that says how something feels and not what it does. The fix names the mechanism or the number |
| W4 | A term a first-time player does not know and the game has not taught by that point; an internal system name shown to the player ("pilot", never "class") |
| W5 | Lists forced into three, "not just X but Y", "from X to Y", stacked adjectives, an adverb propping a weak verb |
| W6 | Em dashes, mid-sentence colons, Title Case On Every Word, capitals for more than a short mark, decorative symbols, curly quotes, an ellipsis or exclamation mark used as energy |
| W7 | One thing called two names across screens. Pick one name and use it everywhere |
| W8 | Passive or roundabout phrasing where a short imperative fits |
| W9 | A sentence that could appear unchanged in another game |

**How it is checked.** A review of any change a player can read or navigate cites this section by code. `npm run sketch:lint` checks W1, W2, W4, W6, W7 and S8 over the player strings its source list reads (`scripts/sketch-lint-words.mjs`, with a planted bad case for each), taking W7's banned names from [NAMES.md](NAMES.md), the one home for names; S1 to S5, S6, S7, W3, W5, W8 and W9 stay with the reviewer and with a blind read of a still.

## Changes to the plan

- The fight axis and the harpoon-input axis are gone. There is no `--variant=` row.
- Units VH and VD are not built. PK is replaced by EN. TL is absorbed by TM. B0 splits into B0b and B0a. G1, HL, S1 and R3's units are new.
- The order is the one in section 9.
- Wave R1 runs as two waves. R1a is C2, WY1 and TM. R1b is HL, C1 and WY2. C1 follows C2 because a prompt shows only when the ball says the press would succeed (`verb_ready`), and a key is unregistered only after the intent stops reading it. WY is split by system: WY1 is the rules and the facts (the slice's five synergies, `cause_armed`, `cause_fired`, discovery at first firing), and WY2 draws the callout.
- The slice table is the one seam for the slice's content cuts. The five synergies, and later the six enemy kinds, the packs and the event mix, are rows on that table. The default three-stage game keeps everything, so its tests stay intact until Andrew has played.
- S1 (reorder the stages so the Reach is first) is replaced by ST (a slice table chosen at launch). The plan puts the Spillway back as zone 1-1 in M2, so a reorder would rewrite about 35 stage-order tests twice. The sitting launches with `--table=slice`.
