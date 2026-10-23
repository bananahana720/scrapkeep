# The Spillway roster

Status: wave 19, world 1 unit 1. Working default of the open roster card (Andrew, 23 Oct): bring three stored Spillway kinds back reworked around Flow, plus one new Mojulo body. That card reverses part of the 17 Oct "Re-home a few" ruling (the six spare Spillway kinds stayed out of the alpha); if Andrew picks another option, this file changes with it. Paths are under `sketches/core-loop/`. Plan: https://claude.ai/artifact/GzjpkrydUYjV787yaYhVor.

## The ask

Andrew (23 Oct 19:29Z) wants a 100% finished world 1 for a sitting. The audit on `stage/alpha-w18` (acb55972) found world 1 the thinnest world: one own-world enemy kind (the chaser) and two or three packs per park, against five to seven in the Dig and the Highdraft. The unit's bar: four or more own-world kinds on each park, five packs on the dam and six on the flume, and a Spillway elite of its own.

## One lesson: speed beats Flow

The Spillway teaches the master verbs (WORLD-ROSTERS.md): stay fast and fields miss you, bowl through packs, hook posts. Every Spillway kind asks one of those, and in every case the answer is speed or your own line. The Dig then makes you commit to casts, and the Highdraft makes you swing (FIELDS-AND-CASTS.md section 5: "speed beats fields, casts beat plates").

| Kind | Status | Rule | Answer | Flow twist |
| --- | --- | --- | --- | --- |
| Chaser | kept | Lunges along a committed lane | Ram it in the wind-up | Soaked |
| Jolt layer (`jolt_layer`) | re-admitted | Lays a live mat; a pulse on a slow ball drops casts and jams specials for 0.5 s | FAST tier, the air or a line slips every pulse | A mat laid on water (a live flood, or a water floor on the map) spreads 1.5x (`WET_SPREAD`) |
| Hooker (`hooker`) | re-admitted, reworked | Harpoons you to its post and reels you in | Outrun the line, boost, or (new) bite another post: the "hook" break snaps the tether and kicks you along your new line | Soaked; hook posts are the Spillway's grapple lesson |
| Ramp flipper as the sluice flap (`ramp_flipper`) | re-admitted, reworked | Tilts a plate under a slow ball and flings it off its line | (New) reach it at FAST tier and it launches you along your own line, 9 m/s up plus 4 m/s forward; a jump on the tilt still rides it | Soaked |
| Boom tender (`boom_tender`, new) | new body and kind | Swings a five-float debris boom into a lane and pins a slow ball to its hull | Bowl through at FAST tier: the floats pop like pins and pay scrap | Soaked; its own body (Mojulo, one shell, crisp bevels) |

Rejected: the bola thrower (tests the air, the Highdraft's verb), the gyro jammer (the lamp swarm already plays its steering steal, WORLD-ROSTERS.md audit), and the swatter (now a Highdraft kind in the plate-press packs).

### Soaked crews (the "wet" armour row)

`damage_families.gd` gains a `wet` row: weak to arc (150%, ZZAP!), resists nothing. The chaser, the hooker, the sluice flap and the boom tender carry it (`ARMOUR_OF`); the jolt layer stands on rubber boots and is dry. This is Andrew's Q3 answer ("Spillway flow/current, wet machines conduct") placed on the crews themselves, as the Dig's Plate is placed on the drill crew. Overpowered pays: it only makes an arc build stronger here, never weaker. The first arc hit discovers the codex entry `armour_wet` and badges every soaked crew.

## Packs

| Stage | Pack | Kinds | What it asks |
| --- | --- | --- | --- |
| Dam | run_down | chaser x3, lobber | kept |
| Dam | grounded | mag trapper, lobber x2 | kept |
| Dam | live_wire | jolt layer, chaser x2 | stay fast on the mat while turning off the lunges |
| Dam | sluice_line | hooker, chaser, lobber | snap the tether before the chaser and the shell arrive |
| Dam | flap_run | ramp flipper, boom tender, chaser | hit the flap fast and come down through the boom |
| Flume | run_down, grounded | as the dam | kept |
| Flume | shift_crew | Foreman, plated brute, chaser x2 | kept (the Foreman's first world) |
| Flume | crossed_wires | jolt layer x2, boom tender | thread two mats at speed, then bowl the boom |
| Flume | weir_strung | hooker, plated brute, chaser | the tether drags you into the slam |
| Flume | flap_line | ramp flipper x2, lobber | ride the flaps under the shells |
| Both | elite_spillway (elite) | hooker, jolt layer, plated brute | the exam: the tether pulls you into the live mat under the slab; speed answers all three |

The Spillway elite keeps the pack id `elite`, so the park files' home rows (which name it in `reinforce.pack`) and their bakes are unchanged, and dam and flume dressing threads keep their files. The old shared elite (plated brute, winch drone) stays declared as `ELITE` (the table fallback) and no stage names it. Packs live in `alpha_defs.gd` and its mirror `park_defs.gd`.

## Wind-ups, codex, achievements

- Wind-up sounds (`windup_rows.gd`): hooker `warn_tether` (two ratchet clicks and a taut twang), sluice flap `warn_flap` (a hinge creak over a water gush), boom tender `warn_reel` (five rising ratchet clicks, one per float lamp, over a tug-engine chug, and a brass ping), all synthesized in `sfx_bank.gd`; the jolt layer uses its rendered `jolt_layer_tell`.
- E-rows: E06 (hooker), E14 (ramp flipper) and E27 (jolt layer) already carry every field. E40 is the boom tender's sweep (lane, ray band, 1.1 s), claimed in the attack-ids registry.
- Codex (`codex_entries.gd`): `mat_slip`, `flap_ride`, `hook_out`, `armour_wet`, `boom_pop` (Bowl Through) and `boom_strike` (Strike!), each with its detector; the hooker keeps `tether_snap`.
- Achievements (`achievements.gd`): record-only rows `ach_w19_mat_slip`, `ach_w19_flap_ride`, `ach_w19_hook_out`, `ach_w19_soaked`, `ach_w19_boom_strike`.

## The boom tender

A low tug on tracks with a cable reel on its back, paying out five linked floats and an end buoy (Boom Tender No. 22, petrol and oxide, brass float lamps). Reference sheets: `docs/art/reference/enemies/boom_tender/` (PR #405). Body: `tools/blender/world_one/boom_tender.mojulo.json` (mojulo shell for the hull, tracks and reel) and `enemy_boom_tender.py`, written to `assets/models/world_one/enemy_boom_tender.glb`.

Mechanic `boom_pin` (`src/combat/boom_tender.gd`, E40). The warning is a lane from the hull toward the ball, the boom's whole reach (8.4 m by 3 m). Through the 1.1 s warn the boom stows to one side, the reel ratchets and the float lamps light one by one out along the lane. Live (0.6 s), the boom swings through the lane:

- a ball in the lane below FAST tier is pinned for 1 s: stung (5), shoved and hauled toward the hull; boost, jump or hook out;
- a ball at FAST tier bowls through: every standing float within 1.6 m of it bursts, pays one scrap and stays burst for the tender's life (`boom_pop`). All five in one sweep is a strike (`boom_strike`).

The lane, the pin and the pops all read the committed heading; the swing is presentation. It replaces a chaser in `flap_run` on the dam and in `crossed_wires` on the flume. Parked: the grown pilot remix (two crossing booms) and a slack boom left lying after the kill.

## Checks

- Scorecard (`/mnt/project-files/alpha-status/intent-check/scorecard.py`): own-world kinds on the dam and the flume go from 1 to 5 (chaser, jolt layer, hooker, ramp flipper, boom tender); packs 2 to 5 and 3 to 6.
- `tests/spillway_roster_test.gd`: the packs and elite, the soaked row, the flap's speed ride, the hooker's hook-out, the wet mat, and the boom tender's pin, pops and strike.
- Bands and the attack budget re-read on 24 seeds with `--warm-band=1` before the gate; Learner unchanged or better.
