# Pilots: the roster index

Status: wave 13 unit A2-CRITIC design spec (2026-10-10 on `cand/alpha-w13`; subsequently implemented across waves 13–46 — see [PILOT-CADENCE.md](PILOT-CADENCE.md) under ruling `ek` and `src/` for current code and numbers). This page superseded the older pilot text in `design-v2/I1-character-kits.md`, `DESIGN-V2.md` and `docs/CHARACTER-BIBLE.md`. Paths without a prefix are under `sketches/core-loop/`. A number marked (start) is a starting value to tune in play.

Reads with: [SKILL-BAR.md](SKILL-BAR.md), the framework, whose section 12 holds the eight cross-pilot rules this pass added; [PILOT-CADENCE.md](PILOT-CADENCE.md), which owns weapon firing/timers under ruling `ek`; the six sheets in [pilots/](pilots/), which own per-pilot design intent; [ROSTER-LOOK.md](ROSTER-LOOK.md), the body language.

Patch the possum (`line_splicer`, ruling `dl`) has a design sheet at [pilots/patch.md](pilots/patch.md) and partial asset wiring (`AllyHusk` / achievements), while its playable kit remains unbuilt.

Terms, once. **Slot 2** is the old F special. **Slot 3** is the line skill: the harpoon flavour. **Set piece** is the ultimate's ride from A to B on Q. **Peak** is its middle beat. **Shift** is the pilot's instant movement chip. **Smash** is the Ctrl slam flavour. **Heft class** is the I to V weight class that scales the payoff.

## 1. Roster index

| Pilot | Fantasy | Slot 2 | Slot 3 (line skill) | Ultimate (path, then payoff) | Shift | Smash | Body machinery | Silhouette rule | Uptime (buff over cooldown; when the cooldown starts) | Envelope (clip, reload, spread) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **Sable**, fox, `pylon_engineer` | turns the world into launch points and leaves each one faster | Arc discharge: gauge, 14 to 70 damage, 2 to 8 targets, reads live speed | **Bank Shot**: whip round the anchor, leave toward the aim at up to 45 m/s | **Cable Run**: rides the line, drives a stake every beat, plants a beachhead, slingshots out at blazing | Boost: +11 m/s shove | Arc slam: tags steep faces as vault invitations | coil mast at 11, winch spool at 3, wrench rack, twin arc emitter on the weapon ring | one tall spike at 11 with a mint tip; nothing at 1 (`pilots/sable.md` section 5) | none: Boost is an instant shove, no timed buff | clip 1 charge; reload none, fires at 5/s; spread bolt 0.55 m, aim cone 0.9 degrees at 70 m |
| **Rivet**, mole, `runner_gunner` | an unstoppable machinist whose every push becomes forward speed | Overdrive Blast: gauge ring 12 to 18 m, 30 to 45, then 3 s of x1.6 fire | **Line Drive**: punch the bitten machine down the cable, or haul to a wall immune to holds | **Foundry Cutter**: rides the line with one hand-aimed beam cutting each beat, ends in a forward Breach Skid at banked speed | Overdrive Sprint: hold, cruise x1.25, holds slide off | Shockwave Skid: no plant, the fall becomes forward speed | drill nose with `DrillTip` lens, twin exhaust stacks, fins folded flat in the front gaps | two short vertical stacks at 11:30 and 12:30 over an earless head (`pilots/rivet.md` section 5) | Sprint 2 s over 5 s = 40%, cooldown starts at activation; Overdrive fire 3 s over 6 s = 50%, cooldown starts at activation; Point Blank (swap) 3 s over 6 s = 50%, cooldown starts at activation | clip 1 charge; reload none, fires at 12/s; spread bolt 0.25 m, aim cone 0.3 degrees at 85 m |
| **Kest**, kestrel, `demolitions_caster` | places damage first and pays it later; her own blasts carry her | Detonation line: lane 6 to 14 m sets off live charges early, 20 to 30 x up to 1.75 | **Cable Charge**: a charge rides the line and blows when the line ends | **Windhover**: lobs to a point 14 m above B, hangs 2 beats while her mortar shells B, then stoops onto it | Smoke blink: 8 m, starts the cloak | Demo slam: a ring of 3 mini charges | fin vents at 2 and 10, mortar tube, satchel bands that count volley targets | the V at 2 and 10 with a centred crest (`pilots/kest.md` section 5) | Dust cloak 1.5 s over 4 s = 37.5%, cooldown starts at activation | clip 1 charge; reload 0.6 s per charge; spread bolt 3 m blast, aim cone 11.4 degrees at 30 m |
| **Tarn**, tiger, `tarn` | everything comes to the tiger: drag it in, clamp it, rend it | Claw clamp: gauge ring 4 to 7 m drags in and marks | **Claw Drag**: drags the bitten body to claw reach, or climbs what it cannot move | **Redjaw Rend**: climbs the line claw over claw, snatches and tows bodies, drops them at B and rends inward | Claw pull: 12 m plant, 24 m/s floor | Rend: pulls every enemy within 9 m inward | two hooked claw arms on side hubs, two blades on the weapon ring, pull drum low at the rear | bottom-heavy: claw arms at 4 and 8, blades pulse at 2 Hz while firing (`pilots/tarn.md` section 5) | none: Claw pull is an instant plant; the mark is a debuff on enemies | clip 1 charge; reload none, fires at 2/s; spread bolt 1.1 m, aim cone 24.8 degrees at 5 m |
| **Tally**, pack rat, `tally` | gather the pack, clip it on the line, make it pay | Gather Plate: pulls ordinary enemies to a plate, no damage, 6 s | **Ledger Clip**: clips 3 enemies, pays 1 pressure each, the next hit arcs to all | **Plate Return**: rides home to her plate, clips what each beat hits, then settles every clip anywhere at 40% of the landing | Flywheel Surge: speed floor 20.8 m/s, pays 1 pressure | Stamp Slam: each enemy reached pays 1 pressure | ledger drums at 3 and 9 with pressure windows, reader carriage whose raised card is the selected slot | four circles on a square: drums at 3 and 9, ears above (`pilots/tally.md` section 5) | none: Flywheel Surge is an instant floor | clip 3 pressure; reload 2 s per pressure, rolling at cruise or faster; spread bolt 0.5 m, aim cone 1.9 degrees at 30 m |
| **The Cannon**, rebuilt ancient, `remembered_cannon` | the Mind's guns turned outward; calls hits that land late, then fires itself as the last shell | Cannon Plate: sector 18 to 34, exposes for x1.4 contact | **Lane Charge**: the cable is the lane, and it fires now | **Fire Mission**: lobs on an arc, calls one family zone per beat, every zone and the landing strike on one beat | Recoil Split: kick 20.8 m/s, two lanes behind | Rush Ring: a delayed ring through the nearest enemy | one cast barrel with four family bands on the weapon ring's front arc at the equator, split ports at 5 and 7, rush ring at the bottom, lattice folds to a shell casing in the wind-up | low: twin-bore split ports at 5 and 7 and the rush ring at the bottom; the long barrel breaks the outline at the equator only when the aim swings off the camera line (`pilots/cannon.md` section 5) | none: Recoil Split is an instant kick; the x1.4 exposure is a debuff on enemies | clip 1 charge; reload none, fires at 1/s; spread bolt 0.6 m, aim cone 2.6 degrees at 26 m |

**Uptime, once.** Uptime is a buff's duration over its cooldown. Every cooldown in `src/core/ability_state.gd` starts at activation (`spend` takes the charge, `tick` refills it while the buff runs), so no row waits for expiry. Today's three timed buffs sit at 37.5% to 50%, inside the 25% to 75% band from `research/comps/roboquest/movement-and-feel.md`. Overdrive fire stacks to 6 s (`OVERDRIVE_MAX`), so a cooldown pick can lift it past the band. `tests/pilot_uptime_test.gd` prints the table and checks its structure; it gates every row inside the band once PC-PACK flips `GATE_BAND`.

**Envelope, once.** Each weapon is stated as clip, reload and spread, the three numbers `research/comps/roboquest/weapons-and-affixes.md` found separate a loot category. Clip is the weapon slot's charges (`src/core/ability_state.gd`; Tally's are pressure). Reload is the seconds to refill one charge: `cooldown` on the weapon row, or `PRESSURE_ROLL_S` for Tally (`src/combat/weapons.gd:122`). Spread is the bolt radius (`src/combat/weapons.gd:32-52`) and the aim cone, the angle one bolt covers at the weapon's range. The target: reload medians within 1.2x of each other, clip and spread medians each spanning at least 3x. Today clip and spread meet it (1 to 3 charges, 0.25 m to 3 m) and reload misses it, because four of six weapons have no reload at all and fire on rate alone. `tests/weapon_envelope_test.gd` prints the table and checks its structure, including that each cell here quotes the code's bolt radius; it gates the three targets once PC-PACK flips `GATE_ENVELOPE`. PC units own the kit numbers (`P-UNITS.md:236`), so no number here is a change request.

**Distinctness, checked across all six.**

- **Slot 3 mechanics:** speed off the anchor (Sable), force down the cable (Rivet), a payload that blows on let-go (Kest), the target pulled to the pilot (Tarn), value clipped from the bite (Tally), a lane fired now (Cannon). The plan's six flavours hold (plan, "Slot sourcing"). No pair repeats.
- **Ultimate path and payoff:** line then speed exit (Sable), line then forward skid (Rivet), arc plus hang then stoop (Kest), line then inward rend of a towed catch (Tarn), line to her plate then a map-wide settle (Tally), arc then time on target (Cannon). The draft's Kest arc with a deferred carpet matched the Cannon's arc with deferred calls, so Kest's base moved to Windhover (section 3).
- **Shift feel:** additive shove (Sable), held state (Rivet), vanish (Kest), pull to a planted claw (Tarn), floor plus a wallet payment (Tally), kick with a trail of lanes (Cannon).
- **Depth-3 variants** (`variant_of` rows, SKILL-BAR section 12, item 3): Ball Lightning and Outpost (Sable); Prism Cutter and Juggernaut Drive (Rivet); Air Raid and Minelayer (Kest); Rake Run and Vice Leap (Tarn); Audit Trail and Flywheel Throw (Tally); Creeping Barrage and Plate Mortar (Cannon). Three of them run a damage corridor along a line path: Juggernaut Drive throws outward and pins, Rake Run drags inward and marks, Audit Trail stamps clips for a settle. They push or pay in different directions, so each stays its pilot's.

## 2. Balance table

Class I, chain x1, 172 BPM, a nominal 7-beat flight (2.44 s). Weapon, slot 2 and slot 3 figures are today's code where cited in the sheets; set-piece figures are (start).

| Pilot | Sustained (slot 1) | Burst (slot 2, full) | Slot 3 hit | Set-piece tech per beat | Peak | Landing, per enemy at B | Q to control | Charge time |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sable | 60/s, 1 chain jump at 0.7 (`weapons.gd:34-37`) | 70 to 8 targets, 30 m (`weapons.gd:74-83`) | 10 x chain, plus an exit of 21.5 to 45 m/s | 36: a stake arcs 3 x 12 | about 4 stakes x 12, one target each | 60, then a 27.7 m/s exit | 2.2 to 3.8 s; stakes stand 6 s; Outpost +4 s of turret | 45 to 90 s, the framework band for every pilot (SKILL-BAR section 4) |
| Rivet | 84/s, single target, hitscan (`weapons.gd:32-33`) | 30 to 45, ring 12 to 18 m, then x1.6 fire for 3 s | 24.9 to 35.1 punch | 36: beam cuts 3 x 12 | 18 to every machine in a 90 degree, 30 m sweep | 60 in a forward cone, 9 m | 2.2 to 3.8 s | same |
| Kest | 26.7/s, 3 m blasts, 1.2 s fuse (`weapons.gd:40`, `:192`) | 52.5 lane (30 x 1.75) | 28 x chain, 4 m blast | 36: 3 charges x 12, each a 3 m blast | cloak plus that beat's volley | 75 (60 x 1.25) in 7 m | 2.9 to 4.5 s (2 hold beats) | same |
| Tarn | 64/s at 5 m; 96 on a marked enemy (`weapons.gd:44-45`, `combat.gd:1178-1183`) | 14 to 24, ring 4 to 7 m, plus a mark | 14 x chain plus a 2.5 s mark | 36: 2 snatches x 12 plus 3 towed x 4 | 18 to every enemy in a 5 m ring | 60 inward; towed 75; marks 3 s | 2.2 to 3.8 s | same |
| Tally | about 15 to 22/s, pressure-gated: 19 to 42 per shot, 1 pressure each, cruise refills 1 per 2 s, surge 1 per 4 s | none: Gather Plate deals 0 | 0; +3 pressure; the next hit copies to 3 | 36: 3 cards x 12, each hit clipped | none: the plate pulls | 60, then 24 per clip outside the radius (up to 6 at class I), pressure to full | 2.2 to 3.8 s | same |
| Cannon | 30/s to every enemy in a 24.4 x 3.2 m lane, 1.4 s late (`weapons.gd:132-133`) | 18 to 34 sector, then x1.4 contact for 2.5 s | 28 x chain lane, live in 0.1 s | 12 to every enemy in one zone, cap 12 calls | 4 zones round B: 48 on one enemy | 60, with every zone live on the same beat: 108 worst case | 2.2 to 3.8 s; Plate Mortar fixed at 2.69 s | same |

**Outliers, with the fix or the reason.**

1. **Rivet's beam was a third over budget** (4 machines x 12 = 48 a beat) and his peak dealt 24. Fixed: 3 machines and 18 (`pilots/rivet.md` section 3).
2. **Rivet's 84/s weapon** is the roster high. Kept: today's code, single target only, no area, and his bar is difficulty 1 (`pilots/rivet.md` section 1).
3. **Sable's full discharge**, 70 to 8 targets, is the burst high. Kept: today's code, and it needs a 1 s gauge or blazing speed.
4. **Kest's Windhover** gets about one more volley than a line set piece of the same length, and a x1.25 landing. Kept: every volley lands within 15 m of B, so she deals nothing along the route, and the hang holds her in the air 0.7 s longer. Its 4.5 s top end is the longest set piece. Space still bails.
5. **Tally's settle** (24 x 6 = 144 at class I) is above Rivet's and Tarn's uncapped peaks on six enemies (18 x 6 = 108). Kept: her peak deals nothing, settles need clips made in flight, and they are noncontact, so they never touch a Warden core.
6. **The Cannon's zones and Kest's charges** are area hits, so in a dense pack a beat can pass 36. The Cannon also has the highest worst case at B (108). Kept, with one condition: the Cannon unlocks after the ending, every zone waits on drawn ground that enemies can walk off, and 12 calls is the cap. **Check:** if B4's bots show the Cannon's median set-piece damage above 1.3 times the roster median, cut zone damage from 12 to 10 (start).
7. **Charge time** uses one meter for all six. Which sources each kit leans on is inference: contact for Rivet, Tarn and Tally; kills for Kest and the Cannon; speed and near misses for Sable. **Check:** B4 bots measure the median fill per pilot. A pilot outside 45 to 90 s gets a per-pilot points scale, not a new source.

## 3. Difficulty: what each world's pack scale must absorb

The pressure rows today (`src/core/alpha_defs.gd:59-65`, `threat` on the stage rows at `:69-111`):

| World, stages | `pack_scale` | `elite_rate` | `threat` | New power arriving | Pack-scale change (start) |
| --- | --- | --- | --- | --- | --- |
| 1, stages 1 and 2 | 1.03, 1.04 | 0.60, 0.80 | 1.0, 1.0 | slot 3 line skill and the base set piece. Inference: about +4 damage a second from slot 3 while a line stands, and about +7 a second from one set piece every 75 s. That is 10 to 15% over the mid weapons and up to 30% over Tally, Kest and the Cannon | +0.05 each (1.08, 1.09) |
| 2, stages 3 and 4 | 1.20, 1.25 | 1.00, 1.20 | 1.1, 1.2 | depth-3 variants, the same budget in a new shape. The plan's harpoon answers (deflector, counter-ram) enter here and already tax slot 3 | +0.05 each (1.25, 1.30) |
| 3, stages 5 and 6 | 1.30, 1.40 | 1.40, 1.60 | 1.3, 1.4 | depth-4 knobs: `ult_beats` +2 volleys, `ult_encore` a second leg, `ult_volley` +1 target. Together up to about +50% on the set piece | +0.10 each (1.40, 1.50) and `elite_rate` +0.1 |

`posture_curve` stays as it is. SKILL-BAR section 12, item 7 caps a set piece's posture on a closed guard at 45, so the grown Warden band moves only through the open-core shatter, which `alpha_posture_bands_test` already guards (SKILL-BAR section 11). These are recommendations for the P-C units and B4; this page changes no code.

## 4. Readability, momentum, lore and feasibility

- **Two prompts at most.** Each sheet's committed geometry draws only while its slot is selected and a line stands, so the most at once is that slot's preview plus the full meter ring. Set-piece paths draw only during the 0.35 s wind-up, when the bar is locked. Telegraphs differ by colour and shape: mint rings (Sable), copper chevrons (Rivet), amber rings (Kest), rust crosses (Tarn), cream tags and dotted thread (Tally), green zones with a dotted seam (Cannon). Sable's meter fill draws in sand-light, so mint means only "ready" (SKILL-BAR section 12, item 8).
- **Momentum.** Every set piece hands back the banked speed (`src/world/ride_rail.gd:5-14`) except two chosen stops, both drawn at wind-up. Sable's Outpost ends mounted, and Space slingshots at once. Kest's Windhover hangs 2 beats in the air, then stoops on. No skill stops the ball unasked. Tarn's Claw Drag on a heavy body pulls the ball forward.
- **Lore.** Brass is the Furnace Fleet's colour (`ROSTER-LOOK.md:239`; `src/core/palette.gd:20-21`). Every friendly brass trim in the sheets became copper, and Tally's icons move to ledger cream. **Ancient light is uranium-glass green `#9dff3c`, not Cherenkov blue.** Andrew chose it on 2026-10-09 (`docs/decisions.tsv:350`), and the code follows (`palette.gd:12-15`). The brief for this unit said Cherenkov blue; the newer owner record wins. The Cannon's sheet uses green.
- **Rig.** Every clip names only `pilot-v1` bones (`tools/blender/PILOT-RIG.md:23-40`): no legs, so seated poses key `root`; Kest's "wing" is the arm chain; Tarn's "finger" is `curl`.
- **Budgets** (`assets/asset_budgets.json:39-80`). Pilot: 4,600 tris, 3,100 verts, 5 draws. Shell: 11,000 tris, 10 draws. Detail: 1,500 tris and 1 draw per heft layer. Each body's machinery is two to four parts on hubs and the weapon ring, plus one glow slot. **Risk:** `shell_kest` already carries a 16-draw exception (`asset_budgets.json:43`). The P-D Kest unit must fold her vents, mortar and satchel bands into the 10-draw cap or record the exception again.

## 5. What this pass changed, and why

| File | Change | Why |
| --- | --- | --- |
| `SKILL-BAR.md` section 12 | Eight framework additions: multi-leg paths with `hold_beats` and `beats`, a `target` row key, `variant_of`, one pilot knob each with pre-seeded table blocks, one source for card copy, depth-3 pairs, the 45-posture cap per set piece, the sand-light meter fill | each was a private rule in one or more sheets; now the framework says it once |
| `SKILL-BAR.md` section 4 | the closed-guard row names the whole-set-piece cap | Cannon zones and Sable stakes could stack posture past 45 |
| `pilots/kest.md` | Windhover is the base set piece; Air Raid is a depth-3 variant; Homecoming became a discovery; "wing" pinned to the arm chain | Air Raid matched the Cannon's arc with deferred payoff; achievement rows cannot test the pilot (`src/core/progress.gd:259-288`); the rig has no wing bones |
| `pilots/rivet.md` | beam pierce 4 to 3; peak 24 to 18; Breach Skid loses its 27 m/s floor; Juggernaut Drive throws outward; fins fold flat; the hood is earned through a discovery | budget; the speed gift is Sable's; inward force is Tarn's; 4 and 8 o'clock is Tarn's outline; achievement limit |
| `pilots/tarn.md` | Rake Run drags raked enemies 2 m in and marks them; copper rivets; Hold Still becomes a discovery; the cross-check note | Rake Run sat beside Rivet's corridor; brass rule; achievement limit |
| `pilots/tally.md` | Flywheel Surge pays 1 pressure; copper replaces brass; icons move to ledger cream; coordinator items point at section 12; the posture cap noted | Shift feel matched Sable's shove; brass rule; framework fit |
| `pilots/sable.md` | meter fill in sand-light; the Outpost stop stated as foreseen; the body mapped to the Hoberman mecha | mint means "ready"; momentum check; the live body |
| `pilots/cannon.md` | silhouette claim narrowed; `beats`, `variant_of`, card copy and posture cap now cite the framework | Rivet's stacks and Sable's mast also break the crown; framework fit |

## 6. Veto list for Andrew

Say "veto" on a line and it changes. These are the calls most worth reversing; each sheet's section 11 holds the rest.

1. Kest's base ultimate is Windhover: hang over B, shell it, stoop. Air Raid becomes a world-2 choice.
2. Tally's Shift surge pays 1 pressure, so her movement feeds her gun.
3. Rivet's Juggernaut Drive throws machines outward instead of pulling them in.
4. Tarn's Rake Run drags what it rakes 2 m inward and marks it.
5. Rivet's set piece keeps his banked speed but no longer floors it at 27 m/s. The speed gift is Sable's alone.
6. Rivet's beam cuts 3 machines a beat, and his peak sweep deals 18.
7. One set piece adds at most 45 posture to a closed Warden guard, volleys included.
8. Sable's Outpost is the one set piece that ends with the ball still. It is drawn at wind-up, and Space slingshots out.
9. Rivet's fins fold flat into the lattice, so 4 and 8 o'clock read only as Tarn's claws.
10. Tally's seven existing icons move from Brindle's brass to her ledger cream.
11. Each world's pack scale rises by the start values in section 3: +0.05, +0.05, then +0.10.
12. Ancient light stays uranium-glass green, your 2026-10-09 call, over the brief's Cherenkov blue.

## 7. Baseline ratios

Wave 14 unit SQ8, 2026-10-14. A pilot is a baseline, a kit and a tree. The kit and tree differ already (sections 1 and 2); this table makes the baseline differ too. Each pilot states two numbers as ratios to Sable, the starter: **hull**, the health a run starts with (`base_hp` on the row in `src/core/class_def.gd`), and **growth**, the hull gained per heft class above I (`hp_growth`). All values are (start). The shape comes from `research/comps/roboquest/classes-and-perks.md` (a class baseline is health plus health per level, and the heavier class grows faster); none of its numbers are used.

| Pilot | Hull | Hull ratio | Growth | Growth ratio | Why |
| --- | --- | --- | --- | --- | --- |
| **Sable** | 100 | 1.00 | 10 | 1.00 | the reference; today's shared 100 stays the starter's hull |
| **Rivet** | 115 | 1.15 | 12 | 1.20 | an unstoppable machinist who shrugs off holds and fights at mid range |
| **Kest** | 80 | 0.80 | 7 | 0.70 | hides in smoke and places damage from far; the lightest hull |
| **Tarn** | 135 | 1.35 | 15 | 1.50 | committed close contact; the heaviest hull and the fastest growth |
| **Tally** | 90 | 0.90 | 8 | 0.80 | a caster who pays pressure and works from her plate |
| **The Cannon** | 105 | 1.05 | 10 | 1.00 | a rebuilt ancient that fires from lanes; near Sable |

**Rules, checked by `tests/pilot_baseline_ratio_test.gd`.** Each ratio cell matches the code within 0.005. The heaviest hull is 1.5x to 2.0x the lightest (today 1.69x, Tarn over Kest), so the pilots differ without one doubling another. A lighter hull never grows faster per heft class than a heavier one.

**Live hull, 2026-10-15 coordinator scope extension.** `RunState.begin()` starts full at the chosen pilot's `base_hp`. `RunState.base_max_hp()` adds `hp_growth` for each published heft class above I; a drop removes those class bonuses, and a retry restores the checkpoint's class and hull. Build recomputes and Scrap Armor add their bonuses to that same base. A class rise fills the added hull through `set_max_hp()`. `GATE_LIVE` is on; the test checks starts, growth through class V, pickup event ordering, recomputes, drops, retries and new runs. Live start ratios use a 0.02 tolerance. At later heft classes the declared ratio is `(base_hp + hp_growth * (class - 1))` divided by Sable's value at that class, before part bonuses.
