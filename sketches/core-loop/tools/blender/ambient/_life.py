"""Shared kit for the ambient life models (wave 17, issue #149): one soft, bevelled, smooth critter or local per GLB.

The record is the one source. A recipe names its kind (`Critter("dusk_quail")`) and this module reads that row's palette,
height_m, tris and model path straight out of src/core/ambient_kinds.gd by regex, so no colour or budget is copied here.

Conventions (every recipe follows them):
  - All coordinates are Godot metres: +Y up, the creature faces -Z (so its back is +Z), +X is its own left... of the screen
    when seen from the front. Origin on the ground under the creature. The helpers convert to Blender axes themselves.
  - One mesh, one material ("critter", vertex colours, roughness 0.7, no emission), one draw call. Pieces are built per
    bone group, then joined before the export; every piece is weighted whole to its bone (rigid skin, nothing tears).
  - Soft toy look (ruled 18 Oct): chunky, bevelled, smooth. Pieces are smooth ellipsoids, capsules and swept tubes
    subdivided in Python (polish.subdivide): region(bevel=0, subsurf=2) for bodies and heads, 1 for small bits.
  - Three baked clips, named exactly idle, move, react. idle and move are seamless loops (cycle); react is a one-shot that
    ends in its hidden/ducked pose and carries a seamless hold loop from `loop_from` (a recipe argument, printed in the export row) to its end, so a runtime that
    loops it re-seeks to loop_from instead of snapping back to standing.
  - Palette law (ambient_kinds.gd): hue 250 to 300, saturation 0.15 to 0.55, `cream` and `eye` accents, neutrals at most
    30% of vertices, no emission. check_life() asserts it on the built mesh before the export.

A recipe is about 80 lines:

    life = Critter("dusk_quail")
    life.ellipsoid("body", "body", (0, .12, 0), (.075, .07, .1))     # bone, palette name, centre, radii
    life.capsule("legs", "plume", (0, .07, 0), (0, .01, 0), .011)
    life.tube("plume", "plume", [(0, .25, -.06), (0, .3, -.08)], [.01, .006])
    life.rig([("root", (0, 0, 0), None), ("body", (0, .12, 0), "root")])
    life.cycle("idle", 2.0, {"body": [(0, {}), (1.0, {"loc": (0, .004, 0)})]})
    life.oneshot("react", 2.0, {...}, loop_from=0.8)
    life.finish()           # joins, binds, exports, asserts; honours --stills DIR and --out FILE

Run:  blender -b --threads 2 --python-exit-code 1 -P tools/blender/ambient/<kind>.py -- [--out FILE] [--stills DIR]
"""
import hashlib
import json
import math
import os
import re
import struct
import sys
import tempfile
from pathlib import Path

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

HERE = Path(__file__).resolve().parent
BLENDER = HERE.parent
sys.path.insert(0, str(BLENDER))
sys.path.insert(0, str(BLENDER / "world_one"))
import common
import cycles_device
import polish
import kill_first_rig as kfr

SKETCH = Path(common.SKETCH)
RECORD = SKETCH / "src" / "core" / "ambient_kinds.gd"
MODEL_ROOT = SKETCH / "assets" / "models" / "ambient"
SLOT = "critter"
ROUGH = 0.7
GLOBAL_TRIS = (800, 6000)
HEIGHT_TOL = 0.15
FPS = kfr.FPS
CLIPS = ("idle", "move", "react")

_B = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))

common.SLOTS[SLOT] = {"vc": True, "rough": ROUGH}


def _record_text():
    return RECORD.read_text()


def read_constants():
    """LIFE_HUE, LIFE_SAT, NEUTRAL_SAT, NEUTRAL_SHARE straight from the record."""
    text = _record_text()
    hue = re.search(r"const LIFE_HUE := Vector2\(([\d.]+), ([\d.]+)\)", text)
    sat = re.search(r"const LIFE_SAT := Vector2\(([\d.]+), ([\d.]+)\)", text)
    return {
        "hue": (float(hue.group(1)), float(hue.group(2))),
        "sat": (float(sat.group(1)), float(sat.group(2))),
        "neutral_sat": float(re.search(r"const NEUTRAL_SAT := ([\d.]+)", text).group(1)),
        "neutral_share": float(re.search(r"const NEUTRAL_SHARE := ([\d.]+)", text).group(1)),
        "accents": re.findall(r'"(\w+)"', re.search(r"const ACCENTS := \[(.*?)\]", text).group(1)),
        "tris": tuple(int(x) for x in re.search(r"const TRIS := \[(\d+), (\d+)\]", text).groups()),
    }


def read_kind(kind_id):
    """One row of ambient_kinds.gd: {id, model (file name), height_m, tris (lo, hi), palette {name: '#hex'}}."""
    text = _record_text()
    start = text.index('\t"%s": {' % kind_id)
    nxt = re.search(r'\n\t"\w+": \{', text[start + 5:])
    block = text[start:start + 5 + nxt.start()] if nxt else text[start:]
    palette = re.search(r'"palette": \{(.*?)\}', block, re.S).group(1)
    return {
        "id": kind_id,
        "model": re.search(r'"model": MODEL_DIR \+ "([\w.]+)"', block).group(1),
        "height_m": float(re.search(r'"height_m": ([\d.]+)', block).group(1)),
        "tris": tuple(int(x) for x in re.search(r'"tris": \[(\d+), (\d+)\]', block).groups()),
        "palette": {k: v for k, v in re.findall(r'"(\w+)": Color\("([0-9a-fA-F]{6})"\)', palette)},
    }


def hsv(rgb):
    """sRGB 0..1 triple -> (hue degrees, saturation, value)."""
    import colorsys
    h, s, v = colorsys.rgb_to_hsv(*rgb)
    return h * 360.0, s, v


def hex_rgb(hexs):
    return tuple(int(hexs[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def in_band(rgb, k):
    h, s, _v = hsv(rgb)
    return k["hue"][0] <= h <= k["hue"][1] and k["sat"][0] <= s <= k["sat"][1]


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"out": None, "stills": None}
    for key in out:
        flag = "--" + key
        if flag in argv and argv.index(flag) + 1 < len(argv):
            out[key] = argv[argv.index(flag) + 1]
    return out


def _m(loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    """A Godot-space transform; rot is degrees about Godot X, Y, Z."""
    return common.mtx(loc, [math.radians(a) for a in rot], scale)


class Critter:
    def __init__(self, kind_id, detail=1):
        self.k = read_constants()
        self.row = read_kind(kind_id)
        self.id = kind_id
        common.reset()
        polish.enable(detail=detail, bevel=0.0, subsurf=2, ao=False, edge=0.0, crease_angle=179.0)
        self.root = common.empty(kind_id, (0, 0, 0))
        self.parts = {}
        self.rig_ = None
        self.clips = {}
        for name, hexs in self.row["palette"].items():
            if name not in self.k["accents"]:
                assert in_band(hex_rgb(hexs), self.k), "%s palette %s %s is outside the life band" % (kind_id, name, hexs)

    def col(self, name):
        """The record's colour for a palette name, as the hex string Part.paint takes."""
        return self.row["palette"][name]

    def part(self, bone):
        """The Part holding every piece weighted to `bone` (created on first use)."""
        if bone not in self.parts:
            p = common.Part("%s_%s" % (self.id, bone))
            p.bevel = 0.0
            p.subsurf = 0
            self.parts[bone] = p
        return self.parts[bone]

    def _paint(self, p, bm_verts, color):
        p.bm.verts.index_update()
        faces = sorted({f for v in bm_verts for f in v.link_faces}, key=lambda f: f.index)
        p.bm.faces.index_update()
        p.paint(faces, SLOT, self.col(color) if color in self.row["palette"] else color)

    def ellipsoid(self, bone, color, centre, radii, rot=(0, 0, 0), subsurf=2, u=8, v=6):
        """A smooth ellipsoid. centre and radii in Godot metres (radii along the Godot axes, before rot, which is
        degrees about Godot X, Y, Z). u segments around, v rings; subsurf Catmull-Clark levels (2 for bodies, 1 for bits)."""
        p = self.part(bone)
        with p.region(bevel=0, subsurf=subsurf, detail=1):
            r = bmesh.ops.create_uvsphere(p.bm, u_segments=u, v_segments=v, radius=1.0,
                                          matrix=_B @ _m(centre, rot, radii))
            self._paint(p, r["verts"], color)

    def capsule(self, bone, color, a, b, r0, r1=None, subsurf=1, u=8, v=6, squash=(1.0, 1.0)):
        """A rounded rod from a to b (Godot points), radius r0 at a and r1 at b (default r0). squash scales the
        cross-section (x, y of the rod's local frame) for flat flippers and feet."""
        p = self.part(bone)
        a, b = Vector(a), Vector(b)
        d = b - a
        half = d.length / 2
        r1 = r0 if r1 is None else r1
        with p.region(bevel=0, subsurf=subsurf, detail=1):
            r = bmesh.ops.create_uvsphere(p.bm, u_segments=u, v_segments=v, radius=1.0, matrix=Matrix.Identity(4))
            for vert in r["verts"]:
                z = vert.co.z
                t = 0 if abs(z) < 1e-9 else (1 if z > 0 else -1)
                rad = (r0 + r1) / 2 if t == 0 else (r1 if t > 0 else r0)
                vert.co = Vector((vert.co.x * rad * squash[0], vert.co.y * rad * squash[1], z * rad + t * half))
            aim = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4() if d.length > 1e-9 else Matrix.Identity(4)
            bmesh.ops.transform(p.bm, matrix=_B @ Matrix.Translation((a + b) / 2) @ aim, verts=r["verts"])
            self._paint(p, r["verts"], color)

    def tube(self, bone, color, points, radii, sides=6, subsurf=1, cap=0.9):
        """A tapered tube swept along `points` (Godot), radii per point, closed by a rounded dome at each end (cap is the
        dome length as a fraction of the end radius). Plumes, tails, necks, trunks."""
        p = self.part(bone)
        pts = [Vector(q) for q in points]
        assert len(pts) == len(radii) >= 2
        with p.region(bevel=0, subsurf=subsurf, detail=1):
            rings = []
            up = Vector((0, 1, 0))
            for i, q in enumerate(pts):
                t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
                s = t.cross(up)
                if s.length < 1e-6:
                    s = t.cross(Vector((1, 0, 0)))
                s.normalize()
                n = s.cross(t)
                rings.append([p.bm.verts.new(_B @ (q + (s * math.cos(math.tau * j / sides) + n * math.sin(math.tau * j / sides)) * radii[i]))
                              for j in range(sides)])
            ends = []
            for i, sign in ((0, -1), (len(pts) - 1, 1)):
                t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
                ends.append(p.bm.verts.new(_B @ (pts[i] + t * sign * radii[i] * cap)))
            faces = []
            for i in range(len(pts) - 1):
                for j in range(sides):
                    k = (j + 1) % sides
                    faces.append(p.bm.faces.new((rings[i][j], rings[i][k], rings[i + 1][k], rings[i + 1][j])))
            for j in range(sides):
                k = (j + 1) % sides
                faces.append(p.bm.faces.new((ends[0], rings[0][k], rings[0][j])))
                faces.append(p.bm.faces.new((ends[1], rings[-1][j], rings[-1][k])))
            verts = [v for ring in rings for v in ring] + ends
            self._paint(p, verts, color)

    def rig(self, bones):
        """bones: [(name, Godot head, parent or None)], parents first. Every `bone` named in ellipsoid/capsule/tube
        must be in this list. Pieces are built, weighted whole to their bone and joined into one mesh."""
        names = [b[0] for b in bones]
        assert set(self.parts) <= set(names), (sorted(self.parts), names)
        objs = []
        for bone in sorted(self.parts):
            obj = self.parts[bone].to_object()
            obj.vertex_groups.new(name=bone).add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
            objs.append(obj)
        for o in bpy.context.scene.objects:
            o.select_set(False)
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.object.join()
        mesh = bpy.context.view_layer.objects.active
        mesh.name = self.id
        mesh.data.name = self.id
        mesh.parent = self.root
        self.mesh = mesh
        self.rig_ = kfr.Rig(self.root, self.id + "_rig", bones)
        self.rig_._attach(mesh)

    def _closed(self, seconds, tracks):
        out = {}
        for bone, keys in tracks.items():
            keys = [(round(t, 4), dict(pose)) for t, pose in keys]
            assert keys[0][0] == 0 and keys[-1][0] < seconds - 1e-6, (bone, keys[-1][0], seconds)
            out[bone] = keys + [(seconds, dict(keys[0][1]))]
        return out

    def cycle(self, name, seconds, tracks):
        """A seamless loop: each bone's last key is its first pose at `seconds`. 1 to 3 s, on the 30 fps grid.
        tracks: bone -> [(t, {"loc": (x,y,z) m, "rot": (pitch,yaw,roll) deg, "scale": f or (x,y,z)})], first t = 0."""
        self._check_clip(name, seconds)
        self.rig_.clip(name, seconds, self._closed(seconds, tracks))
        self.clips[name] = seconds

    def oneshot(self, name, seconds, tracks, loop_from):
        """The react clip: starts standing, ends in its ducked pose. The pose at `loop_from` must equal the pose at
        `seconds` for every bone (a seamless hold loop between them); asserted."""
        self._check_clip(name, seconds)
        for bone, keys in tracks.items():
            at = {round(t, 4): pose for t, pose in keys}
            assert round(loop_from, 4) in at and at[round(loop_from, 4)] == at[round(seconds, 4)], (
                "react hold loop does not close on bone " + bone)
        self.rig_.clip(name, seconds, tracks)
        self.clips[name] = seconds
        self.react_loop_from = loop_from

    def _check_clip(self, name, seconds):
        assert name in CLIPS, name
        assert 1.0 <= seconds <= 3.0, (name, seconds)
        assert abs(seconds * FPS - round(seconds * FPS)) < 1e-6, (name, "off the 30 fps grid")

    def height(self):
        bpy.context.view_layer.update()
        zs = [(self.mesh.matrix_world @ v.co).z for v in self.mesh.data.vertices]
        return max(zs) - min(zs)

    def check_life(self):
        """The life law on the built mesh: vertex colours are record colours, band or accent; neutrals <= 30% of verts."""
        attr = self.mesh.data.color_attributes["Color"]
        counts = {}
        total = 0
        lin = {}
        for name, hexs in self.row["palette"].items():
            lin[tuple(round(x, 3) for x in common.rgba(hexs)[:3])] = name
        for poly in self.mesh.data.polygons:
            for li in poly.loop_indices:
                c = tuple(round(x, 3) for x in attr.data[li].color[:3])
                counts[lin.get(c, "?")] = counts.get(lin.get(c, "?"), 0) + 1
                total += 1
        assert "?" not in counts, "vertex colour not from the record palette: %s" % counts
        neutral = sum(n for name, n in counts.items() if hsv(hex_rgb(self.row["palette"][name]))[1] < self.k["neutral_sat"])
        share = neutral / total
        assert share <= self.k["neutral_share"], "neutral share %.2f over %.2f" % (share, self.k["neutral_share"])
        return share

    def export(self, path):
        rig = self.rig_
        rig.stop()
        scene = bpy.context.scene
        scene.render.fps = FPS
        scene.frame_start, scene.frame_end = 1, kfr.frame(max(self.clips.values()))
        bpy.context.view_layer.update()
        for o in scene.objects:
            o.select_set(False)
        for o in common.tree(self.root):
            o.select_set(True)
        bpy.context.view_layer.objects.active = rig.arm
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="scrapkeep-life-") as scratch:
            packed = os.path.join(scratch, os.path.basename(path))
            bpy.ops.export_scene.gltf(filepath=packed, export_format="GLB", use_selection=True,
                export_animations=True, export_animation_mode="ACTIONS", export_anim_slide_to_zero=True,
                export_frame_range=False, export_force_sampling=True, export_def_bones=False,
                export_skins=True, export_yup=True, export_materials="EXPORT",
                export_vertex_color="ACTIVE", export_extras=False, export_cameras=False, export_lights=False)
            common.canonical_indices(packed, vertices=True)
            data = open(packed, "rb").read()
        with open(path, "wb") as fh:
            fh.write(data)
        size = struct.unpack_from("<I", data, 12)[0]
        doc = json.loads(data[20:20 + size])
        prims = [p for m in doc["meshes"] for p in m["primitives"]]
        stats = {
            "verts": sum(doc["accessors"][p["attributes"]["POSITION"]]["count"] for p in prims),
            "tris": sum(doc["accessors"][p["indices"]]["count"] // 3 for p in prims),
            "draws": len(prims),
            "materials": len(doc.get("materials", [])),
            "joints": len(doc["skins"][0]["joints"]) if doc.get("skins") else 0,
            "clips": sorted(a["name"] for a in doc.get("animations", [])),
        }
        lo, hi = self.row["tris"]
        assert lo <= stats["tris"] <= hi, ("tris outside the row band", stats, self.row["tris"])
        assert GLOBAL_TRIS[0] <= stats["tris"] <= GLOBAL_TRIS[1], ("tris outside the ambient class", stats)
        assert stats["draws"] == 1 and stats["materials"] == 1, stats
        assert stats["clips"] == sorted(CLIPS), stats
        assert all("JOINTS_0" in p["attributes"] for p in prims), "skinned"
        mat = doc["materials"][0]
        assert "emissiveFactor" not in mat and "KHR_materials_emissive_strength" not in mat.get("extensions", {}), mat
        stats["sha256"] = hashlib.sha256(data).hexdigest()
        print("AMBIENT_EXPORT " + json.dumps({"file": os.path.basename(path), "kind": self.id, **stats}, sort_keys=True))
        return stats

    def stills(self, outdir, pose=None):
        """Three Cycles CPU stills (640x480) on a neutral sandstone ground: front 3/4, side, and the react pose (the end of
        the react clip; pose=(clip, seconds) shows another frame, labelled by the clip)."""
        scene = bpy.context.scene
        scene.render.engine = "CYCLES"
        cycles_device.use(scene)
        scene.cycles.samples = 32
        scene.cycles.use_denoising = False
        scene.render.threads_mode = "FIXED"
        scene.render.threads = 2
        scene.render.resolution_x, scene.render.resolution_y = 640, 480
        scene.render.resolution_percentage = 100
        scene.view_settings.view_transform = "Standard"
        scene.world = bpy.data.worlds.new("life_preview")
        scene.world.use_nodes = True
        bg = scene.world.node_tree.nodes["Background"]
        bg.inputs["Color"].default_value = common.rgba(common.mix("sandstone", "bone", 0.55))
        bg.inputs["Strength"].default_value = 0.9
        bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
        bpy.context.object.data.materials.append(common._flat("ground", "sandstone"))
        sun = bpy.data.lights.new("sun", "SUN")
        sun.energy = 3.0
        sun_obj = bpy.data.objects.new("sun", sun)
        sun_obj.rotation_euler = (math.radians(50), math.radians(10), math.radians(150))
        scene.collection.objects.link(sun_obj)
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        cam.data.angle_y = math.radians(30)
        cam.data.sensor_fit = "VERTICAL"
        scene.collection.objects.link(cam)
        scene.camera = cam
        h = self.row["height_m"]
        d = h * 3.2
        target = Vector((0, 0, h * 0.42))
        os.makedirs(outdir, exist_ok=True)
        shots = [
            ("front34", None, Vector((0.62, 0.78, 0.5)).normalized() * d + target),
            ("side", None, Vector((1.0, 0.0, 0.22)).normalized() * d + target),
            (pose[0] if pose else "react", pose or ("react", self.clips["react"]), Vector((0.62, 0.78, 0.5)).normalized() * d + target),
        ]
        paths = []
        for label, pose, at in shots:
            if pose is None:
                self.rig_.stop()
            else:
                self.rig_.evaluate(*pose)
            cam.location = at
            common._look(cam, target)
            path = os.path.join(outdir, "%s_%s.png" % (self.id, label))
            scene.render.filepath = path
            bpy.ops.render.render(write_still=True)
            paths.append(path)
        self.rig_.stop()
        print("STILLS " + " ".join(paths))
        return paths

    def finish(self):
        """Asserts, exports to assets/models/ambient/<model> (or --out) and renders --stills DIR if asked."""
        a = args()
        share = self.check_life()
        h = self.height()
        want = self.row["height_m"]
        assert abs(h - want) <= want * HEIGHT_TOL, "height %.3f m vs %.3f m (+-%d%%)" % (h, want, HEIGHT_TOL * 100)
        assert set(self.clips) == set(CLIPS), sorted(self.clips)
        print("AMBIENT_CHECK %s height %.3f m (row %.2f) neutral share %.2f" % (self.id, h, want, share))
        path = a["out"] or str(MODEL_ROOT / self.row["model"])
        stats = self.export(path)
        if a["stills"]:
            self.stills(a["stills"])
        return stats
