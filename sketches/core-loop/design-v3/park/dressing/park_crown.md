# Crown (`park_crown`) dressing kit

Dressing lane (DRESSING-KITS.md), phase 1: the Blender kit only. Recipe `tools/blender/park/props/crown.py`; GLBs, `manifest.json` and import stubs under `assets/models/park/props/crown/`; registry rows in `assets/registry.d/park_props_crown.json` (the Gate lane folds `registry.json`). No placement yet: phase 2 writes `src/world/park/props/park_crown.json`.

The kit tells two stories. The net-weavers are non-hostile builders, so only their gear appears (ochre rope, nets, hammocks, a loom, mending baskets), never a face or a creature. The Fleet signal crew's gear is iron oxide `#9b513a` and charcoal with one brass tag, and is drawn as abandoned equipment: a hut, a weather post, a flat-lying cable spool and a tally slab, with no barrels and no gun-like masts. The ancient spires are never touched. Props use pale canvas, ochre rope, dusty sage and charcoal so they separate in value and hue from the red-orange sandstone ground, which sits close to HAZARD in hue. Brass is `#d9b44a`, used only on the Fleet tags.

| Kind | Class | LOD0 tris (a/b/c) | Height m | Tags | Story |
| --- | --- | --- | --- | --- | --- |
| `loom_frame` | hero | 11312/9768/8952 | 4.6/4.6/3.6 | machine,soft,tall | Net-weavers' floor loom: chunky bobbins on the bed and a half-woven ochre net in a leaning frame. |
| `billing_booth` | hero | 10880/11060/9752 | 4.1/4.1/4.1 | machine,sign,tall | Fleet signal crew's tally hut: sun-bleached oxide walls patched with timber, a chalkboard counting ELEVEN against TWELVE, abandoned mid-shift. |
| `storm_station` | hero | 16092/16264/8752 | 4.5/4.5/2.9 | machine,sign,tall | Fleet weather post on a squat plinth: cup anemometer, and a big barometer dial whose needle sits on STORM: YES. |
| `hammock_rig` | prop | 2328/2448/2284 | 1.4/1.4/1.4 | soft | Net-weavers' low hammock on two short posts, a blanket still in it; run down, it sags to the dust. |
| `knot_board` | prop | 2940/1752/2032 | 1.7/1.2/1.2 | soft | A mending basket of spare net and a knot board with sample splices, set down mid-lesson. |
| `spool_shed` | prop | 2980/2980/2656 | 3.0/3.0/2.1 | machine | A Fleet cable spool lying flat under a four-post canopy, its brass tag the only mark of owner. |
| `fulgurite` | prop | 1576/1696/1436 | 0.7/0.4/0.3 | - | Where lightning struck sand: pale glass tubes branching half-buried in a scorched sand scar, a bent rod lying by. |
| `watch_stool` | prop | 1500/1188/1380 | 1.5/0.9/1.4 | soft | A lookout's stool with a tarp slung over it and a thermos left on the seat: someone is coming back. |
| `dish_stones` | prop | 2580/2880/2532 | 1.6/0.4/0.7 | - | Three smooth palm dishes where someone sets a morning drink: one still steaming, one cold. |
| `rope_fence` | prop | 2060/1948/1364 | 1.2/1.3/1.3 | - | A short net-weaver rope fence between two stout posts, knotted with cloth tags, marking a mending spot. |
| `storm_lantern` | prop | 1300/1380/1156 | 1.5/1.5/1.0 | - | An unlit storm lantern hung on a short crook post, waiting for the dark to come. |
| `tally_slab` | prop | 2492/2236/2208 | 1.8/0.3/1.0 | sign | A slate tally slab the signal crew scratched with chalk: forty tallied, forty-one just begun. |
| `rabbitbrush` | prop | 2736/1812/2944 | 1.7/1.0/1.6 | plant | Dusk-flowering rabbitbrush, a sage-green clump with dusty yellow plumes; in c it has grown up through a fallen iron wheel. |
| `yucca` | prop | 2644/824/2994 | 2.4/1.6/2.1 | plant | A yucca rosette with a tall cream flower stalk; the dry one is winter-bare, the third grows through a flat gear plate. |
| `kite_pennant` | prop | 2088/2088/1492 | 1.8/1.5/0.6 | - | A crew pennant on a thick stake in a cairn: out in the wind, slack, or on the ground after the gale. |

Variants run a (in use), b (run down), c (collapsed or overgrown). Notes on swaps and reviews:

- `hammock_rig` posts stay under 1.5 m; `spool_shed` is a two-sided gabled canopy with gable boards (a single sloped plane reads as a ramp); `billing_booth`'s "ELEVEN / TWELVE" is chalk tally strokes (eleven and twelve) because the kit cannot carry text; the `storm_station` "STORM: YES" is a needle on the STORM end plus a three-stroke label slab.
- Fleet gear is weathered: the oxide is mixed toward canvas, patched with timber, with a stove-in panel and sagging roof on b and c, and an irregular fieldstone footing under the storm station. Its mast is short (about 4.5 m overall) with a cup anemometer and a wind vane, so it cannot read as a signal mast or turret.
- `fulgurite` is irregular branching pale-glass tubes in a sand scar with a short bent rod beside them: no radial symmetry, no disc, no knobbed stake (those read as a trap or mine).
- `loom_frame` leans back and carries an awning so it does not read as a two-post gate. Plants-through-scrap are `rabbitbrush_c` (iron wheel) and `yucca_c` (gear plate). Crew warmth: hammock blanket, thermos on a stool, mug and laundry at the booth, steaming dish stone.
- Keep `kite_pennant` 30 m from lines.
