# World rosters: the Dig and the Highdraft

Status: decided 2026-10-17 by Andrew's card taps, relayed by the project coordinator (subsequently implemented for full-alpha Worlds 2 & 3, unparked under ruling `ep` in [DECISIONS.md](../../../project-guide/handoff/DECISIONS.md)). This file is the brief that the build threads shared. Paths are under `sketches/core-loop/`.

## The ask

Andrew (19:52Z, 17 Oct): enemy design for worlds 2 and 3 must not rehash or reuse the Spillway. Each world needs an identity of its own that is not a gimmick, built on the core game the player masters. A grown pilot should meet harder remixes of those verbs.

## What the audit found (main at cf63e622)

- The Dig and the Highdraft have three enemies each (`src/combat/roster_dig.gd`, `roster_highdraft.gd`).
- Two of the six are near-reskins: `lamp_swarm` plays like `gyro_jammer` (it steals your line, and boost breaks it). `anchor_crew` is the `hooker` lane plus the `winch_drone` pull.
- `burrower`, `drill_crew` and `kite_drone` are half new. `line_cutter` is the only fully native enemy.
- All six stages use the same elite pack, `plated_brute` plus `winch_drone` (`src/core/alpha_defs.gd` ELITE).
- Every park carries `fleet_landing`, `machine_eruption` and `boiler_burst` (`src/world/park/*.json` event_rows).
- The six world 2 and 3 rows have `"tag": ""`, but each has its own wind-up sound in `src/presentation/windup_rows.gd` (`warn_burrow`, `warn_bore`, `warn_lure`, `warn_cut`, `warn_winch`, `warn_dive`).
- Eight Spillway gear rows are built but never spawn on the alpha table (authored packs only).

## Decisions

| Card | Tap (17 Oct) | Rule |
| --- | --- | --- |
| Dig carving | Commit, 20:03:46Z | Dig floor threats cannot reach a ball that is carving a wall, on a bank or in the air. The Dig is where grip and carve become the skill. |
| Highdraft heavies | Ring-outs, 20:03:50Z | Highdraft heavies are near-unkillable by damage. Knocked off an island edge, one is finished. |
| Spare Spillway gear | Re-home a few, 20:03:01Z | The catch trap moves to the Dig as the pit jaw and the netcaster moves to the Highdraft as the gap net. Each is reworked around its world's master verb and re-dressed as a native body. The other six stay out of the alpha; their code stays in the repo. |

Standing rules still hold: the four specials (Foreman, Dispatcher, Splitter, Linker), the attacker budget (PR #15) and the 2x growth rule.

## One master verb per world

| Verb | Spillway: learn it | Dig: the floor fights back | Highdraft: nothing to stand on |
| --- | --- | --- | --- |
| Rolling, momentum | Stay fast and fields miss you | Slow on the floor is where burrowers find you | Momentum carries you across gaps |
| Ramming | Bowl through packs | Flat rams bounce off plate; ram from above | Ram heavies off the edge for a ring-out |
| Grapple | Hook posts, chain hits | Hook the walls (mag floors make it slip) | Your lifeline; enemies cut it, you re-bite |
| Carve, downforce | Optional | **Master verb.** The wall is the safe lane; the lip drop is the big hit | Island rims and updrafts |
| Swing, air | Bonus height | Short hops out of holds | **Master verb.** Swing island to island, ram in the air |

These world motifs match the fields and cast-times design (`design-v3/FIELDS-AND-CASTS.md`, branch `claude/project-thread-azoily`): Spillway Flow, Dig Plate, Highdraft Wind. That design owns how fields, cast times and damage families read in each world. This file owns the rosters.

## The Dig floor rule

`src/combat/floor_rule.gd`: a ball is **on the floor** when it is grounded on a surface whose normal has `y >= 0.9` (flatter than about 25 degrees). Banks, half-pipe walls, ramps and the air count as off the floor. Every Dig floor threat (burrower, drill crew bore, pit jaw, prop crew debris) gates its catch or hit on `FloorRule.on_floor(state)`. When grip and carve lands (wave 18, machine), carving a vertical wall is off the floor by the same test, so the rule needs no change.

## The Dig roster (stages 3 and 4)

| Enemy | Status | Rule | Answer | Grown pilot (heft class 3 and up) |
| --- | --- | --- | --- | --- |
| Burrower | rework in place | Tunnels toward a ball that is on the floor and below cruise; surfaces under it. It cannot reach a ball off the floor. The lunge lane goes. | Carve the wall; slam its floor marker from above (a lip drop kills it) | Comes in pairs that close both floor exits |
| Drill crew | keep, tweak | Plated rig; the bore only hits a ball on the floor. The bore hole stays open for 4 s as a pit (`bore_fact`). | Lip drop or arc cracks the plate; carve past the bore | Bores under the lip you were about to land on |
| Lamp swarm, becomes the floodlight rig | rework in place | Throws the light that plates its crew (the fields thread's floodlight aura). The fields thread strips the steering shove in that same PR, stacked on its field slice. | Ram the lamps at cruise to scatter them | Two rigs cross beams; only the crossing is soft |
| Pit jaw (new id `pit_jaw`, from the catch trap) | new behaviour, new body | A toothed jaw flush with the floor that snaps on a ball rolling over it **on the floor**. A ball on a bank, a wall or in the air passes over. A slam from above onto the open jaw kills it. | Carve round it; smash or boost out if held; a slam kills | Jaws line the bowl floor, so the wall is the only lane |
| Prop crew (new id `prop_crew`) | new behaviour, new body | Holds shoring over its pack. Ram the prop and the roof comes down on everything under it, the player included if on the floor. | Ram the prop from the wall side | The prop sits on a floor the burrowers own |

- Dig elite: `drill_crew` plus the Foreman under a floodlight, replacing the Spillway elite on stages 3 and 4. Until the Foreman merges: `drill_crew`, `drill_crew`, `pit_jaw`. Every member of a Dig elite pack arrives plated, following Andrew's Q3 answer "Flow, Plate, Wind": `EliteAffixes.PLATED` sets spec armour `plated`, which `enemy.armour_class()` hands to `damage_families.gd` on PR #65. Kinetic hits are resisted, and arc and abilities are weak (`tests/dig_plated_elite_test.gd`).
- Prop crew packs (identity thread, 17 Oct): stage 3 `dig_bore` is `drill_crew`, `burrower`, `prop_crew`, the teaching pack (ram the jack from the wall side; the burrower punishes a ball lining up the ram from the floor). Stage 4 `deep_crew` is `drill_crew`, `drill_crew`, `lamp_swarm`, `prop_crew`, the payoff (the prop is kill-first; one wall ram wipes both drill crews and the floodlight). Never in the Dig elite or the jaw packs; stage cap 1.
- Dig fleet landing becomes a lift cage rising from the pit. Cave-ins start where a burrower surfaces.
- Specials in the Dig: Splitter pods burrow; the Dispatcher hangs from a ceiling rig; the Linker joins plated crews.

## The Highdraft roster (stages 5 and 6)

| Enemy | Status | Rule | Answer | Grown pilot |
| --- | --- | --- | --- | --- |
| Line cutter | keep, tweak | A cut costs you only over a gap. A fresh harpoon bite within 0.5 s of the cut saves the swing with a small speed bonus. | Re-bite; glide under; land early | Two cutters throw at your line and your landing |
| Ballast heavy (new id `ballast_heavy`, replaces `anchor_crew` in packs) | new behaviour, new body | A slab crew on island edges. Its health is too high to wear down in a stage, but a knock that carries it past an edge finishes it (ring-out). Before it slams it braces with an interruptible cast. Uses the knockback of PR #43; coordinate through the coordinator. | Ram it off the island; ram during the brace | Plants a cable behind it; cut it or hit from the island side |
| Kite drone | rework in place | Rides thermals. A ball riding the same thermal reaches it, and an air ram at the top kills it outright. Ground answers still work, but slowly. | Ride the thermal, air-ram | Circles over downdrafts, so the kill drops you toward the next island |
| Gap net (new id `gap_net`, from the netcaster) | new behaviour, new body | Two posts on facing island rims with a live net across the gap. It catches an airborne ball crossing the gap below its tear speed and slings it back the way it came. Above tear speed you rip through it and it breaks. | Cross fast (swing or launch); smash; cut a post | Nets stack two deep on a long gap |

### Ring-outs (built 17 Oct)

In the Highdraft (world 3), any enemy knocked off an island edge is gone, and it counts as the pilot's kill (`enemy.gd` `_rings_out`, `ring_out`).
- **What opens it:** only a knock that strikes the enemy on a floor does, meaning its knocked speed is at least 1 m/s. Any knock path counts: ram, slam, Lift Pulse, Quake Knock, pins and the kit pushes. Tarn's tow and hurl open it too (`open_ring_out`). A knock that lands while the enemy is already falling opens nothing.
- **When it fires:** the enemy rings out while it is in the air at least `RING_OUT_DROP` (6 m) below the floor it was knocked from, with the ground under it at least that far down too. Health and plating don't matter. A ram down a ramp or a slope carries it downhill but keeps the ground close under it, so it doesn't count. Every island top sits 12 m or more above the net deck.
- **Flyers:** kite and winch drones hover, so a knock never drops them and they never ring out. Splitter pods can be rung out, but the mama splitter cannot.
- **What closes it:** once the enemy is back on a floor with the knock spent, a later fall no longer counts. So a throw that lands back on the island is safe, and an enemy that walks off with no knock is still rescued.
- **Always rescued:** bosses, Wardens and their relics (`reactor_relic`, `swarm_remnant`, `mind_hand`), plus the kill-first specials (`RING_OUT_KEPT`). Boss arenas and the Spillway and Dig keep today's rescue.
- **Tell:** the fall itself, then the break-up. The `enemy_ringed_out` event row plays `ring_out_fall` (PR #12: a slide whistle falling two octaves, a far-off poof and a two-ping twinkle) through `sound_next`, and borrows `near_whoosh` until #12 lands. `enemy_killed` follows with the kill pop. Scrap drops where the enemy rang out, over the deck. No attack id is claimed, because a ring-out is not an attack.
- **Tests:** `tests/ring_out_test.gd`.

- Highdraft elite: `ballast_heavy` plus two `kite_drone`, replacing the Spillway elite on stages 5 and 6.
- Highdraft fleet landing becomes a zipline drop from the barge. Impacts knock heavies toward edges.
- Specials in the Highdraft: Splitter pods can be rung out; the Dispatcher perches on a moving island tip; the Linker strings its cable across a gap.

## Every Dig and Highdraft enemy gets

- a wind-up sound that matches its attack (`windup_rows.gd`; new kinds request one from the music thread);
- a grown-pilot remix, one row in `src/combat/elite_affixes.gd`;
- a lab check (behaviour test) and an independent review before it reaches a candidate.

## Who builds what

| Thread | Owns | Files |
| --- | --- | --- |
| World 2 and 3 enemy identity (this file's thread) | floor rule, burrower, drill crew, pit jaw, the floodlight rig's roster line and pack placement, Dig packs and elite | `src/combat/floor_rule.gd`, `roster_dig.gd`, `burrower.gd`, `drill_crew.gd`, `pit_jaw.gd`, stages 3 and 4 in `alpha_defs.gd` and `park_defs.gd` |
| Highdraft roster | gap net, ballast heavy, kite drone, line cutter, Highdraft packs and elite | `roster_highdraft.gd`, `gap_net.gd`, `ballast_heavy.gd`, `kite_drone.gd`, `line_cutter.gd`, stages 5 and 6 in the defs |
| Bodies | Blender recipes and glbs for the pit jaw, gap net, ballast heavy and prop crew; re-dress the lamp swarm as the floodlight rig | `tools/blender/world_two/`, `tools/blender/world_three/`, `assets/models/world_two/`, `assets/models/world_three/`, registry entries |
| Prop crew and Dig events | prop crew behaviour and row; cave-ins at burrower surfacing; lift-cage and zipline fleet landings | `prop_crew.gd`, one appended row in `roster_dig.gd`, `src/world/events/` |
| Fields and cast times | the floodlight aura, and removing the lamp swarm's steering shove in the same PR | its field component, `lamp_swarm.gd` behaviour |

Shared one-line lists (`director.gd` KIND_NAMES, `director_cards.gd` CARDS, `presentation/windup_rows.gd`, roster tests) are appended by whichever thread adds a kind; merge conflicts there are expected and trivial.
