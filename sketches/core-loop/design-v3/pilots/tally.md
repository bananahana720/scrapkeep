# Tally: pilot sheet

Status: design spec for wave P-C, unit A2-tally of wave 13. Written 2026-10-10 on `cand/alpha-w13` at `38ceda3`. Nothing here is built or played. Every `file:line` cites that commit. Paths without a prefix are under `sketches/core-loop/`. A number marked **start** is a starting value to tune in play. A line marked **Call** is a decision made under the creative charge; section 11 collects them as the veto list.

**Weapon fire (ruling ek, 22 Nov 2026):** how this pilot's weapon fires, with its timers, damage and first tree pick, is now [PILOT-CADENCE.md](../PILOT-CADENCE.md) section 3.5. Where this sheet's weapon text differs, that page wins.

Reads with: [SKILL-BAR.md](../SKILL-BAR.md) (the bar, the line-skill hook and the set-piece contract; this sheet uses its names exactly), [ROSTER-LOOK.md](../ROSTER-LOOK.md) (the Hoberman mecha language; section 0 is the live design), [DESIGN-V3.md "Tally's program cards"](../DESIGN-V3.md) (`DESIGN-V3.md:192-241`, the kit decisions D1 to D15 this sheet keeps or replaces) and [LEGIBILITY.md](../LEGIBILITY.md). It supersedes the Tally text in DESIGN-V3 where the two disagree.

Terms, defined once:

- **Pressure**: Tally's ammunition. The weapon slot's charges, 3 at start, 4 with the shop part (`src/core/trees/tally.gd:6`). Time never refills it (`src/core/ability_state.gd:285-290`).
- **Clip**: an enemy tagged in Tally's ledger for 4 s. A paper tag hangs off it. The next direct hit on any clip copies to every other clip (today's Link arc, `src/combat/combat.gd:1775-1801`).
- **Plate**: the gather plate on the ground. It pulls ordinary enemies toward it (`combat.gd:1654-1672`).
- **Settle**: the set piece's payout to a clip that sits outside the landing radius. One arc from the landing point carries a share of the landing strike.
- **Set piece**: the ultimate, a directed ride from A to B (SKILL-BAR section 4).

## 1. Fantasy and difference

**Fantasy.** A pack-rat bookkeeper on wheels: gather the pack, clip it on the line, then make it pay.

**What only Tally does.** Two mechanics no other pilot shares.

1. **Her gun runs on a wallet that momentum fills.** Every other weapon row has no charges to spend and refills by time (`ability_state.gd:49-74`). Only `ledger_reader` carries `pressure` (`ability_state.gd:68`), and `_recharge` skips it (`:285-290`). Pressure comes back from rolling at cruise tier or faster, 1 per 2 s (`combat.gd:1675-1687`, `src/combat/weapons.gd:122`), from rams and stomps (`combat.gd:1776-1780`), from harpoon smashes and slams (`combat.gd:307-310`) and from her stamp (`src/movement/player_ball.gd:934-942`). Standing still starves her. The new line skill adds one more income: the line clips value from what it bites.
2. **Damage copies across a group.** Kest delays damage at a point on a fuse. Tarn holds one target in hand. Tally links up to three enemies, and what you do to one, you do to all. Her ultimate extends that to the whole ride: everything clipped on the way pays at the landing, wherever it ran.

| Pilot | What a shot spends | What refills it | Where the damage lands |
| --- | --- | --- | --- |
| Sable, Rivet, Kest, Tarn, Cannon | a cooldown | time | at the shot, the fuse, the claw or the lane |
| Tally | pressure | rolling, contact, the ledger clip | at the shot, then copied to every clip; the set piece settles the whole ledger |

## 2. Kit

**Call.** Today's deck re-cut to the bar, as SKILL-BAR section 1 ("Tally's deck, re-cut") sets it: slot 1 Balance Due, slot 2 Gather Plate, slot 3 the ledger clip, Q Plate Return. Tally is the one pilot whose old F special (`plate_return`, `class_def.gd:117`) moves up to the ultimate. The Gather card takes slot 2. Two refinements over B1's mechanical re-cut, both **Calls**: Gather Plate leaves the pressure pool and gets its own 6 s cooldown, and the ledger clip pays pressure instead of costing it. Reason: a slot whose state depends on another slot's charges reads badly (principle 11), and the line skill should feed the wallet, not drain it.

| Place | Name, ability id | Fire shape | What it does | Numbers (start where new) | What the player sees and hears | Stays from today | New |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 (home) | Balance Due, `ledger_reader` running card `balance_due` | tap | A capacitor ring discharges once at the aim point. Damage grows with planar speed at the press. | 1 pressure. Reach 30 m. Radius 3 m. Damage 10 + 1.2 per m/s, cap 56: 19 at the cruise floor (7.7 m/s), 29 at fast (16.1), 42 at blazing (26.6) (`src/movement/speed_tier.gd:8`, `tuning.gd:7`). Knock 6. Recovery 0.4 s. | The 3 m footprint in neutral sand at the aim (D15). Pressure pips on slot 1 and cream-filled windows on the drum faces (section 5). `tally_balance_due` on the release (`src/presentation/audio.gd:88`). An empty reader shakes the pips 3 px with a slate flash and the dull tick. | `_run_balance` (`combat.gd:1754-1771`), constants `weapons.gd:100-101, 117-122`, pressure 3 (`ability_state.gd:68`), card dispatch (`combat.gd:1620-1645`). | `cards` shrinks to `["balance_due"]`, so `bay` is always 0. A dry press emits `verb_failed("fire", "cooling")`, today it is silent (`combat.gd:1696-1698`). |
| 2 | Gather Plate, `gather_plate` | tap | Plants a plate at the aim point. Ordinary enemies within the radius roll toward it, harder from farther out. No damage. Never the player or a Warden. | **Cooldown 6.0 s, 1 charge, no pressure (Call).** Reach 30 m. Radius 4 m. 4 s. Pull tick 0.2 s, knock 6 x clamp(distance / 4, 0.25, 1). One plate at a time; a new one replaces the old. | A cream disc with punched holes, its 4 m ring drawn at cast (`combat.gd:1709`). A copper plate ring on D3, `tally_plate` (new, keyed). The pulled enemies skid toward it. | `_run_gather`, `_step_plate`, `_ordinary` (`combat.gd:1703-1710, 1654-1672, 1647-1651`), constants `weapons.gd:104-107`. | Moves from a card to the special slot through B1's tap path (SKILL-BAR section 1). Drops `_spend_card`. Inherits plate return's 6 s slot cooldown, so the special-slot relics and tree nodes keep their meaning. |
| 3 | Ledger Clip, `link_clips` (line skill) | tap | **On a body latch:** clips the latched enemy and its 2 nearest neighbours within 9 m for 4 s. Each clip pays 1 pressure at once. The next direct hit on any clip arcs once to every other clip. **On a world latch:** plants a clip post. The first 3 enemies that pass within 4 m of it in 4 s become clips and pay 1 pressure each. The ball also gets the default `reel_burst`, +8 m/s toward the anchor. **No line:** loads the next bite for 4 s. | **Cooldown 8.0 s, 1 charge, no pressure (Call).** Load 4.0 s. Clips at most 3. Arc damage max(8, 0.6 x the hit's force) x the chain multiplier stored at the cast (`chain.gd:49`). Pressure pay never passes the cap. | While slot 3 is selected and a line stands, the committed geometry: a 9 m ring round the latched enemy and a tick on each enemy it will clip. A cream paper tag on each clip, dotted cream thread between clips. Sound `tally_clip`: a paper-punch click and one ledger stroke per clip, D4, E4, F4, each rising a step of D dorian per chain link (`chain_link` climbs the pentatonic; her stepwise phrase climbs the mode). `cog_tick` per pressure point. A loaded bite shows a cream tag on the hook head. | `_run_link`, `_link_target`, `_on_card_struck` (`combat.gd:1734-1752, 1715-1732, 1775-1801`), constants `weapons.gd:110-115`. | Becomes a `_line_skills` row (SKILL-BAR section 7). The aim-ray target becomes the latched body. The clip post, the pressure pay and the stored chain multiplier are new. |
| Shift chip | Flywheel Surge, `flywheel_surge` | instant | A kick-start: drives the ball along its travel, or along the aim when nearly still, and the spun-up drums pay 1 pressure. | Cooldown 4.0 s, 1 charge. Speed max(planar, 16 x 1.3 = 20.8 m/s); keeps vertical speed (`augments.gd:109-112, 305-315`; `tuning.gd:15`). **+1 pressure per surge, to the cap (start, A2-CRITIC Call).** | Unchanged cue, plus `cog_tick` for the pressure point. New body read: the ledger drums spin to 3x for 0.4 s, one more drum window fills cream, and steam leaves `ReturnExit` (`tools/blender/shell_tally.py:159`). | The speed rule. | Never selectable (SKILL-BAR section 1). The pressure pay is new (A2-CRITIC): a speed floor is near Sable's shove and Rivet's sprint in feel, so the surge's purpose becomes the wallet. It raises her income by at most 1 point per 4 s, a quarter of what cruise rolling pays (1 per 2 s, `weapons.gd:122`). |
| Ctrl chip | Stamp Slam, `stamp_slam` | instant | The shared slam, then the stamp: every enemy within 9 m turns into 1 pressure. A clip inside the stamp counts as a direct hit, so the stamp fires the clip arc. | Slam radius 9 m, knock 26 x strength (`augments.gd:67-68`, `player_ball.gd:891-903`). +1 pressure per enemy reached, to the cap (`player_ball.gd:934-942`). The stamp replaces the ordinary slam's +1 (`combat.gd:308-310`). | Unchanged cue, plus the `smash` clip (section 6). | All of it, including the arc: the shared slam strikes as `slam`, which reaches `_on_card_struck`. | Nothing in code. The clip combo is now taught by the codex row `tally_skim` (section 8). |
| Q | Plate Return, `plate_return` (ultimate) | press | The set piece in section 3. | Meter, wind-up, flight and defence from SKILL-BAR section 4. | Section 3. | The id, the name and the idea: the plate comes home. | All behaviour. The F-special gauge corridor (`combat.gd:1802-1836`) retires. |

**Card lines** (8 words or fewer, for `class_card.gd` per SKILL-BAR section 5):

| Slot | Line |
| --- | --- |
| 1 Balance Due | Discharge where you aim. Speed hits harder. |
| 2 Gather Plate | Plant a plate. The pack rolls in. |
| 3 Ledger Clip | The line clips three and pays pressure. |
| Q Plate Return | Ride home. Every clip settles on landing. |
| Ctrl Stamp Slam | Stamp the crowd. Each one refills pressure. |

**The rhythm this makes.** Roll to fill the wallet. Pick 2, click: plate. Harpoon into the knot, pick 3, click: three clips and three pressure back. Ram or stamp one clip: all three take it. Tap Balance Due into the knot at speed. When the ring round the crosshair closes, Q rides home and settles the books.

### Line-skill contract (SKILL-BAR section 3 fields)

| Field | Ledger Clip |
| --- | --- |
| `id`, icon, name | `link_clips`, `ab_tally_line` (new SVG: the link icon with a cable and hook head), "Ledger Clip" |
| fire shape | tap; no `charge_max` |
| `cooldown`, charges | 8.0 s, 1 |
| `on_body` | clip target + 2 nearest within 9 m; +1 pressure per clip; arc on the next direct hit, max(8, 0.6 x force) x stored chain multiplier |
| `on_world` | clip post at the anchor: 4 m, 4 s, first 3 passers clipped, +1 pressure each; plus `reel_burst` |
| `load_seconds` | 4.0 |
| chain scaling | yes, stored at the cast and paid by the arc |
| committed geometry | a 9 m ring round the target with a tick on each enemy it will clip; on a world latch, a 4 m ring at the anchor |
| ground contact | no; the chain carries on |
| Warden and boss read | A Warden can be clipped and pays 1 pressure. Arcs to or from a Warden are noncontact: they fill posture as gun bolts do (1.5 base, `LEGIBILITY.md:85`) and never crack or shatter the core (`LEGIBILITY.md:87`; DESIGN-V3 D8). A boss (Brindle, the Waking, the Mind) takes arcs at x0.5. While a boss is in a no-damage window its tag shows a slate VOID stamp and the arc does nothing (principle 14). |
| sound | `tally_clip`, strokes D4 E4 F4, rises with the chain |
| card and codex | "The line clips three and pays pressure."; codex row `tally_skim` (section 8) |
| clip | `cast_line`, 0.5 s (section 6) |

During a committed smash the clip fires and the haul continues (SKILL-BAR section 3, rule 1). The smash landing is a direct hit on the latched clip, so the arc fires on the landing. That is the combo the codex row teaches.

## 3. Plate Return, the set piece

### The ride

| Field (SKILL-BAR section 4 list) | Plate Return |
| --- | --- |
| id, name, icon | `plate_return`, "Plate Return", `ab_tally_ult` (new SVG, drawn from `ab_tally_special` with the meter ring) |
| `paths` | `["line", "rail", "arc"]`, the framework order. **Call:** a plate target comes first. If her gather plate lies within 45 m (`rope_range`, `tuning.gd:18`) and within 30 degrees of the aim, B is the plate and the path is `line`; a fresh cable fires to it at departure. Otherwise the framework order runs: standing line, lock, rail, arc, then the hop. |
| Tech, each beat | The ledger drums punch one card at each of up to 3 targets within 10 m of the ball, nearest the reticle first (25 degree bias). 12 damage x the heft multiplier per target. Every target struck becomes a clip, up to the clip cap. |
| Peak (the middle beat) | **The plate goes home.** A plate lands at B now. It pulls ordinary enemies within the landing radius toward B for the rest of the flight (tick 0.2 s, knock 6). If B already is her plate, its radius grows to the landing radius and its timer runs to the landing. The tape tears off the drums. |
| Landing | **Settle up.** The strike: 60 x heft multiplier x chain multiplier within the landing radius, knock 26 (framework). Then each clip outside the radius takes one settle arc from the landing point for 40% of the strike. Then pressure refills to full. The chain ends, as a paid smash ends it. |
| Heft scaling beyond the default | the clip cap, below |
| Music | below |
| Mecha | below |
| Clips | `ult_ready` 0.8 s, `ult_windup` 0.35 s, `ult_strike` 0.5 s, `ult_recover` 0.7 s (section 6). Her paws take the copper lap bar at the wind-up and hold it through the flight in the shared `ult_ride_loop` (PILOT-CLIPS section 1). |
| Card line, codex, run log | "Ride home. Every clip settles on landing."; codex row `tally_books_balanced` (section 8); run log `ultimates` rows with id `plate_return`, where `volley_hits` counts clips made and `landing_hits` counts strike hits plus settles |

A clip inside the landing radius takes the strike, never a settle as well, so no enemy is paid twice. `ultimate_landed`'s `hits` counts strike hits plus settles.

### Heft class

Framework rows from SKILL-BAR section 4, plus Tally's clip cap.

| Heft class | I | II | III | IV | V |
| --- | --- | --- | --- | --- | --- |
| damage multiplier (framework) | 1.00 | 1.15 | 1.30 | 1.45 | 1.60 |
| landing radius (framework) | 6 m | 7 m | 8 m | 9 m | 10 m |
| arc reach (framework) | 40 m | 47 m | 55 m | 62 m | 70 m |
| clip cap per ride (start) | 6 | 7 | 8 | 9 | 10 |
| settle per clip at chain 1 | 24 | 28 | 31 | 35 | 38 |

At 172 BPM a beat is 0.35 s, so a 1.6 to 3.2 s flight holds 5 to 9 beats (SOUND-STORY.md:31; SKILL-BAR section 4, duration). With 3 targets a beat, the cap is usually what limits clips, not the volleys.

### Wardens and bosses

The framework rule stands (SKILL-BAR section 4, "Wardens and bosses"). Tally's notes keep DESIGN-V3 D8: program effects never touch the core.

| Target | Card volleys and settle arcs | Landing strike |
| --- | --- | --- |
| Warden, guard closed | noncontact: posture only, 1.5 base per hit at half damage; a Warden can be clipped | contact: up to 45 posture once, like a harpoon smash; the 45 caps the whole set piece, cards and settles included (SKILL-BAR section 12, item 7) |
| Warden, core open | noncontact: posture only, never the core | the ball itself lands: counts as a harpoon smash and shatters the chunk |
| Brindle, the Waking, the Mind | x0.5; a boss is clipped at most once per ride; VOID stamp in a no-damage window | x0.5, no knock, windows untouched, the brace pose and the "nope" glyph |

**Harmonized.** DESIGN-V3 says "every program effect and `plate_return` is noncontact forever" (`DESIGN-V3.md:218`). The set piece honours it: the cards and the settles never crack a core. Only the ball's own landing can, because the ball rode the harpoon line there. "Standing off cannot win" (`DESIGN-V3.md:219`) still holds: you have to fly in.

### Music moment

Tally's leitmotif counts four strokes up the ledger and strikes the total an octave over home: D4 E4 F4 G4, a rest, D5 (`src/presentation/harmony.gd:129, 136`; voice `keys`, band voice `beep`). The set piece plays it across the ride, so the tune is the ride.

| Moment | What sounds | Owner |
| --- | --- | --- |
| meter full | the framework's one-layer lift; Tally's lifted layer is the counter-line seeded from her motif head on the `beep` voice, the rotation SOUND-STORY.md:67 already allows | B3 lift; Tally's row names the seed |
| wind-up | the framework launch build | B3 |
| each flight beat | the next ledger stroke on `keys`, D, E, F, G, then round again, one per volley, in the live key | `tally_stroke` (new keyed row) |
| peak | the motif head as a fast run, D E F G in sixteenths (87 ms each), doubled by `beep`: the column totals | the peak stinger |
| landing | the total, D5, an octave over home, with a small bell, on the framework drop | the landing cadence |
| settle ripple | one `cog_tick` per settled clip in sixteenths after the drop, at most 10, climbing the D minor pentatonic like the reward ladder (SOUND-STORY.md:82) | `tally_settle` (new keyed row) |

The books balance on the drop. A player who hears four strokes and no total knows the ride was bailed.

### Mecha during the ride

| Phase | What the machinery does |
| --- | --- |
| ready | `class_accent` glows at the card slot (`ReaderExit`) on the weapon ring, the only light on the mecha (ROSTER-LOOK section 0.7); the drum tape turns one slow turn a second, in step with the 1 Hz ring breathe |
| wind-up | all three cards stand up in the card bank (`ReaderCarriage`); the drums spin up |
| flight | drums at full spin; a card leaves `ReaderExit`, the card magazine's slot on the weapon ring, on each volley (`shell_tally.py:158`); the ring stays level and yaws with the aim |
| peak | the tape tears and streams behind for the rest of the flight |
| landing | `StampContact` stamps the ground (`shell_tally.py:159`); a ring of punched paper bursts out |

### Depth 3: two set pieces to choose from

Depth 3 opens in world 2 (`upgrade_tree.gd:119-120`). Each depth-3 node swaps the ultimate with the existing op shape, `"swap": {"ultimate": <id>}` (SKILL-BAR section 4). **Call:** the two children of every depth-2 node are always one Audit Trail and one Flywheel Throw, so the world-2 pick is the set-piece choice, every time.

| Variant | id | Changes | Path | Tech | Peak and landing |
| --- | --- | --- | --- | --- | --- |
| Audit Trail | `plate_audit` | the tech: steering picks targets, not aim | `["line", "rail", "arc"]` with the plate target | Each beat stamps a 4 m ring on the ground under the ball (if ground lies within 12 m below): 12 x heft damage, knock 10 outward. Everything stamped is clipped, up to the cap. No 3-target limit. The 3 m steering corridor decides what you stamp. | as base |
| Flywheel Throw | `plate_flywheel` | the path: an arc launch, no line needed | `["arc", "rail", "line"]`; the arc lands on her plate if the plate is in reach and within 30 degrees of the aim | Each beat throws a small plate at the densest knot within 15 m of the ground track: pulls 4 m for 1.5 s, clips up to 3 in that knot. | Peak as base. Landing radius +2 m. 0.2 s before the strike, everything within radius + 4 m is pulled 4 m inward. |

Audit Trail rewards a line through a crowd. Flywheel Throw rewards a long launch over a bowl. Both keep the settle, so both stay Tally.

### Depth 4: modifiers

Each depth-4 node turns one knob with the existing `"knob"` op. Four are the framework's (SKILL-BAR section 4). **Call:** one is Tally's own.

| Knob | Default | Set to | On Plate Return | On Audit Trail | On Flywheel Throw |
| --- | --- | --- | --- | --- | --- |
| `ult_encore` | false | true | framework: a second leg if a target sits within 30 m; Tally's leg goes to the live clip with the most health left, and its landing settles the live clips again | same | same |
| `ult_beats` | 0 | 2 | +2 flight beats, so +2 volleys | +2 stamps | +2 small plates |
| `ult_radius` | 0.0 | 2.0 | +2 m landing radius | same | same, on top of the variant's +2 m |
| `ult_volley` | 0 | 1 | +1 target per volley | stamp radius +1 m | +1 clip per knot |
| `ult_settle` (new, Tally) | 0.4 | 0.7 | settle share 40% to 70% | same | same |

### Tree changes (`src/core/trees/tally.gd`)

The tree is heap-ordered: index 0 and 1 are depth 1, 2 to 5 depth 2, 6 to 13 depth 3, 14 to 29 depth 4; the children of node i are 2i+2 and 2i+3 (`upgrade_tree.gd:136-141`). The left half grows from `tl_audit_stamp`, the right from `tl_steam_bank` (`tally.gd:3-4`).

**Call: every changed node keeps its id and its old op, and gains the ultimate op.** So late picks still grow the kit and no two nodes in the tree are the same pick. Node `key` becomes `"ultimate"` and `icon` becomes `ab_tally_ult` on the depth-3 and depth-4 rows. Effects stay at 8 words or fewer and names at 3 or fewer (`upgrade_tree.gd:49-50`). "Plate return" in today's text means the special slot, which is now Gather Plate, so the wording changes too.

Depth 2, one wording change only:

| i | id | Old effect | New effect |
| --- | --- | --- | --- |
| 5 | `tl_corner_plate` | Every plate return refills a surge | Every gather plate refills a surge |

Depth 3 (world 2):

| i | id | Parent | Kept op (`tally.gd` line) | Added op | New effect |
| --- | --- | --- | --- | --- | --- |
| 6 | `tl_deep_ledger` | 2 | proc `enemy_killed` → `refund_special` 0.5 (`:23-24`) | `"swap": {"ultimate": "plate_audit"}` | Audit Trail ultimate; kills wind gather along |
| 7 | `tl_carbon_copy` | 2 | proc `enemy_rebounded` → `blast` 0.5 (`:25-26`) | `"swap": {"ultimate": "plate_flywheel"}` | Flywheel Throw ultimate; rebounds throw a shockwave |
| 8 | `tl_stamp_duty` | 3 | proc `slammed` → `air` (`:27-28`) | `"swap": {"ultimate": "plate_audit"}` | Audit Trail ultimate; stamps return your air jump |
| 9 | `tl_reel_in` | 3 | proc `harpoon_smashed` → `grant_move` (`:29-30`) | `"swap": {"ultimate": "plate_flywheel"}` | Flywheel Throw ultimate; smashes refill a surge |
| 10 | `tl_blowdown` | 4 | proc `dashed` → `blast` 0.5 (`:31-32`) | `"swap": {"ultimate": "plate_flywheel"}` | Flywheel Throw ultimate; surges vent a shockwave |
| 11 | `tl_governor` | 4 | `charges` movement 1, `cooldown` movement 0.8 (`:33-34`) | `"swap": {"ultimate": "plate_audit"}` | Audit Trail ultimate; a third, faster surge |
| 12 | `tl_plate_rack` | 5 | `charges` special 1 (`:35-36`) | `"swap": {"ultimate": "plate_flywheel"}` | Flywheel Throw ultimate; stockpile two gather plates |
| 13 | `tl_return_slip` | 5 | proc `special_used` → `blast` 0.5 (`:37-38`) | `"swap": {"ultimate": "plate_audit"}` | Audit Trail ultimate; gather plates throw shockwaves |

Depth 4 (world 3). The variant comes from the parent's swap. Sibling pairs never share a knob.

| i | id | Parent (variant) | Kept op (`tally.gd` line) | Added `knob` | New effect |
| --- | --- | --- | --- | --- | --- |
| 14 | `tl_full_ledger` | 6 (audit) | proc `enemy_struck` → `air` (`:40-41`) | `{"ult_settle": 0.7}` | Hits return air jump; clips settle for more |
| 15 | `tl_settled` | 6 (audit) | proc `enemy_killed` → `refund_move` 1.0 (`:42-43`) | `{"ult_beats": 2}` | Kills wind surge; ultimate flies two beats longer |
| 16 | `tl_bounce_back` | 7 (flywheel) | proc `enemy_rebounded` → `grant_move` (`:44-45`) | `{"ult_radius": 2.0}` | Rebounds refill a surge; ultimate lands wider |
| 17 | `tl_red_ink` | 7 (flywheel) | proc `enemy_rebounded` → `refund_special` (`:46-47`) | `{"ult_settle": 0.7}` | Rebounds wind gather; clips settle for more |
| 18 | `tl_rubber_stamp` | 8 (audit) | proc `slammed` → `grant_move` (`:48-49`) | `{"ult_radius": 2.0}` | Stamps refill a surge; ultimate lands wider |
| 19 | `tl_postmark` | 8 (audit) | proc `slammed` → `blast` 0.8 (`:50-51`) | `{"ult_encore": true}` | Heavier stamp shockwaves; ultimate flies an encore |
| 20 | `tl_long_line` | 9 (flywheel) | `charges` movement 1 (`:52-53`) | `{"ult_encore": true}` | Second surge; ultimate flies an encore leg |
| 21 | `tl_closing_entry` | 9 (flywheel) | proc `harpoon_smashed` → `grant_special` (`:54-55`) | `{"ult_volley": 1}` | Smashes refill gather; ultimate volleys clip more |
| 22 | `tl_pressure_valve` | 10 (flywheel) | proc `dashed` → `refund_special` 1.5 (`:56-57`) | `{"ult_beats": 2}` | Surges wind gather; ultimate flies two beats longer |
| 23 | `tl_scald` | 10 (flywheel) | proc `boosted` → `blast` 0.4 (`:58-59`) | `{"ult_radius": 2.0}` | Boosts vent steam; ultimate lands wider |
| 24 | `tl_freewheel` | 11 (audit) | proc `landed` → `refund_move` 0.5 (`:60-61`) | `{"ult_beats": 2}` | Landings wind surge; ultimate flies two beats longer |
| 25 | `tl_overspeed` | 11 (audit) | proc `enemy_killed` → `grant_move` (`:62-63`) | `{"ult_volley": 1}` | Kills refill a surge; ultimate stamps wider |
| 26 | `tl_plate_stack` | 12 (flywheel) | `charges` special 1, `cooldown` special 0.8 (`:64-65`) | `{"ult_volley": 1}` | Three faster gather plates; ultimate clips one more |
| 27 | `tl_backstop` | 12 (flywheel) | proc `hold_broken` → `grant_special` (`:66-67`) | `{"ult_encore": true}` | Breaking free refills gather; ultimate encore leg |
| 28 | `tl_paid_in_full` | 13 (audit) | proc `special_used` → `air` (`:68-69`) | `{"ult_encore": true}` | Gather returns air jump; ultimate encore leg |
| 29 | `tl_bounced_check` | 13 (audit) | proc `hold_broken` → `blast` 0.6 (`:70-71`) | `{"ult_settle": 0.7}` | Breaking free vents steam; clips settle for more |

Coverage: Audit Trail builds see `ult_settle` 2, `ult_beats` 2, `ult_encore` 2, `ult_radius` 1, `ult_volley` 1. Flywheel Throw builds see `ult_radius` 2, `ult_encore` 2, `ult_volley` 2, `ult_settle` 1, `ult_beats` 1. No new proc enters any build, so the proc-loop check (`upgrade_tree.gd:319-337`) sees the same links as today.

New `ABILITIES` rows (`ability_state.gd:48-75`), owned by the P-C unit:

```
"ledger_reader": {"icon": "ab_tally_weapon", "cooldown": 0.0, "cards": ["balance_due"], "pressure": 3},
"gather_plate": {"icon": "ab_tally_gather", "cooldown": 6.0},
"link_clips": {"icon": "ab_tally_line", "cooldown": 8.0, "line": true, "load_seconds": 4.0},
"plate_return": {"icon": "ab_tally_ult", "paths": ["line", "rail", "arc"]},
"plate_audit": {"icon": "ab_tally_ult", "paths": ["line", "rail", "arc"]},
"plate_flywheel": {"icon": "ab_tally_ult", "paths": ["arc", "rail", "line"]},
```

`link_clips` carries no `pool`, which reverses B1's mechanical re-cut (SKILL-BAR section 1). `plate_return` drops `charge_max` and `cooldown`, because the meter is its charge.

## 4. Three worlds

`depth_cap = clamp(world + 1, 2, 4)` (`upgrade_tree.gd:119-120`): depths 1 and 2 in world 1, depth 3 opens in world 2, depth 4 in world 3.

| World | Tree depth open | What Tally gains | How it meets the world |
| --- | --- | --- | --- |
| 1, Spillway Works (Brindle; reactor-relic Wardens) | 1 and 2 | The base kit and the first Plate Return, earned by play because the meter starts empty each run (SKILL-BAR section 4). Two play identities (principle 19): the **stamp clerk** down the left half (`tl_audit_stamp`, then `tl_through_feed` or `tl_line_feed`: contact feeds the wallet, stamps throw shockwaves) and the **flywheel courier** down the right (`tl_steam_bank`, then `tl_spring_vent` or `tl_corner_plate`: two surges, air jumps, a plate that refills a surge). | Learn the wallet: Balance Due is weak standing and strong at speed, so the flume and dam-face lines teach "roll, then pay". Gather works on chasers and lobbers (`combat.gd:1647-1651`). |
| 2, the Dig (the Waking; swarm-remnant Wardens) | 3 | The set-piece choice: Audit Trail or Flywheel Throw, each bundled with a kit perk. | Swarm adds count as ordinary (`combat.gd:1649-1651`), so plates and Flywheel Throw's small plates gather them. Audit Trail carpets a tunnel. Flywheel Throw clears a sinkhole bowl. Harpoon-spam answers enter here (plan, creative-charge list): a deflector cannot reflect a clip, because a clip is a tag, not a shot; Tally's answer to a deflector is clip it, then stamp a clip beside it. |
| 3, the Highdraft (the Mind; the Mind's hands) | 4 | One set-piece modifier: encore, beats, radius, volley or settle. | Arc reach 62 to 70 m at heft IV and V crosses island gaps; encore legs hop to the next island. The Mind quotes her motif inverted with the total a semitone flat (`mind_tally`, `audio.gd:90`; SOUND-STORY.md:61), so the boss's telegraph is her own tune going wrong. |

## 5. The mecha

The Hoberman mecha from ROSTER-LOOK section 0. A mulberry lattice on Core tumbles with the roll and carries the Hub and Gap empties. A level weapon ring under Pod yaws to the aim. The upright Pod hangs in a two-axis gimbal and holds the seat, twin yokes, the card bank, a copper lap bar and two pedals. Tally sits centred at the equator, her face clear through the front gap. Her row is ROSTER-LOOK section 0.2. This section adds what her machinery reads.

### Machinery: the ledger drums, the card bank and the card magazine

| Part (node, `shell_tally.py`) | Form | What it reads (form mirrors function) |
| --- | --- | --- |
| Ledger drums, `Flywheel.R/L` and `FlywheelAxis.R/L` (`:132-143`) | Today's flywheels, wound with punched card tape. Hub modules carried by the weapon ring at 3 and 9 o'clock, 0.12 m proud of the lattice, so they stay level and yaw with the aim (ROSTER-LOOK section 4, carrier column; section 11, coordinator item 6). | **Pressure.** Each drum face, the rear tell, carries four punched windows. One window shows cream per pressure point, from a punched card behind it. The windows never glow; only the card slot does (ROSTER-LOOK section 0.7). The fourth stays capped with a copper blank until the shop part raises the cap to 4. The HUD pips and the windows read the same slot record (`ability_state.gd` `slots()`), so they cannot drift apart. Surge spins them; the set piece runs them flat out. |
| Card bank, `ReaderCarriage` with `CardBay.0/1/2` (`:144-157`) | A petrol box on Pod beside the right yoke, with three tabbed punched cards in a row, one per bar slot (ROSTER-LOOK sections 0.2 and 0.7). | **Selection.** Bay 0 is slot 1, bay 1 slot 2, bay 2 slot 3. The selected slot's card stands 0.06 m proud; the others lie flat (DESIGN-V3 D11, now driven by `selected`). It slides in 0.12 s, the same time as the HUD mouse glyph. A cooling slot's card shows slate. Tabs 2 and 3 are the levers she throws for slots 2 and 3. Slot 1 fires on a yoke trigger squeeze, so tab 1 only shows the selection (ROSTER-LOOK sections 0.4 and 0.7). |
| `ReaderExit` (`:158`) | The card slot of the card magazine, on the front arc of the weapon ring at 12 o'clock, pointing forward (ROSTER-LOOK sections 0.2 and 0.7). It moves from the carriage top to WeaponRing. | **Aim.** The ring stays level and yaws to the aim, so the slot points where the shot goes. Glow point (`class_accent`) at ultimate ready, and the only light on the mecha. A card leaves here on each volley. |
| `ReturnExit` (`:159`) | A vent on Pod, low behind the seat. The steam escapes through the rear gaps. | Steam on every surge. |
| `StampContact` (`:159`) | The stamp sole on the bottom hub (ROSTER-LOOK section 0.2). | Fires its stamp on the stamp slam and the set-piece landing. |

**Cockpit controls** (ROSTER-LOOK sections 0.4 and 0.7): twin yokes, the card bank beside the right yoke, a copper two-handed lap bar across her lap and exactly two pedals. A callout sheet labels them "1: Balance Due" on the yoke triggers, "2: Gather Plate" and "3: Ledger Clip" on the card tabs, "Q: Plate Return" on the lap bar and "Shift: Flywheel Surge" on the pedals. Each control moves when its skill fires; section 6 names the clips.

### Gap panels across heft classes

The stages are ROSTER-LOOK section 0.3: panels fill the gaps. Tally's gap panel is a square stamped plate with rows of punched holes (ROSTER-LOOK section 0.2).

| Class | What accretes on Tally |
| --- | --- |
| I | Bare lattice: struts, hubs, weapon ring, gimballed pod, drums, card bank. Every gap open. A rider. |
| II | Square panels in the lower gaps, below the pod, like a filing tray, each stamped with two tally strokes. |
| III | Panels in the side gaps, and thicker tread caps on the hubs. Each panel is stamped with three strokes. |
| IV | Panels in most gaps; only the gaps on the sight cone to her head stay open (ROSTER-LOOK section 0.3). The drums sit proud of the lattice, so no panel covers a drum face. Her class IV extra is two drum hoods: curved square plates over the top half of each drum. The drum faces, the pressure read, stay open. Four strokes. |
| V | Every gap paneled except the sight gaps, and the hub modules at their heavy form: big drums, diameter +30% with a second tape reel, the outline break grown to 0.20 m (inside the 0.25 m cap, ROSTER-LOOK section 3 rule 4). The panels carry the crossed five-bar gate. |

Losing a class flings that layer's panels out of their gaps over 0.45 s like loose ledger pages (ROSTER-LOOK sections 0.3 and 5). The strokes count the class: four strokes and the slash are her motif's four strokes and the total. They read at the close camera only; they are flavour, not a read.

### Silhouette rule

**Four circles on a square.** From behind, Tally is the only pilot whose outline breaks with a level, symmetric pair of round shapes at exactly 3 and 9 o'clock. With her two disc ears above (ROSTER-LOOK section 0.2, "echoing the ears"), the four circles sit on the corners of a square, which is her class shape (`class_def.gd:118`). The 2026-10-10 audit of the concept pictures found the read holds at game size: the drums show as bright discs and the ears as the best greyscale read (ROSTER-LOOK section 0.7, Tally). Check: the greyscale identity test in ROSTER-LOOK section 3, rule 10.

## 6. Clips

The seven existing reactions stay as they are (`src/presentation/pilot_reactions.gd:5-18`). A5 confirms ids and the pose route; P-E builds them. Lengths are **start**. Rows follow the shape `{clip, priority, cooldown}`. Clip names follow PILOT-CLIPS section 2, one name per role in every pilot's GLB. The cockpit controls drive the hands (ROSTER-LOOK section 0.4): the yoke triggers for slot 1, the card tabs for slots 2 and 3, the copper lap bar for Q and the pedals for Shift.

| Clip | Length | Trigger signal | Priority, cooldown | Pose story |
| --- | --- | --- | --- | --- |
| `idle_loop` | 4.0 s loop | none; plays under every other clip | lowest | Licks a pencil, ticks the card tabs twice with it, glances out through a side gap at a drum window, tucks the pencil behind an ear. |
| `class_up` | 1.0 s | `heft_class_changed` | 50, 4.0 s | Holds a fresh page up to the camera, then stamps it on her knee as the gap panels slam in. |
| `cast_special` | 0.5 s | `slot_cast` with slot `special` | 30, 1.0 s | Flicks the slot-2 card tab (bay 1) forward, like a dealer dealing a card. |
| `cast_line` | 0.5 s | `line_skill_fired` | 32, 1.0 s | Punches the slot-3 card tab (bay 2) down and tugs it twice like ticker tape. |
| `ult_ready` | 0.8 s | `ultimate_ready` | 45, 10.0 s | Cracks her knuckles and pulls her visor down. |
| `ult_windup` | 0.35 s | `ultimate_started` | 70, 0 s | Grabs the copper lap bar with both paws and leans into the seat. |
| `ult_strike` | 0.5 s | `ultimate_peak` | 68, 0 s | Hauls the lap bar back so the drum tape rips free, punches the air with the stamp, and takes the bar again. |
| `ult_recover` | 0.7 s | `ultimate_landed` | 65, 0 s | Lets go of the lap bar, slams the book shut and sits back. Control returns at 0.25 s; the clip runs on as upper body only. |
| `smash` | 0.45 s | `slammed` (`game_events.gd:50`), the shared roster row (PILOT-CLIPS.md section 1.1) | 36, 1.0 s | Both paws drive a rubber stamp down as the ball lands. |
| `unlock` | 3.0 s | `achievement_earned` with id `ledger_balanced` (`src/core/achievements.gd:62-63`), in Moss's bay | 90, once | Walks in holding the pen (the achievement beat line), climbs into the gimballed seat, stamps the third leaf, and the drums spin up. |

Timing follows principle 15: key poses get short holds, and only the stamp and the punch are fast.

## 7. Earned cosmetics

Nothing is bought. The slot kinds come from A4's scaffold (CUSTOMIZE.md); outfit and shell variant are new kinds there. Grants use today's achievement row schema (`achievements.gd:3-20`). A row cannot test for one pilot today (`need: "class"` only checks that a class is chosen, `src/core/progress.gd:259-288`), so each grant filters on a Tally-only ability id or codex id instead.

| Item | Slot | Look | Grant row | Condition |
| --- | --- | --- | --- | --- |
| Punch Tape | trail | A ribbon of cream card tape with punched holes, tint `f7f1e3` | `ach_tally_punch_tape`: discovery `tally_punch_tape` | "Fire the ledger clip ten times in one stage." |
| Eyeshade | outfit | A mulberry visor and sleeve garters with a copper rim (brass is the Furnace Fleet's colour, `ROSTER-LOOK.md:239`); mulberry is the cloth colour (DESIGN-V3 D12) | `ach_tally_eyeshade`: discovery `tally_eyeshade` | "Settle twenty clips with Plate Return in one run." |
| Abacus Lattice (working name) | shell variant | A shell variant per ROSTER-LOOK section 7; the working idea is copper abacus beads threaded on the lattice struts that slide with speed | `ach_tally_books_balanced`: `on: "synergy_discovered"`, `where: {"synergy_id": "tally_books_balanced"}`, `count: 1`, `hidden: true` | "Settle six clips with one landing." |

`codex.mark_discovered` emits `synergy_discovered` (`src/core/codex.gd:143-157`), so a codex discovery can grant a cosmetic with no new evaluator.

## 8. Discovery and codex rows

Two Tally rows in `src/combat/codex_entries.gd` (`ENTRIES` at `:12`; fields id, name, hint, clue, text). B6 adds the five framework rows (`loaded_line`, `set_piece`, `set_piece_core`, `set_piece_cash_in`, `set_piece_breakout`); these two are hers.

| id | Name | Hint | Clue | Text | Detected in |
| --- | --- | --- | --- | --- | --- |
| `tally_skim` | Skim | The line takes its cut on the way in. | a harpoon bite + the ledger clip on three enemies | Cast the ledger clip on a standing line, or load it before the bite. It clips the target and two neighbours, a point of pressure each. Hit one clip and the rest take it too. | `combat.gd`, the first `link_clips` fire that clips 3 |
| `tally_books_balanced` | Books Balanced | Every clip is a debt. Land and collect. | six clips + one Plate Return landing | Clip enemies on the ride in, then land. The landing settles every clip you made, wherever it ran, and your reader refills. | `ultimate.gd`, the first Tally landing with 6 or more settles |

Tree card copy for the depth-3 picks goes in `src/core/trees/world_one_cards.gd` (`ROWS` at `:10`), one sentence each; depth-4 cards show the node's own effect:

| Node | Card row |
| --- | --- |
| `tl_corner_plate` | Every gather plate hands back a surge. (replaces `world_one_cards.gd:45`) |
| `tl_deep_ledger` | Audit Trail: stamp what you steer over. Kills wind your plate. |
| `tl_carbon_copy` | Flywheel Throw: launch, gather, collect. Rebounds throw a shockwave. |
| `tl_stamp_duty` | Audit Trail: stamp what you steer over. Stamps return your air jump. |
| `tl_reel_in` | Flywheel Throw: launch, gather, collect. Smashes refill a surge. |
| `tl_blowdown` | Flywheel Throw: launch, gather, collect. Surges vent steam. |
| `tl_governor` | Audit Trail: stamp what you steer over. A third, faster surge. |
| `tl_plate_rack` | Flywheel Throw: launch, gather, collect. Two gather plates. |
| `tl_return_slip` | Audit Trail: stamp what you steer over. Plates throw shockwaves. |

## 9. Tests and bot checks

All run headless: `npm run sketch:smoke -- --sketch core-loop --test <name>` (the `--test` option, `scripts/sketch-smoke.mjs:127, 158`).

| File | Kind | Cases |
| --- | --- | --- |
| `tests/tally_kit_test.gd` | re-pin, dated header | Class row: weapon `ledger_reader` with cards `["balance_due"]`, special `gather_plate`, line `link_clips`, ultimate `plate_return`. Slot 1 tap spends 1 pressure; time never refills; a dry press emits `verb_failed("fire", "cooling")` and spends nothing. Rolling at cruise restores 1 per 2 s; ram, stomp and stamp restore. Balance Due scales with speed and never shatters a Warden chunk (today's case at `:440-470` kept). Slot 2 tap: no pressure spent, 6 s cooldown, the plate pulls ordinary enemies only. Slot 3 on a body line: 3 clips, +3 pressure capped at max. Slot 3 with no line loads; the bite within 4.0 s clips; expiry at 4.01 s. Clip post on a world latch clips the first 3 passers. A direct hit on one clip arcs to the others at the stored chain multiplier. Arcs on a Warden fill posture and never touch the core. Surge keeps today's speed case (`:472-501`) and adds +1 pressure per surge, capped (A2-CRITIC). The old bay, plate-return and echo cases (`:242-253, 503-578`) retire. |
| `tests/tally_set_piece_test.gd` | new | Plan: plate within 45 m and 30 degrees picks a `line` path to it; otherwise the framework order. Volleys clip up to 3 per beat, up to the class cap (6 at I, 10 at V). The peak plants a plate at B. Landing: strike in radius; each clip outside takes 40% once; no enemy is paid twice; pressure refills to full. Open Warden core: the landing shatters it; volleys and settles do not. Boss x0.5. Audit Trail stamps under the path and ignores aim. Flywheel Throw prefers `arc`. Each knob in section 3 changes its number. Picking `tl_deep_ledger` swaps the ultimate to `plate_audit`; `tl_carbon_copy` to `plate_flywheel`. |
| `tests/tree_data_test.gd` | must pass | `UpgradeTree.problems("tally")` is empty with the new rows. |
| `tests/tree_safe_picks_test.gd` | pass or re-pin | Ultimate swaps replace an ability by design. Either B1 exempts `ultimate` swaps, or `UNSAFE["tally"]` (`:23`) lists the 8 depth-3 ids under a dated header. |
| `tests/tally_look_test.gd` | re-pin, dated header | `SLOTS` icons (`:24`) read the special slot as `ab_tally_gather`; `ICON_SLOTS` (`:25`) gains `line` and `ult`; the registry count (`:204`) follows the icon unit's total. Tree icons stay `ab_tally_*`. |
| `tests/ability_swap_pressure_test.gd` | must pass unchanged | `ledger_reader` keeps pressure 3. |
| `tests/relics_data_test.gd` | must pass unchanged | Relic ids stay; only three texts change. |
| `tests/combat_codex_test.gd`, `tests/codex_coverage_test.gd` | pass | The two Tally rows open once on their scripted trigger. |
| `tests/bot_six_tally_test.gd` | the bot win | Four skipper runs, stage 1 to the world-one win (`bot_six_tally_test.gd:1-7`, runs in `bot_six_pilots_test.gd`). Each winning run casts slot 2 and slot 3 at least once and fires at least one ultimate (B4's acceptance). |
| `tests/alpha_posture_bands_w23_test.gd` | must stay in band | Tally runs at seed 5 (`:25`). The grown band stays at 25 s or more (SKILL-BAR section 11 risk). If a band moves, re-pin with a dated header and a `docs/decisions.tsv` row. |

Bot hands for Tally (`tools/bot_driver.gd`, `_card_hands` only, `:2136-2147`): drop the `bay_pick` hold. Keep the held trigger turned into one slot-1 press per `CARD_PRESS_GAP`. Cast slot 2 through B4's `_cast(1)` when 3 or more ordinary enemies stand within 12 m of the aim point. Slot 3 and Q go through B4's `_line_hands()` and `_ultimate_hands()`. Q also fires when her plate is out within 45 m with 3 or more enemies within 6 m of it.

## 10. Implementation map: wave P-C, unit Tally

**SCOPE** (exact files; the Tally block only where a file is shared):

- `src/core/class_def.gd`: the tally row (`:115-121`): `special_id` `gather_plate`, `line_id` `link_clips`, `ultimate_id` `plate_return`, pitch "Gather the pack, clip it on the line, then make it pay. Roll to refill the pressure. Q rides home and settles every clip."
- `src/core/ability_state.gd`: the six rows in section 3.
- `src/combat/weapons.gd`: Tally constants beside `:97-128`: `CLIP_PRESSURE := 1`, `CLIP_POST_RADIUS := 4.0`, `CLIP_POST_SECONDS := 4.0`, `CLIP_POST_MAX := 3`, `SETTLE_SHARE := 0.4`, `CLIP_CAP := [6, 7, 8, 9, 10]`, `ULT_PLATE_AIM_DEG := 30.0`, `AUDIT_STAMP_RADIUS := 4.0`, `AUDIT_STAMP_KNOCK := 10.0`, `FLY_KNOT_SEARCH := 15.0`, `FLY_PLATE_SECONDS := 1.5`, `FLY_PULL := 4.0`, `FLY_PULL_LEAD := 0.2`. The `PLATE_RETURN_*` constants (`:124-128`) retire.
- `src/combat/combat.gd`: the Tally block (`:1605-1836`): `_step_cards` runs Balance Due only; `_specials["gather_plate"]` on the tap path without `_spend_card`; `_line_skills["link_clips"]` with `on_body`, `on_world` (clip post) and `geometry`; `link_group` stores the chain multiplier; pressure pay; `_specials["plate_return"]` and its echo branch removed (`:302`, `:1322-1325`); `tally_skim` detection.
- `src/combat/ultimate.gd`: `_ult_rows` entries for `plate_return`, `plate_audit`, `plate_flywheel`; `tally_books_balanced` detection.
- `src/core/trees/tally.gd`: the 25 row edits in section 3.
- `src/core/upgrade_tree.gd`: one `KNOBS` row, `"ult_settle": {"default": 0.4}` (beside `:54-76`). The coordinator serializes this line with the other pilots' units.
- `src/core/trees/world_one_cards.gd`: the 9 rows in section 8.
- `src/build/relics.gd`: three texts: `return_spring` "Gather plate recharges 25% faster" (`:55`), `plate_hinge` "Gather plate recharges 30% faster" (`:92`), `second_plate` "Stock a second gather plate" (`:129`).
- `src/ui/class_kit.gd`: `LABELS` gains `link_clips` "ledger clip" (replacing "link", `:40`), `plate_audit` "audit trail", `plate_flywheel` "flywheel throw"; `FANTASY["tally"]` (`:65`) "Gather. Clip on the line. Make them pay."
- `src/combat/codex_entries.gd`: the two rows in section 8.
- `src/core/achievements.gd` and `src/core/cosmetics.gd`: the three rows in section 7, if B5's scaffold accepts rows whose art lands in P-D. Otherwise they move to the P-D Tally unit.
- `src/presentation/audio.gd`: rows `tally_plate`, `tally_clip`, `tally_stroke`, `tally_settle`, each in `KEYED_SOUNDS` (`:85-90`), in one Tally block.
- `assets/icons/ab_tally_line.svg`, `assets/icons/ab_tally_ult.svg`, and their `Icons.EXTRA` rows in `src/ui/icons.gd`. Palette: ledger cream `#e6d9b8` (`Palette.LEDGER`, `src/core/palette.gd:22-23`; `TALLY_COLOR`, `class_def.gd:17`), no amber, no mint, no brass. **A2-CRITIC lore fix:** `tally_look_test.gd:200` pins all seven existing Tally icons to brass `#d9b44a` (`ICON_SLOTS`, `:25`), which is Brindle's colour (`palette.gd:20-21`) on friendly gear. The unit re-pins that check to `#e6d9b8` with a dated header and recolours the seven existing icons in the same commit, so the two new ones match them.
- `tools/bot_driver.gd`: `_card_hands` only.
- Tests in section 9.

**ACCEPTANCE**:

- Keys 1, 2, 3 play Balance Due, Gather Plate and Ledger Clip; Q plays Plate Return.
- Balance Due spends 1 pressure; Gather Plate and Ledger Clip spend none.
- Gather Plate refuses a pick for 6.0 s after a cast; Ledger Clip for 8.0 s.
- A body-latch clip makes 3 clips and pays 3 pressure, never past the cap.
- A world-latch clip post clips the first 3 passers within 4 m in 4 s and adds `reel_burst`.
- One direct hit on a clip arcs once to each other live clip at the chain multiplier stored at the cast.
- Plate Return picks a `line` path to a plate within 45 m and 30 degrees of the aim.
- The landing settles every clip outside the radius once at 40%, refills pressure to full and ends the chain.
- No card, arc or settle cracks or shatters a Warden core; the landing on an open core shatters it.
- A boss takes x0.5 from every Tally source, and its windows do not move.
- A world-2 tree offer for Tally shows one Audit Trail node and one Flywheel Throw node as siblings.
- Each depth-4 knob changes the number section 3 names.
- `tests/bot_six_tally_test.gd` wins world one with at least one slot-2 cast, one slot-3 cast and one ultimate per winning run.
- `tally_kit_test`, `tally_set_piece_test`, `tree_data_test`, `tree_safe_picks_test`, `tally_look_test`, `ability_swap_pressure_test`, `relics_data_test`, `combat_codex_test`, `codex_coverage_test` and `alpha_posture_bands_w23_test` pass, with dated headers on every re-pin.
- `git diff --name-status` against the base shows only SCOPE files.

**Depends on wave P-B:**

| P-B unit | What Tally needs from it |
| --- | --- |
| B1 | The slot model and router; the tap path in `_step_special`; `_line_skills`, `_step_line` and the load; `line_id` and `ultimate_id` on class rows; `SWAPPABLE`. Also `upgrade_tree.KEYS` (`:45`) must gain `line` and `ultimate`, or every depth-3 and depth-4 row here fails `problems()` (`:280-281`). B1's scope names only `SWAPPABLE`; this sheet asks for `KEYS` too. |
| B2 | The bar draws slot 1's pips and the slot-3 load badge from `slots()` and `line_load()`. |
| B3 | `ultimate.gd`, the meter and `_ult_rows`; the four framework knobs in `KNOBS`. One generic addition this sheet asks for: an optional row key `target: Callable(ball, aim) -> Dictionary` that `plan()` consults first, so a pilot can name its own B (Tally's plate; Sable's pylon or Kest's mine could use it later). |
| B4 | `_cast`, `_line_hands`, `_ultimate_hands`, and the `bay_pick` removal everywhere but `_card_hands`. |
| B5 | The outfit and shell-variant slot kinds and the cosmetic reward path. |
| B6 | The codex framework rows, so `codex_coverage_test` counts Tally's two on top. |

Order: the Tally unit starts after B1, B3 and B4 merge. Its cosmetic rows wait for B5 and its codex rows for B6. Between B1 and this unit, Plate Return is off her kit (SKILL-BAR section 11 risk); the P-B export notes say so.

### Measures: how each part shows it works

| Part | Measure, from the run log (SKILL-BAR section 7) | Healthy band (start) |
| --- | --- | --- |
| The wallet | share of slot-1 presses refused for empty pressure | under 15% |
| Gather Plate | `slot_casts.special` per stage | 3 or more |
| Ledger Clip | `line_skill.on_line` against `line_skill.loaded`; clips per cast | both used; 2.5 clips a cast or more |
| Plate Return | settles per landing, from `ultimates[].landing_hits` minus strike hits | 3 or more |
| Depth 3 | which variant bots and Andrew pick in world 2 | neither above 80% over 10 runs |

## 11. For Andrew

### Veto list (Calls; say "veto" on a line and it changes)

1. Gather Plate leaves the pressure pool: free to cast, 6 s cooldown.
2. The ledger clip pays 1 pressure per clip instead of costing pressure.
3. A clip post on a wall clips the first three enemies that pass it.
4. Plate Return rides to your gather plate first when it is within 45 m and near your aim.
5. At the peak, a plate lands under the landing point and pulls the pack in.
6. The landing settles every clip at 40% of the strike, anywhere on the map.
7. The landing refills pressure to full.
8. Cards and settles never crack a Warden core; only the ball's landing can.
9. In world 2 the tree pick is always Audit Trail against Flywheel Throw.
10. Depth 3 and 4 picks keep their old kit perk beside the ultimate change.
11. Tally gets one knob of her own, a bigger settle share (40% to 70%).
12. The selected slot's card stands up in the card bank beside her right yoke.
13. The drum faces show pressure as four punched windows.
14. Class IV adds hoods over her drums; the drum faces stay open.
15. Her gap panels are stamped with tally marks that count the heft class.
16. Earned items: Punch Tape trail, Eyeshade outfit, Abacus Lattice shell.
17. Each Flywheel Surge pays 1 pressure (A2-CRITIC), so her Shift feeds the wallet instead of copying Sable's shove.
18. Her icons and trims use ledger cream and copper, never brass; the seven existing brass icons are recoloured (A2-CRITIC).

### Open questions for Andrew

1. Should holding left click repeat Balance Due every 0.4 s? Default: no, it stays a tap as today.
2. Should a clip that finds pressure already full feed the ultimate meter instead of being lost? Default: no, lost; listed as an extra below.

### Open for the coordinator (not Andrew)

1. Resolved by A2-CRITIC: `KEYS` gains `line` and `ultimate`, and a swap to a `variant_of` row counts as growth (SKILL-BAR section 12, item 3).
2. Resolved by A2-CRITIC: see item 1.
3. Resolved by A2-CRITIC: the `target` key is SKILL-BAR section 12, item 2.
4. Resolved by A2-CRITIC: B1 pre-seeds one marked block per pilot in `KNOBS` and the other shared tables (SKILL-BAR section 12, item 4).
5. Cosmetic rows whose art lands in P-D. Default: rows land in P-C only if B5 accepts pending assets.
6. Drums on tumbling hubs. ROSTER-LOOK section 0.2 puts the ledger drums on the 3 and 9 o'clock hubs and the stamp sole on the bottom hub. Hubs tumble with the lattice (ROSTER-LOOK section 0.1; Core is a child of the rolling node, `hero_assets.gd:401`). So once the ball rolls, the drums leave 3 and 9, which breaks the rear pressure read and the four-circle rule (section 5), and the sole leaves the bottom. Default: parent `Flywheel.R/L` and `FlywheelAxis.R/L` to WeaponRing at 3 and 9, so the drums stay level beside the gun they feed and swing with the aim. Place the stamp effect at the ground contact under the ball, and keep the sole on its hub as a look.

### Optional extras (separable, not in the unit)

- **Overdrawn.** With pressure at 0, the ledger clip pays 2 per clip. An inversion in the spirit of principle 20: the empty wallet becomes the reason to bite.
- **Carry-over.** Pressure a clip cannot hold feeds the meter at 2 points each, so a full wallet still earns.
- **The plate as an anchor.** The harpoon can latch her own plate for a short yank into the knot. It touches the harpoon target query (`src/movement/harpoon.gd:20-29`), so it waits for a later wave.
