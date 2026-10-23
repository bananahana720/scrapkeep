# Mojulo prop and critter trial, 23 Oct 2026

A bounded trial for the coordinator brief "try Mojulo for objects and beings". Maps and hero blockout were settled on 22 Oct (BLK-01, `scrapkeep-blockout`). This trial asks one thing: does Mojulo beat the Blender kits for dressing props and ambient life? Nothing here touches `sketches/` or the Blender pipeline. Mojulo is `mojulo@3.0.0` through its CLI, and Blender is 5.2.3 headless. The CPU runs used `nice -n 10`.

## Targets

1. **The prop:** `gate_wheelhouse` from the dam dressing kit (`tools/blender/park/props/dam.py`, a `dress_hero`, variants a and b). It was ported line for line to a Mojulo `code` recipe (`wheelhouse.js`), so the geometry plan is identical and only the tool differs.
2. **The critter:** the Spillway puddle toad (`tools/blender/ambient/puddle_toad.py`, rest pose, palette and budget from `ambient_kinds.gd`), ported to `toad.js`.

## Pipeline

`mkmint.py` builds the mint args, then `mint_solid` and `export_model {lit: true}` run, then `adopt.py` turns the Mojulo glb into a kit-contract glb with the kit's own code (`kit.Kit.write`, `kit.Kit.decimate` and `polish.bake`). The kit contract is one surface, linear COLOR_0, the `paint` slot, AO and wear, and LOD0, LOD1 and LOD2. `adopt.py still` renders with `kit.render`'s camera, so the stills match.

## Results

| Measure | Blender kit | Mojulo + adopt |
|---|---|---|
| Wheelhouse a, LOD0/1/2 tris | 16,880 / 8,440 / 2,532 | 17,092 / 8,546 / 2,564 |
| Wheelhouse b, LOD0/1/2 tris | 17,864 / 8,932 / 2,680 | 15,974 / 7,986 / 2,396 |
| Wheelhouse a, glb bytes and vertices | 652,532, 11,453 | 726,764 after welding (1,946,976 and 38,382 before) |
| Build time, both variants with bake and LODs | 3.9 s | 2 × (1.7 s mint + 1.6 s export + 4 s adopt) ≈ 15 s |
| Godot runtime import, LOD0 | 5.3 ms | 6.1 ms, one surface, colours present, floor at 0 |
| Determinism | geometry is code; a rebuild on Blender 5.2.3 differs from the committed glb (see below) | Mojulo geometry hash identical across two mints (`geomhash.py`); adopt output byte-identical across runs |
| Toad tris (band 900 to 4,000) | 3,928 | 3,900, collapsed from a 39,014-triangle field |

## Findings

- **The prop look matches.** Exact rounded boxes (`box.round` inside an `exact: true` field) give crisp planks with rounded bevels, which is the Soft toy rule for machines. The sampled tarp comes out smooth. The stills of the two pipelines are hard to tell apart.
- **Bevels cost more than in Blender.** An exact rounded box uses at least 8 facet segments, so full bevels on every plank cost 29,202 triangles, against the 20,000 hero cap. To fit, the roof planks lost their bevel (`params-r1.json` against `params-r2.json`, still `moj-a-fullbevel.jpg`). Blender's one-segment bevel is cheaper.
- **Mojulo glbs need welding.** Every triangle carries its own corners, so vertices run 3× the kit's. `adopt.py --weld` merges them and keeps edges over 40 degrees sharp.
- **COLOR_0 was already linear.** In this exact-field lit export, `timber_dark #5d4630` arrives as `0.109, 0.061, 0.030`. That contradicts BLK-12 (decode gamma 2.2) for this export path, so check before decoding.
- **Watch the ground plate and LOD floors.** Mojulo adds a `static` ground plate mesh, so drop it. Decimated LODs floated 3 to 5 cm, because the collapse left loose vertices under the floor and the kit's re-seat read them. `adopt.py` removes loose vertices and checks the kit's `FLOOR_TOL`.
- **Critters blend better but have no rig.** Smooth unions melt the dome, eye bumps and thighs into one plush body, with none of Blender's stacked-ball look (principle 12). The surface net is uniform, though. At the lowest `cells` the toad was still 10.7k triangles and visibly lumpy. It only reads clean when sampled finely (72 cells, 39k triangles) and collapsed to the 3,900 budget in Blender. Mojulo has no bones, weights or clips, while the kit's critters rig by part in `_life.py`. A blended single mesh would need weight painting to move.
- **Iteration speed is a wash for code-authored assets.** Both are scripts that Claude edits. Mojulo's extra is the studio view and `update_sketch` dials for Andrew to watch. It adds no speed headless.
- **Aside, outside the trial:** rebuilding `dam.py` on Blender 5.2.3 gives a `gate_wheelhouse_a.glb` whose sha256 differs from the committed one (`38eda46a…` against `8f611111…`). Two 5.2.3 rebuilds agree with each other, so the change likely comes from the Blender version or host behind the 19 Oct commit. A rebuild of the kit now would touch every GLB.

## Recommendation

- **Props:** not yet as a replacement. It matches the kit but beats it on nothing, and it costs more triangles for bevels and a weld step. Use it only when a prop needs true booleans (bores, cut slots) or smooth blended forms, through `adopt.py`.
- **Beings:** adopt Mojulo for body sculpting of round critters and blobby enemies. Sample finely, then collapse to budget in Blender. Rigging and clips stay in Blender, and the blended mesh needs weight painting, which is the open cost.
- **Maps and heroes:** unchanged (BLK-01).
