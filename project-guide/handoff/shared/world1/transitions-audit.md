# World 1 hand-overs audit (architect, read-only, 10 Nov 2026)

Read at 75099fa70. Evidence level 2 (file and line reads; some figures are arithmetic from constants, marked inference). Nothing run. Paths relative to sketches/core-loop/.

## Headline
No dead stops between areas: horizontal speed carries across every stage seam (`src/core/flow.gd:652-676`; `tests/world_launch_test.gd` allows at most 15% loss). But every stage-to-stage hand-over is a hard cut taken in the middle of a 0.6 s cannon shot, into a separate map with a snapped heading, and nothing on screen says where you came from. Only camp gate to dam is covered, by the comic swipe (`src/presentation/launch_take.gd`).

Worst: flume to Slag Bowl. The design aims the launch east at Brindle's smoke column; no smoke column exists in code or data. The bowl is built floating 30 m above the head house with the flume hidden (`src/boss/arena.gd:47,56-73`). You appear on the bank about 110 m behind the direction you launched (inference), turned 60 degrees, with no landing rings (`world.gd:368-369`).

Earlier rulings that parked this: DECISIONS.md:26 ("richer world transitions" until after the alpha) and DECISIONS.md:56 (arrivals on the musical grid). Andrew's 10 Nov words ("at least within one world") override the first for World 1.

## Hand-overs in play order
| # | Hand-over | What happens today | Kind match | Direction | Momentum | Screen | Story |
|---|---|---|---|---|---|---|---|
| 1 | Title to camp | K on title; not traced further | n/c | n/c | n/c | n/c | n/c |
| 2 | Camp gate to dam | Gate throws the ball out; comic swipe (wind 0.45 s, cover 0.24 s, hold 0.1 to 1.5 s, reveal 0.34 s); fall in 14 m above the dam spawn; speed reset to 0.8 cruise (`game.gd:871-896`, `flow.gd:473-474,675`) | partly | unknown | partly | partly (directed swipe) | partly: "Run again" skips this swipe |
| 3 | Dam Warden broken to reward gates | Three roll-through arches unseal (`flow.gd:1169-1199`, `reward_gates.gd:202-228`) | meets | meets | meets | meets | meets |
| 4 | Moss's bay in and out | Steam cradle up, bow pad back, banked speed returned (`bay.gd:11-19,41-46`) | meets | meets | meets | meets | meets |
| 5 | Dam gate to flume | Launch rail (24 m/s up along your own heading), 0.6 s flight, hard cut, fall onto landing rings at the flume spawn, heading snapped 0 to 31 degrees (`world.gd:702-714`, `launch.gd:46-54`, `flow.gd:993-1020`) | partly | GAP: aimed at the 120 m face, cut in front of it | speed meets, heading GAP | GAP: raw cut, only a HUD card | partly: leave by a generic gate and cannon |
| 6 | Flume gate to Slag Bowl | Same rail, hard cut, every stage map hidden, ball set on the bowl's bank, no landing rings, 60 degree snap, then Brindle's entrance (`boss.gd:171-177`, `arena.gd:41-43,136-167`) | GAP | GAP: arrive behind where you aimed; smoke column absent | partly | GAP: cut into a floating bowl | partly |
| 7 | Brindle defeated to world 2 | Keep rolling, victory card after the rout veil, hard cut to the Dig (`flow.gd:955-960,1023-1041`, `screens.gd:399-480`) | GAP | GAP | partly | GAP | partly |
| 8 | Death to restart | RUN OVER, one key, cut to the dam drop with no swipe (`flow.gd:373-377,444-475`) | n/a | n/a | n/a | partly | partly: a different start from the camp gate |

Small mismatches: stage 2's card reads "The Cable Reach" (`src/core/park_defs.gd:112`, the old map's name) but the map is the flume ("Spillway: the flume", journey page :145). Dam spawn heading is 20 degrees in `park_dam.json:6`, 30 in the journey page :436.

## Ranked units
| # | Player sees | Files | Geometry | Size | Could move | Proof | Before the sitting |
|---|---|---|---|---|---|---|---|
| T1 | The dam-to-flume and flume-to-bowl cuts sit under the same comic swipe as camp to dam | `launch_take.gd` reused; triggers `world.gd:705-714`, `flow.gd:993-997` | no | S-M | pixels and timing in a played game; bots skip the take, bands do not move | extend `launch_take_test`; PC film | yes |
| T2 | The rail turns ball and camera toward the next stage's arrival heading in flight: no yaw snap | `launch.gd` (`rail`, `fire`), `terrain.entry_heading(next)` | no | S | landing spot and heading | `world_launch_test` + hand-over test | yes |
| T3 | The Slag Bowl lies ahead along the flume launch and you land in it on rings | `arena.gd` `place()`, ENTRY_ANGLE; `boss.gd` `_place_ball`; `launch.mark_landing` | no | M | Brindle's opening seconds and band (keep `_ship_angle = entry + PI`, rulings bv and cf) | `boss_momentum_test`, `spine_boss_seam_test`, 24-seed Brindle band | yes, with a band read |
| T4 | Stage 2's card says the flume's name | `park_defs.gd:112` | no | S | pixels | read the card | yes (veto list) |
| T5 | Data rows and a test per hand-over; a world 1 atlas placing camp, dam, flume and bowl in one frame | park JSON `exit`, `arrives`, `atlas`; `park_schema.gd`; `ParkMap.handover()`, `Arena.handover()`; `tests/handover_rows_test.gd` | no | S-M | nothing | planted cases | yes |
| T6 | Brindle's smoke column and furnace glow stand on the flume's east horizon where the launch aims | new impostor beside `landmark_impostor.gd` | light | M | pixels, frame time | sight share from the bend overlook; 4080 frame read; PC still | yes, after the frame read |
| T7 | After Brindle's rout a rim kicker launches you out toward the Dig under the swipe | `flow.gd` VICTORY branch, `Launch.fire`, arena kickers | no | M | victory timing | victory and lap tests, film | after (crosses worlds) |
| T8 | The dam launch rides up the face and over the crest with the reservoir and weir mesa in view | dam landmark recipe, vista; `launch.gd` lift | yes | L | pixels, frame time, timing | sight test, film, frame read | after |

## Verification
- CODE: `tests/handover_rows_test.gd`, data only, through `ParkMap.handover()` and `Arena.handover()`. Asserts per pair: one exit and one arrival; kinds match (launch to land, slide to slide, door to door); arrival heading within 20 degrees of exit heading in the atlas frame; exit aim within 25 degrees of the next place; seconds without control <= 2.5; `opens` is warden_broken or boss_defeated; speed carried >= 0.85. Planted cases: flume heading flipped 180; `opens` = "timer"; door exit paired with a drop arrival; ENTRY_LIFT 60. Today's data fails on its own (flume exit 90 against bowl arrival 150; bowl behind the exit aim; dam 0 against flume 31), which is the positive control.
- PICTURE: extend `tools/eye_film.gd` (driven by `tools/self_play.gd --self-play-film`) with a `--handover` mode keeping chase-camera frames from 3 s before `launched` to 2 s after `landed`; 6-frame sheet (-2 s, -1 s, launch, cut frame, +0.5 s, touchdown). Blind reader: "Where did you just come from?" "How did you get here?" Controls: the Dig's arrival spliced after the dam exit must be called wrong; a strip with the swipe removed must be called a cut. Needs a display and CPU: not while a gate runs.

## Draft ruling
1. Inside a world every hand-over is one ride: you arrive on the same kind of thing you left by, the exit points where the next place lies, and the objective you finished is what opens it.
2. Speed and heading carry across. A camera turn or a lost second is allowed only inside a directed set piece with its own music, never as a bare cut.
3. Before you leave, the next place or its sign (a beam, smoke, a glow) is in view, and the place you left shows when you arrive wherever the geography allows.
4. A cover such as the comic swipe may hide loading, but it starts and ends on motion that matches on both sides.
5. Each hand-over is a data row checked by a test and shown on a transition strip before it ships.

## Journey cues, camp to Brindle
Landmark: dam with green beam, penstock tower with green beam, nothing for the bowl before arrival (break). Machinery: 120 m dam, head house drum, the Requisition. Packs: 5, then 6 with the Foreman's crew, then Brindle. Warden plating 90 then 110 (`park_defs.gd:106-117`). Light: dawn, then morning. Music: theme 0, theme 1, Brindle.
Breaks: no sign of the bowl from the flume; the bowl hangs over a hidden world; stage 2's name is a leftover; "Run again" skips the camp-gate swipe.

## Not checked
Camp layout and gate geometry; title-to-camp walk; air control during the fall; whether the dam view shows the weir mesa; the arena's light and sky; boss music hand-over; whether `Arena.place` pulls the bowl inward (would change the 110 m figure).
