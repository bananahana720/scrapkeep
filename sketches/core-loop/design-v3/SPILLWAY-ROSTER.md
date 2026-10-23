# The Spillway roster

Status: wave 19, world 1 unit 1. Working default of the open roster card (Andrew, 23 Oct): bring three stored Spillway kinds back reworked around Flow, plus one new Mojulo body. That card reverses part of the 17 Oct "Re-home a few" ruling (the six spare Spillway kinds stayed out of the alpha); if Andrew picks another option, this file changes with it. Paths are under `sketches/core-loop/`. Plan: https://claude.ai/artifact/GzjpkrydUYjV787yaYhVor.

## The ask

Andrew (23 Oct 19:29Z) wants a 100% finished world 1 for a sitting. The audit on `stage/alpha-w18` (acb55972) found world 1 the thinnest world: one own-world enemy kind (the chaser) and two or three packs per park, against five to seven in the Dig and the Highdraft. The unit's bar: four or more own-world kinds on each park, five packs on the dam and six on the flume, and a Spillway elite of its own.

## One lesson: speed beats Flow

The Spillway teaches the master verbs (WORLD-ROSTERS.md): stay fast and fields miss you, bowl through packs, hook posts. Every Spillway kind asks one of those, and in every case the answer is speed or your own line. The Dig then makes you commit to casts, and the Highdraft makes you swing (FIELDS-AND-CASTS.md section 5: "speed beats fields, casts beat plates").

| Kind | Status | Rule | Answer | Flow twist |
| --- | --- | --- | --- | --- |
| Chaser | kept | Lunges along a committed lane | Ram it in the wind-up | Soaked |
| Jolt layer (`jolt_layer`) | re-admitted | Lays a live mat; a pulse on a slow ball drops casts and jams specials for 0.5 s | FAST tier, the air or a line slips every pulse | A mat laid on standing water spreads 1.5x (`WET_SPREAD`) |
| Hooker (`hooker`) | re-admitted, reworked | Harpoons you to its post and reels you in | Outrun the line, boost, or (new) bite another post: the "hook" break snaps the tether and kicks you along your new line | Soaked; hook posts are the Spillway's grapple lesson |
| Ramp flipper as the sluice flap (`ramp_flipper`) | re-admitted, reworked | Tilts a plate under a slow ball and flings it off its line | (New) reach it at FAST tier and it launches you along your own line, 9 m/s up plus 4 m/s forward; a jump on the tilt still rides it | Soaked |
| Boom tender (`boom_tender`, new) | sheets requested, PR 2 | Drags a five-float debris boom across your lane and pins a slow ball | Bowl through the floats at speed: they pop like pins | Soaked; its own body (Mojulo, one shell, crisp bevels) |

Rejected: the bola thrower (tests the air, the Highdraft's verb), the gyro jammer (the lamp swarm already plays its steering steal, WORLD-ROSTERS.md audit), and the swatter (now a Highdraft kind in the plate-press packs).

### Soaked crews (the "wet" armour row)

`damage_families.gd` gains a `wet` row: weak to arc (150%, ZZAP!), resists nothing. The chaser, the hooker and the sluice flap carry it (`ARMOUR_OF`); the jolt layer stands on rubber boots and is dry. This is Andrew's Q3 answer ("Spillway flow/current, wet machines conduct") placed on the crews themselves, as the Dig's Plate is placed on the drill crew. Overpowered pays: it only makes an arc build stronger here, never weaker. The first arc hit discovers the codex entry `armour_wet` and badges every soaked crew.

## Packs

| Stage | Pack | Kinds | What it asks |
| --- | --- | --- | --- |
| Dam | run_down | chaser x3, lobber | kept |
| Dam | grounded | mag trapper, lobber x2 | kept |
| Dam | live_wire | jolt layer, chaser x2 | stay fast on the mat while turning off the lunges |
| Dam | sluice_line | hooker, chaser, lobber | snap the tether before the chaser and the shell arrive |
| Dam | flap_run | ramp flipper, chaser x2 | hit the flap fast and land on the chasers |
| Flume | run_down, grounded | as the dam | kept |
| Flume | shift_crew | Foreman, plated brute, chaser x2 | kept (the Foreman's first world) |
| Flume | crossed_wires | jolt layer x2, chaser | thread two mats at speed |
| Flume | weir_strung | hooker, plated brute, chaser | the tether drags you into the slam |
| Flume | flap_line | ramp flipper x2, lobber | ride the flaps under the shells |
| Both | elite_spillway (elite) | hooker, jolt layer, plated brute | the exam: the tether pulls you into the live mat under the slab; speed answers all three |

The old shared elite (plated brute, winch drone) stays declared as `ELITE` (the table fallback) and no stage names it. Packs live in `alpha_defs.gd` and its mirror `park_defs.gd`; the park files' home rows are unchanged, so dam and flume dressing threads keep their files.

## Wind-ups, codex, achievements

- Wind-up sounds (`windup_rows.gd`): hooker `warn_tether` (two ratchet clicks and a taut twang), sluice flap `warn_flap` (a hinge creak over a water gush), both synthesized in `sfx_bank.gd`; the jolt layer uses its rendered `jolt_layer_tell`.
- E-rows: E06 (hooker), E14 (ramp flipper) and E27 (jolt layer) already carry every field.
- Codex (`codex_entries.gd`): `mat_slip`, `flap_ride`, `hook_out` and `armour_wet`, each with its detector; the hooker keeps `tether_snap`.
- Achievements (`achievements.gd`): record-only rows `ach_w19_mat_slip`, `ach_w19_flap_ride`, `ach_w19_hook_out`, `ach_w19_soaked`.

## The boom tender (PR 2)

A low tugboat on tracks with a cable reel on its back, dragging five linked floats and an end buoy (Boom Tender No. 22, HIRED stamp, petrol and oxide, brass float lamps). Mechanic `boom_sweep`: the reel ratchets and the float lamps light in order along the sweep arc (lane telegraph), then it swings the boom across the arc. A ball below FAST tier in the sweep is shoved toward the hull and stung; a ball at FAST tier or ramming through bursts each float it touches (scrap per float, a "Strike!" codex trick for all five in one pass). Killing the tender drops the boom slack. Grown pilot remix: two booms cross. It joins `flap_run` on the dam and replaces a chaser in `crossed_wires` on the flume when it lands. Reference prompts: `/mnt/project-files/world1/roster/boom_tender-PROMPTS.md`; approved board `docs/art/reference/enemies/enemies-spillway-moodboard.jpg`. Nothing is modelled before the sheets.

## Checks

- Scorecard (`/mnt/project-files/alpha-status/intent-check/scorecard.py`): own-world kinds on the dam and the flume go from 1 to 4 (chaser, jolt layer, hooker, ramp flipper); packs 2 to 5 and 3 to 6.
- `tests/spillway_roster_test.gd`: the packs and elite, the soaked row, the flap's speed ride, the hooker's hook-out and the wet mat.
- Bands and the attack budget re-read on 24 seeds with `--warm-band=1` before the gate; Learner unchanged or better.
