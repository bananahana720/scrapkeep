# Placeholder breakdown, wave 16 candidate

Checked 2026-10-17 22:20Z on `cand/alpha-w16` (GitHub `2fce8953`) with the repo's own check, `npm run sketch:placeholders` (scripts/placeholder-gate.mjs): **1,442 placeholders in 140 findings**, the same count as wave 15 main `cf63e622`. The check was also run on the tree of all 63 open PRs (#12 to #75), each with the candidate's check and with the PR's own copy of the check. Raw findings: [gate-w16-2fce8953.json](gate-w16-2fce8953.json). Per-PR runner: [pr-gate.sh](pr-gate.sh). The earlier plan, with the kit tables, is [../placeholder-burndown.md](../placeholder-burndown.md).

Cloud means code, text, data rows or Blender recipes that a cloud thread can build and gate. PC means it needs Andrew's 4080 (ACE-Step music and stems, GPU captures).

## By bucket

| # | Bucket | Count | Owner area | Where | Cloud or PC | Covered by | Left with no owner |
| ---: | --- | ---: | --- | --- | --- | --- | ---: |
| 1 | Anchor fields drawn as grey 8 m posts | 877 | park art + park runtime | `park_recipes.gd place_anchor_field`, 6 park JSONs | cloud | kit on #32 (15 GLBs); **swap: this thread** | 0 |
| 2 | Stamped ride lips (tunnels, half-pipes, kickers, caverns, lines) | 209 | park dressing (waves 18-19) | park JSONs + Blender kits | cloud | none | 209 |
| 3 | Grey boxes drawn (unstamped rows) | 153 | park dressing (waves 18-19) | park JSONs + Blender kits | cloud | none | 153 |
| 4 | Stamped plain slopes (bank, drop, ground, sky island) | 125 | gate rule + scatter | `placeholder-gate.mjs PLAIN_SLOPES`, `park_map.gd` scatter | cloud | rule on #32 ("Ride lips only"); scatter follow-up unowned | scatter only |
| 5 | Registry art delivered, not wired | 41 | assets/registry + src loaders | `assets/registry.json`, `registry.d/` | cloud | #46 (0 left on its tree); #45 wires spil9 | 0, but see new rows below |
| 6 | Cosmetics owed art (`PENDING_ART`) | 19 | cosmetics | `src/core/cosmetics.gd` | cloud | #17 drops 6 shells; #46 drops 9 trails/decals; #18 models 4 outfits but leaves them on the list | 1 (`outfit_kest_rigger`: no art) + 4 list removals |
| 7 | Attack rows with open fields | 10 | combat telegraphs | `event_kinds.gd ATTACK_ROWS` | cloud | #46 fills all 10 on its tree | 0, but see new rows below |
| 8 | Park landmarks with no GLB | 6 | landmark art | `assets/models/park/landmark_*` | cloud | #26 models (0 left on its tree), #28 places, #38 carries them | 0 |
| 9 | Icon `ab_sable_reel.svg` | 1 | UI icons | `assets/icons` | cloud | #32 | 0 |
| | **Gate total** | **1,442** | | | | | |
| 10 | Audio cues (the gate cannot see them yet) | +28 | sound | SfxBank, boss score | **PC** (ACE-Step; music RC thread, reaches the game through #12) | #41 makes the check count them; #58 is the cue hook | 28 renders |

## Rising buckets: open PRs that add placeholders

| PR | Adds | What |
| --- | ---: | --- |
| #29 sinkhole ring | +21 to +23 | new greybox gallery ledges, dressed by the sinkhole landmark |
| #19 trails and decals | +9 | registry rows "integration pending" for its 9 new trails and decals; #46 must absorb them |
| #44 rigs | +1 | `spil9_marks` registry row |
| #60 Splitter | +1 | attack row E25 |
| #65 fields and casts, #69 Dig floor, #71 prop crew | +1 each | one new attack row each (E27, E30, E31) |
| #72 Highdraft roster | +2 | E32 brace slam, E33 net charge |
| #41 audio gate | +28 | not new debt: it makes bucket 10 visible |

Rule for new attack rows: the PR that adds an E-row fills its pose, floor, colour and glyph before the gate, the way #46 fills E19 to E24. Otherwise every new enemy re-opens bucket 7.

## By park (buckets 1 to 4)

| Park (dress wave) | Anchors | Ride lips | Drawn boxes | Plain slopes | Landmark | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| park_dam (18) | 29 | 40 | 0 | 35 | 1 | 105 |
| park_flume (18) | 4 | 14 | 94 | 13 | 1 | 126 |
| park_pit (18) | 2 | 5 | 23 | 0 | 1 | 31 |
| park_sinkhole (19) | 339 | 110 | 13 | 3 | 1 | 466 |
| park_islands (19) | 308 | 34 | 4 | 59 | 1 | 406 |
| park_crown (19) | 195 | 6 | 19 | 16 | 1 | 237 |

Ride lips by element: tunnel 76 (sinkhole 73), half_pipe 41 (sinkhole lava channels 23), kicker 25, elevated_line 21, flow_line 13, flooded_cavern 11, bowl 8, ledge 6, grind_line 4, terrace 3, rail 1.
Drawn boxes by element: grind_line 81 (flume 79), kicker 36 (crown 16, flume 9, pit 9, islands 2), ledge 11, drop 10, flow_line 6, elevated_line 3, half_pipe 2, terrace/bank/rail/bowl 1 each.

## Ruled since: "Edges are ground" (Andrew, 2026-10-17 22:29Z)

The Highdraft's full-width mesa step edges count as ground, not ride lips: 18 island step lips, about 29 km (the card said 21 and 34 km by mistake). They get scatter (#81). The check counts them as terrain on #79 (the same rule as park_map.gd mesa_edge), so the islands drop 18 from bucket 2. Narrower lips such as fin_nose_kicker and lookout_lip still need a piece (unit I).

## Projection

If every open PR lands and the anchor swap lands: about **360** (380 before the mesa-edge ruling) in the gate (191 ride lips, 153 drawn boxes, about 21 from #29, a handful of new attack and registry rows, 1 outfit), plus 28 audio cues once #41 lands. Every one of them is cloud work. Only the 28 audio cues need the PC.

## Burn-down units, each sized for one thread

| Unit | Count | File area | Done-check |
| --- | ---: | --- | --- |
| A. Anchor swap (**this thread**, stacks on #32) | 877 | `park_recipes.gd`, 6 park JSONs, park tests | gate drops by 877; `park_place_test`, `park_anchors_test`, park crown/dam tests and `sketch:smoke` pass; anchor-gap traversal band unchanged |
| B. Flume grind lines, lips and drops | 99 | `park_flume.json` (79 grind lines, 14 ride lips, 6 other boxes) onto `flume_span`, `canal_lip`, `penstock_run` | gate shows no flume grind_line or lip rows; seat and tile fits accepted (`park_place_test`); flume traversal re-measured |
| C. Industrial kicker piece for flume and pit | 18 | new Blender recipe under `tools/blender/park/`, plus flume and pit kicker rows | GLB within the landform budget; gate shows no flume or pit kicker rows; kicker ride sensor fires in `park_place_test` |
| D. Pit flow lines, terraces, rails and lips | 19 | `park_pit.json` onto `pit_haul_ramp`, `bench_coping`, `pipeline_rail` | gate shows 0 for park_pit apart from the landmark (#26) |
| E. Sinkhole tunnels and caverns | 84 | `park_sinkhole.json` tunnels onto `lava_tube_run` and its bends; caverns onto `cavern_shell`, `cenote_pool`, `flooded_shaft` | gate shows no sinkhole tunnel or flooded_cavern rows; tunnel mouths line up with the stamp (`park_holes_test`) |
| F. Lava channel half-pipe piece | 23 | new Blender recipe plus the sinkhole half_pipe rows | GLB in budget; gate shows no sinkhole half_pipe rows |
| G. Sinkhole drawn boxes, other lips and #29's ring | about 37 | `park_sinkhole.json` drops onto `shaft_drop`; #29's gallery_ring ledges onto `mesa_rim_ledge` | gate shows no sinkhole drop or ledge rows on #29's tree |
| H. Dam ride lips | 40 | `park_dam.json` onto existing half-pipe, ledge and line kits | gate shows 0 dam rows apart from anchors and the landmark |
| I. Highdraft lips and boxes (islands and crown) | about 63 | `park_islands.json`, `park_crown.json` kickers onto `mesa_lip_kicker`, ledges onto `mesa_rim_ledge` and `cliff_dwelling_row`; coordinate with the crown pass (#67) | gate shows no islands or crown kicker, ledge or line rows |
| J. Scatter on plain slopes | 125 (rule) | `park_map.gd` lets scatter onto `isPlainSlope` rows | scatter test shows scatter on stamped plain slopes; #32's rule note holds |
| K. Kest rigger outfit and the cosmetic list | 5 | new outfit recipe (as #18), then drop #18's 4 ids and this one from `cosmetics.gd PENDING_ART` | gate pending count 0 with #17, #18 and #46 applied |
| L. Late registry and attack rows | about 15 | registry rows from #19 and #44; E25, E27, E30 to E33 fields | gate registry and attack counts 0 on the stacked candidate |
| M. Audio cues (PC, music RC thread) | 28 | 17 special-enemy sounds and 11 boss tracks through #12 and SfxBank | #41's audio check passes on the candidate |

Units B to I are the wave 18 and 19 dressing. Each one edits one park JSON, so two units on the same park conflict. Give each park to one thread. Units A to I add up to the 1,260 park rows that are not plain slopes or landmarks (1,239 now plus #29's 21).
