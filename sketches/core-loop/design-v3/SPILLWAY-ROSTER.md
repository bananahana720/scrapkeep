# The Spillway roster

Status: wave 19, world 1 unit 1 brief (historical card default subsequently implemented on `main`). Brought three stored Spillway kinds back reworked around Flow, plus one new Mojulo body, reversing part of the 17 Oct "Re-home a few" ruling. Paths are under `sketches/core-loop/`.

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

## Old jobs (ruling ch, 9 Nov 2026)

Andrew ruled that ordinary enemies are the old works' machines still on the job, requisitioned by the Fleet, and that each attack is the old job done to you ([Story map](STORY-MAP.md), ruling ch). The Spillway is a water works, and to its machines the ball is something in the water that should not be there. The jobs below are working calls from the game systems thread, written to fit each kind's rule as built; Andrew can strike any of them. The art thread draws from this table (the tool is the silhouette and the only hand-fitted part), the sound thread takes the job's noise from it, and each kind's row in `src/combat/roster.gd` and `roster_specials.gd` carries the job as its `job` line, which the camp's enemy list shows ahead of the kind's own line.

| Kind | Old job | The tool | To it, you are |
| --- | --- | --- | --- |
| Chaser | Pipe pig: ran the penstocks end to end to scrape them clear | A scraper head on a sprung body | A blockage |
| Dispatcher (special) | Pig launcher: loaded pipe pigs into the line from a station above it | A launch tube on a gantry | The line that needs clearing |
| Lobber | Leak plugger: threw bungs and sandbags at a breach until it stopped | A sling arm over a hopper | A leak |
| Mag trapper | Rack magnet: lifted scrap iron off the intake screens, up to its rated load | A lifting magnet on a short jib, with a load plate | Scrap under its rating |
| Jolt layer | Fish fence layer: rolled out the live mat that kept fish out of the turbines | A cable drum and a mat roller; rubber boots | A fish |
| Catch trap | Fish lift: carried the fish that got through over the dam in a bucket | A cup on a hoist | A fish that got through |
| Hooker | Mooring winch: made barges fast to a bollard and hauled them in | A line gun and a capstan | A barge adrift |
| Ramp flipper (sluice flap) | Flap tender: tipped the overflow off the weir | A hinged plate and a counterweight | Overflow |
| Boom tender | Boom tender: strung floats across the channel to catch drift (No. 22) | A cable reel and five floats | Drift |
| Plated brute | Stoplog setter: dropped steel logs into a bay to shut it | A stack of stoplogs carried as its plate | An open bay |
| Splitter (special) | Jam breaker: set charges on log jams and ice | A rack of fused charges | A jam |
| Linker (special) | Shield tender: held the weather screen over a weld until it cooled | A dish on an arm | Weather |
| Shift Boss (special; code name `foreman`; Andrew named it on 9 Nov, ruling ck) | Shift horn: called the patch crews, and every machine in earshot re-sealed | A horn on a mast | The reason for the horn |

Six kinds had no job when their heads were built (W1-24, 12 Nov 2026). The crew heads thread gave them these working calls so each could wear a head from its job; Andrew can strike any, and the systems thread owns whether they become `job` lines in `roster.gd`:

| Kind | Old job | Head (`tools/blender/crew.py`) | To it, you are |
| --- | --- | --- | --- |
| Bola thrower | Heaving-line thrower: whirled a weighted line out to boats coming into the lock | A signal lantern | A boat to bring in |
| Netcaster | Trash screen: hung the screen that caught drift at the intake | The screen rack | Drift |
| Deflector | Outlet guard: turned the outlet jet off the bank so it would not scour | A flip-bucket nozzle | The jet |
| Gyro jammer | Current meter: hung in the stream and spun to read the flow | A cup rotor | The current to be read |
| Swatter | Screen sweeper: knocked weed off the intake screens | A brush | Weed on the screen |
| Winch drone | Buoy lifter: winched channel buoys up for paint | A channel buoy | A buoy |

Every crew kind's head now comes from its job, with its cast crew number and HIRED (W1-24); the numbers are in each recipe.

Two things follow for play, both after the sitting. The pig launcher and the pipe pig are one job in two bodies, so a Dispatcher's chasers can wear its number. And a kind's counter is the way that job fails: a pig jams on a harder plug (ram it in the wind-up), a bung comes back (bat the shell home), a magnet drops what is over its rating.

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

- Historical shared scorecard path (outside this repo): `/mnt/project-files/alpha-status/intent-check/scorecard.py` — own-world kinds on the dam and the flume go from 1 to 5 (chaser, jolt layer, hooker, ramp flipper, boom tender); packs 2 to 5 and 3 to 6.
- `tests/spillway_roster_test.gd`: the packs and elite, the soaked row, the flap's speed ride, the hooker's hook-out, the wet mat, and the boom tender's pin, pops and strike.
- Bands and the attack budget re-read on 24 seeds with `--warm-band=1` before the gate; Learner unchanged or better.
