"""The three pilot outfits and SPIL-9's Till Bell (design-v3/COSMETICS-ART-BRIEFS.md).

blender -b --python-exit-code 1 -P build_outfits.py -- [ITEM ...]     (no ITEM builds all four)

Each item is modelled in its rig's pilot space against the shipped GLB's rest vertices, then
moved into the frame of the bone it rides, so `hero_assets.fit_outfit` / `fit_companion_skin`
mount it with no offset: one top-level node per bone, named for the bone. Looks only: no
light, no emission, shared slot names. Each mesh is one surface, for the detail class's one
draw: pilot-worn pieces are the `pilot` slot with copper baked in vertex colour (pins and
rims too small for the metal to read), and the Till Bell is all `copper`. The
Welding Hood carries `ult_windup` (snaps down 70 degrees in 0.12 s, then holds) and
`ult_recover` (lifts back). Authored from primitives; no external meshes or textures.
"""
import math
import os
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
SKETCH = HERE.parents[2]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent))
import common
import rig_space

common.SLOTS.setdefault("copper", {"color": "copper", "metal": 0.6, "rough": 0.4})

BONE_SCUFF = common.mix("bone", "sandstone", .3)
SMOKED_GLASS = common.mix("charcoal", "petrol", .30)
MULBERRY = "7a3b5c"
MULBERRY_DARK = common.mix("7a3b5c", "charcoal", .35)
STEADY_PETROL = common.mix("petrol", "bone", .12)
REDJAW = "9b513a"


def lathe(part, slot, profile, segs, loc=(0, 0, 0), color=None):
    """Revolves (radius, z) points about local Z; a zero radius closes that end."""
    c = Vector(loc)
    rows = []
    for r, z in profile:
        if r < 1e-6:
            rows.append([part.bm.verts.new(c + Vector((0, 0, z)))])
        else:
            rows.append([part.bm.verts.new(c + Vector((r * math.cos(k * math.tau / segs), r * math.sin(k * math.tau / segs), z)))
                         for k in range(segs)])
    faces = []
    for a, b in zip(rows, rows[1:]):
        for k in range(segs):
            k2 = (k + 1) % segs
            if len(a) == 1:
                faces.append(part.bm.faces.new((a[0], b[k], b[k2])))
            elif len(b) == 1:
                faces.append(part.bm.faces.new((a[k], b[0], a[k2])))
            else:
                faces.append(part.bm.faces.new((a[k], b[k], b[k2], a[k2])))
    if len(rows[0]) > 1:
        faces.append(part.bm.faces.new(list(reversed(rows[0]))))
    if len(rows[-1]) > 1:
        faces.append(part.bm.faces.new(rows[-1]))
    for f in faces:
        f.smooth = True
    return part.paint(faces, slot, color)


def sheet(part, slot, grid, thickness, color=None, shade=None):
    """A curved plate from a grid of outer-surface points [row][col] with outward normals
    estimated per point; shade(row, col) may recolour single front faces."""
    rows, cols = len(grid), len(grid[0])
    centre = sum((p for row in grid for p in row), Vector()) / (rows * cols)
    outer = [[part.bm.verts.new(p) for p in row] for row in grid]
    inner = [[part.bm.verts.new(p - (p - centre).normalized() * thickness) for p in row] for row in grid]
    front, back, edge = [], [], []
    for i in range(rows - 1):
        for j in range(cols - 1):
            f = part.bm.faces.new((outer[i][j], outer[i][j + 1], outer[i + 1][j + 1], outer[i + 1][j]))
            front.append((i, j, f))
            back.append(part.bm.faces.new((inner[i][j], inner[i + 1][j], inner[i + 1][j + 1], inner[i][j + 1])))
    ring = [(0, j) for j in range(cols)] + [(i, cols - 1) for i in range(1, rows)] + \
           [(rows - 1, j) for j in range(cols - 2, -1, -1)] + [(i, 0) for i in range(rows - 2, 0, -1)]
    for (i, j), (k, l) in zip(ring, ring[1:] + ring[:1]):
        edge.append(part.bm.faces.new((outer[i][j], inner[i][j], inner[k][l], outer[k][l])))
    part.paint([f for _, _, f in front] + back + edge, slot, color)
    for _, _, f in front:
        f.smooth = True
    for f in back:
        f.smooth = True
    if shade:
        for i, j, f in front:
            c = shade(i, j)
            if c:
                part.paint([f], slot, c)
    bmesh.ops.recalc_face_normals(part.bm, faces=[f for _, _, f in front] + back + edge)
    return front


class Outfit:
    """One exported GLB whose scene roots are <bone> nodes at identity, so Godot's imported
    root holds them as direct children; parts sit in that bone's rest frame."""

    def __init__(self, item, rig):
        self.item = item
        self.rig = SKETCH / rig
        self.frames = rig_space.joint_frames(self.rig)
        self.verts = rig_space.bone_vertices(self.rig)
        self.holders = {}
        self.parts = []

    def holder(self, bone, under=None):
        key = (bone, under)
        if key not in self.holders:
            if bone not in self.holders:
                self.holders[bone] = common.empty(bone)
            self.holders[key] = self.holders[bone] if under is None else common.empty(under, parent=self.holders[bone])
        return self.holders[key]

    def add(self, bone, part, pivot=(0, 0, 0), under=None):
        frame = self.frames[bone]
        inv = frame.inverted()
        bmesh.ops.transform(part.bm, matrix=inv, verts=part.bm.verts)
        obj = part.to_object(origin=inv @ Vector(pivot), parent=self.holder(bone, under))
        self.parts.append(obj)
        return obj

    def export(self, animated=False):
        path = SKETCH / ITEMS[self.item]["out"]
        bpy.context.view_layer.update()
        bpy.ops.object.select_all(action="DESELECT")
        for key, holder in self.holders.items():
            if isinstance(key, str):
                for o in common.tree(holder):
                    o.select_set(True)
        os.makedirs(path.parent, exist_ok=True)
        extra = dict(export_animation_mode="ACTIONS", export_anim_slide_to_zero=True, export_frame_range=False,
                     export_force_sampling=True) if animated else {}
        bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_apply=True,
                                  export_yup=True, export_materials="EXPORT", export_vertex_color="ACTIVE",
                                  export_extras=False, export_animations=animated, export_cameras=False,
                                  export_lights=False, **extra)
        common.canonical_indices(str(path))
        tris = sum(common.tris(o) for o in self.parts)
        surfaces = sum(len(o.data.materials) for o in self.parts)
        budget = ITEMS[self.item]["tris"]
        assert tris <= 1500, (self.item, tris)
        print("OUTFIT %s %d triangles (start %d), %d surfaces, nodes %s -> %s" % (
            self.item, tris, budget, surfaces, sorted({o.parent.name for o in self.parts}), path))
        return tris


HOOD_HINGE_UP = math.radians(70)


def rivet_hood():
    o = Outfit("outfit_rivet_hood", ITEMS["outfit_rivet_hood"]["rig"])
    face = o.verts["goggles"] + o.verts["head"]
    rx = max(abs(v.x) for v in face) + .03
    ry = max(v.y for v in o.verts["goggles"]) + .045
    cy, zc, rz = .0, .255, .21
    cols, span = 11, math.radians(78)
    elevations = [math.radians(e) for e in (-26, -9, 9, 26, 43, 60)]
    grid = [[Vector((rx * math.cos(e) * math.sin(a), cy + ry * math.cos(e) * math.cos(a), zc + rz * math.sin(e)))
             for a in (-span + 2 * span * j / (cols - 1) for j in range(cols))] for e in elevations]
    hood = common.Part("HoodShell")
    scuffs = {(0, 2), (3, 8), (4, 3)}

    def shade(i, j):
        if i == 1 and 2 <= j <= 8:
            return SMOKED_GLASS
        return BONE_SCUFF if (i, j) in scuffs else None

    sheet(hood, "pilot", grid, .014, "bone", shade)
    hinge_x, hinge_y, hinge_z = rx * math.sin(span), cy + ry * math.cos(span), zc
    for s in (-1, 1):
        hood.cyl("pilot", .028, .028, .022, 10, color="copper", loc=(s * (hinge_x + .008), hinge_y, hinge_z), rot=(0, math.pi / 2, 0))
    obj = o.add("head", hood, pivot=(0, hinge_y, hinge_z))
    obj.rotation_mode = "XYZ"
    obj.rotation_euler = (HOOD_HINGE_UP, 0, 0)
    scene = bpy.context.scene
    scene.render.fps = 30
    clips = rig_space.clip_lengths(o.rig, ("ult_windup", "ult_recover"))
    for clip, keys in (("ult_windup", ((0, HOOD_HINGE_UP), (.12, 0), (clips["ult_windup"], 0))),
                       ("ult_recover", ((0, 0), (min(.25, clips["ult_recover"]), HOOD_HINGE_UP), (clips["ult_recover"], HOOD_HINGE_UP)))):
        if obj.animation_data:
            obj.animation_data.action = None
        for t, angle in keys:
            obj.rotation_euler = (angle, 0, 0)
            obj.keyframe_insert(data_path="rotation_euler", frame=1 + t * 30)
        action = obj.animation_data.action
        action.name, action.use_fake_user = clip, True
        track = obj.animation_data.nla_tracks.new()
        track.name = clip
        track.strips.new(clip, 1, action)
        track.mute = True
    obj.animation_data.action = None
    obj.rotation_euler = (HOOD_HINGE_UP, 0, 0)
    return o.export(animated=True)


def hood_pose(angle):
    def pose(objects):
        for ob in objects:
            if ob.name.startswith("HoodShell"):
                ob.animation_data_clear()
                ob.rotation_mode = "XYZ"
                ob.rotation_euler = (angle, 0, 0)
    return pose


def ring_band(part, slot, centre, rx, ry, z0, z1, segs, color, y_shift=0.0, thick=.008):
    """An elliptical band round local Z with real thickness."""
    c = Vector(centre)
    def loop(scale, z):
        return [part.bm.verts.new(c + Vector((rx * scale * math.cos(k * math.tau / segs),
                                              y_shift + ry * scale * math.sin(k * math.tau / segs), z))) for k in range(segs)]
    so = 1.0
    si = 1 - thick / min(rx, ry)
    lo_o, hi_o, hi_i, lo_i = loop(so, z0), loop(so, z1), loop(si, z1), loop(si, z0)
    faces = []
    for a, b in ((lo_o, hi_o), (hi_o, hi_i), (hi_i, lo_i), (lo_i, lo_o)):
        for k in range(segs):
            k2 = (k + 1) % segs
            faces.append(part.bm.faces.new((a[k], a[k2], b[k2], b[k])))
    return part.paint(faces, slot, color)


def tally_eyeshade():
    o = Outfit("outfit_tally_eyeshade", ITEMS["outfit_tally_eyeshade"]["rig"])
    head = o.verts["head"]
    z0, z1 = .262, .300
    band_pts = [v for v in head if z0 - .01 <= v.z <= z1 + .01]
    rx = max(abs(v.x) for v in band_pts) + .012
    front, back = max(v.y for v in band_pts), min(v.y for v in band_pts)
    cy, ry = (front + back) / 2, (front - back) / 2 + .012
    visor = common.Part("Eyeshade")
    ring_band(visor, "pilot", (0, 0, 0), rx, ry, z0, z1, 16, MULBERRY_DARK, y_shift=cy)
    cols, span, reach, dip = 9, math.radians(68), .095, math.radians(22)
    grid = []
    for i, d in enumerate((0, reach * .55, reach)):
        row = []
        for j in range(cols):
            a = math.pi / 2 - span + 2 * span * j / (cols - 1)
            ex, ey = rx * math.cos(a), cy + ry * math.sin(a)
            n = Vector((math.cos(a) * ry, math.sin(a) * rx, 0)).normalized()
            row.append(Vector((ex, ey, z1)) + n * d * math.cos(dip) - Vector((0, 0, d * math.sin(dip))))
        grid.append(row)
    sheet(visor, "pilot", grid, .008, MULBERRY)
    rim = grid[-1]
    for a, b in zip(rim, rim[1:]):
        visor.rod("pilot", a, b, .0055, 5, color="copper")
    o.add("head", visor, pivot=o.frames["head"].translation)
    t = .2
    for side in ("R", "L"):
        bone = "upper_arm." + side
        a = o.frames[bone].translation
        axis = (o.frames["lower_arm." + side].translation - a).normalized()
        loop = [v for v in o.verts[bone] if abs((v - a).dot(axis) - t) < .015]
        centre = sum(loop, Vector()) / len(loop)
        flat = sorted(((v - centre) - axis * (v - centre).dot(axis)).length for v in loop)
        radius = flat[int(len(flat) * .8)] + .006
        garter = common.Part("Garter." + side)
        ring_band(garter, "pilot", (0, 0, 0), radius, radius, -.011, .011, 10, MULBERRY, thick=.006)
        rot = Vector((0, 0, 1)).rotation_difference(axis).to_matrix().to_4x4()
        bmesh.ops.transform(garter.bm, matrix=Matrix.Translation(centre) @ rot, verts=garter.bm.verts)
        o.add(bone, garter, pivot=centre)
    return o.export()


def tarn_steady_cap():
    o = Outfit("outfit_tarn_steady_cap", ITEMS["outfit_tarn_steady_cap"]["rig"])
    cap = common.Part("SteadyCap")
    crown = cap.uv("pilot", 1, 16, 7, loc=(0, -.005, .402), scale=(.142, .126, .045), color=STEADY_PETROL)
    for f in crown:
        f.smooth = True
        c = f.calc_center_median()
        if abs(c.x) < .026 and c.z > .405:
            cap.paint([f], "pilot", REDJAW)
    brim = [(.108 * math.cos(a), .100 + .052 * math.sin(a)) for a in [math.pi * k / 8 for k in range(9)]]
    cap.prism("pilot", brim, .008, matrix=common.mtx((0, 0, .401), (math.radians(-8), 0, 0)), color=STEADY_PETROL)
    cap.uv("pilot", .016, 8, 4, loc=(0, -.005, .447), scale=(1, 1, .6), color=REDJAW)
    o.add("head", cap, pivot=(0, -.005, .403), under="Replace_Cap")
    return o.export()


def till_bell():
    o = Outfit("companion_skin_till_bell", ITEMS["companion_skin_till_bell"]["rig"])
    deck = o.verts["Deck"]
    top = max(v.z for v in deck)
    x, y = .07, -.20
    sockets = o.verts["Socket.01"] + o.verts["Socket.02"]
    assert all(abs(v.y - y) > .09 or abs(v.x - x) > .09 for v in sockets), "bell overlaps a socket collar"
    assert min(v.y for v in deck) < y - .07 and max(abs(v.x) for v in deck) > abs(x) + .07, "bell off the deck"
    bell = common.Part("TillBell")
    lathe(bell, "copper", [(0, 0), (.062, 0), (.066, .006), (.062, .014), (0, .014)], 14, loc=(x, y, top))
    lathe(bell, "copper", [(.011, .014), (.011, .034)], 8, loc=(x, y, top))
    dome = [(.064, .034), (.066, .040), (.060, .062), (.046, .080), (.026, .092), (0, .096)]
    lathe(bell, "copper", dome, 14, loc=(x, y, top))
    lathe(bell, "copper", [(.006, .096), (.006, .108), (.014, .110), (.014, .118), (0, .119)], 8, loc=(x, y, top))
    o.add("Deck", bell, pivot=(x, y, top))
    return o.export()


ITEMS = {
    "outfit_rivet_hood": {"rig": "assets/models/pilot_rivet_anim.glb", "out": "assets/cosmetics/outfits/outfit_rivet_hood.glb",
                          "build": rivet_hood, "tris": 350, "pose": hood_pose(HOOD_HINGE_UP), "pose_down": hood_pose(0), "look_at": (0, .05, .28),
                          "shots": {"front": (25, 12, 1.9, 720), "chase": (180, 22, 2.4, 720)}},
    "outfit_tally_eyeshade": {"rig": "assets/models/pilot_tally_anim.glb", "out": "assets/cosmetics/outfits/outfit_tally_eyeshade.glb",
                              "build": tally_eyeshade, "tris": 300, "look_at": (0, .05, .18),
                              "shots": {"front": (25, 14, 2.1, 720), "chase": (180, 22, 2.4, 720)}},
    "outfit_tarn_steady_cap": {"rig": "assets/models/pilot_tarn_anim.glb", "out": "assets/cosmetics/outfits/outfit_tarn_steady_cap.glb",
                               "build": tarn_steady_cap, "tris": 250, "look_at": (0, .03, .26),
                               "shots": {"front": (25, 14, 1.9, 720), "chase": (180, 22, 2.4, 720)}},
    "companion_skin_till_bell": {"rig": "assets/models/companion/spil9.glb", "out": "assets/cosmetics/companion_skins/companion_skin_till_bell.glb",
                                 "build": till_bell, "tris": 200, "look_at": (0, -.05, .1),
                                 "shots": {"front": (35, 25, 3.0, 720), "chase": (180, 30, 3.0, 720)}},
}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for item in argv or list(ITEMS):
        common.reset()
        ITEMS[item]["build"]()


if __name__ == "__main__":
    main()
