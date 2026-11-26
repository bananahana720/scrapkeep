# Skill bar and ultimate framework

Status: design spec for wave P-B, unit A1 of wave 13. Written 2026-10-10 on `cand/alpha-w13` at `e2e364a`. Nothing here is built or played. Every `file:line` cites that commit; paths without a prefix are under `sketches/core-loop/`. A number marked **start** is a starting value to tune in play. A line marked **Call** is a decision made under the creative charge; section 11 collects them as the veto list.

Settled in the wave-13 session decisions: a 1-2-3 bar plus one ultimate for every pilot; snap-back firing; F retires into slot 2; slot 3 is the line skill (Sable motion, Rivet force, Kest payload, Tarn claw drag, Tally ledger clip, Cannon lane charge); ultimate on Q, charged by performance, scaled by heft class, never spends heft, a full meter lifts the music one layer; the ultimate is a directed set piece on the line; harpoon, Shift, Space and Ctrl stay instant; tree depths 3 and 4 hold ultimate variants; keys 1, 2, 3 reuse `cl_bay_1..3`.

Reads with: `design-v3/PILOTS.md` (A2 fills the per-pilot contracts named here), `design-v3/CUSTOMIZE.md` (A4), the A5 animation spec, [LEGIBILITY.md](LEGIBILITY.md) and [HOOK-CHAIN.md](HOOK-CHAIN.md).

Terms, defined once:

- **Slot**: one ability with its own charges, cooldown and optional gauge (`src/core/ability_state.gd:133-154`).
- **Selected slot**: the slot left click fires. Exactly one is selected at every tick.
- **Cast**: the left click that commits the selected slot.
- **Snap-back**: the selection returning to slot 1.
- **Verb chip**: a small unnumbered readout beside the bar for Shift and Ctrl. It is never selectable.
- **Line skill**: slot 3, the pilot's own flavour sent along the harpoon line.
- **Load**: a line skill cast with no line standing, waiting for the next bite.
- **Meter**: the ultimate's charge, 0 to 100 points.
- **Set piece**: the ultimate itself, a directed ride from A to B with the pilot's tech firing on the way.
- **Heft class**: I to V, from `HEFT_CLASS_AT := [1.0, 1.5, 2.2, 3.2, 4.6]` (`src/core/run_state.gd:21`).

## 1. Slot model

### What exists today

- Four slots: weapon, movement, special, smash (`src/core/ability_state.gd:11-15`). Their keys are LMB, RMB or Shift, F and Ctrl (`:19-20`; `src/movement/player_ball.gd:480-481` picks RMB or Shift for the movement slot).
- The F special is a hold-gauge-release shot for all six pilots: every special row has `charge_max` (`ability_state.gd:51-74`). `_step_special` runs it (`src/combat/combat.gd:1265-1310`). A second F press cancels (`:1275-1279`); RMB during a charge cancels (`player_ball.gd:463-465`).
- The only selection model is Tally's card bays. Keys 1, 2, 3 set `intent.bay_pick` (`src/movement/intent.gd:45`, `:130-133`); the pick is sticky and runs on the next LMB press (`combat.gd:1620-1644`).
- The harpoon has no slot. Its readiness is the reticle ring (LEGIBILITY.md:77).

### The new bar

| Place | Slot id | Key | Holds | Fire shape | Selectable | Drawn as |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `weapon` | 1 (home) | the class weapon, `weapon_id` | auto, tap or gauge, unchanged | home | numbered slot |
| 2 | `special` | 2 | today's F special, `special_id` | gauge (all six today) or tap | yes | numbered slot |
| 3 | `line` (new) | 3 | the line skill, `line_id` (new) | tap, or gauge if the row has `charge_max` | yes | numbered slot |
| chip | `movement` | Shift | the Shift verb: Rivet sprint, Kest blink, Tarn claw pull, Tally surge, Cannon recoil, Sable boost | unchanged | never | verb chip |
| chip | `smash` | Ctrl | the smash flavour | unchanged | never | verb chip |
| Q | `ultimate` (new) | Q | the ultimate, `ultimate_id` (new) | press | never | meter arc at the reticle |
| none | harpoon | RMB | the shared harpoon | unchanged | never | reticle ring |

Data shape (B1 owns it):

- `SLOTS := [WEAPON, MOVEMENT, SPECIAL, SMASH, LINE]`. LINE is appended so the first four keep their order.
- `BAR := [WEAPON, SPECIAL, LINE]`, `CHIPS := [MOVEMENT, SMASH]`, `NUMBER := {WEAPON: 1, SPECIAL: 2, LINE: 3}`.
- `ULTIMATE := "ultimate"` stays out of `SLOTS`. Its charge is the meter, not a cooldown, and `_recharge` refills any slot whose cooldown is 0 (`ability_state.gd:293-297`).
- `SWAPPABLE := SLOTS + [ULTIMATE]`. The tree validator checks swaps against `SLOTS` today (`src/core/upgrade_tree.gd:292-295`); it reads `SWAPPABLE` instead.
- Class rows gain `line_id` and `ultimate_id` beside `weapon_id` to `smash_id` (`src/core/class_def.gd:25-28`).

### What "selected" means

Left click (`cl_fire`) acts on the selected slot and nothing else. Weapon is home: it is selected at run start and after every snap-back. No other key reads the selection. RMB, Shift, Space, Ctrl, E and Q behave the same whatever is selected.

### The router

One function, `player_ball._route_slots()`, runs right after `source.poll(intent)` (`player_ball.gd:419`) and before `_read_grammar()` (`:423`):

1. While a set piece runs, swallow everything but `move`, `jump_pressed` and `ultimate_pressed` (section 4).
2. Apply `intent.slot_pick` (section 2 has the refusals).
3. Route left click. Selected `special`: OR `fire_*` into `special_*`. Selected `line`: OR `fire_*` into `line_*`. Then clear `fire_*`.
4. Combat reads `special_*` in `_step_special` unchanged and `line_*` in a new `_step_line` beside it.

The router ORs into the target fields, the way `_read_shift` ORs into `movement_*` (`player_ball.gd:493-495`). A scripted source that writes `special_pressed` directly still drives a kit test. Combat's weapon dispatch (`combat.gd:1031-1047`) never sees a click meant for slot 2 or 3. B1 checks that the player's physics tick runs before combat's, so combat reads the routed fields on the same tick.

### Snap-back timing

| Event | Snaps back | Reason id | Why |
| --- | --- | --- | --- |
| The cast commits: a tap on its press, a gauge on its release or on the grace auto-fire (`ability_state.gd:108-119`) | yes, that tick | `cast` | the rule |
| The selected number pressed again, or 1 pressed | yes | `deselect` | the undo gesture; the same hand as today's second-F cancel |
| RMB cancels a charging gauge (`player_ball.gd:463-465`) | yes | `cancel` | a cancelled cast ends the intent |
| 3.0 s (start) pass with no cast begun | yes | `timeout` | a stale pick must never eat a later click; the timer pauses while a gauge charges and while the game is paused |
| The harpoon fires (RMB) | no | | "pick 3, bite, click" is the line-skill combo (section 3); the harpoon and the pick are different hands |
| Damage taken, or a hostile hold starts | no | | the hit already costs; losing the pick as well doubles the cost (principle 1, momentum is sacred) |
| The ultimate starts | yes | `ultimate` | inputs are swallowed during the set piece |
| Death, retry, `stage_entered`, `stage_content_cleared`, run end | yes | `reset` | `refill()` already drops gauges at these points (`player_ball.gd:172-173`, `ability_state.gd:258-265`) |
| Sable mounts or dismounts | no | | mounted casts stay legal (the Auto Gauge knob, `combat.gd:1273-1274`) |

Two input rules keep one click to one action:

- **Edge rule.** A cast starts only on a left-click press (`fire_pressed`) on a tick when its slot is selected. A pick and a press on the same tick count, with the pick applied first. A click already held when the pick lands does not cast, so nobody fires a special by surprise while spraying the weapon.
- **Release latch (Call).** After any snap-back with left click still down, the weapon ignores left click until it comes up. A tap line skill commits on the press. Without the latch, Rivet's held click would roll straight into weapon fire and Kest's would start a sticky gauge she did not ask for.

### Native fire shapes under one left-click rule

| Shape | Rows today | Press | Hold | Release | Commits |
| --- | --- | --- | --- | --- | --- |
| auto | `arc_caster`, `rapid_laser`, `claw_sweep`, `cannon_lane` (slot 1) | first volley | one volley per interval | stops | every volley; slot 1 never snaps |
| tap | Tally's cards (`combat.gd:1631`) | casts | nothing | nothing | on press |
| gauge | every special row; `sticky_charge` on Kest's slot 1 | begins the gauge and draws its committed geometry (`combat.gd:1293`) | fills | fires at the fraction reached | on release, or at full plus 0.5 s grace |
| channel | reserved, no row yet | begins | sustains | ends | on release |

`_step_special` returns when a row has no gauge (`combat.gd:1270`). B1 adds the tap path: a special row without `charge_max` fires on `special_pressed`. Tally's gather plate needs it.

### Cooldown and charge readouts

Unchanged in kind: the petrol wedge, the pips and the ready swell with its sound (`src/ui/ability_bar.gd:8-16`, `:57-62`, `:76-82`). Slot 3 uses the same drawing. Chips use it at 0.75 scale. Sable's chip shows her boost cooldown (`state.boost_cooldown`, `player_ball.gd:499-502`): her movement row is the grapple, which is the harpoon, and the harpoon has no slot. `slot_key(MOVEMENT)` returns Shift for every pilot.

### Tally's deck, re-cut

Her bays retire. Following the plan's creative-charge line: slot 1 `balance_due`, slot 2 `gather_plate` (tap), slot 3 `link_clips` (her ledger clip, as the line skill), ultimate `plate_return` (P-C builds it). Pressure stays one pool. A row with `pool: "weapon"` spends slot 1's charges, which `_spend_card` already does (`combat.gd:1696-1700`). B1 does this mechanical re-cut so Tally keeps working when `bay_pick` goes. Plate return is off her kit between B1 and P-C (veto list).

## 2. Misfire and edge rules

| Case | Result | Cue | Spent |
| --- | --- | --- | --- |
| Pick a cooling slot | refused, selection unchanged | `verb_failed("select", "cooling")`: the slot frame shakes 3 px for 0.15 s with a slate flash and the dull tick | nothing |
| Pick an unavailable slot | refused | `verb_failed("select", "unavailable")` | nothing |
| Cast with no valid target (an aimed row, or a row whose `can` fails) | no cast; selection and timer kept | today's `gauge_cancelled(id, "blocked")` (`combat.gd:1300-1302`), plus `verb_failed(slot verb, "no_target")` for a tap | nothing |
| Cast while cooling | cannot happen, picks are refused; a shared pool emptied by slot 1 while 2 or 3 is selected refuses the cast | `verb_failed(..., "cooling")` | nothing |
| Line skill cast while a load waits | refused | `verb_failed("select", "loaded")` | nothing |
| Another number pressed mid-gauge | gauge cancelled; the new slot selected if ready | `gauge_cancelled(id, "swap")` | nothing |
| Same number pressed mid-gauge | gauge cancelled, snap to 1 | `gauge_cancelled(id, "cancel")` | nothing |
| 1 pressed mid-gauge | gauge cancelled, snap to 1 | `gauge_cancelled(id, "cancel")` | nothing |
| Kest's slot-1 sticky gauge charging when 2 or 3 is pressed | her gauge is dropped first (`cancel_gauges`, `ability_state.gd:315-321`) | `gauge_cancelled` | nothing |
| Death or retry mid-selection | selection to 1, gauges dropped, load cleared, set piece aborted; on retry the meter returns to its stage-entry value, the pattern `run_state.gd:529` and `:588` use for the run | none | n/a |
| Pause or held notes | selection, timeout, load timer and meter freeze (the tree pauses, `src/game.gd:432`) | none | n/a |
| Q with the meter short of full | refused | `verb_failed("ultimate", "uncharged")`: the meter arc shakes 3 px and the dull tick plays | nothing |
| Q while busy: in the bay, a ceremony, a world launch in flight, a boss intro, a set piece already running | refused | `verb_failed("ultimate", "busy")` | nothing |
| Q during a hostile hold | allowed; the hold breaks as `hold_broken(kind, "ultimate")` (`src/core/game_events.gd:130`) | the hold's own break cue | the meter |

The new verbs carry fail cue ids `verb_fail_select` and `verb_fail_ultimate` in their `Bindings.VERBS` rows.

**Gamepad (ships after alpha; the mapping is left in the table now).** D-pad left, up, right pick 1, 2, 3 (the existing `cl_bay` pad rows, `src/core/bindings.gd:50-52`). RT casts. LB is the ultimate, freed when `cl_special` retires (`bindings.gd:41`). LT harpoon, B Shift verb, X haul, A jump, Y interact, RB retry, Start pause stay. D-pad down stays free. Known cost: a D-pad pick takes the right thumb off the camera stick; acceptable until a pad pass.

## 3. The line skill hook

### Three options, one pick

| Option | For | Against |
| --- | --- | --- |
| Fire a flavoured harpoon of its own | one press | two lines on screen: breaks one-row-per-meaning for the line (LEGIBILITY.md:56) and the one `ChainState` (HOOK-CHAIN.md:21) |
| Arm the next harpoon only | RMB keeps its key | a dead cast while a line already stands |
| Act on the current latch only | reads directly | a dead cast with no line, which is most of the time |
| **Act on the current line; with no line, load the next bite** (picked) | never a dead cast; one line; RMB stays instant and plain | one hidden state, the load, which needs its own read |

The pick matches principle 23, "each pilot sends their own thing along the line" (Sable motion, Rivet force, Kest payloads).

### The rule

1. **A line stands** (`kit.hooked`): the flavour fires now along it. A body latch runs `on_body`; a world latch runs `on_world`. During a committed smash (`LINE_SMASH`) `on_body` fires and the haul continues.
2. **No line stands**: the cast loads. The next RMB bite within 4.0 s (start) carries the flavour and fires it on the latch.
3. A plain RMB press with nothing loaded is today's harpoon, untouched. A load never delays a bite.
4. A dry fire keeps the load. HOOK-CHAIN's miss cost already applies (0.6 s, `src/combat/chain.gd:24`).
5. A load that runs out emits `line_skill_expired` and refunds nothing. The cooldown started at the cast, so half of the 8 s cooldown is already gone.
6. The load shows on the reticle (the flavour's icon inside the ring, a ring that drains over 4 s) and on the hook head in the class colour. Class colour is identity, not a meaning colour (LEGIBILITY.md:37).

### With HOOK-CHAIN

- A loaded bite is a bite: +1 on an enemy, a pivot on a wall, through the same `chain.link` call (`player_ball.gd:401`). The flavour adds no link.
- Flavour damage multiplies by `chain.multiplier()` (`chain.gd:49`) at the moment it fires: x1.0 at combo 1, x2.5 at the cap of 6 (`chain.gd:19-20`). One source for every chain payout.
- The flavour neither ends nor extends a chain. If its effect puts the ball on the ground, ground contact ends the chain as it always does (HOOK-CHAIN.md:15). The sheet says whether it does.
- A line cutter cuts the line, not the load. A flavour that already fired stays fired.
- The line skill cooldown starts at 8.0 s (start), longer than the specials' 5 to 6 s, so slot 3 seasons the harpoon rhythm and does not replace it.

### What each pilot sheet fills for its line skill

| Field | Content |
| --- | --- |
| `id`, `icon`, name | an `ABILITIES` row id, an icon id `ab_<pilot>_line`, a name of two words or fewer |
| fire shape | tap, or a gauge with `charge_max` (the fraction scales the flavour) |
| `cooldown`, charges | default 8.0 s, 1 charge |
| `on_body` | what happens to the latched enemy and to the ball, with damage, knock and range |
| `on_world` | what happens on a wall or post latch; default `reel_burst`, +8 m/s toward the anchor once |
| `load_seconds` | default 4.0 |
| chain scaling | uses `chain.multiplier()` for damage (default yes) |
| committed geometry | the shape drawn before it lands, which is exactly what it hits (TADR-008, `adr/TADR-008-ability-contract.md:38`) |
| ground contact | whether its effect grounds the ball (ends a chain) |
| Warden and boss read | what it does to a closed guard, an open core and a boss; a resisted effect plays a visible "nope" and leaves the windows alone (principle 14) |
| sound | a row and its motif note; it rises with the chain like `chain_link` |
| card and codex | a card line of 8 words or fewer, a discovery card (hint, clue, text) |
| clip | the `cast_line` clip and its length (A5 owns the clip). The pilot throws the slot 3 lever in the bank beside the right yoke (ROSTER-LOOK.md 0.7, cockpit controls) |

### Fit check of the six settled flavours

These only show that the contract holds all six. PILOTS.md owns the finals.

| Pilot | Flavour | `on_body` seed | `on_world` seed |
| --- | --- | --- | --- |
| Sable | motion | the ball surges along the line and vaults off the target | slingshot release off the anchor |
| Rivet | force | a pulse runs down the cable and knocks the target back hard | yank: the ball snaps to the anchor at sprint speed |
| Kest | payload | a sticky charge rides the cable and sets on the target | the charge sets on the wall as a mine |
| Tarn | claw drag | the target is dragged to the ball and clamped | the claw rakes the wall, a short reel |
| Tally | ledger clip | `link_clips` with the latched enemy as the first clip (`combat.gd:1734-1751`) | a clip post on the wall that links passers-by |
| Cannon | lane charge | a lane fires along the cable through the target | a lane fires from the anchor along the aim |

Until P-C, B1 gives every pilot but Tally one shared placeholder row, `line_reel`: `on_body` yanks the enemy 4 m toward the ball for 10 damage times the chain multiplier; `on_world` is `reel_burst`.

## 4. The ultimate

### The meter

| Source | Signal it reads | Points | Limit |
| --- | --- | --- | --- |
| weapon hit | `enemy_struck` with kind from a weapon | 0.25 each | 0.4 points per second from weapon hits |
| contact: ram, stomp, slam strike | `enemy_struck` with a contact kind | 2.0 each | once per enemy per 0.5 s |
| harpoon smash landing | `harpoon_smashed` | 5.0 times `chain.multiplier()` | none |
| chain link on an enemy beyond the first | `line_state_changed("chain_link")` | 2.0 each | once per enemy per 1.0 s |
| near miss | `near_miss` (`game_events.gd:144`) | 4.0 each | the watch's own grace; 0.05 points per second from near misses, holding one (4.0) |
| kill | `enemy_killed` | 1.0 each | none |
| Warden stagger | `posture_changed` with `staggered` rising | 8.0 | once per stagger |
| Warden chunk shatter | the chunk-shatter event | 12.0 | once per chunk |
| speed, fast tier | `player.state.tier` (`src/movement/speed_tier.gd:5-8`) | 0.5 per second | none |
| speed, blazing tier | same | 1.2 per second | none |

2026-10-11 (w13 B3b): near misses got a rate limit (0.05 points per second, holding 4.0) and a chain link pays once per enemy per 1.0 s, because B4's bot measured the camper's median first fill at 41.1 s over seeds 1 to 16 (69 to 95 of its first 100 points from near misses) and Tally's lost Brindle fights earned 852 to 2719 chain-link points a run biting one boss; measured after: camper median 183.3 s, completionist 63.6 s (was 54.3 s), Tally and Sable skipper seeds 1 to 4 won 4 of 4 each under the 330 s child cap, and the Cannon won 4 of 4 uncapped (game time 402 to 447 s) but was undecided under the cap at wave load (coordinator wording at merge; the capped Cannon run is owed at wave close with the load under 32).

- Cap 100 points (start). No decay. Taking damage costs nothing. Overflow is lost.
- The meter starts at 0 each run and carries across stages and worlds. A retry restores its stage-entry value.
- It does not fill during a set piece, in the bay, or during a ceremony.
- Target fill times, checked by bots in B4: a chaining player 45 to 60 s of play, an average fight 75 to 90 s, the hold-fire camper at least 180 s. The near-miss and weapon limits are what keep the camper slow.
- **Harmonized with BIBLE.md:400**, which says the ultimate "unlocks through play during world one". The slot is on the bar from the drop, but it starts empty every run, so the first one is earned by playing. No separate unlock gate.

### Ready cue: one fact, every layer

Every layer reads `abilities.meter.full()` or the `ultimate_ready` signal, so they cannot drift apart.

| Layer | At full |
| --- | --- |
| shape | the meter arc closes into a full ring |
| colour | the fill is the class colour (identity); the rim turns live mint, "your verb works now" (LEGIBILITY.md:23). Where the class colour is the live mint itself (Sable, `class_def.gd:13`), the fill draws in sand-light `bare_metal` instead, so mint still means only "ready" (section 12) |
| motion | a 1 Hz breathe; the hook lock pulses at 2 Hz (LEGIBILITY.md:65), so the two never read alike |
| sound | `ultimate_ready`: the class motif's three notes an octave up and a small bell, in the live key (`KEYED_SOUNDS`, `src/presentation/audio.gd:85-90`); the rice-cooker end-of-cycle tune is the reference |
| music | one layer lifts at the next bar line (below) |
| pilot | the `ult_ready` clip |
| body | the working device on the weapon housing glows brighter in the class colour (the ring band stays bone). It is the only place a mecha glows (ROSTER-LOOK.md 0.7, colour discipline). The P-D mechas read the signal |
| words | the Q keycap and the word ULTIMATE for the first 3 ready states on a profile, then the keycap alone |

### Payoff by heft class

The ultimate never spends heft and never knocks scrap loose. Only its payoff grows with class.

| Heft class | I | II | III | IV | V |
| --- | --- | --- | --- | --- | --- |
| damage multiplier | 1.00 | 1.15 | 1.30 | 1.45 | 1.60 |
| arc reach | 40 m | 47 m | 55 m | 62 m | 70 m |
| landing radius | 6 m | 7 m | 8 m | 9 m | 10 m |

The line path's reach stays the harpoon's 45 m (`rope_range`, `src/movement/tuning.gd:18`) at every class, so the lock brackets stay honest.

### The set piece contract

**Phases.** Wind-up 0.35 s, flight, landing strike, recovery 0.25 s. It passes TADR-008's four tests for a commitment beat (`adr/TADR-008-ability-contract.md:40`): the player starts it, the row declares it, it shows at commitment, and full control returns at its end with no stun or debt.

**Choosing B.** At the Q press the path is planned once with the harpoon's own target query (`src/movement/harpoon.gd:20-29`), in this order unless the pilot's sheet reorders `paths`:

1. A line stands: path `line` to its anchor. A body anchor is tracked; if the body dies mid-flight, the path keeps its last point.
2. The harpoon has a lock or a reach point: path `line` to it (a new line fires at departure).
3. A world rail entry within 12 m of the aim point: path `rail`.
4. Ground at the aim point within the class's arc reach: path `arc`.
5. None of these: the fallback `hop`, straight up 8 m and down on the same spot over 1.6 s. A full meter never meets a dead Q.

**Commit and draw.** The planned path is drawn at wind-up in the live colour along its whole length, with the steering corridor as two faint rails. The flight follows exactly that path (TADR-008:38, one query for the preview and the act). A collision on the way ends the flight early as a landing at the contact point.

**Carrier.** The flight rides a `RideRail` (`src/world/ride_rail.gd`), in `LINE` or `ARC` mode (`:41`, `:77`). These are the rail maths the cannon, trebuchet, geyser and grapple line already use. They hold the ball to the drawn path and hand back the banked speed on release (`:5-14`, `:130-132`), so the set piece can keep or gift speed and never cut it. The stepping loop follows `world.gd`'s `_hold_ride` (`src/world/world.gd:506-512`).

**Line cut cause.** `set_velocity_now` cuts the harpoon line with the cause "launched" (`player_ball.gd:297-299`), and `_publish_end` would publish that as a rust "broke" twang (`:614-623`). B3 cuts with the cause `ultimate`, which publishes nothing, as a landing does. The set piece draws its own cable from the ball to B.

**Duration.** Flight seconds = path length / 18 m/s, clamped to 1.6 to 3.2 s, then rounded to whole beats of the music playing, so the landing falls on a beat. With the music off, 2.4 s. The wind-up is fixed so Q never feels late; only the flight stretches. This un-parks principle 6's idea that "contraption flight times land you on the downbeat".

**Ball control.**

| Input | During wind-up | During flight |
| --- | --- | --- |
| move (WASD) | none | steer up to 3 m either side of the path |
| look | aims the tech | aims the tech: targets within 25 degrees of the reticle come first |
| Space | none | bail: leave the path now with the current velocity |
| Q | recall: cancel with a full refund | none |
| everything else | swallowed silently | swallowed silently |

The player picks B by aiming and steers on the way. That keeps BIBLE's ultimates "a player-chosen path through a fight" (BIBLE.md:294) and "actively steered rather than ... a screen-filling random event" (BIBLE.md:357).

**Tech along the way.** One volley per beat of the flight, at up to 3 targets within 10 m of the ball. Base 12 damage per target per volley (start), times the heft multiplier. The pilot sheet names the volley's pattern.

**Peak.** The middle beat of the flight: the pilot's signature beat (`ultimate_peak`), the `ult_strike` clip with both hands on the copper lap bar (the Q control), a stinger.

**Landing strike.** Base 60 damage (start) times the heft multiplier, within the class's landing radius, knock 26 (the slam's `SLAM_KNOCK`, `src/movement/augments.gd:68`). The landing pays the chain: it multiplies by `chain.multiplier()` and then ends the chain as a paid smash does. During the flight the chain clock is frozen: no links, no grace running out. **Call:** build a chain, cash it in with the ultimate.

**Defence.** From the wind-up until recovery ends: damage taken x0.2, no knockback, no hostile hold can start, no scrap knocked loose, and health cannot drop below 1.

**Camera.** Distance x1.25, field of view +8 degrees, looking 0.3 s ahead along the path, easing back over 0.4 s after the landing. Reduced motion keeps the distance change and drops the field-of-view change and the shake.

**Music.**

| Moment | Synth band | ACE band |
| --- | --- | --- |
| meter full | `set_ultimate_lift(true)` adds one intensity step at the next bar, the same step `set_heft_lift` uses (`src/presentation/music_engine.gd:821-825`, `:1550`); add a layer, never swap one (MUSIC-GEMS.md:21, G11) | one pressure step through `set_pressure` (`src/presentation/ace_sequencer.gd:274-276`) |
| wind-up | `start_build(flight_seconds, true)`, the launch build (`music_engine.gd:1021-1027`) | inside a Warden break's set piece the band holds through the flight, as a Warden launch does; in a stage (roaming or a Warden fight) the recorded band stops on the beat and the synth band's build takes the flight (`audio.gd` `_on_ultimate_started`); a pilot's ultimate in Brindle's fight leaves the music alone |
| peak | the pilot's motif quoted as a stinger on the peak beat | the same stinger on the ACE grid beat |
| landing | `drop_now(4, 0.85)` on the landing beat (`audio.gd:1625-1640`): the launch is the build and the landing is the drop (MUSIC-GEMS.md:19, G9) | in the set piece, handover on the beat, as `_land_drop` does; in a stage the synth band's drop plays alone |
| after | the lift releases with the drop; the meter is empty | the pressure step releases, and the stage's recorded band comes back on the bar after the drop: the stage's own take while roaming, the fight's sections inside a sealed Warden fight. A recall or a bail brings it back at the next bar. Nothing comes back after a death or a stage's end, when the Warden breaks or the player launches before the drop is over (the break and the launch have their own music), or when the band the ultimate stopped was a boss's or a champion's (`audio.gd` `_ace_return`, `tests/ultimate_band_return_test.gd`) |

**Cancel rules.**

| Cancel | When | Meter |
| --- | --- | --- |
| Q again (recall) | wind-up only | full refund |
| Space (bail) | flight | spent; no landing strike; the volleys already fired stand |
| collision on the path | flight | spent; the landing strike fires at the contact point |
| stage change, death, retry, run end | any time | spent; restored on retry with the rest of the stage-entry state |

**Wardens and bosses.** Principle 14: the boss resists with a visible "nope" and its windows stay as they are.

| Target | Tech volleys | Landing strike | Read |
| --- | --- | --- | --- |
| Warden, guard closed | fill posture as gun bolts do (base 1.5 per hit, LEGIBILITY.md:85) at half damage | one contact at most: up to 45 posture once, like a harpoon smash; it cannot crack or shatter. **The 45 caps the whole set piece, volleys and landing together** (section 12) | slate sparks and the low clank, the glance read (LEGIBILITY.md:50) |
| Warden, core open | as above | counts as a harpoon smash on the core: it shatters the chunk (LEGIBILITY.md:87) | the normal shatter |
| Warden as anchor (wave K-F) | a `line` path may end on a Warden anchor; landing on it is the drop finisher | as above by guard state | as above |
| Brindle, the Waking, the Mind | x0.5 damage | x0.5 damage; phase windows untouched | a brace pose and the "nope" glyph on the boss |

**Not allowed.** In the bay, during a ceremony, while a world launch flies, during a boss intro, inside another set piece. Mounted Sable may fire it: the mount ends and the path leaves from the mount point with the banked speed.

### What each pilot sheet must specify for its ultimate

1. `id`, a name of two words or fewer, an icon id `ab_<pilot>_ult`.
2. `paths`: preference order over `line`, `arc`, `rail`; any reach override.
3. Tech: the volley pattern on each beat, its target rule, damage per volley before the heft multiplier.
4. Peak: what happens on the middle beat.
5. Landing: shape, radius, damage, knock, and anything beyond the default posture rule.
6. Heft scaling beyond the default table, if any.
7. Music: the motif quoted at the peak (a `Harmony.MOTIFS` id) and any cadence choice at the landing.
8. Mecha: how the weapon ring and the hub modules read ready, wind-up and flight. Only the weapon's working device glows (ROSTER-LOOK.md 0.7). The full-span lattice is an optional extra (ROSTER-LOOK.md 0.5).
9. Clips (A5 confirms): `ult_ready`, `ult_windup`, `ult_strike`, `ult_recover`. Clip lengths come from PILOT-CLIPS.md section 1.2, not from this page. The hands take the copper lap bar, the Q control, at wind-up and hold it through the flight in the shared `ult_ride_loop` (PILOT-CLIPS.md section 1).
10. Depth 3: two variant rows, each changing the path type or the tech, not only a number.
11. Depth 4: modifiers on those variants (knob names below).
12. Warden and boss notes beyond the defaults.
13. Card line, discovery card and run-log id.

### Tree depths 3 and 4

- `depth_cap(world_index)` is `clamp(world_index + 1, 2, 4)` (`upgrade_tree.gd:119-120`, with `DEPTHS := 4` at `:31` and `WORLD_ONE_DEPTHS := 2` at `:36`). World two opens depth 3 and world three opens depth 4, so by world three a build has changed its set piece.
- A depth-3 node swaps the ultimate with the existing op shape: `"swap": {"ultimate": "<variant id>"}` (the tree's ops are listed at `upgrade_tree.gd:46`).
- A depth-4 node turns knobs with the existing `"knob"` op. New knob names: `ult_encore` (a second leg if a target sits within 30 m of the landing), `ult_beats` (+2 flight beats), `ult_radius` (+2 m landing radius), `ult_volley` (+1 target per volley). A pilot may add at most one knob of its own (section 12).
- Depths 1 and 2 stay on slots and movement.

B3 ships one placeholder ultimate for all six, `ult_default`: paths line then arc, the pilot's own weapon pattern as the tech, the default landing. P-C replaces it per pilot.

## 5. Readability

### The bar

```
                 LMB glyph rides the selected slot
                         v
   [ 1 ]   [ 2 ]   [ 3 ]        [Shift] [Ctrl]     chain 4
   weapon  special line          chips, 0.75 scale
```

- The numbered slots sit where the four slots sit today. The chips sit 24 px to the right at 0.75 scale with no number. The chain counter moves to the right of the chips (today it sits right of the bar, `src/ui/hud.gd:711`). `hud.gd:702` sizes the bar for at least 4 slots; B2 sizes it for 3 slots plus 2 chips.
- **Selection is not the active frame.** Active is a doubled frame, a 3 px lift and the class tint (`ability_bar.gd:132-134`, `:155-161`). Selection is a mouse glyph (the LMB picture, no letters) above the selected slot and an inverted number keycap (sand fill, charcoal digit). A gauge charging on slot 2 shows both at once and stays readable.
- Form mirrors function: the mouse glyph is literally where left click goes. A pick slides it there in 0.12 s; a snap-back slides it home. Its underline drains over the 3 s timeout.
- A refused pick shakes the slot 3 px and flashes slate. The glyph does not move.
- A loaded line skill shows on slot 3 as a small hook badge in the class colour until the bite or the expiry.

### The ultimate meter

- An arc around the reticle, outside the hold-gauge ring the reticle already fills (`hud.gd:939-944`): radius equal to the gauge ring's plus 10 px, 4 px thick at 1080p, 270 degrees from seven o'clock round to five o'clock, filling clockwise.
- The gap at six o'clock holds the Q keycap (20 px) once the meter is full. Below full the gap stays empty, so Q costs no word until it means something.
- During the set piece the arc drains with the flight's progress, and the bar dims to 40 percent because its keys are swallowed.

### Prompts (LEGIBILITY.md section 5)

- New prompt verb `ultimate`: the Q keycap at the reticle, on ticks a press would succeed. It retires after 3 uses, returns after a refused press, after 90 s unused and at the first full meter of each run (the rules in `src/ui/key_glyphs.gd:30-38`).
- `select` gets no prompt. The bar's own keycaps show it.
- The load has no words. Its read is the reticle icon and the hook badge.
- Word budget, 25 in a fight (LEGIBILITY.md:114). The bar draws four keycap words today; the new bar draws five (1, 2, 3, Shift, Ctrl), plus Q only when full. The mouse glyph has no letters. B2 re-runs the fight-case budget test and trims if it runs over.

### Class card

One row of the bar as it plays, `[1 weapon] [2 special] [3 line skill]  [Q ultimate]`, each with its icon and one line of 8 words or fewer from PILOTS.md. A second row of chips: `[RMB harpoon] [Shift verb] [Ctrl smash]` and the Space and E extras from `src/ui/class_kit.gd:50-54`. `SLOT_VERBS` (`class_kit.gd:57`) gains `line: "select"` and `ultimate: "ultimate"`.

### Field notes (`src/ui/field_notes.gd:53-63`)

- Retire the `special` row.
- Add `select`: "1, 2, 3 pick what left click does: 1 the weapon, 2 the special, 3 the line skill. A cast, or 3 s without one, returns to 1".
- Add `ultimate`: "Q when the ring round the crosshair is full: ride a line or a launch to where you aim; your tech fires on the way. Space bails out".
- `fire` becomes: "left click fires the picked slot: the weapon unless you picked 2 or 3".
- `harpoon` gains: "with a line skill loaded, the next bite carries it".
- The pause row (`field_notes.gd:69`) names X (hold) for quit.

### Pause menu

Quit moves off Q (`src/ui/pause_menu.gd:46`, `:355-357`) to X held for 0.6 s (start), with a fill ring like the retry hold. **Call.** Q is now the most-pressed key in a fight, and muscle memory pressing it on an open menu must never end a run. X is not a gameplay key on the keyboard.

## 6. Bindings delta

| Action | Verb in `Bindings.VERBS` | Intent field | Keyboard | Mouse | Pad | Change |
| --- | --- | --- | --- | --- | --- | --- |
| `cl_bay_1` | `select` (new) | `slot_pick = 0` | 1 | none | D-pad left | moves from `EXTRA_ACTIONS` (`bindings.gd:50`) into the new verb |
| `cl_bay_2` | `select` | `slot_pick = 1` | 2 | none | D-pad up | same (`:51`) |
| `cl_bay_3` | `select` | `slot_pick = 2` | 3 | none | D-pad right | same (`:52`) |
| `cl_ultimate` (new) | `ultimate` (new) | `ultimate_pressed` | Q | none | LB | new; glyph `key_q`, fail `verb_fail_ultimate` |
| `cl_special` | `special` | none | — (retired; `bindings.gd:26`, `keys: []`) | none | — | **retired** in `bindings.gd`; `F` now triggers active items (`cl_active`, `bindings.gd:36`, pad D-pad Down), while `special_*` stay as routed outputs |
| `cl_fire` | `fire` | `fire_*` | none | LMB | RT | reading becomes "cast the picked slot" |
| `cl_harpoon` | `harpoon` | `harpoon_*` | none | RMB | LT | unchanged; refused during a set piece |
| `cl_boost` | `boost` | `shift_*` | Shift | none | B | unchanged; never selectable |
| `cl_haul` | `haul` | `brake_held` | Ctrl | none | X | unchanged |
| `cl_jump` | `jump` | `jump_*` | Space | none | A | gains the reading "bail" during a set piece |
| `cl_interact` | `interact` | `mount_*`, `interact_pressed` | E | none | Y | unchanged; Sable's pylon mount stays on E (below) |
| pause menu quit | screen key | none | X held 0.6 s (was Q) | click | accept on the focused row | moved |

Screen-level keys that stay, because the game is paused or a screen owns the input: settings tabs Q and E (`src/ui/settings_pages.gd:434-437`), field-notes pages Q and E (`field_notes.gd:457`, notes pause the tree at `game.gd:407-409`), the title's pilot pick 1 to 9 (`game.gd:710-712`), the companion panel 1 to 6 (`src/ui/companion_panel.gd:182`), the workshop 1 and 2 (`src/ui/workshop.gd:477-480`), and the hot-wire screen's F to recycle (`src/ui/hotwire_screen.gd:222-224`).

Table edits beside the actions:

- `STATES` (`bindings.gd:61`) gains `set_piece` as the highest state.
- `READS` (`bindings.gd:66-76`) gains `select: {any: "pick", charging: "swap", set_piece: ""}` and `ultimate: {any: "ultimate", set_piece: ""}`. `fire` gains `charging: "release"` (it inherits the line `special` had) and `set_piece: ""`. `jump` gains `set_piece: "bail"`. Every other verb reads `""` in `set_piece`. The `special` row goes.
- `verbs_on` (`bindings.gd:128-137`) keeps one verb per key: 1, 2, 3 belong to `select`; Q to `ultimate`.
- The rebinding page (`settings_pages.gd`) lists `select` (three keys) and `ultimate`.

**E stays world interact, and Sable's pylon mount stays on E.** The plan's table said "F and E retire into slots 2 and 3"; the unit brief narrowed that to F and left E open. The mount stays on E for three reasons. It acts on a world object, a steep face, which is what E means everywhere (`player_ball.gd:664-674`). It is time-critical: a mount banks the ball's speed, and a pick plus a click would add a key and a selection to it, against principle 1. It is already prompt-driven at the face (`key_glyphs.gd:21-22`), so it needs no slot readout. Her slot 2 keeps its pylon tie: planting still fires the discharge free (`plant_discharge`, `ability_state.gd:51`).

## 7. Signals and data contract

### New `GameEvents` signals

Every signal gets a row in `src/core/event_kinds.gd` `ROWS` (`:30`) and an owner line in `CONTRACTS.md`, as `game_events.gd:3-7` requires. B1 declares all of them, including B3's, so only one unit edits the bus.

| Signal | Owner | Meaning | Row: group, shape, sound |
| --- | --- | --- | --- |
| `slot_selected(slot: String, reason: String)` | `player_ball.gd` (the router) | the selection changed; reason `pick` or a snap reason (`cast`, `deselect`, `cancel`, `swap`, `timeout`, `ultimate`, `reset`) | combat, square, `ui_tick` at -12 dB, priority 1, no toast |
| `slot_cast(slot: String, ability_id: String, at: Vector3)` | `combat.gd` | slot 2 or 3 committed a cast; the cast's own signal (`special_used`, `line_skill_fired`) carries the presentation | combat, none, no sound (log, bots, snap) |
| `line_skill_loaded(ability_id: String, seconds: float)` | `combat.gd` | a cast with no line loaded the next bite | combat, ring, `line_load` (new) |
| `line_skill_fired(ability_id: String, target: Node3D, at: Vector3, on: String)` | `combat.gd` | the flavour fired; `on` is `body` or `world` | combat, burst, the pilot's row |
| `line_skill_expired(ability_id: String)` | `combat.gd` | a load ran out with no bite | combat, none, `dry_tick` at -18 dB |
| `ultimate_ready(ultimate_id: String)` | `src/combat/ultimate.gd` (new) | the meter reached full | combat, ring, `ultimate_ready` (new) |
| `ultimate_started(ultimate_id: String, path: String, from: Vector3, to: Vector3, seconds: float)` | `ultimate.gd` | Q committed; the path is planned and drawn; `seconds` is wind-up plus flight | combat, lane, `launched` |
| `ultimate_peak(ultimate_id: String, at: Vector3)` | `ultimate.gd` | the middle beat of the flight | combat, star, the pilot's stinger |
| `ultimate_landed(ultimate_id: String, at: Vector3, hits: int, damage: float)` | `ultimate.gd` | the landing strike resolved | combat, burst, `slammed` |
| `ultimate_cancelled(ultimate_id: String, reason: String, refunded: bool)` | `ultimate.gd` | `recall`, `bail`, `stage`, `death` | combat, none, `dry_tick` |

No meter signal: the meter changes every tick and the HUD polls it, as it polls `slots()` (`hud.gd:931`).

### Runtime APIs

- **AbilityState** (`src/core/ability_state.gd`): `selected: String`, `select(name) -> String` (returns "" on success or the refusal reason), `snap_back(reason)`, `tick_selection(delta, charging)`, `SELECT_TIMEOUT := 3.0`, `meter: UltimateMeter`, `ultimate_id: String`, `ultimate() -> Dictionary`. Each `slots()` record (`:344-357`) gains `number` (1 to 3, or 0 for a chip), `group` (`bar` or `chip`), `selected` (bool) and `select_left` (0 to 1). `ultimate()` returns `{id, icon, key, fill, state}` with state `charging`, `ready` or `active`.
- **UltimateMeter** (`src/core/ultimate_meter.gd`, new, pure rules like `chain.gd`): `CAP := 100.0`, `WEIGHTS`, `WEAPON_RATE_CAP := 0.4`, `value`, `sources` (points by source), `add(source, amount := 1.0) -> float`, `tick(delta, speed_tier)`, `full()`, `fraction()`, `spend() -> bool`, `refund(points)`, `mark_entry()`, `restore_entry()`, `locked`. Only `ultimate.gd` writes it.
- **Line skill** (in `combat.gd`): a `_line_skills` dispatch table beside `_specials` (`combat.gd:296-305`), each row `{on_body: Callable(target, fraction, chain_mult), on_world: Callable(anchor, fraction, chain_mult), geometry: Callable(fraction)}`; `_step_line(intent, delta)`; `line_load() -> Dictionary` (`{id, fraction, left}` or empty) for the HUD and bots.
- **Set piece** (`src/combat/ultimate.gd`, new Node under combat, like `near_miss.gd` at `combat.gd:293-295`): `can_start() -> String`, `plan(ball, aim) -> Dictionary` (`{path, from, to, target, beats, seconds}`), `start(plan)`, `recall()`, `bail()`, `phase() -> String` (`idle`, `windup`, `flight`, `recover`), `active() -> bool`. A `_ult_rows` dispatch table keyed by ultimate id: `{tech: Callable(beat, ball, aim, heft_mult), peak: Callable(at), landing: Callable(at, heft_mult, chain_mult)}`, plus the optional `target: Callable(ball, aim) -> Dictionary` of section 12. It hands the router `ctx.player.set_piece_phase = Callable(ultimate, "phase")`, following the injected-callable pattern at `combat.gd:328-329`.
- **ABILITIES row capabilities** (documented in the comment at `ability_state.gd:33-47`): `pool` (the slot whose charges a row spends), `line` (marks a line-skill row), `load_seconds`, `paths`, `beats`, and the section 12 keys `hold_beats` and `variant_of`. `beats` means: 0 or absent, the path length sets the flight beats; a positive number fixes them.

### Run log rows (`src/core/run_log.gd`, the record at `:167-168`)

| Field | Shape | Counts |
| --- | --- | --- |
| `slot_casts` | `{special: int, line: int}` | `slot_cast` |
| `snaps` | `{cast, deselect, cancel, swap, timeout, ultimate, reset: int}` | `slot_selected` with reason not `pick` |
| `picks` | int | `slot_selected` with reason `pick` |
| `line_skill` | `{on_line, loaded, load_bitten, load_expired: int}` | the line-skill signals |
| `ultimates` | `[{id, path, seconds, heft_class, volley_hits, landing_hits, damage, bailed, recalled, fill_seconds}]` | one row per start |
| `meter_points` | `{source: float}` | `meter.sources` at run end |

Refused picks and refused Q presses are already counted by verb under `verb_fails` (`run_log.gd:332`).

### Discovery and codex rows

Combat's codex entries live in `src/combat/codex_entries.gd` (`ENTRIES` at `:12`, category `enemy`, where the Chain card already sits at `:26-30`). B6 adds five, each detected in combat code:

| id | Name | Fires when |
| --- | --- | --- |
| `loaded_line` | Loaded Line | the first loaded bite fires its flavour |
| `set_piece` | Set Piece | the first ultimate lands |
| `set_piece_core` | Curtain Call | an ultimate landing shatters an open Warden core |
| `set_piece_cash_in` | Cash In | an ultimate landing pays a chain of 3 or more |
| `set_piece_breakout` | Breakout | Q breaks a hostile hold |

Tree card copy for depth-3 and depth-4 ultimate nodes goes in `src/core/trees/world_one_cards.gd` (`ROWS` at `:10`) per pilot in P-C. B6 adds the framework rows only.

### Pilot reaction triggers (`src/presentation/pilot_reactions.gd:5-18`)

Rows point at clips that exist today; A5 and P-E re-point them at the new clips. Clip lengths are not given here. PILOT-CLIPS.md section 1.2 is the source of every clip length.

| Signal | Clip today | Final clip (A5) | Priority | Cooldown |
| --- | --- | --- | --- | --- |
| `ultimate_ready` | `brace` | `ult_ready` | 45 | 10.0 s |
| `ultimate_started` | `brace` | `ult_windup` | 70 | 0.0 s |
| `ultimate_peak` | `heave` | `ult_strike` | 68 | 0.0 s |
| `ultimate_landed` | `drop_land` | `ult_recover` | 65 | 0.0 s |
| `slot_cast` (slot `special`) | `brace` | `cast_special` | 30 | 1.0 s |
| `line_skill_fired` | `heave` | `cast_line` | 32 | 1.0 s |
| `heft_class_changed` | `big_cheer` | `class_up` | 50 | 4.0 s |

## 8. Bot contract

`tools/bot_driver.gd` drives the game through an `Intent.Scripted` source (`:215`). Today it presses the special as `special_pressed` (`:2007`) and keeps Tally's bay 3 loaded with `bay_pick` (`:2136-2147`).

| Field | Type | Set by the bot through | Meaning |
| --- | --- | --- | --- |
| `slot_pick` | int | `source.press` | -1 none; 0, 1, 2 pick slot 1, 2, 3 this tick (replaces `bay_pick`) |
| `fire_pressed`, `fire_held`, `fire_released` | bool | `press` and `hold` | cast the picked slot; a pick and a press on the same tick cast |
| `ultimate_pressed` | bool | `source.press` | Q |
| `move` | Vector2 | `source.hold` | steering, including the set-piece corridor |
| `jump_pressed` | bool | `source.press` | bail during a set piece |
| `special_*`, `line_*` | bool | **not for bots** | router outputs; module tests may set them directly |

Rules:

- Bots cast through `slot_pick` plus `fire_*`, never `special_*` or `line_*` directly, so a bot run pays the real input cost of one extra key per cast.
- The traversal policy is human-shaped (`bot_driver.gd:32-35`): it sends the pick and the click 0.1 s apart (`CAST_GAP`) and counts a cast as one verb against its press gap.
- What a bot may read, all player-visible: `player.abilities.selected`, `player.abilities.slots()`, `player.abilities.ultimate()["fill"]`, `combat.line_load()`, `combat.ultimate.phase()`.
- Helpers B4 adds: `_cast(slot: int, hold_seconds := 0.0)`, `_line_hands()` (cast slot 3 while latched on an enemy within 15 m, or just before a planned bite), `_ultimate_hands()` (press Q at full when a Warden core is open within 45 m, or 3 or more enemies are within 20 m; the traversal policy fires it when the next waypoint lies 25 to 70 m ahead over open ground).

## 9. Starting numbers

Every value is **start**, to tune in play.

| Area | Value | Number |
| --- | --- | --- |
| selection | timeout with no cast | 3.0 s |
| selection | mouse glyph slide | 0.12 s |
| selection | refused-pick shake | 3 px for 0.15 s |
| line skill | load window | 4.0 s |
| line skill | default cooldown, charges | 8.0 s, 1 |
| line skill | `reel_burst` | +8 m/s toward the anchor, once |
| line skill | `line_reel` placeholder | 4 m yank, 10 damage x chain multiplier |
| meter | cap | 100 points |
| meter | weapon hit, rate limit | 0.25 each, 0.4 per s |
| meter | contact | 2.0 each, once per enemy per 0.5 s |
| meter | harpoon smash | 5.0 x chain multiplier |
| meter | chain link past the first | 2.0, once per enemy per 1.0 s |
| meter | near miss, rate limit | 4.0, 0.05 per s holding 4.0 |
| meter | kill | 1.0 |
| meter | stagger, chunk shatter | 8.0, 12.0 |
| meter | speed: fast, blazing | 0.5 per s, 1.2 per s |
| meter | decay, damage loss | none, none |
| meter | fill bands | chainer 45 to 60 s, average 75 to 90 s, camper 180 s or more |
| set piece | wind-up | 0.35 s |
| set piece | flight | length / 18 m/s, 1.6 to 3.2 s, whole beats; 2.4 s with music off |
| set piece | recovery | 0.25 s |
| set piece | line reach | 45 m (`rope_range`) |
| set piece | arc reach, class I to V | 40, 47, 55, 62, 70 m |
| set piece | rail entry search | 12 m from the aim point |
| set piece | fallback hop | 8 m up, 1.6 s |
| set piece | steering corridor | 3 m either side |
| set piece | tech | 1 volley per beat, 3 targets within 10 m, 12 damage, 25 degree reticle bias |
| set piece | landing | 60 damage, radius 6 to 10 m by class, knock 26 |
| set piece | heft multiplier, class I to V | 1.00, 1.15, 1.30, 1.45, 1.60 |
| set piece | damage taken | x0.2, health floor 1 |
| set piece | Warden, boss damage | x0.5; landing up to 45 posture once |
| set piece | camera | distance x1.25, +8 degrees, 0.3 s lead, 0.4 s return |
| HUD | meter arc | gauge radius + 10 px, 4 px thick, 270 degrees |
| HUD | ready breathe | 1 Hz |
| HUD | chips | 0.75 scale, 24 px gap |
| HUD | ULTIMATE word | first 3 ready states per profile |
| pause | quit hold | X for 0.6 s |
| bots | pick-to-click gap (traversal policy) | 0.1 s |

2026-10-11 (w13 B3b): the near-miss row gained its rate limit (0.05 per s holding 4.0) and the chain-link row its per-enemy gap (1.0 s); measured after: camper median first fill 183.3 s (was 41.1 s), completionist 63.6 s (was 54.3 s), over seeds 1 to 16.

## 10. Implementation map for wave P-B

Order: B1 lands first and alone, because it owns every shared declaration (signals, rows, bindings, intent fields, class fields, slot ids). B5 and B7 run beside it on disjoint files. B2 and B3 follow in parallel. B4 and B6 close the wave. Fable review on B1 and B4, as the plan says.

### B1 slot model (Fable review)

- SCOPE: `src/core/ability_state.gd`, `src/core/bindings.gd`, `src/movement/intent.gd`, `src/movement/player_ball.gd` (`_route_slots`, the release latch, `slot_selected`, Sable's chip key), `src/combat/combat.gd` (the tap path in `_step_special`, `_step_line`, `_line_skills`, the `line_reel` placeholder, Tally's re-cut, `slot_cast`), `src/core/class_def.gd` (`line_id`, `ultimate_id`), `src/core/upgrade_tree.gd` (`SWAPPABLE`), `src/core/game_events.gd` and `src/core/event_kinds.gd` (all ten signals and rows from section 7), `CONTRACTS.md` (owner lines).
- ACCEPTANCE:
  - Keys 1, 2, 3 pick; left click casts the pick; the pick snaps back on every reason in section 1 and on none of the "no" rows.
  - A pick and a press on the same tick cast; a held click at the pick does not.
  - After a snap-back with the click held, the weapon fires nothing until the click comes up.
  - Every refusal in section 2 spends nothing and emits its `verb_failed` reason.
  - The line skill fires on a standing line, loads with none, carries on the next bite, survives a dry fire, expires at 4.0 s.
  - A loaded bite adds exactly one chain link.
  - F does nothing in play; Q is bound to `cl_ultimate` (B3 gives it behaviour).
  - Tally plays balance due on 1, gather plate on 2, link clips on 3, all from one pressure pool.
  - Kit tests that write `special_pressed` directly still pass unchanged.
- TESTS: new `tests/skill_bar_select_test.gd` (a table of at least 20 scripted sequences, the timeout edge at 2.99 and 3.01 s, the same-tick pick and press, the latch, Kest's slot-1 gauge cancel, pause freeze, retry reset); new `tests/line_skill_hook_test.gd` (load, bite, expiry at 3.99 and 4.01 s, dry fire keeps the load, on-line cast, chain link count). Re-pin with dated headers: `bindings_table_test`, `tally_kit_test`, `ability_swap_pressure_test`, `tree_data_test`, `combat_arena_retry_test`. Must pass unchanged: `char_combat_test`, `cannon_kit_test`, `tarn_kit_test`, `hook_chain_test`.

### B2 HUD and card

- SCOPE: `src/ui/ability_bar.gd`, `src/ui/ability_slots.gd` (`ROLES` gains `line` and `ult`), `src/ui/hud.gd` (layout at `:702-711`, the meter beside `:939-944`), `src/ui/aim_reticle.gd` (the meter arc), `src/ui/key_glyphs.gd` (the `ultimate` prompt), `src/ui/glyphs.gd`, `src/ui/class_kit.gd`, `src/ui/class_card.gd`, `src/ui/tree_card.gd`, `src/ui/field_notes.gd`, `src/ui/controls_diagram.gd`, `src/ui/pause_menu.gd` (quit on X held), `src/ui/settings_pages.gd` (rebind rows).
- ACCEPTANCE:
  - The bar draws 3 numbered slots and 2 chips; the mouse glyph sits over the selected slot and slides on picks and snaps.
  - Selected and active are distinct in a pixel test.
  - The meter arc fills in the class colour, closes with a mint rim at full, and breathes at 1 Hz.
  - The Q prompt follows LEGIBILITY's retire and return rules.
  - Q does nothing on the pause menu; X held 0.6 s quits.
  - The fight-case word budget stays at 25 or under.
- TESTS: re-pin `ui_ability_slots_test`, `ui_key_glyph_test`, `ui_field_notes_test`, `ui_settings_paged_test`, `ui_pause_menu_test`, `ui_class_card_test`, `hud_icon_distinct_test`; new `tests/ui_skill_bar_test.gd`.
- Runs after B1 merges, because it reads the new `slots()` and `ultimate()` records.

### B3 ultimate system

- SCOPE: `src/core/ultimate_meter.gd` (new), `src/combat/ultimate.gd` (new), a setup hook and `ult_default` row in `src/combat/combat.gd`, the set-piece swallow and the `ultimate` cut cause in `src/movement/player_ball.gd`, `src/combat/holds.gd` (break method `ultimate`), `src/presentation/music_engine.gd` (`set_ultimate_lift`), `src/presentation/audio.gd` (lift, build, peak stinger, landing drop, the `ultimate_ready` and `line_load` sound rows), `src/presentation/ace_sequencer.gd` (pressure step), `src/presentation/pilot_reactions.gd` (rows), `src/core/run_log.gd` (rows).
- ACCEPTANCE:
  - The meter weights, rate limit, cap, no decay and retry restore match section 4.
  - The path order picks line, rail, arc, then the hop; a full meter never meets a dead Q.
  - The landing lands on a beat: the drop falls within one beat of touchdown.
  - Damage taken is x0.2 with health floored at 1; Q breaks a hold.
  - An open Warden core shatters on the landing; a closed guard gets at most 45 posture once.
  - Recall refunds in full; bail spends; a stage change aborts.
  - The handover after the flight publishes no "broke".
- TESTS: new `tests/ultimate_meter_test.gd`, `tests/ultimate_set_piece_test.gd`, `tests/presentation_ultimate_music_test.gd`, a run-log case. `posture_bands_test` stays green: the camper still cannot win. If the grown or small bands move, re-pin with a dated header and a line in `docs/decisions.tsv`.
- Runs after B1 (signals and fields exist). It touches `combat.gd` and `player_ball.gd` after B1, never at the same time.

### B4 bot adapter (Fable review)

- SCOPE: `tools/bot_driver.gd` only, plus re-pins in the tests below.
- ACCEPTANCE:
  - No bot writes `special_*` or `bay_pick`.
  - Each of the six pilots casts slot 2 and slot 3 at least once and fires at least one ultimate per winning run.
  - Fill seconds land in the run log.
  - The meter fill bands hold over 16 seeds: the completionist's median fill is 90 s or less and the camper's 180 s or more.
- TESTS: the six `bot_six_*_test.gd` (`bot_six_pilots_test`, `bot_six_runner_gunner_test`, `bot_six_demolitions_caster_test`, `bot_six_tarn_test`, `bot_six_tally_test`, `bot_six_remembered_cannon_test`), `world_one_rtree_test`, `bot_chain_hand_test`, `stage_layers_test`, `posture_bands_test` and the `scripts/sketch-export.mjs` win proofs pass or re-pin with dated headers; new `tests/bot_skill_bar_test.gd`.
- Runs after B1 and B3.

### B5 customization touch points

CUSTOMIZE.md owns the scaffold; this unit adds only what the bar feeds it.

- SCOPE: rows in `src/core/achievements.gd` for "first set piece", "Curtain Call" and "Cash In 6", each granting one earned cosmetic; `src/presentation/cosmetic_presentation.gd` reads `ultimate_started` to draw the set-piece trail through the trail cosmetic slot and `ultimate_ready` to brighten the shell variant's working device on the weapon housing, the only place a mecha glows (ROSTER-LOOK.md 0.7).
- ACCEPTANCE: a scripted run that lands a set piece grants the row once and saves it; the trail slot's equipped trail draws along the path.
- Runs beside B1. Its only shared contract is the signal names in section 7.

### B6 discovery rows

- SCOPE: `src/combat/codex_entries.gd` (the five entries in section 7), their detection points in `src/combat/combat.gd` and `src/combat/ultimate.gd`, and framework rows in `src/core/trees/world_one_cards.gd`.
- ACCEPTANCE: each entry opens once on its scripted trigger; `codex_coverage_test`, `discovery_cards_test` and `discovery_card_size_test` pass.
- Runs after B3. It edits `combat.gd` and `ultimate.gd` only at detection points.

### B7 the `--profile=sitting` flag

- SCOPE: `src/movement/tuning.gd` (a `FLAGS` row `"profile": ["profile", "option", "launch"]` beside `:113-126`, options `default` and `sitting`), `src/game.gd` (`pilot_unlocked` at `:266-267` answers true under `sitting`), the title's one-word SITTING tag, and `scripts/sketch-export.mjs` (`howToRun` at `:292-304` gains a line naming `./core-loop.x86_64 -- --profile=sitting`).
- ACCEPTANCE: all six pilots can be chosen on the title; the saved profile file is byte-identical after a run started under the flag; no unlock achievement fires from the flag.
- TESTS: re-pin `tuning_flags_test` and `scripts/sketch-export.test.mjs`; new `tests/sitting_profile_test.gd`.
- Runs beside B1. It is the only P-B unit that edits `src/game.gd`.

### File conflicts at a glance

| File | Units, in order |
| --- | --- |
| `src/combat/combat.gd` | B1, then B3, then B6 |
| `src/movement/player_ball.gd` | B1, then B3 |
| `src/core/game_events.gd`, `src/core/event_kinds.gd`, `CONTRACTS.md` | B1 only |
| `src/presentation/audio.gd`, `music_engine.gd` | B3 only |
| `src/ui/*` | B2 only |
| `tools/bot_driver.gd` | B4 only |
| `src/game.gd`, `src/movement/tuning.gd` | B7 only |

## 11. Risks and the veto list

### Risks, with the cheapest check

| Risk | Cheapest check |
| --- | --- |
| The pick-then-click adds a key to every special; the old F was one press | Andrew's sitting; a `snaps.timeout` share above 30 percent in the run log means picks are going stale |
| Bots and bands drift because every pilot gains two new sources of power | B4's bands and `posture_bands_test`; pay for it in pack scale per world, as the plan says |
| The ultimate trivializes the Warden through the open-core shatter | `alpha_posture_bands_test`: the grown band must stay at 25 s or more |
| The meter fills from traversal alone and fires with no fight around | the `meter_points` split in the run log; cap speed's share if it passes 40 percent |
| Two rings at the reticle crowd the aim | the meter sits outside the gauge ring and its gap stays empty below full; a blind still at 1080p in B2 |
| The fight-case word budget goes over 25 | B2's budget test |
| Beat rounding stretches a flight past 3.2 s at slow tempos | the clamp in B3; the presentation music test asserts the band |
| Tally loses plate return between B1 and P-C | P-C lands in the next wave; the P-B export notes it |

### Veto list

Say "veto" on any line and it changes.

1. Slot 3 acts on a standing line, and with no line it loads the next bite for 4 s.
2. A dry fire keeps the load; a load that expires refunds nothing.
3. The selection snaps back after 3 s with no cast.
4. Firing the harpoon does not snap the selection back.
5. Taking damage does not snap the selection back.
6. After a snap-back, left click must come up before the weapon fires again.
7. Picking a cooling slot is refused, not queued.
8. F is unbound in play, not an alias for 2.
9. Sable's pylon mount stays on E.
10. Quit moves from Q to X held for 0.6 s.
11. The meter starts empty each run; that is how the ultimate "unlocks through play" (BIBLE.md:400).
12. The meter has no decay and taking damage drains nothing.
13. Weapon hits fill the meter slowly (0.4 per second at most), so camping is the slowest road.
14. The set piece's flight is stretched to land on a beat; the wind-up is fixed.
15. Space bails out of a flight; Q recalls only during the wind-up, with a full refund.
16. The landing cashes in the chain multiplier and ends the chain.
17. An ultimate landing on an open Warden core shatters the chunk.
18. Q breaks a hostile hold.
19. A full meter with no target still fires, as a hop in place.
20. Damage taken during the set piece is x0.2 with health floored at 1, not full immunity.
21. Tally's deck: balance due on 1, gather plate on 2, link clips as her line skill on 3, plate return as her ultimate.

## 12. Cross-pilot extensions (unit A2-CRITIC, 2026-10-10)

The six pilot sheets (`design-v3/pilots/*.md`) needed eight things this framework did not say. Each is added here once, so no sheet carries a private rule. [PILOTS.md](PILOTS.md) holds the roster view and the consolidated veto list.

1. **Legs.** `plan()` returns `legs`, an ordered list of `{mode, to, beats}` with `mode` one of `line`, `arc`, `rail`, `hold` or `hop`. One leg by default. `ult_encore` appends a leg. A row with `hold_beats` (int) inserts a `hold` leg (the ball hangs at that point) before its last leg. Hold beats add to the clamped flight; they do not share it. With a hold, the peak is the first hold beat. Every leg is drawn at wind-up, so the stop is foreseen. A row may also carry `beats` (int): 0 lets the path length set the flight beats; a positive value fixes them and skips the length clamp. Users: Kest's Windhover (`hold_beats` 2), the Cannon's Plate Mortar (`beats` 6), every encore.
2. **`target`.** An optional `_ult_rows` key, `target: Callable(ball, aim) -> Dictionary`, that `plan()` consults before the path order. It returns `{}` or `{to, path}`. User: Tally's plate.
3. **`variant_of`.** Every depth-3 ultimate row names its base ultimate id. B1 adds `line` and `ultimate` to `upgrade_tree.KEYS` (`src/core/upgrade_tree.gd:45`) and makes `safe_pick_problems` (`:183-227`) and `apply_pick` read a swap to a row whose `variant_of` is the held ultimate as growth. `tree_safe_picks_test` then needs no per-pilot re-pin for these swaps.
4. **One pilot knob.** A pilot may own at most one knob named `ult_<word>`, registered in its own block of `KNOBS` (`upgrade_tree.gd:54-76`). Users: Rivet `ult_pins`, Tally `ult_settle`. B1 pre-seeds one marked block per pilot in each shared table (`ABILITIES`, `_line_skills`, `_ult_rows`, `KNOBS`, the audio rows, `codex_entries.gd`, `achievements.gd`, `cosmetics.gd`, `class_kit.gd` `WORDS`, `icons.gd` `EXTRA`), so the six P-C units never edit the same lines.
5. **Card copy, one source.** A depth-3 or depth-4 node keeps its `key`, its `icon` and its own `effect` (reworded only where it names F or the retired plate-return special). The card's second line comes from a `SET_PIECE_LINES` table keyed by ultimate id and knob. B6 makes the tree card read it at every depth, because `world_one_cards.gd` rows show only at depths 1 and 2 under the world-one flag (`src/core/trees/world_one_cards.gd:3-5`).
6. **Depth-3 offers.** The two children of every depth-2 node hold one variant each, so the world-two pick is always a set-piece choice, on every pilot.
7. **Posture cap.** On a closed guard, one set piece adds at most 45 posture in total, volleys and landing together. Nine Cannon zones or eleven Sable stakes cannot stack past it. This keeps the grown band (section 11 risk) safe.
8. **Ready colour.** Where a class colour equals the live mint (only Sable today), the meter fill draws in sand-light `bare_metal`, so mint keeps one meaning.
