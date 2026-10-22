# Per-park kit briefs (Dressing lane)

> **Status.** These are the wave 18 briefs the Dressing lane wrote before building each kit. The park notes in this folder (`park_<id>.md`) and the park PR bodies cite them. The kits as built are listed in each park's `assets/models/park/props/<id>/manifest.json`; where the two differ, the manifest records what shipped and the park note says why. Placement rules are the validator tiers in [DRESSING-KITS.md](../DRESSING-KITS.md), not this file.
>
> **The 30 m kinds.** Four kinds below say "keep 30 m from lines": dam `laundry_line`, flume `washline`, pit `windsock` and crown `kite_pennant`. The plan check enforces it once #280 lands: each of these kinds carries `line_clear_m` 30 in its kit manifest, and `kit_errors` rejects a kit that defines one of them without it (#241 6329056497). Each park note also records the edge distances (ParkProps `Context.line_distance` at the centre, minus the instance radius) in its "30 m brief kinds" section.

Each kit has at least 12 kinds with 2 or 3 geometric variants. H marks a hero (dress_hero, 6k to 20k tris at LOD0). Every other kind is dress_prop (300 to 3k). Variants follow a three-step ladder: a = in use or recently left, b = worn or run down, c = collapsed or overgrown, where it fits. Every kit carries plants growing through scrap. The readability rules are in [READABILITY.md](READABILITY.md). The palette, story notes and the "who" sources are the stage pages under [design-v3/park/stages/](../stages/) and [LORE-ALPHA-DRAFT.md](../../LORE-ALPHA-DRAFT.md).

## dam (world 1, dawn). Arizona slickrock and concrete. Dam-era works crews; the survey deck; a Fleet docket calls the dam "surplus concrete".
- H gate_wheelhouse: timber-and-concrete hut with a big hand wheel chained shut. Variants: a intact, b roof sagging.
- H mixer_wreck: chunky soft-toy concrete mixer truck, drum tipped. Variants: a parked, b wheel off with brittlebush in the cab, c half sunk in silt.
- H survey_tent: canvas wall tent on a timber platform, with a cot, a table and a sagging ridge. Variants: a pitched, b collapsed.
- survey_tripod: toppled tripod and a plumb bob.
- flood_staff: water-level staff, 2.6 m, chunky numerals painted higher three times.
- stencil_post: low concrete post with a "STAND CLEAR OF THE FACE" plate (no stripes) and a chalk tally board.
- lunch_pail: pail, thermos and a tin cup on a flat rock.
- hardhat_rack: peg board with hats, one fallen.
- cable_drum: wooden cable drum lying on its side, rope coiled flat.
- compressor_cart: small two-wheel compressor with one oversized whistle.
- cold_campfire: stone ring, charred logs, a kettle on a stone. No glow, no smoke.
- laundry_line: two posts under 2 m with shirts and a towel. Keep at least 30 m from lines.
- sandbags: a low curved sandbag wall.
- rebar_bloom: a rebar bundle with brittlebush growing through.
- brittlebush and creosote clumps (plant).

## flume (world 1, morning). Weathered timber flume on trestles, canal country. Flume crews' bunk ledges, cooked fish on the trestles, bents numbered downhill.
- H boom_crane_wreck: timber crane boom lying on blocks, the lock and chain still on. Static.
- H skiff_on_blocks: stranded rowboat on trestle blocks, with a net and a fish rack. Variants: a with tarp, b holed.
- H sluice_shed: gabled shed over a big sluice wheel, a flask on the post. Static.
- bunk_cots: a canvas cot under a lean-to.
- milepost: a low post with painted depths, one crossed out.
- tea_hearth: hearth stone, kettle and cups (cold).
- washline: washboard, tub and a short line. At least 30 m from lines.
- timber_ties: a low stack of ties (low, never a step shape).
- tool_peg: peg board with saw, adze and shovel.
- gauge_dial_shed: a small shed with a big round white dial.
- fish_rack: drying rack with grey hemp nets.
- bent_numbers: a fallen numbered bent plank with grass through it.
- cattail and reeds clumps near the canal, saltbush (plant).
- pipe_section: a short flume pipe section with a plant growing out.

## pit (world 2, noon). Copper porphyry pit. Mining crews; the last truck down at shift end; lunch tins that arrived at the hoist house. LAMP VETO: no lit lamps, no light pools.
- H haul_truck: enormous soft-toy haul truck, parked. Variants: a whole, b tyre off and bed tipped, c rusted with bursage in the bed.
- H drill_rig_wreck: powder-cut drill rig on crawler pads, mast lowered flat (never a tall pole).
- H rope_drum_wagon: wagon with a giant coiled hoist-rope drum.
- shift_bell: a short bell post (2.5 m) with an over-long rope coiled on the ground.
- lunch_shelf: a shelf with lunch pails (pails with handles, not stacked tins).
- assay_bench: a bench with a big balance scale and a ledger board.
- ore_cart_stub: a stubby ore cart on a 2 m stub of track. Never longer track.
- water_tank: a round tank on short stilts (2.8 m) with a hose reel.
- bench_sign: a "BENCH 3" sign on a low frame.
- timber_lagging: lagging and props stacked low.
- windsock: a short mast (3 m) with a sock. Tag it tall; keep 30 m from lines.
- rock_bucket: a broken shovel bucket tooth lying in the dirt, with cholla growing.
- core_trays: drill core trays on trestles (cylinders in rows; turquoise streaks only on the rock).
- bursage and cholla clumps (plant).

## sinkhole (world 2, afternoon, underground). Basalt, lava tubes, timber gallery ring. Mining crews and pumps. Lamp racks that face the wrong way. LAMP VETO.
- H pump_engine: bevelled steel pump with piston arms, parked off.
- H lamp_rack: a big lamp rack with unlit lamps, all facing one way. Lenses white and non-emissive.
- H gallery_collapse: a fallen timber set and lagging pile, with a painted water mark.
- echo_horn: a big steel-grey horn on a short stand (no brass).
- tin_cart: a mine cart with pails and a bone tag. No cog read.
- granary_jars: stone jars for the reference trench only. No hearth.
- column_stubs: broken basalt column stubs with pale lichen tops.
- rain_gauge: a short pole with a chunky dial.
- coat_hooks: hooks on a short timber post with a hung coat and a hand lamp (unlit).
- hose_reel: a pump hose coiled on a reel, CABLE grey.
- tally_post: a short numbered stroke-tally post.
- cave_fern and moss mats under skylights (plant).
- drill_steels: a bundle of drill steels leaning in a low A-frame, under 1.5 m.
- mist_rings: smooth stacked rings at the pool edge (non-emissive).

## islands (world 3, golden hour). Sky islands with pines. Animal net crews (ochre rope), a dam-era fire lookout, a mining tram, the Fleet mooring mesa.
- H lookout_hut: a timber cab on short stilts with a round window and a log board. A small sibling of the World-owned lookout; check whether `fire_lookout` is a landmark row and keep clear of it.
- H balloon_basket_wreck: a deflated patched envelope draped over a basket, two stitch styles. Fleet tag only if near the mooring.
- H tram_car_parked: a tram cabin set down on blocks (never hung, never a route).
- net_bundle: coiled ochre nets, floats and mending needles.
- mender_stool: a stool and a knot board.
- chart_post: a pine-stump signpost painted with the roost chart.
- ore_trolley: a single parked bin with no rails.
- stair_stones: numbered marker stones, flat.
- spyglass_tripod: a telescope on a short tripod (1.6 m).
- winch_drum: a mooring winch drum with neat rope, charcoal with a brass tag (Fleet only, near the mooring).
- rope_basket: an unlit lantern basket set on the ground.
- bird_vane: a weather vane (2.4 m) shaped like a bird.
- pine_sapling and manzanita, grass tufts (plant).
- patch_bolt: a fabric bolt and a sewing kit spilled on a rock.

## crown (world 3, dusk, storm). Monument buttes. Net-weavers' hammocks and looms; the Fleet signal crew billing strikes; ancient spires (never touched).
- H loom_frame: a net-weaver loom with chunky bobbins and a half-woven net.
- H billing_booth: a small Fleet shed with an "ELEVEN / TWELVE" tally chalkboard. Fleet colours, clearly a hut; keep it far from camps.
- H storm_station: a weather station with a round anemometer and a "STORM: YES" barometer dial, on a squat base.
- hammock_rig: a low hammock on two short posts (under 1.5 m), ochre.
- knot_board: a mending basket and a knot board.
- spool_shed: a lean-to with a wire spool lying flat, with a Fleet tag.
- fulgurite: fused glass fragments around a short rod (pale glass, never mint or green).
- watch_stool: a tarped stool and a thermos.
- dish_stones: three smooth palm dishes, one steaming (a soft cloud mesh, no glow).
- rope_fence: short ochre rope-fence segments (posts under 1.2 m, 3 m spans, never long).
- storm_lantern: an unlit lantern on a short hook post.
- tally_slab: a chalk tally slab reading "40, 41".
- rabbitbrush and yucca, dusk flowers (plant).
- kite_pennant: a pennant on a low stake. Keep 30 m from lines; it must not read as a kite drone.
