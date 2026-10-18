# CK: small cut stone, bent scrap and dry blades, in metres, Z-up in Blender.
# Procedural bmesh only; no external mesh, texture, collision or runtime placement.
# blender -b --factory-startup -P sketches/core-loop/tools/blender/world_one/clutter_kit.py -- --out /tmp/clutter.glb
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import common
import polish

SEED = 20261002
PLATE_THICKNESS = 0.055


def finish(part, tone=None, tilt=0.0, straw=False):
    bm = part.bm
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    rot = Matrix.Rotation(tilt, 3, "Y")
    for v in bm.verts:
        v.co = rot @ v.co
    bottom = min(v.co.z for v in bm.verts)
    for v in bm.verts:
        v.co.z -= bottom
    bm.normal_update()
    if tone is not None:
        # Shade in linear light: multiplying sRGB first made the stone nearly black.
        # Straw follows the former runtime lift, capped below sand, with darker roots.
        linear = common.to_linear(tone)
        top = max(v.co.z for v in bm.verts)
        for face in bm.faces:
            part.paint([face], "paint")
            gain = 0.72 + 0.23 * max(0.0, face.normal.z) + 0.16 * min(0.0, face.normal.z)
            for loop in face.loops:
                shade = 1.32 * (0.85 + 0.15 * loop.vert.co.z / top) if straw else gain
                loop[part.col] = (*[c * shade for c in linear], 1.0)
    return part.to_object()


def rock(name, size, seed):
    rng = random.Random(seed)
    part = common.Part(name)
    pts = []
    # Unequal, offset lower and upper rings make a cut stone, rather than a round pebble.
    for height, radius, shift in [(0.0, 0.84, 0.0), (0.28, 1.0, 0.0), (1.0, 0.55, 0.18)]:
        for i in range(5):
            angle = i * math.tau / 5 + shift
            r = radius * rng.uniform(0.84, 1.0)
            pts.append((math.cos(angle) * r, math.sin(angle) * r,
                        height if height == 0.0 else height * rng.uniform(0.88, 1.0)))
    vs = [part.bm.verts.new(v) for v in pts]
    bmesh.ops.convex_hull(part.bm, input=vs)
    for axis in range(3):
        low = min(v.co[axis] for v in part.bm.verts)
        span = max(v.co[axis] for v in part.bm.verts) - low
        for v in part.bm.verts:
            v.co[axis] = ((v.co[axis] - low) / span - (0.5 if axis < 2 else 0.0)) * size[axis]
    tone = common.mix("sandstone", "bone", 0.12 if name != "rock_b" else 0.06)
    return finish(part, tone)


def slab(name, size, tilt):
    part = common.Part(name)
    outline = [(-0.50, -0.32), (-0.22, -0.50), (0.33, -0.43), (0.50, -0.12),
               (0.37, 0.37), (0.02, 0.50), (-0.45, 0.30)]
    outline = [(x * size[0], y * size[1]) for x, y in outline]
    part.prism("paint", outline, size[2])
    # Broad strata planes share the map's stone hue; darker than the smaller stones.
    return finish(part, common.mix("sandstone", "bone", 0.08), tilt)


def plate(name, flipped=False):
    part = common.Part(name)
    outline = [(-0.31, -0.19), (0.13, -0.19), (0.31, -0.09),
               (0.24, 0.17), (-0.10, 0.21), (-0.30, 0.08)]
    if flipped:
        outline = [(-x * 0.82, -y * 1.08) for x, y in reversed(outline)]
    # Matching cap triangles preserve a uniform sheet across the fold. Independent ngon
    # triangulations would interpolate the folded top and underside differently.
    lo = [part.bm.verts.new((x, y, -PLATE_THICKNESS / 2)) for x, y in outline]
    hi = [part.bm.verts.new((x, y, PLATE_THICKNESS / 2)) for x, y in outline]
    for i in range(1, len(outline) - 1):
        part.paint([part.bm.faces.new((hi[0], hi[i], hi[i + 1])),
                    part.bm.faces.new((lo[0], lo[i + 1], lo[i]))], "fleet_paint")
    for i in range(len(outline)):
        j = (i + 1) % len(outline)
        part.paint([part.bm.faces.new((lo[i], lo[j], hi[j], hi[i]))], "bare_metal")
    for v in part.bm.verts:
        # A folded lip is continuous with the plate and preserves the extrusion thickness.
        v.co.z += max(0.0, v.co.x - 0.10) * (0.48 if flipped else 0.62)
    return finish(part, tilt=math.radians(-11 if flipped else 9))


def stub():
    part = common.Part("stub_a")
    # Six-sided open pipe with a broad foot flange, narrow shaft and broken rim.
    # The flange stays inside the existing 0.21 m placement footprint; 72 triangles.
    rings = []
    for radius, height in [(0.105, 0.0), (0.105, 0.045), (0.080, 0.090),
                           (0.080, 0.515), (0.050, 0.0), (0.050, 0.515)]:
        rings.append([part.bm.verts.new((radius * math.cos(i * math.tau / 6),
                                       radius * math.sin(i * math.tau / 6),
                                       height + (0.035 if height > 0.5 and i in (1, 2) else 0.0)))
                      for i in range(6)])
    for i in range(6):
        j = (i + 1) % 6
        for a, b, slot in [(0, 1, "bare_metal"), (1, 2, "bare_metal"),
                           (2, 3, "fleet_paint"), (5, 4, "bare_metal"),
                           (3, 5, "bare_metal"), (4, 0, "bare_metal")]:
            face = part.bm.faces.new((rings[a][i], rings[a][j], rings[b][j], rings[b][i]))
            part.paint([face], slot, (0.55, 0.55, 0.55) if (a, b) == (5, 4) else None)
    return finish(part)


def tuft(name, height, blades, seed):
    rng = random.Random(seed)
    part = common.Part(name)
    for i in range(blades):
        angle = i * math.pi / blades + rng.uniform(-0.12, 0.12)
        rot = Matrix.Rotation(angle, 3, "Z")
        # Closed tapered blades have a broad face, a narrow side and an actual base.
        h = height if i == 0 else height * rng.uniform(0.78, 0.94)
        coords = [(-0.055, -0.006, 0), (0.055, -0.006, 0),
                  (0.055, 0.006, 0), (-0.055, 0.006, 0),
                  (rng.uniform(-0.07, 0.07), 0.024, h)]
        vs = [part.bm.verts.new(rot @ Vector(v)) for v in coords]
        for f in [(3, 2, 1, 0), (0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4)]:
            part.paint([part.bm.faces.new([vs[k] for k in f])], "paint")
    return finish(part, common.srgb("sandstone"), straw=True)


def main():
    common.reset()
    # Polish (POLISH.md): clutter_kit_asset_test pins per-piece triangle caps of 24 to 72, so smooth shading and the
    # AO/wear bake only (detail 1, bevel 0). The recipe writes its own GLB, so each piece is baked on its own.
    # edge=0: the wear bake would lighten tuft tips past the sand-brightness cap (clutter_kit_asset_test CK-3, KC-1).
    # sharp_angle=5: plates stay flat-shaded so their caps keep exact opposite normals (CK-4 physical thickness).
    polish.enable(detail=1, bevel=0, edge=0, sharp_angle=5)
    # The shared bare-metal preview is polished bone; this dry clutter uses dull exposed steel.
    metal = common.material("bare_metal").node_tree.nodes.get("Principled BSDF")
    metal.inputs["Base Color"].default_value = common.rgba(common.mix("charcoal", "bone", 0.36))
    metal.inputs["Roughness"].default_value = 0.82
    objects = [rock("rock_a", (0.48, 0.32, 0.26), SEED),
               rock("rock_b", (0.30, 0.13, 0.43), SEED + 1),
               rock("rock_c", (0.58, 0.20, 0.21), SEED + 2),
               slab("slab_a", (1.05, 0.65, 0.105), 0.0),
               slab("slab_b", (0.82, 0.48, 0.13), math.radians(27)),
               plate("plate_a"), plate("plate_b", True), stub(),
               tuft("tuft_a", 0.32, 3, SEED + 3), tuft("tuft_b", 0.38, 4, SEED + 4)]
    bpy.context.view_layer.update()
    for obj in objects:
        polish.bake(obj)
        print("CK_GEOMETRY", obj.name, "triangles", common.tris(obj),
              "size", tuple(round(v, 6) for v in obj.dimensions),
              "bottom", round(min(v.co.z for v in obj.data.vertices), 6))
        obj.select_set(True)
    out = common.args()["out"] or os.path.join(common.MODELS, "world_one", "clutter_kit.glb")
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    # Ten independent scene nodes; no extra authored root or layout transform.
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True, export_materials="EXPORT",
                              export_vertex_color="ACTIVE", export_extras=False,
                              export_animations=False, export_cameras=False, export_lights=False)
    common.canonical_indices(out, vertices=True)
    print("EXPORTED", out)


if __name__ == "__main__":
    main()
