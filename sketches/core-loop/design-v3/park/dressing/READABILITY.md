# Dressing lane readability rules (from [palette.gd](../../../src/core/palette.gd), [VISUAL-LANGUAGE.md](../../../VISUAL-LANGUAGE.md), DECISIONS)

> **Status.** These are the wave 18 working rules behind the kit briefs in [KITS.md](KITS.md). The colour rules are enforced by the kit builder's colour guard (`tools/blender/park/props/kit.py`). The placement section is **superseded**: placement follows the coordinator's ruling (b) height tiers as built in the validator (`src/presentation/park_props.gd`, contract [DRESSING-KITS.md](../DRESSING-KITS.md)). It is kept here as written, for the record.

Never on dressing:
- HAZARD #ff5a3c (the one hostile colour, telegraphs, 45 deg stripes). No hazard stripes, no red/orange/amber stripe paint.
- ANCIENT #9dff3c (awakened ancient machines, landmark beacon only).
- MINT #8bf0d3 (scrap, beacon, Sable's field).
- Any emissive. All lamps unlit. Pit and sinkhole: lamp veto (no light pools, no warm OmniLight).
- SAFETY AMBER #e5a044 (Kest, rare rarity), COPPER #b77843 (Rivet), BONE #d2c5a5 as a dominant (HUD text) - accents only, never emissive.
- BRASS #d9b44a only on Fleet-owned props (tags, moorings); Fleet body paint is iron oxide #9b513a + charcoal #242a28 + one brass tag. Non-Fleet props pair rust with timber, canvas or sandstone so they don't read as Fleet enemies.

Safe hues: SAND #d2c5a5 (accent), SANDSTONE #c6a274, VERDIGRIS #365754 (sparingly; ancient enamel is petrol #365754), CABLE #2a3231, weathered timber browns, canvas off-whites, concrete greys, dusty greens for plants.

Shapes to avoid:
- Crates, barrels, boxes with bolt holes, stacked round tins: read as caches / breakables (crates burst cogs). Use pails, kettles, jars, sacks, benches instead. Nothing box-like near cracked_cache sites.
- Irregular four-facet chunks with a bolt hole (scrap pickup).
- Two-post arches with a lintel/keystone (reward gate, drop gates 5 m).
- Ramps, wedges, stairs, loading boards, leaning ladders (kicker / ride route read). Steps are boxes, never wedges.
- Long rails, cables, trolley poles, grind-able edges (grind/grapple lines). Rope coils lie flat.
- Tall thin poles/masts/tripods on ~40 m spacing (harpoon anchor read). Tall props stay off lines.
- Hanging or spinning machines near lines (swing-anchor / hazard read). Everything static.
- Anything creature-like with eyes, legs or a face (enemy read). Ambient critters belong to the Life lane.

Placement (superseded by ruling (b), see Status):
- Off ride lines (route lane half-width 20 m, park_recipes ROUTE_LANE_HALF_M), 15-30 m clear of pilot waymarks, enemy homes, gates, bays, engage rings, landing spots.
- Never inside landmarks or landforms (World lane) or crown/pit greybox rows (Content lane). Around them.
- Reference cultures (ancestral_puebloan, hohokam rows): no living spaces, hearths or homes; minimal and abandoned.
- No colliders on dressing unless proven; no shadows on scatter (GeometryInstance3D.SHADOW_CASTING_SETTING_OFF), heroes may cast.
