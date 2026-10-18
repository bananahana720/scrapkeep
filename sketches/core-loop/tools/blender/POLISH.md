# Model polish

`polish.py` turns a recipe's primitive stack into a model that reads as one object: soft
bevels, denser curves, smooth shading with hard creases, optional Catmull-Clark
subdivision, and baked ambient occlusion and edge wear. Andrew asked for it on 18 Oct:
"bake the models", make them denser and less "geometric blobbish with spheres tacked
on", as long as frames hold.

## Opting a recipe in

Call `polish.enable()` after `import common` and before the first `Part`:

```python
import common
import polish
from common import Part

polish.enable(detail=2, bevel=0.03)
```

`common.Part.to_object` then bevels and smooths each part before it triangulates, and
subdivides it when asked. `common.export` bakes AO and wear over the whole tree before it
writes the GLB. A recipe that never calls `enable()` builds byte for byte as before. Recipes that write
their own GLB with `bpy.ops.export_scene.gltf` instead of `common.export` (the pilots,
bosses, Wardens, `kill_first_rig.py` and the animation scripts) get the bevels and
subdivision but no bake and no vertex sort: call `polish.bake(root, polish.options())`
and `common.canonical_indices(path, vertices=True)` around their export, or their
rebuilds will not stay byte-identical.

Per part, set `part.bevel` (metres, `0` for none) or `part.subsurf` (levels) before
`to_object()`. Organic shapes such as crew bodies and heads look best with `bevel = 0`
and `subsurf = 2`; hard machinery with the default bevel and `subsurf = 0` or `1`; thin
sails, nets and decals with `bevel = 0` and `subsurf = 0`.

### Regions: different polish for pieces of one part

A part is one draw, so a crew head often shares a part with hard machinery. Wrap the
primitives that need their own settings in `part.region(...)`:

```python
with body.region(bevel=0, subsurf=2, detail=1):   # head and muzzle: soft
    body.uv("fleet_paint", 0.38, u=8, v=6, loc=head)
with body.region(bevel=0.01):                       # a 4 cm stay: narrow bevel
    body.rod("fleet_paint", a, b, 0.04)
```

`bevel`, `subsurf`, `detail` and `fit` default to the part's. Faces built inside the
block are cut out, finished alone and joined back before triangulation, so wrap whole
primitives: a region that shares vertices with the rest of the part opens a seam.
Subdivided regions usually want `detail=1`, since each level already multiplies
triangles by four. Without polish, `region()` does nothing.

`fit=True` (an `enable()` option, or per region) scales each connected piece back to its
unpolished bounding box after bevel and subdivision, so measured envelopes (a core's
0.8 m radius, an ear tip's height, a bulb's 0.6 m face) hold exactly. Leave it off for a
lopsided piece, such as the kite drone's keeled hull, where a per-axis stretch pushes
diagonals past the envelope.

The world 2 and 3 enemies use it for the shared crew critter (`world_two/fleet_crew.py`):
head and muzzle `subsurf=2`, ears and paws `subsurf=1`, eyes and nose smooth with no
subdivision, all `detail=1`.

Subdivision carries loop colours, UVs, deform weights, materials and shading flags, and
the mesh's integer and float vertex layers: an integer tag (`pilot_bone`, `tally_bone`,
`rig_part`) goes to whatever most of a new vertex's source vertices carry, the lowest on
a tie, and floats average. Concave ngons are ear-clipped before subdividing. Shape keys
do not survive a bmesh rebuild; recipes with morphs subdivide only their unmorphed parts.

| Option | Default | Effect |
| --- | --- | --- |
| `detail` | 2 | Segment multiplier for `cyl`, `rod`, `uv` and `ring`; `ico` gains a subdivision |
| `bevel` | 0.03 | Bevel width in metres on edges sharper than `bevel_angle` (30°) |
| `bevel_segments` | 1 | One chamfer; smooth shading rounds it |
| `sharp_angle` | 50° | Edges sharper than this stay hard after the bevel |
| `subsurf` | 0 | Catmull-Clark levels; about 4x triangles per level |
| `crease_angle` | 70° | On subdivided parts, edges sharper than this stay creased |
| `fit` | off | Scale each piece back to its unpolished bounding box (see Regions) |
| `ao`, `ao_rays`, `ao_reach`, `ao_strength` | on, 24, 0.18, 0.55 | Ambient occlusion bake |
| `edge` | 0.18 | Convex edges lighten and creases darken by up to this much |
| `bake_slots` | the `vc` slots | Slots whose vertex colours take the bake |

## What the bake writes

- Vertex colours of faces in `bake_slots` (by default `paint`, `pilot`,
  `ancient_enamel`, `hydraulic`) are multiplied by the AO and wear. These slots already
  show vertex colour in game, so the bake is visible with no runtime change.
- Every baked mesh gets a second UV map, `Bake` (glTF `TEXCOORD_1`, Godot `UV2`):
  `x` is the unoccluded fraction (1 is open, 0 is covered) and `y` is wear (0.5 neutral,
  higher on convex edges). Materials of any slot can opt in, for example
  `ALBEDO *= mix(1.0, UV2.x, 0.55)`. A mesh with no UV map gets an all-zero first map
  ahead of `Bake`, since every runtime material maps by triplanar projection; one with
  a UV map keeps it, and one that already has two keeps both and gets no `Bake` map.

## Rebuilds stay byte-identical

Blender's corner normals, polygon normals and subdivision differ in the last bits
between runs. The pass computes its own normals in Python doubles, subdivides in Python
(`polish.subdivide`), rounds AO before quantising to 1/1024, and `common.export` sorts
each primitive's vertices when polish is on. Polished quads split on their shorter
diagonal (ties through the lowest corner), since a face's first loop, and with it
Blender's fixed diagonal, can differ between runs. `check_polish.py` builds a recipe twice
under polish and fails on any byte difference.

```sh
blender -b --factory-startup -P sketches/core-loop/tools/blender/check_polish.py -- \
  world_three/enemy_kite_drone.py subsurf=1
```

## Budgets

Polish raises triangle and vertex counts, not draw counts: it adds no surfaces. The class
caps in `assets/asset_budgets.json` are already raised for it, so a family pass changes
only its recipes' own asserts. The caps hold until one 4080 frame check on the densest
fight confirms them.

| Class | Triangles then | Triangles now | Vertices now |
| --- | --- | --- | --- |
| enemy | 1,100 | 10,000 | 19,100 |
| pilot | 4,600 | 12,000 | 8,100 |
| warden_kit | 1,500 | 6,000 | 11,200 |
| warden_base | 5,000 | 20,000 | 38,400 |
| prop | 270 | 2,000 | 4,600 |
| landmark | 900 | 4,000 | 8,900 |
| detail | 1,500 | 4,000 | 8,000 |
| clutter | 280 | 1,200 | 2,800 |
| gate | 2,700 | 6,000 | 11,800 |
| chunk | 2,900 | 6,000 | 17,600 |

Vertices keep each class's old ratio to triangles. Shell, hero_landmark, park_large,
landform and scenery caps are unchanged.

## Before and after

`polish_compare.py` builds a recipe with polish off and on and writes one JPEG, today's
model on top and the polished one below, for the family's phone page:

```sh
blender -b --factory-startup -P sketches/core-loop/tools/blender/polish_compare.py -- \
  world_one/enemy_reactor.py /tmp/reactor.jpg
```

## Keep

Polish changes surfaces only. Keep node names, mesh names, material slot names, bone
names, rigid weights, origins and collider envelopes. A recipe's envelope asserts
(radius, half extents, heights) must still pass, and can move both ways: bevels and
subdivision pull corners inward, but `detail` adds segments to curved primitives, so
their faces sit closer to the true circle and the mesh grows slightly outward.
