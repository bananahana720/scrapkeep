# Core-loop visual language (V1)

This is the style sheet for the v2 greybox as it grows into its real look (TRACKING EV-0588, light play lane). It serves V2 icons, V3 hero assets, W1 UI, W2 threat grammar and W5 audio. It applies BIBLE §7 (AD-01 to AD-11) and does not amend it. Promoting any of it into the Bible or PD-01 needs a heavy-lane card. The species, cultures and enemy factions come from DESIGN-V2 §9 and §10 on `proto/core-loop-v2` (c5c2137), which this sketch may use. The Bible still treats them as candidates (AD-11) until that heavy-lane card lands.

**One source.** Every fact on screen reads from one row in code, and every layer (shape, colour, motion, sound, wording, placement) reads the same row.

| Fact | Source row |
| --- | --- |
| A colour's value | `src/core/palette.gd` |
| A colour's meaning, and the code that must never draw it | `tests/support/colour_meanings.gd` (checked by `tests/colour_meanings_test.gd`) |
| A class's colour, shape and sound | the class row in `src/core/class_def.gd` |
| An event's colour, shape, sound, wording and priority | `src/core/event_kinds.gd` |
| A threat type's fill, motion and sound | `src/combat/threat_grammar.gd` (W2) |
| An icon | `assets/icons/<id>.svg`, keyed by the ids in §5 |

`SOUND-STORY.md` is the sibling source for story and audio. Each motif here names its intended sound character in one phrase, and that file owns the sound itself.

## 1. Essence

After humans were lost, animals became the reigning intelligent species, and they grew up repairing the machines that ended us. Everything the player owns was salvaged, bolted on and repaired by a visible pilot, and it hums with the same mint field that pulls scrap home. Everything hostile is either Furnace Fleet gear in requisition paint or an ancient human war machine the Fleet dug up, and both mark their danger with hazard stripes.

| Mood word (AD-09) | What it means on screen |
| --- | --- |
| Greasy | Dark oil pools at joints and hinges only. Panels stay readable. |
| Scrappy | Mismatched plates, visible bolts, lopsided mass. No two chunks share a face colour. |
| Inventive | Every ability shows its mechanism: the pylon, the rope, the fins, the fuse. |
| Rowdy | One bold, loud animation per event, with an instrument to match. |
| Weathered | Sun-faded paint on top faces, rubbed bright metal where hands and rope touch. |
| Adventurous | The camera shows the route ahead. A focal landmark (the dam-works tower cluster) orients every layer. |
| Awe-filled | Small ball, huge gorge, ancient ruins older than anyone alive. Scale comes from the world, never from inflating the player. |

**Two material eras.** The living world is steampunk. It is bolted, welded, steam-driven and patched, and every surface shows a repairer's hand. The ancient layer is post-apocalyptic futurism. It is cast, seamless and geometric, made by humans, then buried and weathered. Contrast between the eras tells the player, at a glance, who made a thing.

## 2. Palette roles

The eight AD-02 colours carry every role. Four extensions already live in code and keep narrow jobs, and one more is proposed. AD-02 allows local colours, and each extension exists so one fact reads as nothing else.

| Colour | Hex | Role | Never |
| --- | --- | --- | --- |
| Sandstone | `#c6a274` | Terrain, dust, masonry | Any indicator fill (it vanishes on terrain) |
| Iron oxide | `#9b513a` | Rust, red rock, harm to you (player hit, scrap lost, heft down), Fleet body paint | Text on charcoal (2.5:1) |
| Oil charcoal | `#242a28` | UI panels, tyres, keylines on every world indicator, icon strokes | Large world surfaces (it reads as a hole) |
| Weathered petrol | `#365754` | Machinery bodies, recesses, the old enamel of ancient machines, cooldown wedge, inactive slot fill | Text of any kind |
| Worn bone | `#d2c5a5` | HUD text, neutral glyphs, keycaps, grey panels, the kinetic element | Hostile marks |
| Copper | `#b77843` | **Rivet**. Coils and windings on every mech | World rewards, enemy parts |
| Safety amber | `#e5a044` | **Kest**. Relic rarity (gold rung, with a mint heart). Pressure gauges | Hostile fills |
| Field mint | `#8bf0d3` | The shared collection field (scrap, beacon, core), **Sable**, the arc element, common rarity (the field-kit rung) on cards, gates and shop frames | Enemy parts; ambient decoration away from a working device |
| Fleet cobalt (extension) | `#3d8bff` | Rare rarity: the fleet-grade rung, on cards, gates, shop frames and the ball's rare part pieces | Hostile marks, the ancients' light |
| HAZARD (extension) | `#ff5a3c` | Hostile danger areas and nothing else | Any reward, any player effect |
| BRASS (extension) | `#d9b44a` | Admiral Brindle and the Fleet's requisition tags | Player effects, the money |
| Worn steel (extension, W1-21, 12 Nov 2026) | `#9aa0a0` | The cog (the money) with bone-worn teeth, the HUD wallet chip, the grey panels' hardware (`Palette.STEEL`). Chosen off brass because a deuteranope reads brass as the relic's amber; an assumption Andrew can overturn | Not-yet states (slate's job), hostile marks |
| ICE (extension) | `#c8f0ff` | The frost element | Anything that is not frost |
| ANCIENT | `#9dff3c` (candidate B, chosen by Andrew 2026-10-09; seams carry the pattern cue) | Light seams on awakened ancient machines, the focal landmark's beacon | The Fleet, the player, rewards, danger areas |
| Life lilac (extension, proposed 2026-10-19) | hue 250°–300°, saturation 0.15–0.55, for example `#8f84b3` | Ambient critters and locals: harmless and alive. Measured: no enemy, Warden or boss GLB has a saturated colour in 240°–330° (`tests/ambient_palette_test.gd` re-measures every run). See [AMBIENT-LIFE.md](AMBIENT-LIFE.md) | Enemy parts, telegraphs, rewards, pickups, targets, any emissive light |

**Cannon exception (22 Oct, DECISIONS section 10).** The Cannon's relic part alone carries dashed ANCIENT seams and four barrel bands, from the Cannon board Andrew kept. No other player part may carry ANCIENT green.

**ANCIENT candidates.** Ancient machines need a light no other fact uses. Andrew rejected violet on 2026-09-27 as overused. Three alternatives were measured with the same method as above: WCAG contrast, and the smallest Machado CIELAB ΔE against all eleven palette colours (the AD-02 eight plus HAZARD, BRASS and ICE) under each vision type.

| Candidate | Hex | Meaning | Contrast on charcoal / sandstone / petrol | Closest collision, normal / deutan / protan / tritan | Redundancy cue it needs |
| --- | --- | --- | --- | --- | --- |
| **A. Cherenkov blue** (recommended) | `#3d8bff` | The glow of a human reactor pool, the light of the age that ended | 4.4 / 1.39 / 2.39 | ICE 68 / ICE 67 / ICE 59 / mint 31 | Seams cut as charcoal grooves twice the seam width, so the glow reads by value on petrol enamel. Pure sine hum. |
| B. Uranium-glass green | `#9dff3c` | The phosphor of old dials and glassware | 11.7 / 1.90 / 6.35 | BRASS 65 / BRASS 20 / BRASS 37 / mint 13 | Would need a pattern on every seam, because it reads as Brindle's brass to deuteranopes and as mint under tritanopia |
| C. Thin-film sheen plus neutral white | `#ffffff` light on an iridescent enamel | Machined perfection no workshop can reproduce | 14.6 / 2.38 / 7.93 | ICE 17 / mint 14 / ICE 11 / ICE 21 | Rests entirely on the sheen shifting with view angle and on the seam pattern, because white sits near frost and mint |

Rejected violet `#a98cf0` measured ICE 61 / ICE 43 / ICE 49 / bone 22 for reference.

**Recommendation.** Choose A, Cherenkov blue. It is the only candidate whose closest collision stays at ΔE 31 or more in every vision type, it has no hue neighbour in the palette, and its meaning is literal (it is the light of human nuclear tech, which also ties to the reactor relics). Its one weakness is value on petrol enamel (2.39:1), which the charcoal groove fixes. C's sheen can layer on top as a material cue if Andrew wants more strangeness. Andrew chose B, uranium-glass green, on 2026-10-09. Its redundancy cue is mandatory: every ancient seam carries the seam pattern as well as the colour, because B reads as BRASS to deuteranopes (ΔE 20) and as mint under tritanopia (ΔE 13). palette.gd, the swarm icon and the pinned tests move with it in wave 12 (VX-SURF).

**Mint is shared on purpose.** Sable's kit is the collection field turned into a tool, so Sable owns mint and the collectors keep it. Scrap in flight is a square chunk on a path into the intake. Sable's effects are rings. Shape separates them.

**Class colour means "yours".** Any effect the player's own action creates (indicator, trail, hit spark, kill pop, movement cue) takes the class colour from the class row. Rewards, the world and hostiles never do. The rule governs emissive light and effects, not materials. A copper pipe on a steam lift is plumbing, and a painted amber stripe on a valve is a safety marking.

**Rarity ramp.** The item ladder (23 Oct 19:28Z): grey panels are worn bone, common (the field-kit rung) field mint, rare (the fleet-grade rung) cobalt, and relic (the gold rung) two-tone amber with a mint heart, since I2 names every rare_plus item a Core or Heart (Andrew accepted this on 2026-09-27). Two places keep an older read on purpose: a common part piece on the ball stays copper hardware, so mint never coats the shell, and the common pickup flash stays sandstone, because mint flashes mean "live" (an open weak point). HAZARD leaves the ramp. Each rarity also has a frame (§5), so colour never carries it alone.

**Contrast rules.** These ratios were measured with the WCAG formula.

- Text sits only on charcoal. Bone is 8.5:1, mint 10.8:1, amber 6.6:1, brass 7.4:1, HAZARD 4.7:1.
- Copper text on charcoal is 4.0:1, so copper labels must be bold and at least 18 px, or lightened 20% toward bone.
- Amber on sandstone is 1.07:1 and HAZARD on sandstone 1.3:1. Every world-space indicator, player or hostile, therefore carries a charcoal keyline (4 px on screen, or 0.08 m in world) so it separates from terrain by value.

**Colour-blind redundancy rule.** Every fact carries at least one non-colour cue (shape, pattern, motion or sound), and every hostile fact carries two. Measured with Machado CVD simulation (CIELAB ΔE):

| Pair | Normal vision | Deuteranopia | Protanopia |
| --- | --- | --- | --- |
| Kest amber / HAZARD | 45 | 8 | 23 |
| Rivet copper / HAZARD | 44 | 17 | 2 |
| Kest amber / Brindle brass | 16 | 3 | 6 |

Rivet's indicators and a hostile telegraph are the same colour to a protanope. That is why hostile areas carry hazard stripes and player indicators never do (§3). Amber and brass are close even in normal vision. Kest and Brindle therefore never share a shape. Kest is a starburst, and Brindle's mark is a brass tag.

## 3. Shape grammar

| Shape | Means | Examples | Sound character |
| --- | --- | --- | --- |
| Ring | Area around a point | Sable's discharge, beacon charge zone, landing puff | A bright rising arpeggio |
| Chevron | Motion and direction | Rivet's sprint, a wave's travel, boost, stage entered | A driving hi-hat roll |
| Starburst | Explosive release | Kest's charges, a kill pop, a synergy found | A low kick-drum thump |
| Diamond | Reward or core | Gates, parts, bonus core, fabricator stock | A warm bell chime |
| Bracket (four corners) | Target or landing point | Projectile landing reticle, objective frames, lock-on | A dry ratchet click |
| Dashed line | Future or extent | Charge preview, reach limit, lobbed-arc trace, max gauge | A soft sustained hum |
| Solid line | Committed or now | The geometry that will resolve this tick | A sharp transient |
| Hazard stripes (45°) | Hostile | Every enemy danger area, threat icons | The klaxon family, metal scrape |

**Stroke weights at 1080p.** Committed edge 4 px, dashed extent 2 px (8 px dash, 6 px gap), keyline 4 px charcoal under every world indicator, icon primary stroke 6 px at the 64 px master. In world units, committed edges are 0.12 m and extents 0.06 m.

**Hostile against yours.**

| | Hostile | Yours |
| --- | --- | --- |
| Colour | HAZARD family (fill 35% alpha, edge 100%) | Class colour (fill 15% alpha, edge 100%) |
| Pattern | 45° stripes, HAZARD and charcoal, 0.5 m pitch in world | Clean fill, never striped |
| Edge | Sharp corners, spiked where it ends | Rounded caps, class tick marks on the rim (ring pips, chevrons or starburst spikes) |
| Sound | Hostile instruments (klaxon family, metal scrape) | Class instrument (arpeggio, hi-hat, thump) |
| Motion | Fills toward the moment of harm | Grows with your hold, fires on release |

Hostile bodies belong to two factions with separate looks (§11). Their danger areas share this grammar, whoever owns them.

## 4. Telegraph grammar

Every committed hostile attack draws the declared geometry damage will use, and nothing else (TH-16 RR-01). Its height band is drawn as geometry (RR-02). The four W2 types share the HAZARD family and differ by fill, motion and sound.

| Type | Fill | Motion | Sound | Icon |
| --- | --- | --- | --- | --- |
| Instant AOE | Striped area fills linearly from the edge inward over the wind-up, then flashes solid for one frame at impact | None until the flash | Rising ratchet clicks, one per 0.1 s, then a sharp clang | `thr_instant` |
| Travelling wave | Only the leading edge is bright (0.4 m band). The swept area behind it is 15% stripes. | The edge moves at the real resolved speed, with chevrons pointing along its travel | A whoosh that rises in pitch as the edge nears the player | `thr_wave` |
| Projectile | A dotted flight trace from the launcher, plus a bracket reticle at the landing point | The reticle's four brackets close on the landing circle and meet at impact | A launch thunk, a falling whistle, a landing crump | `thr_projectile` |
| Lane or beam | A striped rectangle fills from the source end to the far end | The fill front runs outward and reaches the end at fire time | A charge hum that holds, then a tearing buzz | `thr_lane` |

- **Boss telegraphs** use the same four types and the same HAZARD fill. Brass marks whose attack it is, as a brass tick every 30° on the rim and on Brindle's tool. Danger is always HAZARD.
- **Composition order** follows RR-05. The attacking tool comes first, then the footprint, then the escape, then effects. Dust and sparks spawn only outside the footprint's edge.
- **Overlap** follows RR-06. Each telegraph draws its own edge. Overlapping fills add no brightness, and edges stay on top.

**Player skill-shot indicator.** This covers every F special, Kest's lobbed LMB and Sable's slingshot.

- **Geometry.** Draw exactly the geometry the hit test resolves. Solid means the release now. A dashed outline shows the full-charge extent.
- **Forgiveness.** Aim forgiveness lives in the hit test, where a target counts if its hull touches the geometry. It never lives in a drawing that differs from the damage (see Conflicts resolved).
- **Style.** Class colour, 15% clean fill, rounded caps and class tick marks on the rim. No stripes, ever. An aim mark (the vault kick, the slingshot, the bank shot) shows the line the ball leaves along, not an area a hit lands in. It is one dashed line with a short root of fill, both starting at the ball's edge so the ball stays clear; the root is a strip along the line (0.6 m wide at its foot, 0.3 m at its end), 15% at the ball's edge and thinned to nothing 1.2 m on, whatever the line's length. It was the cone's spread, which pitched up on a mount stood over the view as a mint sheet (the PC read 8.5 to 9.6% of its box against an 8% line). The whole mark fades out between 4 m and 1.5 m from the lens, because a kick off a wall you face points back over the camera. It was a fan of three dashed lines: blind readers took the spread for a width of travel that does not exist, and all three who saw it said it made the hint line harder to read, against none of three with the one line (10 Nov 2026). The kick's mark shows only while a kick is on offer, so never on a mount. Indicator colours are written as the palette's sRGB values and their material says so (`src/movement/indicator.gd`); without that the PC's renderer drew the charcoal keyline mid grey.
- **Gauge ring.** A 48 px ring around the reticle fills clockwise from 12 o'clock, linearly over `charge_max`. At full it holds with a slow class-colour breathe (0.5 s period) through the 0.5 s grace, then fires.
- **Cancel or knock.** The indicator and the gauge collapse to the reticle in 120 ms with a dry click. No release sound plays and no cooldown sweep starts.
- **Blocked.** A blocked or invalid aim draws the indicator in bone, dashed, with a charcoal cross at the reticle (RR-03).

## 5. Icon grammar

**Grid.** The master is 64 px with a 4 px margin (56 px live area). The keyline shapes are a 52 px circle, a 48 px square and a 56 × 40 px landscape rectangle. The minimum render is 24 px. Test every icon at 24, 32 and 64.

**Stroke and corners.** The primary stroke is 6 px (2.25 px at 24). Detail strokes are 4 px, and nothing is thinner. Outer corners have a 4 px radius for worked metal. Hostile and damage points are sharp (0 radius).

**Colour.** An icon is a bone glyph on a charcoal backplate with at most one accent region. The accent is the class, element or rarity colour, or HAZARD for threats.

**Silhouette first.** Fill the glyph solid charcoal on bone at 24 px. It must stay distinct from every other icon in its category. No text inside an icon, except the letter on a keycap.

**Rarity frames.** The frame is shape, never colour alone.

| Rarity | Frame | Colour |
| --- | --- | --- |
| Common (field kit) | Thin 2 px outline | Mint |
| Rare (fleet grade) | Double outline, two 3 px lines with a 3 px gap | Cobalt |
| Relic (gold; was rare_plus) | Double outline with bolt heads round it, like a gauge bezel: at the four corners (45°) and the edge midpoints, so they still read where the element and trigger badges cover the lower corners | Amber outer, mint inner |
| Evolved | Double outline, the outer cut into the ancients' dashed seam, with diamond points at the corners and no bolts, so the dashes read along every edge | ANCIENT outer, mint inner |

**Rarity shapes in the world.** The same rungs have one 3D shape each, owned by `src/build/tier_mark.gd`: common a bar, rare a diamond, relic a four-point star with a mint heart, evolved a crown. The reward gate's toppers (`tools/blender/reward_gate.py`) carry the same four shapes. A pedestal gem is the upright shape. A part piece on the ball stands on the flat version (none for common, which stays bare copper hardware). `tools/tier_still.gd` and `tools/tier_cvd.py` render the four tiers and check they still differ under deuteranopia (W1-26).

**Category backplates.**

| Category | Backplate | Prefix |
| --- | --- | --- |
| Ability | Rounded square (the HUD slot) | `ab_` |
| Class emblem | Circle medallion | `cls_` |
| Key | Keycap (square with a thicker bottom lip) or mouse body | `key_` |
| Item category | Hex nut | `cat_` |
| Element | Circle | `el_` |
| Trigger | Workshop parts tag (rounded rectangle, punched hole at left) | `trg_` |
| Threat | Warning triangle with a striped base band | `thr_` |
| Objective | Four corner brackets | `obj_` |
| Resource | None (bare glyph beside a gauge or number) | `res_` |
| Faction | Pentagon badge | `fac_` |

No `CONTRACTS.md` Icons section existed when this was written. It was checked in `core-loop-v2-ui` at base 2792144. W1 should adopt these ids.

### Icon list (79)

**Class emblems and abilities (19).**

| id | Meaning | Drawing |
| --- | --- | --- |
| `cls_sable` | Sable | A ring with two bolted pylon plates at 10 and 2 o'clock |
| `cls_rivet` | Rivet | A forward chevron with three raked fins behind it |
| `cls_kest` | Kest | An eight-point starburst with a fuse wick curling off one point |
| `ab_sable_weapon` | Arc caster (LMB) | A stubby pylon prong at left, a zigzag arc leaping right to a small ring |
| `ab_sable_move` | Grapple and winch (RMB) | A hook jaw top-right, a rope curving down to a spool circle bottom-left |
| `ab_sable_special` | Detonation gauge (F) | Three concentric rings, the outer one dashed, crossed by a short bolt |
| `ab_sable_smash` | Arc slam (Ctrl) | A down chevron meeting a ground line, a ring spreading, two short upright ticks |
| `ab_sable_vault` | Vault kick (Space at a face) | A vertical wall bar at left, a ball leaving it along a sharp 60° arrow |
| `ab_sable_mount` | Mount pylon (E) | A pylon spike driven into a wall bar, a small ring at its head |
| `ab_rivet_weapon` | Rapid laser (LMB) | Three short parallel dashes ending in one chevron point |
| `ab_rivet_move` | Overdrive sprint (RMB) | A double chevron punching through a broken bracket |
| `ab_rivet_special` | Overdrive blast (F) | Six chevrons around a centre dot, pointing outward |
| `ab_rivet_smash` | Shockwave skid (Ctrl) | A ball on a ground line, a forward wedge ahead, two skid dashes behind |
| `ab_kest_weapon` | Sticky charges (LMB) | A round charge with a four-point fuse spark, on a dotted lobbed arc |
| `ab_kest_move` | Smoke blink (RMB) | Two ball positions with a dashed gap: a puff-wrapped outline behind, a solid ball ahead |
| `ab_kest_special` | Detonation line (F) | A straight line with three small starbursts along it |
| `ab_kest_smash` | Demo slam (Ctrl) | A down chevron over a ground line, three small starbursts splayed along it |
| `ab_kest_glide` | Glide and rocket jump (Space) | A ball under a shallow wing arc, a small starburst beneath it |
| `ab_kest_cloak` | Dust cloak (passive) | A ball half hidden by a dotted cloud outline, one spark at its edge |

**Key glyphs (16).** Each is a bone keycap with a charcoal letter, or a mouse body.

| id | Meaning | Drawing |
| --- | --- | --- |
| `key_lmb` | Weapon | A mouse body, the left button a solid bone fill, a clear divider |
| `key_rmb` | Movement | A mouse body, the right button a solid bone fill, a clear divider |
| `key_f` | Special | Keycap "F" |
| `key_ctrl` | Smash | A wide keycap "CT" |
| `key_space` | Jump, vault, glide | A long flat keycap with an empty face |
| `key_shift` | Boost | A wide keycap with an outlined up arrow |
| `key_e` | Mount | Keycap "E" |
| `key_q` | Winch | Keycap "Q" |
| `key_r` | Hold to restart | Keycap "R" with a circular arrow |
| `key_tab` | Hold for field notes | A wide keycap with an arrow into a bar |
| `key_1` | Menu choice 1 | Keycap "1" |
| `key_2` | Menu choice 2 | Keycap "2" |
| `key_3` | Menu choice 3 | Keycap "3" |
| `key_n` | New run | Keycap "N" |
| `key_c` | Choose class | Keycap "C" |
| `key_t` | Replay stage | Keycap "T" |

**Item categories (6).** Each sits on a hex-nut backplate.

| id | Meaning | Drawing |
| --- | --- | --- |
| `cat_damage` | Weapon damage | A single sharp claw tooth, point up |
| `cat_mobility` | Movement | Two stacked chevrons, pointing right |
| `cat_defense` | Plating and resistance | A thick rounded plate with four rivets |
| `cat_utility` | Non-combat effects | An open-ended wrench, diagonal |
| `cat_charge` | Extra charges | A cell with three stacked pips |
| `cat_transform` | Pattern transformers | A square at left and a circle at right, joined by a curved arrow |

**Elements (3).** Each sits on a circle backplate.

| id | Meaning | Drawing |
| --- | --- | --- |
| `el_frost` | Frost (ICE) | A six-arm snowflake with short barbs |
| `el_arc` | Arc (mint) | A zigzag bolt between two small nodes |
| `el_kinetic` | Kinetic (bone) | A heavy ball with three impact lines at one side |

**Triggers (12).** Each sits on the parts-tag backplate.

| id | Meaning | Drawing |
| --- | --- | --- |
| `trg_on_hit` | On hit | A four-bracket reticle with a centre dot |
| `trg_on_kill` | On kill | A four-bracket reticle with an X |
| `trg_on_smash` | On smash | A down chevron striking a ground line |
| `trg_on_rebound` | On rebound | A ball hopping up off a floor line (never a bare V: it reads as a tick) |
| `trg_on_vault` | On vault kick | A wall bar with a sharp exit arrow |
| `trg_on_charge_release` | On charge release | A three-quarter gauge ring with an arrow leaving its gap |
| `trg_on_cloak_break` | On cloak break | A dotted cloud split by a spark |
| `trg_on_land` | On land | A ball above a ground line, two small puff arcs |
| `trg_on_speed_tier_up` | On speed tier up | A speedometer arc, the needle past a tick, a small up chevron |
| `trg_on_pickup` | On pickup | A U-magnet with a scrap square and two pull lines |
| `trg_on_damage_taken` | On damage taken | A plate with a jagged crack |
| `trg_timed` | Timed | A clock face with one hand and a small repeat arrow |

**Threat types (4).** Each sits on the warning-triangle backplate in HAZARD.

| id | Meaning | Drawing |
| --- | --- | --- |
| `thr_instant` | Instant AOE | A solid disc with a spiked rim |
| `thr_wave` | Travelling wave | One arc front with three chevrons pointing outward |
| `thr_projectile` | Projectile | A dotted arc ending in four closing brackets |
| `thr_lane` | Lane or beam | A long bar half filled from its left end, a source dot at left |

**Objectives (8).** Each is framed by four corner brackets.

| id | Meaning | Drawing |
| --- | --- | --- |
| `obj_beacon` | Beacon | A mast with two ring waves at its top |
| `obj_warden` | The Warden | A C-clamp jaw with three teeth, closing |
| `obj_gate` | Reward gate | A square arch with a diamond keystone |
| `obj_fabricator` | Drive-through fabricator | An upright hoop with a hex nut inside |
| `obj_vault` | Plated vault | A squat box with a heavy band and four rivets |
| `obj_event` | World event | A klaxon lamp with two sound arcs |
| `obj_launch` | Launch | A launch rail or upward chevron over a ring, amber reward accent |
| `obj_stage` | Stage marker | A canyon silhouette in a bracket frame |

**Resources (6).** Bare glyphs.

| id | Meaning | Drawing |
| --- | --- | --- |
| `res_scrap` | Scrap | An irregular four-facet chunk with a bolt hole |
| `res_heft` | Heft class | A ball resting on three stacked plates |
| `res_health` | Health | The cockpit dome with a plus on its glass |
| `res_core` | Bonus core | A diamond with a mint dot at its heart |
| `res_timer` | Run clock | A clock face with two hands |
| `res_difficulty` | Difficulty | A bar with rising sawtooth notches |

**Factions (5).** Each sits on a pentagon badge, for the codex enemy pages and pack warnings.

| id | Meaning | Drawing |
| --- | --- | --- |
| `fac_fleet` | Furnace Fleet crews | A brass requisition tag with a stencilled notch and one bolt hole |
| `fac_reactor` | Reactor relics | A low dome over three thick vent bars |
| `fac_swarm` | Swarm remnants | Five small triangles in an arrowhead |
| `fac_mind` | The Mind's hands | A round lens held by a two-joint arm |
| `fac_brindle` | Admiral Brindle (Fleet boss) | Brindle's requisition mark, brass accent, for the boss objective |

Ids avoid collisions by prefix. `obj_vault` is the plated cache, `ab_sable_vault` the kick and `trg_on_vault` the trigger.

## 6. Per-character ability look

Every ability shows the class's shape at wind-up, speaks with its instrument at release and leaves an aftermath in the same shape. The class row feeds all three. The pilot sits visible behind the cockpit glass in every view (AD-01, AC-01), and the pilot's head reacts to the ability. Growth never covers the glass.

### Sable: field mint, ring, rising arpeggio

The pilot is a fox from the Switchback Enclaves. A narrow russet face, dark-tipped ears and a close work cap read through the glass, and the head leans toward the chosen exit. On the ball, a collar of bolted pylon plates rings the equator, with a compact rope spool on one flank. The Enclaves build quiet, so the plates are felt-lined and rubber-bushed and Sable's shell rattles least of the three. The spool's rope exit must read at gameplay distance.

| Ability | Wind-up | Release | Aftermath |
| --- | --- | --- | --- |
| Arc caster | The pylon prong's tip glows mint | A zigzag arc jumps to the target with a single high arpeggio note | A small ring flashes on the target |
| Grapple and winch | A bracket reticle on the anchor point, dashed rope preview | The rope snaps taut. A two-note rising pickup plays with a muffled clink. | The rope stays visible and wraps what it passes. Winch reel-in ticks up the scale. |
| Detonation gauge | Concentric mint rings grow from 12 m toward a dashed 30 m extent. One arpeggio note per ring is added as the gauge fills. | The full arpeggio climbs and resolves on a bright chord as the ring discharges outward | A fading mint ring on the ground |
| Arc slam | A down chevron under the ball as it drops | A mint shock ring and a low root note plus a fifth | Steep faces within 12 m glow mint for 2 s. Each glow is a vault invitation. |
| Vault kick | One dashed mint line from the ball's edge, with a short root of fill, while a vault is available | A sharp 60° chevron flash off the face and an octave leap | A short mint streak |
| Mount and slingshot | The pylon drives in with a clack | The slingshot releases the gauge with the arpeggio run fast | The pylon stays planted with a slow mint pulse |

### Rivet: copper, chevron, hi-hat rolls

The pilot is a mole machinist. A rectangular visor, blunt nose and nearly hidden ears read through the glass, and a protected instrument cable runs from the visor into the controls. The cyborg kit is useful personal equipment, never an injury. On the ball, copper cooling fins rake backward like chevrons, twin exhaust stacks sit behind them and a straight optical rail runs forward to the cutting lens. The rail is the machinist's instrument and it stays clean among the grime. The fins say which way Rivet is going. During the sprint the visor glows copper, the one place the pilot shares the effect.

| Ability | Wind-up | Release | Aftermath |
| --- | --- | --- | --- |
| Rapid laser | None (it is always on) | Thin copper bolts, one closed hi-hat tick each | Chevron-shaped scorch sparks at the hit |
| Overdrive sprint | The fins flare open and the exhaust glows copper | A hi-hat roll that runs for the whole sprint. Copper chevron speed lines stream behind. | A crowd-control hit that fails shows a broken bracket flicker and a cymbal choke |
| Overdrive blast | Chevrons gather inward around the ball as the gauge fills, with an accelerating hi-hat roll | Six chevrons burst outward and an open hi-hat crash plays | The fins glow for the 3 s fire-rate boost, and the ticks double-time |
| Shockwave skid | The ball dips and the fins drop | A forward copper wedge and a snare flam | Skid marks behind, a tick for each 0.5 s refund |

### Kest: safety amber, starburst, low thumps

The pilot is a bird from the Highdraft Roosts. A swept feather crest, pushed-up goggles and a small hooked beak read through the glass, and the head makes small precise corrections while the shoulders stay still. On the ball, satchels banded in amber hang from an open truss frame, fuse wicks spit small sparks, and a folded glide vane sits on top as Roost lift hardware. The sticky-charge thrower is a short mortar tube in an open recoil cradle, so every lob reads as placed bombardment. The satchels swing with the roll, and with the vane they form the class silhouette. Kest's satchels and gear carry horizontal amber bands only, never 45° diagonals, because diagonal stripes mean hostile (§3). The primer board showed diagonal satchel stripes reading as hazard tape.

| Ability | Wind-up | Release | Aftermath |
| --- | --- | --- | --- |
| Sticky charges | A dashed amber lobbed arc with a bracket at its landing point | A soft thump on the throw. The charge sticks with a wet clack. | A spark-fizz loop while it is armed, then a starburst and a deep kick drum |
| Smoke blink | None (it is instant) | A muffled low thump. A dust puff at the start point. | The dust cloud lingers, and the ball's outline goes dotted during the cloak |
| Detonation line | An amber line grows from 6 to 14 m. Live charges inside it light up with a small spark. | The kick drums roll down the line, one per charge caught | A row of starburst scorch marks |
| Demo slam | A down chevron | A floor tom hit and three mini-charges splaying out | Three small starbursts after the 0.3 s arm |
| Glide and rocket jump | The vane unfolds | The blast thump lifts the ball with a starburst beneath it | A long amber trail while gliding |
| Dust cloak | Not applicable | Not applicable | A dotted outline on the ball and quieter class sounds. A crit from cloak adds a bright starburst and a snare crack. |

## 7. HUD look

This section makes "legible workshop instrumentation" concrete (AD-08, AC-15).

- **Panels.** Charcoal at 88% opacity, with 6 px chamfered corners like cut plate steel. A 2 px petrol inner line runs inside the edge, with a 4 px bone bolt dot at each corner. Grime lives only in the outer 4 px border band and never sits behind text, reticles or critical states.
- **Ability bar.** Bottom centre, four 64 px rounded-square slots (LMB, RMB, F, Ctrl). A 20 px key glyph sits under each slot, with 6 px charge pips beneath the glyph. The ability icon's accent is the class colour.
- **Cooldown sweep.** The icon drops to 40% value. A petrol wedge sweeps clockwise from 12 o'clock and shrinks linearly. No digits.
- **Gauges.** Health is a horizontal tank gauge with a tick every 25% and the cockpit-dome glyph at its left. Below 25%, its edge turns iron oxide and pulses at 1 Hz. A hit leaves the slice it took standing in the hit colour for 0.35 s, then drains it over 0.45 s, so the bar that took the hit shows itself and how much went (`src/ui/gauge.gd`). A gauge's icon wears the outline its words wear, so it holds on pale sand. Each bar carries one small word under its left end, in its own colour: HEALTH, and ARMOUR over the scrap bar. Without the word no blind reader took the amber bar for armour (0 of 12, against 12 of 12 with it; 10 Nov 2026). Heft is a pressure dial with a needle and class tick marks. The needle swings to a new class with a clunk. The run clock is Noto Sans Mono digits. Difficulty is a ramp of rising steps on the run plate, the lowest always lit and one more for each threat tier, with the word THREAT beside them in sand (`src/ui/run_status.gd`). A step that has just lit blinks bone for 1.5 s, so the eye finds the meter when the threat rises; no toast says so. It is never a filled bar: a filled red bar in a status corner was read as the health bar by six blind readers of six.
- **Type.** Noto Sans Bold for labels and toasts, and Noto Sans Mono Bold for numbers so digits do not jitter. Both are SIL OFL and installed at `/usr/share/fonts/noto/`. Vendoring the TTFs into the sketch with their licence is W1's call, with Godot's default font as the fallback.
- **Type sizes, spacing and the five UI colours** live in one place, `src/core/ui_tokens.gd` (11 Nov 2026): five type steps on the 1600x900 canvas (caption 15, body 18, label 22, heading 32, display 56), a spacing scale of 4, 8, 12, 16, 24, 32 and 48 px, and five colours (ink, text, accent, line, alert). The project theme `assets/ui/scrapkeep_theme.tres` is written from them by `tools/ui_theme_build.gd`; `tests/ui_tokens_test.gd` fails a literal size or gap off the scale, a gradient, or a word colour under 4.5:1. Toasts take the label and body steps, the objective the body step. Nothing is under 14 px. A menu target is at least 56 px on the canvas, which is 44 px on the smallest supported window (1280x720 and the Steam Deck's 1280x800).
- **Motion.** A ready pulse scales 1.00 to 1.12 to 1.00 over 180 ms with a class-colour rim flash and the class instrument's single note. A toast enters in 120 ms (fade plus 16 px drop, ease-out), holds 1.6 s at priority 2 or 2.4 s at priority 3, and leaves in 200 ms (fade, ease-in). At most two toasts are visible, and a newer one pushes the older out.
- **Caller plate.** Whoever speaks through the speech bubble besides Moss at his counter (a call-in, a site crew's hello, a boss's line) stands on a 68 px plate at the speech bubble's left, name on a tag across its head, and the bubble takes the caller's colour and points its tail at the plate ([STORY-MAP.md](design-v3/STORY-MAP.md), "Call-ins"). The plate's shape says whose hands the caller is and its colour says which of them: a rounded scrap plate for the crew (a site crew in its site's colour, a freed pilot in the pilot's own colour with the pilot's emblem); Moss's hatch slot with two mitts on the lip, since Moss is never seen; a clipped requisition tag in hazard red for the Fleet; a scanned hard-cornered lozenge in ancient green for the old works, which shows the works' mark and no face. The plate hops on the syllables while the voice lasts; reduced motion keeps it still. `src/ui/caller_tile.gd` owns it.

**Words-on-screen budget, 25 in a fight.** A word is any run of letters. Digits and keycap letters do not count.

| Slot | Words |
| --- | --- |
| Objective line (icon plus words) | 5 |
| Toasts (two at most) | 10 |
| One contextual prompt | 3 |
| Boss or event name | 3 |
| Reserve | 4 |

## 8. Motion and timing

- **Easing follows function.** Anything that measures time or distance moves linearly: cooldown sweeps, gauge fills, telegraph fills, a wave's leading edge. Arrivals ease out (cubic). Departures ease in. A back-out overshoot (1.2) is reserved for player-owned success (ready pulse, pickup, synergy), so bounce means good news.
- **Hit-stop.** Hit-stop belongs to the player's own strike, and the ball's motion never stops: a roll, a dodge, a reward or a beacon asks for none, and damage taken never gets one (`hit_stop_budget.gd` `STRIKE_STOP_FACTS`). An ordinary hit stops 12 to 40 ms by its damage (the `enemy_struck` row in `event_juice.gd`), and a heavier impact profile stops longer, up to the 60 ms cap (`hit_stop_budget.gd` `SPINE_CAP_MS`). Stops keep a 90 ms gap and share a 60 ms budget per 300 ms and 100 ms per second (`hit_stop_budget.gd` `STOP_*`). Those rows own the numbers; this line only names the rule.
- **One bold animation per event.** Each event row owns one hero motion that matches its shape, such as the arc slam's ring or Kest's line of starbursts. Everything else in that event runs at 30% or less of its scale and brightness. Two events in one frame play by priority from `event_kinds`, and the lower one drops to its sound.
- **Reduced motion (RR-11).** Motion that measures time or position is information and stays. Motion that celebrates is cosmetic and goes.

| Reduced motion keeps | Reduced motion removes or softens |
| --- | --- |
| Every telegraph's geometry and fill | Camera shake and hit-stop |
| A wave's travelling edge and chevrons | Toast slides (they become fades) |
| The projectile bracket closing | The ready pulse's scale (it becomes a rim colour step) |
| The gauge ring and the cooldown sweep | Idle loops, speed lines, ambient sparks |

- **Reduce flashes (design question 7, 17 Oct 2026).** A separate saved toggle for brightness, not motion. Every flash keeps its colour, shape and timing; only the spike shrinks. `src/core/flash_guard.gd` owns the shares: decorative pops keep 35% alpha, information flashes (the hit edge, a landing fill, a reach ring) keep 55%, light and emission spikes keep 30% of their rise, white pushes keep 30%, hard on/off blinks hold steady, and no pulse repeats faster than 3 Hz (WCAG 2.3.1). "Timing" means the warning window: a pulse inside it may slow to 3 Hz, but the window never shortens. The flood klaxon takes the spike share (lamp energy 9 to 2.7) because the klaxon sound and the rising water carry the warning; the lamp only confirms it. A new flash site reads FlashGuard before it draws.

## 9. Hero asset briefs (V3)

These briefs are for headless Blender work. The style is chunky, bevelled and smooth (Andrew, 18 Oct 2026: "Soft toy, chunky shapes"): crews and round bodies read as soft toys, machines keep crisp edges with rounded bevels, and silhouettes stay comic and bold. Colour stays flat per material slot, shaded by baked ambient occlusion and edge wear (tools/blender/POLISH.md), with no texture detail below what reads at gameplay distance. The Qwen renders on the primer board drift photoreal, so V3 models to this chunky soft brief and never to the board images. Poly counts are sketch targets, not production budgets (TH-16 RQ-10, RP-22 unset).

**Material slots.** Every asset uses these names so code can map them to palette roles.

| Slot | Colour |
| --- | --- |
| `paint` | Petrol, iron oxide or bone, varied per chunk |
| `bare_metal` | Bone, lightened, rubbed edges |
| `rubber` | Charcoal |
| `class_accent` | The class colour. Emissive only at the working device. |
| `field` | Mint emissive, coils and intake |
| `glass` | Cockpit, clear enough to show the pilot, with a sharp highlight |
| `pilot` | The pilot's fur, feathers or skin, plus cap, goggles or visor |
| `fleet_paint` | Iron oxide |
| `requisition_tag` | Brass |
| `ancient_enamel` | Petrol, cast and seamless, with sandstone dust on top faces. Capped at HSV value 45% and saturation 45%, and never emissive. |
| `ancient_light` | ANCIENT (uranium-glass green `#9dff3c`, chosen 2026-10-09), emissive in thin seams set in charcoal grooves |
| `rarity` | Set at runtime from the rarity ramp |

| Asset | Silhouette | Tris | Slots | Must read at gameplay distance |
| --- | --- | --- | --- | --- |
| **Class shell, Sable** | A lopsided scrap ball with a pylon-plate collar at the equator, a compact rope spool on one flank and a stubby pylon mast. The cockpit dome on top holds a fox pilot bust (ears and cap). | 3,000 to 5,000, plus a 400 to 800 pilot bust | paint, bare_metal, rubber, class_accent (plate edges, mast tip), field (collar coils), glass, pilot | The pilot's ears through the glass (AC-01) and the rope exit |
| **Class shell, Rivet** | The same ball core with raked copper fins in a chevron and twin exhaust stacks behind. A straight optical rail runs forward to a cutting lens. The dome holds a mole pilot bust with a visor and instrument cable. | 3,000 to 5,000, plus a 400 to 800 pilot bust | as above; class_accent on the fins, rail lens and visor | The visor through the glass, the fin direction and the rail |
| **Class shell, Kest** | The same core in an open truss cage, with two or three satchels in horizontal amber bands, a short mortar tube in a recoil cradle and a folded glide vane on top. The dome sits forward and holds a bird pilot bust (crest, goggles, beak). | 3,000 to 5,000, plus a 400 to 800 pilot bust | as above; class_accent on the satchel bands (horizontal only), fuse tips and mortar mouth | The crest through the glass, the satchels, the mortar mouth and the vane when open |
| **Accretion chunks** | Small (a bolt plate or bracket), medium (a dented tank end or pipe elbow) and large (a panel section with a weld seam). Each is irregular, with one flat face to sit on the ball. | 60 to 120, 150 to 300, and 400 to 800 | paint, bare_metal, rubber | Its size class by silhouette, and that it is scrap and not a pickup |
| **Reward gate arch** | Two stout posts and a lintel of salvaged girders with a diamond keystone. The rarity topper sits above, with trigger and element glyph plates beside it. | 1,500 to 2,500 | paint, bare_metal, rarity (lintel trim, keystone), field (keystone core) | The rarity (colour plus topper shape) and a clear opening |
| **Warden clamp base** | An awakened ancient (§11), not Fleet gear. It has two massive cast C-jaws on a seamless pivot housing, closing around the beacon. Its plating is layered cast shells with thin light seams, and the weak point is an exposed core where a shell has cracked away. It has no bolts, welds or brass. One shared base carries a per-stage family kit (below). | 4,000 to 6,000 for the base, plus 800 to 1,500 per family kit | ancient_enamel, ancient_light (seams, core), bare_metal (jaw edges) | The jaws and their closing path, the cracked weak point, and which family it belongs to |

Andrew set one ancient family per stage on 2026-09-27. The clamp base is shared, and each stage's Warden swaps the family kit that sits on the pivot and forms the weak point. The kit carries the family's mechanic, so the three Wardens are not reskins.

| Stage | Family | Kit on the base | Weak point | Sound character |
| --- | --- | --- | --- | --- |
| 1 | Reactor relic | A squat dome over the pivot with three vent stacks that swell before they erupt | The reactor core behind a cracked dome shell | A deep hum with a quickening crackle |
| 2 | Swarm remnant (hive) | A honeycomb hive housing on the pivot that launches and recalls drones in formation | The hive's queen cell, exposed when the swarm is scattered | A unison buzz that locks into a chord |
| 3 | The Mind's hands | Two extra thin jointed arms above the jaws and a lens cluster that tracks the ball | The lens cluster, which opens when it adapts | A pure sine chime echoing the class motif, slightly wrong |

Growth and cockpit rules apply to all three shells. The cockpit dome counter-rotates to stay upright while the shell rolls, so it stays findable (AD-01, AC-01). The motion treatment is still unset under RP-23. Chunks accrete within the shell's clearance envelope, and growth never implies unbounded scale (RQ-06, AC-17). Each asset's recipe notes its provenance.

## 10. Reviewer checklist

Answer yes or no for any new visual. Every item must be yes.

1. Does every fact it shows read from one source row (palette, class, event, threat or icon id)?
2. Does it carry at least one non-colour cue, and two if hostile?
3. Is HAZARD used only for hostile danger, and is a player effect free of stripes?
4. Is class colour used only for effects the player's own action creates?
5. Does a telegraph or indicator draw exactly the geometry the hit test uses, including the height band (RR-01, RR-02)?
6. Does a world indicator carry the charcoal keyline so it reads on sandstone?
7. Does an icon read as a solid silhouette at 24 px, distinct within its category, with no text except a keycap letter?
8. Is rarity shown by frame shape as well as colour?
9. Does it add at most one bold animation for its event, and does linear motion mean measured time?
10. Under reduced motion, does every required telegraph keep its geometry and progress (RR-11)?
11. Does the fight HUD stay within 25 words?
12. Is the cockpit findable and the working tool identifiable (AC-01, AC-10)?
13. Does the machine look assembled and repaired, with collection shown as magnetic pull into an intake (AC-02, AC-08)?
14. Does steam, dust, bloom, spark or distressed UI stay off the attack, its danger area, vital text and the escape (AD-11, RR-05)?
15. For an enemy, does its silhouette carry a mechanic no other enemy has, and does its body read as Fleet or ancient at a glance (§11)?
16. Does it avoid every other AD-11 item? That means no pristine showroom, no cosmetic-only upgrade, no gears or neon as the whole explanation, no flattened orange Southwest, no scrap heap replacing the land, no roster or species treated as canon, no unbounded scale and no copied franchise design.

## 11. Enemy factions and the changing world

This section follows DESIGN-V2 §10. There are two factions, and the ancients split into three families. All of them draw danger with the §4 grammar. Their bodies never share a material era, a silhouette logic or an instrument, because Andrew rejects reskins.

| | Fleet crews | Awakened ancients |
| --- | --- | --- |
| Made by | Animal crews under Brindle, in workshops like the player's | Humans, before the collapse |
| Material | Bolted, welded, stencilled and numbered standard issue | Cast, seamless and geometric, with no fasteners. Buried, cracked and dusted. |
| Colour | `fleet_paint` iron oxide, charcoal and one brass requisition tag | `ancient_enamel` dull petrol under the enamel cap, with thin `ancient_light` seams as the only glow |
| Motion | Mechanical. Ratchets, winch jerks, steam puffs, visible crew effort. | Uncanny. Perfectly smooth, then perfectly still. |
| Sound | Clanks, steam hiss, whistles, the klaxon family | Tonal hums, sub drones, pure sine chimes |
| Silhouette logic | Its anti-ball tool is the biggest shape | Its family's geometry is the whole body |

**Fleet crews.** The tool is the silhouette, so a player reads the mechanic before it acts. A hold on the ball is always a striped HAZARD binding, and breaking it is always a class-colour burst with the boost refund.

| Unit | Silhouette | Hold on the ball | Break-free | Sound character |
| --- | --- | --- | --- | --- |
| Mag trapper | A crew cart with a stack of pit discs on its back | A striped disc under the ball, with filings dragging inward | A smash or jump shatters the disc outward as a ring | A magnetic drone that drags down in pitch |
| Hooker | A harpoon gun on a tall anchor post | A striped tether from the post to the ball | Enough speed snaps the line, and it whips as the ball slings forward | A harpoon crack, then a taut-cable creak |
| Netcaster | Two masts with a crackling net strung between | A striped net plane across the air lane | The net tears as the ball double-jumps or glides through | A crackling electric buzz |
| Bola thrower | A bola spinning overhead | Striped cords wrapped around the ball | The cords burst outward | A whirling whoop-whoop |
| Plated brute | Bolted plate layers, visibly one layer more than a regular unit | None | One plate layer pops off per breaking hit | A heavy plate clang |
| Deflector | A big curved dish shield | None | The rebound flashes a free vault chevron | A springy metallic boing |
| Winch drone | A rotor with a winch drum slung beneath | A striped cable toward the pack | The cable snaps | A rotor whine over a winch ratchet |

Tenacity immunity (DESIGN-V2 §10) shows as the broken-bracket flicker from Rivet's sprint, because both mean crowd control cannot hold you. It takes the class colour, which is copper for Rivet as DESIGN-V2 specifies.

**Awakened ancients.** Each family has one mechanic, one silhouette logic, one motion and one sound.

| Family (cause) | Silhouette | Motion | Sound | How the mechanic reads |
| --- | --- | --- | --- | --- |
| Reactor relics (nuclear) | Squat and heavy. Domes, cooling-tower waists and thick vent stacks, low to the ground. | Slow. Heat shimmer rises over the vents, and a vent swells before it erupts. | A deep hum with a crackling tick that speeds up as a vent nears eruption | Their hazards become terrain. Fallout craters and meltdown vents use the instant or wave telegraph and leave changed ground. |
| Swarm remnants (drones) | Many small identical flat triangles. They are the only identical things in the game, on purpose. | Flocking. They snap into a line, ring or arrowhead in unison. | A unison high buzz, where a locked formation is a chord | The formation is the threat. A ball bowling through scatters it, and the chord breaks into single notes. |
| The Mind's hands (superintelligence) | Tall, thin, many-jointed manipulator arms and a lens cluster that tracks the ball | Still, then exact. The lens always follows you. | A pure sine chime that plays the class motif back, slightly wrong | When it adapts, its lens shows the trigger icon of the habit it counters (for example `trg_on_rebound`) in HAZARD, and it takes its brace or wall-guard pose before the counter takes effect |

**Wardens.** Each stage's Warden is one family on a shared clamp base (§9): stage 1 a reactor relic, stage 2 a swarm-remnant hive, stage 3 one of the Mind's hands.

**Enamel cap.** Ancient enamel stays dull petrol. In HSV its value is at most 45% and its saturation at most 45% (petrol itself is value 34%, saturation 38%, and mint is value 94%). The brightest colour the cap allows at petrol's hue, `#3f736e`, measures CIELAB L* 45 against mint's 88 and sits at ΔE 43 or more from mint in normal, deuteranopic, protanopic and tritanopic simulation. The enamel never glows. Only the ANCIENT green seams emit light. The primer board's s4 and f03 showed bright turquoise enamel reading close to mint, which this cap forbids.

Ancient light is the ANCIENT colour (uranium-glass green `#9dff3c`, chosen 2026-10-09), never mint, because mint belongs to the living salvage field. The thin seams show where the cast shells part. They are the mechanism, not decoration (AD-11).

**The world.**

- **Contraptions** (steam lifts, launchers, pressure valves) belong to the steampunk era. Each has a bone gauge dial whose needle sweeps linearly through its cycle, a steam puff at the fire moment and its own sound. A lift chuffs upward, a launcher whistles then bangs, and a valve squeals then hisses. A smashable valve is a big wheel with a visible crack.
- **The focal landmark**, the dam-works tower cluster, mixes both eras. Ancient cast towers carry steampunk repairs grown over them. An ANCIENT light at the top makes it findable from every layer.
- **Terrain events** use the §4 grammar and draw exactly the new collider. A cave-in is an instant fill over its 3 s crumble, with dust falling from the roof edge, and sounds like a rising rock grind. An impact is a projectile, with brackets closing on the crater, and sounds like a falling shriek into a deep boom. A structural collapse is a lane striped along where the piece will fall, and sounds like groaning steel, then a shear.

## Conflicts resolved

- **Forgiveness.** DESIGN-V2 §4 says the indicator is 15 to 20% larger than the damage geometry. Read literally, a target inside the drawn edge could be missed, which breaks RR-01 and punishes the player at the edge. This sheet keeps the 15 to 20% as a hull allowance in the hit test, and the indicator draws the resolved geometry. W3 applies it.
- **Mint.** AD-02 gives field mint to the shared collection effect, and DESIGN-V2 gives it to Sable. Both stand. Shape separates them (§2).
- **Boss colour.** `event_kinds` gives boss telegraphs BRASS, and W2 puts every attack in the HAZARD family. Danger stays HAZARD, and brass marks the owner (§4).
- **Characters.** Bible §4 describes Rivet as a precise machinist and Kest as a patient mortar pilot, while DESIGN-V2 §2 makes them a sprinter and a demolitions caster. The shells keep the Bible's working landmarks (Rivet's optical rail and cutting lens, Kest's truss, lift hardware and mortar tube), so the kit and the pilot's culture read together.
- **The Warden.** The V3 plan names a "Warden clamp", and the first draft of this sheet made it Fleet gear. DESIGN-V2 §10 makes Wardens ancients, and Andrew set one family per stage (2026-09-27), so the clamp is a shared ancient base with a family kit per stage.
- **Rare_plus.** Andrew accepted amber with a mint heart and a notched frame (2026-09-27). Red stays for things that hurt you.
- **Rarity and faction.** Enemy bodies never use the rarity ramp's colours as emissive light, so a glowing enemy cannot read as loot.

## Deltas from current code

These are follow-ups for the writers who own each file. This document changes no code.

| File | Today | Target | Owner |
| --- | --- | --- | --- |
| `build/reward_gates.gd`, `build/accretion.gd` | Rarity colours disagree (common is sandstone in one and copper in the other), and rare_plus is HAZARD | The bone, mint, amber and amber-plus-mint ramp from §2 in one shared table | W4 |
| `core/event_kinds.gd` | Movement cues are amber, and enemy struck and killed are copper | The class colour at runtime, for example a `"class"` colour token | W1 or W3 |
| `core/event_kinds.gd` | `boss_attack_telegraphed` is BRASS | A HAZARD fill with a brass rim tick | W2 |
| `build/accretion.gd` | Kinetic is copper, the same as Rivet | Kinetic is bone | W4 |
| `core/class_def.gd` | Colour only | A colour, shape and sound per class row (DESIGN-V2 §2) | W3 |
| `core/palette.gd` | No ancient light | An `ANCIENT` constant once Andrew picks from §2's three candidates | W7 |
