# Ambient life

Critters and locals that make each park feel inhabited, with no effect on play. Andrew asked for it on 19 Oct 2026 (DECISIONS section 8, 01:40): parks should read as lived in, with critters and signs of people. The Ambient life lane (wave 17, Wave board #149) owns this page, the record and the code below.

## Rules

1. **Never an enemy, a pickup or a target.** Ambient kinds wear the life band only (hue 250°–300°, saturation 0.15–0.55; VISUAL-LANGUAGE.md section 2). No enemy, Warden or boss model has a saturated colour in 240°–330° (the life band less 10°, plus 30° toward magenta), and `tests/ambient_palette_test.gd` re-measures every enemy, Warden and boss GLB on that window on each run. Kinds carry no emission, no keyline, no stripes, no diamonds or brackets. Silhouettes are small and round (0.14–1.3 m), well under enemy scale.
2. **Never in the way.** A member has no physics body of any kind, so it cannot block the ball, a ride line or a raycast. Homes are planned clear of every ride row (6 m), grapple anchor field (8 m), route line (10 m), enemy home (25 m), the Warden ring (reach plus 10 m), spawn, activities, rescues, contraptions and gate slots (`ambient_homes.gd`; `tests/ambient_homes_test.gd` checks all six parks). At build the runtime also vetoes ground steeper than 30° and any spot with a structure over the ground, such as a gatehouse (`ambient_life.gd` `unfit`; the in-game capture found both). Members cast no shadow.
3. **Never over a warning.** Combat within 30 m makes a member react (scatter up and away, hide or duck). Every ambient sound is muted while a telegraph is live within 40 m of the ball. During a Warden or boss fight every member is hidden.
4. **Momentum is sacred.** Members flee the ball and never run toward it, including a hide run from a threat beyond them. They are drawn only near the ball: at most 24 active per park, the nearest homes first. Ambient life is candy (FEEL-READABILITY.md P7): it goes with the `set_dressing` preset flag.
5. **One record.** `src/core/ambient_kinds.gd` holds each kind's model, loops, palette, sounds, homes and behaviour. The Blender recipes paint from it, `tools/ace/ambient_sfx.py` renders its voices, and the runtime places and drives from it.
6. **Comfort.** Under reduced motion there are no scatter arcs: a reaction is a 0.4 s fade in place, the cap halves to 12 and loops slow to 0.6x. Nothing blinks, and every hide is a fade of at least 0.25 s.

## Kinds

| World | Kind | Role | Look | Behaviour | Sound | Combat |
| --- | --- | --- | --- | --- | --- | --- |
| Spillway | Dusk quail | critter, coveys of 3–5 | round teardrop, curled topknot | scurries in a line on washes and aprons | three-note "chi-ca-go" | runs single file, hides in scrub |
| Spillway | Dam swift | critter, rows of 3–5 | ball with crescent wings | perches on dam rails, mesa rims | thin twitter | the row lifts and circles high, each on its own orbit, then re-perches |
| Spillway | Puddle toad | critter | squat dome, big eyes | sits at canal and pool edges, dozes | low croak | plops in and sinks |
| Spillway | Weir-keeper beaver | local, dam-era keepers, 5 to 6 a park at the empty crew camps and yards (13 Nov) | pear body, flat tail, wide hat | fishes off a bucket, waves, mends nets | two-note whistle | pulls the hat down behind the bucket |
| Dig | Pit burro | critter | barrel body, big ears | grazes the pit benches | bray | trots to the far end of its bench |
| Dig | Tube bat | critter, roosts of 3–6 | furry ball, folded wings, unlit | hangs asleep under tube ceilings and adits, only where a real roof stands 1.5–14 m overhead (none in park_sinkhole yet) | tiny squeaks | unrolls and flutters to a farther roost |
| Dig | Horned lizard | critter | round pancake, soft nubs | basks on warm rock | pebble scratch | puffs up, wedges into a crack |
| Dig | Old prospector badger | local, the miner who never left | round, pick and pan, battered hat | pans the runoff, hums | hummed tune | drops flat, hat over face |
| Highdraft | Bighorn lamb | critter, pairs and trios | woolly cloud body, nub horns | perches on mesa rims, hops ledges | bleat | leaps away along the rim |
| Highdraft | Canyon wren | critter | tiny ball, cocked tail | hops net-deck ropes | falling whistle | flies to the next island |
| Highdraft | Net-weaver ringtail | local | round body, ringed tail (soft plum and lilac rings, never high-contrast stripes) | weaves and mends on net decks | humming, rope creak | curls up in its own tail like a hammock |

The Fleet appears in the Highdraft as signs only (moored kites, an empty crew bench; Dressing-lane props). A live Fleet crew would read as the enemy faction (proposed on #149, building on it until the coordinator rules).

## Code

| File | Job |
| --- | --- |
| `src/core/ambient_kinds.gd` | the record, the life band and the pool constants |
| `src/presentation/ambient_homes.gd` | plans homes per park from the park file, clear of every keepout |
| `src/presentation/ambient_pool.gd` | pure behaviour: activation, cap, idle, wander, sleep, flee, react, hide, return, sound flags |
| `src/presentation/ambient_life.gd` | the view: pooled model instances, loops, audio voices; built by `presentation.gd` with set dressing |
| `tools/blender/ambient/` | Soft-toy recipes, three baked loops each (idle, move, react), 800–6,000 tris, one draw |
| `tools/ace/ambient_sfx.py` | the foley renderer, one recipe per voice |

## Tests

`ambient_pool_test` (cap, flee, react, boss hide, hush, determinism), `ambient_homes_test` (keepouts on all six parks), `ambient_view_test` (no collision, no shadows, no events), `ambient_hook_test` (presentation.gd builds it on the high preset, frees it on low), `ambient_palette_test` (life band, enemy GLBs outside it, distance from the meaning colours), `ambient_assets_test` (tris, loops, height, one material, the mesh audit: no open or over-shared edge, no flipped face, and the loop-seam check on idle, move and the react hold), `ambient_sounds_test` (lengths, peaks, format).

## Dressing lane

Dressing owns the vignettes. A vignette row may carry an optional `"life": "<kind id>"` socket that the Life planner fills with that local (proposed on #149). Until the sockets land, Life plans its own homes and keeps them outside vignette footprints.
