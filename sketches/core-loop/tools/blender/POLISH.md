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

`bevel`, `subsurf` and `detail` default to the part's; `fit` defaults to the `enable()` setting. Faces built inside the
block are cut out, finished alone and joined back before triangulation, so wrap whole
primitives: a region that shares vertices with the rest of the part opens a seam.
Subdivided regions usually want `detail=1`, since each level already multiplies
triangles by four. Without polish, `region()` does nothing.

`fit=True` (an `enable()` option, or per region) scales each connected piece, after bevel
and subdivision, back to its bounding box from before them, so measured envelopes (a core's
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
| `bevel_min` | 0 | Edges shorter than this (metres) are not bevelled, so bolts stay cheap |
| `sharp_angle` | 50° | Edges sharper than this stay hard after the bevel |
| `subsurf` | 0 | Catmull-Clark levels; about 4x triangles per level |
| `crease_angle` | 70° | On subdivided parts, edges sharper than this stay creased |
| `fit` | off | Scale each piece back to its unpolished bounding box (see Regions) |
| `ao`, `ao_rays`, `ao_reach`, `ao_strength` | on, 24, 0.18, 0.55 | Ambient occlusion bake |
| `edge` | 0.18 | Convex edges lighten and creases darken by up to this much |
| `bake_slots` | the `vc` slots | Slots whose vertex colours take the bake |
| `bake_keep` | none | Linear colours the bake leaves exact, such as a shader's state key |

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

Landmarks (`park/landmarks.py`) write their own meshes and never use `Part`, so they opt in through an adapter in that file: it
welds each convex piece of a `sky.Surf`, bevels it to a quarter of its own thickness (at most 0.06 m, only edges sharper than 40 degrees and longer than 0.45 m), smooths it and bakes AO and wear over
the base and detail shells before any `-col` mesh joins the scene. Mid and far views and every collider stay as they were.

Vertices keep each class's old ratio to triangles. Shell, hero_landmark, park_large and
landform caps are unchanged. Scenery rose from 120 / 110 / 2 to 1,500 / 3,000 / 2 for the
polished Highdraft cloud, mesa and thermal air (PR #143; largest member sky_cloud 896 T,
sky_mesa 566 V); the recipes and their tests hold those three at 1,000 / 1,000 and 800 / 500.

## Watertight

Every piece of a model should be a closed island: each edge is shared by exactly two
triangles. An open piece lets the AO bake see through it, so its inside reads lighter than it
should, and with `cull_back` shadows its open end lets a line of light through. Pieces may
overlap (`common.Part` allows it); they must not share faces, since a strip welded onto a body
makes edges with three or more triangles.

`check_manifold.py` reads a GLB with no Blender, welds each mesh by position and lists, per
mesh, its islands, open islands by size, open edges and non-manifold edges:

```sh
python3 sketches/core-loop/tools/blender/check_manifold.py \
  sketches/core-loop/assets/models/world_one/shell_rivet.glb
```

It exits 0 in report mode. `--strict` exits 1 when a file has more than `--max-open` open
edges or more than `--max-nonmanifold` non-manifold edges (both 0 by default); `--mesh Core`
checks one mesh.

`shell_base.py` builds the shared Hoberman base closed, at no more triangles than the open
pieces it replaced:

| Piece | Was (open) | Now (closed) |
| --- | --- | --- |
| Strut bar (`_bar`) | four-sided tube, open ends, 8 tris | three-sided prism with end caps, 8 tris; the outer bar's flat face points out, the inner bar's in, so the pair still runs 0.94 to 0.975 m |
| Pin, collar stud, chalk mark (`_stud`) | 6-sided `_disc`, one face, 4 tris | triangle head closed to a point buried in the part under it, 4 tris |
| Hub tread cap (`_tread_cap`) | `_drum` with no bottom, 3 × sides − 2 tris | same face, sides closed to a point inside the copper hub drum, 2 × sides − 2 tris |

The tread caps save 192 triangles on a 6-sided shell and 256 on an 8-sided one, and the
lattice's outer reach (0.9837 m) does not move. Recipe parts outside `shell_base.py` (Rivet's
drill and pods, Kest's vanes, Tally's drum faces, Tarn's and the Cannon's welded strips) are
still open or non-manifold until their own units close them. `_disc` stays for recipe marks
that sit flush on a face. The six shells' triangle and draw budgets are held by
`tests/hero_six_pilot_budget_test.gd`.

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

Colour tests still apply to baked colours: `tests/hero_assets_test.gd` caps `ancient_enamel`
value and saturation at 0.45, and the default AO pushed dark corners to 0.473. Recipes
with that slot use `edge=0, ao_strength=0.35`.
