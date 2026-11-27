# Wayfinding: finding your way with no mini-map

**Status: wave 46 unit E0-02 design spec (22 November 2026, originally targeted at `stage/alpha-w46` at `c0a4bba6f`; see `src/` and [STATE.md](../../../project-guide/handoff/STATE.md) for integrated state — ruling `ep` later moved to flat `main`).** Ruling ek ([DECISIONS.md](../../../project-guide/handoff/DECISIONS.md), 22 Nov) orders the work this page specifies.

**What this page is for.** World 1 has no mini-map and gets none. A player rolling at 14 m/s or more across a park 1,600 m square has to answer four questions from the picture alone: where does the ride end, which part of the park am I in, where does this side route go, and have I been here. This page gives each question one answer, says what a lock cable is and when it goes dark, says what every kind of site looks like once it is finished, and names the park data the answers need. The map, data and model units of wave 46 build from it.

**What this page does not own.** Where each piece stands on the Dam and the Flume is the map units' work, held to the ten-point map standard and the audits in `project-guide/handoff/shared/world1/` (AGENTS.md rule 9). How a hand-made mark differs from a cast one is [SIGHT-PERSONA.md](SIGHT-PERSONA.md) section 3. The colour law is [LEGIBILITY.md](LEGIBILITY.md) section 1. Place names are in [NAMES.md](NAMES.md).

Paths without a prefix are under `sketches/core-loop/`.

## 1. Four distances, four questions

Each question is asked at its own distance and is answered by one kind of thing. Nothing below is a HUD element, and none of it is a word the player must read.

| Distance | The question | What answers it |
| --- | --- | --- |
| Horizon, 500 to 1,600 m | Where does the ride end, and where does it go after that? | The park's landmark and beam; the furnace smoke; a far card of the next stage; one skyline anchor on each side rim |
| District, 100 to 500 m | Which part of the park is this, and what is the way through it? | Three districts per park, each with its own ground, its own built pieces and its own grade; one drawn way in and one drawn way out |
| Ground, 20 to 150 m | Where does this side route go? What does the Warden still want? | Water and foam; Keeper chalk and bunting at the mouth of a side route; the command cables (section 3) |
| Here again, 0 to 150 m | Have I done this one? | The site's visited state (section 4) |

Two rules hold across all four:

- **Open things are loud and finished things are quiet.** An open site smokes, glows or moves. A finished one is a small, still, light-coloured mark. The eye sweeping a park at speed lands on what is left to do.
- **Routes are chalk and bunting; done is one square flag.** No other mark means either, and neither mark is used for anything else.

## 2. The pieces at each distance

### 2.1 Horizon

- **The landmark and its beam** stay as they are. Today the landmark is in view from 88% of the Dam's open ground and 87% of the Flume's. `park_landmark_sight_test` keeps that at 0.85 or more through every change this page asks for.
- **Brindle's smoke.** The furnace of the Slag Bowl shows as one dark, leaning mass of smoke with gold at its foot. The Flume has it today, placed by its `approach` row. The Dam gains the same row, so from the Dam's crest the player can see where the whole world ends. `smoke_column.gd` already draws it; the Dam only lacks the data.
- **The Flume far card.** Along the line the Dam's launch leaves on, a flat far card shows the Flume's water. It answers "where next" before the Warden falls, and it is dressing: no collider, and never close enough to be reached.
- **Two skyline anchors**, one on the east rim and one on the west, each a different silhouette. Turned away from the beam, the two rims no longer look alike. Dressing only.

### 2.2 Districts

Each park is three districts, named in [NAMES.md](NAMES.md). The names appear in the world only, on old-works signs; the HUD never prints one.

| Park | Districts, in ride order | What falls short today | What is added |
| --- | --- | --- | --- |
| The Dam | Intake Catwalks, Spillway Apron, Sunken Pump Yard | The high line has no visible takeoff. The Pump Yard reads as a sump with no way through | A **takeoff ramp** at the first cable anchor of the Intake Catwalks, so the high line starts at a shape that says "go up here". A **ball-wide concrete shelf** through the pump elbows of the Sunken Pump Yard that rejoins the approach to the Warden. The apron stays terrain; only its lip is dressed |
| The Flume | Weir Bobsled, Trestle Span, Headhouse Overlook | No cables, visited marks or ground leads | The same pieces as the Dam, placed as data and dressing. No collider changes unless the unit that places them declares it |

The takeoff ramp and the shelf are map geometry. They move run hashes and band measures, so they are built before calibration and are never behind a cut line. The harpoon line across the Intake Catwalks stays data (`assets/park/park_dam/lines.json`) and is not a mesh.

Each district also takes its own row of the picture's grade (the tint the whole frame is given), so the three differ at a glance without a sign. The grade must pass `colour_cvd_test`.

### 2.3 Ground leads

- **Water and foam** already run downhill toward the ride's end. They stay the first lead.
- **Keeper chalk arrows and cloth bunting** stand at the mouths of side routes. They are hand-made and a little crooked ([SIGHT-PERSONA.md](SIGHT-PERSONA.md) section 3). They are props with no collider, in sand, bone and copper. None is mint.
- **The command cables** lead to the Warden one way and to the crews the other (section 3).

### 2.4 What stays

The goal marker and the objective plate stay exactly as they are. Everything on this page is added under them. Nothing here replaces a cue the player already has.

## 3. A command cable is a gate pip

The Warden's clamp stays shut until the stage's gate is paid: a number of packs broken this attempt (`lock_rows.gd`: five on the Dam, one on the Flume), or the enemy camp done, or 75 s after the Warden is first engaged. Today that ask shows only as pips on the Warden, and from 300 m the player cannot see what the Warden wants.

**The rule: one cable for each pack the gate asks for, and a cable is dark exactly when its pip is lit.**

- **What a cable is.** The Warden's command line to its crews. It runs along the ground from the clamp at the landmark out to a crew home. The Dam has five crew homes and five cables. The Flume has one cable, to the home the route passes first.
- **How it looks alive.** A closed tube in the old works' cast material, with beads of uranium-green light (`Palette.ANCIENT`) marching along it **toward the lock**. Follow the beads and you reach the Warden. Ride against them and you reach a crew. At the crew end the cable rises out of an old-works casting, so the source reads as the Foreman's and not the Fleet's.
- **How it looks dead.** Severed: two capped ends with a gap between, dark charcoal (`Palette.CHARCOAL`), no light and no motion. A dead cable is quiet, as every finished thing is.
- **When it dies.** The cables hold a fixed order, cable 1 to cable N, the same order as the Warden's pips. When pip `k` lights, cable `k` dies, whichever pack was broken and wherever it was. The cable is the pip drawn large on the ground, and is not a claim about one home.
- **When the clamp opens another way.** The enemy camp, or the 75 s clock, lights every remaining pip. Every remaining cable dies with them, so no live cable ever leads to a clamp that is already open.
- **Resets.** All cables are alive at stage entry and at retry, as the pips are.
- **Colour.** The beads are uranium green because the cable is an old-works mechanism (section 5). They are never mint: a cable is something to follow, and nothing to press.
- **One read.** The cable drawing reads the count of packs from one public call on `stage_locks.gd` and holds no count of its own, so pip and cable cannot disagree. `YardLock.tla` gains sync lines for the read and no new step.

## 4. The visited state

Today a finished site's smoke fades and leaves bare ground, so a fast player circling back cannot tell a cleared site from one they never reached. Each kind of site now flips once, when it is finished, to a lasting mark.

| Site | Open | Finished |
| --- | --- | --- |
| Cache | Its smoke, lid shut | Lid open. A spring pole stands up with one square flag of bone or sand cloth (`Palette.SAND`), tied on with copper rope. The flag is never mint |
| Crew home | Its steam and its crew | The steam dies and a chalk X is on its plate. Never a PAID stamp: PAID is Tally's alone |
| Cage (a rescue) | Its smoke, door shut | The door is off. The freed pilot's scarf hangs from a bone post, in that pilot's colour: copper for Rivet |
| Rogue | Its dark, stuttering smoke | The wreck stays where it fell |
| Shortcut that must be broken | The whole frame | A scorched frame, open through the middle |
| Furnace | Brindle's smoke | It never flips. It is where the world ends |
| Command cable | Beads running toward the lock | Severed, dark charcoal (section 3) |

Rules for every flip:

- A site flips **once**, on the event that finishes it (`activity_done`, which exists today, and the rescue and cache events).
- Every flip **resets at stage entry and at retry**, with the site itself.
- A flip is **quiet**: small, still and light in value, so it reads against dark ground by day and under the Night Shift look by its value, not by a glow.
- The mark is drawn per kind of site, in `site_markers.gd`, so a park needs no data to get it.
- The flag is bone or sand and the scarf post is bone because mint means one thing only (section 5). A copper scarf on a copper or rust post would vanish, which is why the post is bone.

At camp the same two marks carry the same fact: the freed pilot's scarf, and the stamps on the shift board.

**What have I missed.** From a crest (the Dam's lip, the Flume's Headhouse Overlook) the park answers it in one look: open sites smoke, finished sites show a flag, live cables run. No list on a screen is added for it.

**Low ground.** In the Sunken Pump Yard the landmark can drop out of view. There the shelf, the chalk at its mouth and the nearest cable are the lead, and the beam returns at the shelf's far end.

## 5. Three colours this page depends on

| Colour | Means, and only means | So it is not used for |
| --- | --- | --- |
| Mint `#8BF0D3` (`Palette.live()`) | Press now, or act here: your verb works on this right now | Cloth, flags, cables, frost or any mark of something done |
| Uranium green (`Palette.ANCIENT`) | An old-works mechanism: a notched seam, the beam, the beads of a command cable | Mood light, fog, frost or decoration |
| Ice blue (`Palette.ICE`) | Frost and cold | Anything the old works made |

Frost on the ball is drawn in uranium green today (`player_fx.gd`, the frost row of `ELEMENT_COLORS`). It moves to ice blue, so a frosted ball and an old-works seam never share a colour. That is a one-row change for the Gate to place in a code unit.

## 6. Park data

The park files gain keys that are the same for every world. Unit E1-14 settles the spellings and the checks in `park_schema.gd`; this page fixes what each key means. All three are optional at the top of a park, so every park that does not carry them loads as before.

| Key | One row holds | The schema checks |
| --- | --- | --- |
| `cable_rows` | An id; `pip`, the cable's place in the fixed order; `to`, the id of the `home_rows` row it runs to; `via`, the ground points it passes between the clamp and that home | `to` names a home in the same park. The pips run 1 to N with none missing. N equals the packs the park's gate asks for in `lock_rows.gd`, and a park whose gate asks for none has no cables |
| `district_rows` | An id; `name`, one of the place names in NAMES.md; the ground it covers; `grade`, the row of the picture's grade it takes | The districts do not overlap, and every `name` is in NAMES.md |
| `approach` (exists) | Today: `to`, the bowl the floor line leads to, and `smoke`, where the furnace stands, which may be off the map. The Dam gains this row. It also gains one optional field that places a far card along the exit line | The far card stands outside the play rectangle |

The visited state needs no key (section 4). The fixture park `src/world/park/park_test.json` carries all three keys, and one test loads them from it.

## 7. What worlds 2 and 3 inherit

At the time of writing Worlds 2 and 3 were parked; under ruling `ep` ([DECISIONS.md](../../../project-guide/handoff/DECISIONS.md)) they have since been unparked for full-alpha runs and inherit the four distances, the cable-equals-pip rule, the visited state for each kind of site and the three keys of section 6 when populated.

## 8. How it is checked

- `park_landmark_sight_test` stays at 0.85 or more on both parks.
- A cable row loads, and reports dead exactly when its pip lights, including when the camp or the clock opens the clamp.
- Each kind of site flips once and resets at stage entry and at retry.
- The fixture park loads the three keys.
- A chase-camera still from each park's crest, in greyscale, in which both rides can be traced and open sites can be told from finished ones.
- Draw counts idle on the Linux PC stay at or under 310 on the Dam and 480 on the Flume. Those two ceilings are the plan's, for the Gate to confirm.

Automated checks do not show that a person finds their way. That is what the world 1 sitting is for.

## 9. Assumptions Andrew can overturn

1. A cable dies in pip order, and is not tied to the home it runs to. The gate counts packs wherever they are broken, so a cable tied to one home could stay alive after the clamp opened.
2. The Flume, whose gate asks for one pack, has one cable.
3. A rogue's wreck and a broken shortcut's frame are their own visited marks and get no flag.
4. District names are never printed on the HUD. They live on signs in the world.
5. The far card of the Flume is flat dressing and is never reachable.
