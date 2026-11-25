"""KF5: the reactor relic's own body (design-v3/wardens/reactor.md sections 1, 5 and 9).

A fission pile that never shut down, clamped onto the water that used to cool it: a
squat ribbed drum in the clamp's jaws, three control-rod stacks that lift 0.6 m on the
pulse, a caged core dome on top, and uranium-glass seams that breathe. Its motion is
vertical. It replaces the shared clamp and the procedural reactor kit for this kind
(the way tools/blender/bosses/mind_body.py replaces them for the Mind); KF8 wires it.

Convention: +Y up in Godot (Blender +Z here, converted by the exporter), the ball's
approach along -Z (the body's front faces Godot +Z, Blender -Y), the origin at the
body's base centre where it meets the mounting. Metres.

Collider rule (warden.gd RADIUS 2.8, HALF_HEIGHT 1.6; warden_look.gd:31-32): below
2 m above the base nothing passes r = 2.8 m; above it no part passes r = 3.8 m, the
collider plus 1 m, in any view (the approach view's lateral reach is a subset). The
stacks rise past the collider's top on purpose: the sheet asks for 4 m stacks.
The weak point (WeakPoint, the core) sits at warden_kit.gd point_offset (DECK + 3.0)
plus HALF_HEIGHT: 6.8 m above the base, so warden.family_point_at() is unchanged.

Nodes (rigid, an empty hierarchy; each clip is one glTF animation of its length):
  WardenReactor > Drum (static: pedestal, skirt, drum core, iron bands, deck)
                  Jacket0..3 > SeamV0..3   the ribbed jacket quarters, centred at
                                           45/135/225/315 degrees, each with its seam
                  Stack0..2 > StackGlow0..2  control-rod stacks at 90/210/330 degrees
                  CageL, CageR             the core dome's lattice, split in x
                  WeakPoint                the core, r 0.9 at 6.8 m
                  JawL, JawR               the clamp's jaws at -X / +X, hinged on
                                           their bottom outer edge (lean = rotate Y)
                  GateL, GateR             spillway leaves on the back rim (dam_face)
                  PourLip                  the slag spout at the front foot (flume)
                  SteamRing                the pulse's steam ring, scale 0.02 at rest
                  Hardpoint                the crown eye, the body's own line point
                  SeamRing                 the pedestal's seam, under 2 m
Clips (section 5; name: length, blend): see CLIPS. chunk_lost moves Jacket0;
chunk_lost_1..3 are the same fall for Jacket1..3 (the mind_body phase_break idiom).
Seam light is emission on ancient_light; the clips carry its breath and its going dark
as the seams' scale (the runtime keeps owning the 0.8 / 5.0 emission levels).

Run under the 12 GiB prlimit address-space cap of tools/blender/PILOT-RIG.md:72:
  blender --background --threads 2 --python-exit-code 1 \
    --python sketches/core-loop/tools/blender/warden_reactor.py -- [--out file.glb] \
    [--count-only] [--render DIR]
--count-only builds and checks in Blender, exports nothing. --render DIR also writes
Cycles CPU look frames (20, 60, 150 m) for the blind pair reads.
Provenance: authored procedurally here from Blender primitives and bmesh operators;
no external meshes or textures. No light node is exported.
"""

import hashlib
import json
import math
import os
import re
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh
import bpy
from mathutils import Matrix, Vector

import common
import cycles_device
import polish

polish.enable(detail=1, bevel=0.04, bevel_angle=46.0, edge=0.0, ao_strength=0.35)
from common import Part

FPS = 30
CLIPS = {
    "idle": (4.0, 1.0), "pulse_warn": (2.0, 0.5), "pulse": (0.3, 0.1), "active": (0.5, 0.5),
    "chunk_lost": (1.0, 0.8), "shrug": (0.4, 0.2), "gates_open": (0.6, 0.3), "pour": (1.0, 0.3),
    "final_quiet": (2.0, 2.0),
    "chunk_lost_1": (1.0, 0.8), "chunk_lost_2": (1.0, 0.8), "chunk_lost_3": (1.0, 0.8),
}
REQUIRED = ("idle", "pulse_warn", "pulse", "active", "chunk_lost", "shrug", "gates_open", "pour", "final_quiet")
BUDGET = {"tris": 12000, "verts": 9600, "draws": 32}
RADIUS = 2.8
HALF_HEIGHT = 1.6
LOW = 2.0
REACH = 1.0
CORE_Z = 2.2 + 3.0 + HALF_HEIGHT
STACK_RISE = 0.6
JAW_LEAN = math.radians(14.0)

ENAMEL = "petrol"
IRON = common.mix("charcoal", "petrol", 0.2)
COPPER = "copper"
SAND = common.mix("sandstone", "petrol", 0.22)
SAND_DARK = common.mix("sandstone", "charcoal", 0.45)
TOOTH = common.mix("sandstone", "bone", 0.35)
ROD_STEEL = common.mix("ice", "bone", 0.45)
COPPER_DARK = common.mix("copper", "charcoal", 0.6)
DUST = common.mix("petrol", "sandstone", 0.3)

DRUM_R = 2.42
DRUM_Z = (2.5, 5.75)
JACKET_R = (2.5, 2.6)
BAND_R = (2.38, 2.62)
JAW_R = (2.98, 3.2)
JAW_Z = (2.4, 6.9)
JAW_SPAN = math.radians(50)
LIP_H = 0.5
JAW_SEGS = 10
MOUTH_Z = sum(JAW_Z) / 2
MOUTH_G = (JAW_Z[1] - JAW_Z[0]) / 2 - LIP_H
TEETH = ((0.0, 1.4, 1.25, 1.15), (-27.0, 1.0, 0.95, 0.9), (27.0, 1.0, 0.95, 0.9))
TOOTH_R = (2.98, 3.78, 3.25)
TOOTH_W_OUT = 0.6
TOOTH_SIDE_R = 3.3
STACK_R = 2.5
STACK_BASE = 5.95
STACK_ANGLES = (90.0, 210.0, 330.0)
SEAM_ANGLES = (60.0, 120.0, 240.0, 300.0)
CAGE_BASE = 6.3
CAGE_R = 1.45
CAGE_TOP = 7.9
HINGE = Vector((JAW_R[1], 0.0, JAW_Z[0]))
PED_R = (1.0, 1.1)
RAM_BASE = Vector((0.70, 2.94, 4.17))
RAM_LUG = Vector((2.63, 2.21, 6.68))
RAM_BARREL_LENGTH = 1.9
RAM_BARREL_R = 0.475
RAM_ROD_R = 0.23
RAM_BASE_NECK = 0.25
RAM_GLAND_LENGTH = 0.15
RAM_GLAND_R = 0.52
RAM_EYE_R = 0.25
RAM_MOUTH = RAM_BASE_NECK + RAM_BARREL_LENGTH + RAM_GLAND_LENGTH

SIL_CAMERAS = [
    ("over_shoulder", (0.0, 0.6, 2.0), "WARDEN_BODY_CAMERAS row 0"),
    ("three_q", (-1.97, 0.42, 1.31), "WARDEN_BODY_CAMERAS row 3"),
    ("under", (-1.2, -0.45, -1.06), "WARDEN_BODY_CAMERAS row 4"),
]
SIL_APPROACH = ("over_shoulder", "three_q")
SIL_RAM_OUT_M = 0.5
SIL_RAM_OUT_FRAC = 0.3
SIL_RAM_COUNT = 2
SIL_RAM_BASE_Z = 2.0
SIL_RAM_DIAMETER_RATIO = 2.0
SIL_RAM_EXTENSION_RATIO = 2.0
SIL_RAM_EYE_ERROR = 0.05
RAM_RIG = []
SIL_TOOTH_OUT_M = 0.5
SIL_TOOTH_COUNT = 4
SIL_TOOTH_MIN_H = 0.6
SIL_TOOTH_PER_ROW = 3
SIL_JAW_STANDOFF = 0.3


def sweep(part, slot, profile, a0, a1, segs, color=None, caps=True):
    """Sweeps a closed (r, z) profile round the vertical axis from a0 to a1."""
    rows = []
    for k in range(segs + 1):
        a = a0 + (a1 - a0) * k / segs
        ca, sa = math.cos(a), math.sin(a)
        rows.append([part.bm.verts.new((r * ca, r * sa, z)) for r, z in profile])
    faces = []
    n = len(profile)
    for k in range(segs):
        for i in range(n):
            j = (i + 1) % n
            faces.append(part.bm.faces.new((rows[k][i], rows[k + 1][i], rows[k + 1][j], rows[k][j])))
    if caps:
        faces.append(part.bm.faces.new(list(reversed(rows[0]))))
        faces.append(part.bm.faces.new(rows[-1]))
    return part.paint(faces, slot, color)


def sweep_var(part, slot, profile_at, a0, a1, segs, color=None):
    """sweep() with a profile that changes with the angle: profile_at(a) gives the (r, z) loop."""
    rows = []
    for k in range(segs + 1):
        a = a0 + (a1 - a0) * k / segs
        ca, sa = math.cos(a), math.sin(a)
        rows.append([part.bm.verts.new((r * ca, r * sa, z)) for r, z in profile_at(a)])
    faces = []
    n = len(rows[0])
    for k in range(segs):
        for i in range(n):
            j = (i + 1) % n
            faces.append(part.bm.faces.new((rows[k][i], rows[k + 1][i], rows[k + 1][j], rows[k][j])))
    faces.append(part.bm.faces.new(list(reversed(rows[0]))))
    faces.append(part.bm.faces.new(rows[-1]))
    return part.paint(faces, slot, color)


def maw(a):
    """(lower lip top, upper lip bottom) at jaw-local angle a: an ellipse that closes at the corners."""
    g = MOUTH_G * math.sqrt(max(0.0, 1.0 - (a / JAW_SPAN) ** 2))
    return MOUTH_Z - g, MOUTH_Z + g


def smooth(faces):
    for f in faces:
        f.smooth = True
    return faces


def finish(part, origin, parent, rot_z=None):
    """Outward normals, then the object. With rot_z the part was modelled in the +X
    frame round origin; the object turns it to its angle (so a local Y rotation is a
    lean about the tangent)."""
    bmesh.ops.recalc_face_normals(part.bm, faces=part.bm.faces[:])
    if rot_z is None:
        return part.to_object(origin, parent)
    obj = part.to_object(origin, parent)
    o = Vector(origin)
    turned = Vector((o.x * math.cos(rot_z) - o.y * math.sin(rot_z), o.x * math.sin(rot_z) + o.y * math.cos(rot_z), o.z))
    obj["world_origin"] = list(turned)
    obj.location = turned - Vector(parent["world_origin"])
    obj.rotation_euler = (0.0, 0.0, rot_z)
    return obj


def polar(r, deg, z):
    a = math.radians(deg)
    return Vector((r * math.cos(a), r * math.sin(a), z))


def _sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _unit(a):
    n = math.sqrt(_dot(a, a))
    return (a[0] / n, a[1] / n, a[2] / n)


def sil_axes(offset):
    """(view, up, right) in the body's Godot frame for an eye offset: view = -normalize(offset)."""
    view = _unit((-offset[0], -offset[1], -offset[2]))
    up0 = (0.0, 1.0, 0.0) if abs(view[1]) <= 0.9 else (0.0, 0.0, -1.0)
    up = _unit(_sub(up0, tuple(view[i] * _dot(up0, view) for i in range(3))))
    return view, up, _cross(up, view)


def sil_project(points, axes):
    _, up, right = axes
    return [(_dot(p, right), _dot(p, up)) for p in points]


def _turn(o, a, b):
    return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])


def sil_hull(pts):
    """Monotone chain convex hull, counter-clockwise, no repeated end point."""
    pts = sorted(set((round(p[0], 6), round(p[1], 6)) for p in pts))
    if len(pts) < 3:
        return pts
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and _turn(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and _turn(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def _seg_dist(p, a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    n = dx * dx + dy * dy
    t = 0.0 if n == 0 else max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / n))
    return math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dy)


def _inside(p, hull):
    n = len(hull)
    return n >= 3 and all(_turn(hull[i], hull[(i + 1) % n], p) >= -1e-9 for i in range(n))


def sil_outside(p, hull):
    """0 inside the hull, else the distance to its boundary."""
    if _inside(p, hull):
        return 0.0
    n = len(hull)
    return min(_seg_dist(p, hull[i], hull[(i + 1) % n]) for i in range(n))


def _cross_segs(a, b, c, d):
    return (_turn(a, b, c) * _turn(a, b, d) < 0) and (_turn(c, d, a) * _turn(c, d, b) < 0)


def sil_hull_gap(h1, h2):
    """Minimal distance between two convex polygons, 0 when they touch or overlap."""
    if any(_inside(p, h2) for p in h1) or any(_inside(p, h1) for p in h2):
        return 0.0
    n1, n2 = len(h1), len(h2)
    for i in range(n1):
        for j in range(n2):
            if _cross_segs(h1[i], h1[(i + 1) % n1], h2[j], h2[(j + 1) % n2]):
                return 0.0
    best = min(_seg_dist(p, h2[j], h2[(j + 1) % n2]) for p in h1 for j in range(n2))
    return min(best, min(_seg_dist(p, h1[i], h1[(i + 1) % n1]) for p in h2 for i in range(n1)))


def sil_part_outside(part_pts, outline_pts, axes):
    """(outside_m, outside_frac) of a part's vertices against the outline's projected hull."""
    hull = sil_hull(sil_project(outline_pts, axes))
    d = [sil_outside(p, hull) for p in sil_project(part_pts, axes)]
    return max(d), sum(1 for x in d if x > 1e-6) / len(d)


LOOK_SUBJECTS = os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir, "look_subjects.gd")


def sil_frame(subject, const):
    """({camera: stage yaw in degrees}, {camera: world eye offset}) from look_subjects.gd."""
    with open(LOOK_SUBJECTS) as f:
        text = f.read()
    yaws = {}
    start = text.find("const WARDEN_BODY_STAGE_YAW := {")
    if start >= 0:
        block = text[start:text.index("}}", start) + 2]
        for subj, body in re.findall(r'"(\w+)":\s*\{([^}]*)\}', block):
            if subj == subject:
                yaws = {k: float(v) for k, v in re.findall(r'"(\w+)":\s*(-?[0-9.]+)', body)}
    start = text.find("const %s := [" % const)
    rows = {}
    if start >= 0:
        block = text[start:text.index("]]", start) + 2]
        rows = {k: tuple(float(x) for x in v.split(",")) for k, v in re.findall(r'\["(\w+)", Vector3\(([^)]*)\)', block)}
    return yaws, rows


def sil_turn(v, deg):
    """v turned deg about +Y (Godot frame)."""
    a = math.radians(deg)
    return (v[0] * math.cos(a) + v[2] * math.sin(a), v[1], -v[0] * math.sin(a) + v[2] * math.cos(a))


def sil_cameras(subject, const, fails):
    """[(name, body-frame offset)] for SIL_CAMERAS, a CHECK line each; a missing stage yaw or a copy
    that drifts from look_subjects.gd appends to fails."""
    yaws, rows = sil_frame(subject, const)
    out = []
    for name, off, src in SIL_CAMERAS:
        yaw = yaws.get(name)
        if yaw is None:
            print("SILHOUETTE FAIL %s frame %s stage_yaw missing wants a WARDEN_BODY_STAGE_YAW entry" % (subject, name))
            fails.append("stage yaw " + name)
            yaw = 0.0
        live = rows.get(name)
        if live is None or max(abs(a - b) for a, b in zip(live, off)) >= 1e-6:
            print("SILHOUETTE FAIL %s frame %s offset=%s wants look_subjects.gd %s %s" % (subject, name, off, const, live))
            fails.append("camera drift " + name)
        body = sil_turn(off, -yaw)
        view = _unit((-body[0], -body[1], -body[2]))
        print("CHECK silhouette_dir %s offset=(%.3f, %.3f, %.3f) from look_subjects.gd %s stage_yaw=%.1f body_view=(%.3f, %.3f, %.3f)"
              % (name, off[0], off[1], off[2], src, yaw, view[0], view[1], view[2]))
        out.append((name, body))
    return out


def sil_info(body, camera, part, metric, value, want, why):
    """A review aid: prints a SILHOUETTE info line and never fails the build (KF7c round 4)."""
    print("SILHOUETTE info %s %s %s %s=%.3f wants %s (review aid: %s)" % (body, camera, part, metric, value, want, why))
    return True


def sil_say(ok, body, camera, part, metric, value, want):
    print("SILHOUETTE %s %s %s %s %s=%.3f wants %s" % ("ok" if ok else "FAIL", body, camera, part, metric, value, want))
    return ok


TAGS = []
SIL_LAYER = "sil"
RAM_MEASURE_LAYER = "ram_measure"
RAM_MEASURES = []


def measured(part, label, fn, *args, **kwargs):
    layer = part.bm.verts.layers.int.get(RAM_MEASURE_LAYER) or part.bm.verts.layers.int.new(RAM_MEASURE_LAYER)
    faces = fn(*args, **kwargs)
    if label not in RAM_MEASURES:
        RAM_MEASURES.append(label)
    for face in faces:
        for vertex in face.verts:
            vertex[layer] = RAM_MEASURES.index(label) + 1
    return faces


def measured_points(root):
    points = {}
    for obj in common.tree(root):
        if obj.type != "MESH":
            continue
        codes = obj.data.attributes.get(RAM_MEASURE_LAYER)
        if codes is None:
            continue
        for vertex in obj.data.vertices:
            code = codes.data[vertex.index].value
            if code:
                points.setdefault(RAM_MEASURES[code - 1], []).append(obj.matrix_world @ vertex.co)
    return points


def measured_ram_colors(root):
    mesh = next(obj.data for obj in common.tree(root) if obj.name == "JawRams")
    codes = mesh.attributes.get(RAM_MEASURE_LAYER)
    colors = mesh.color_attributes.get("Color")
    if codes is None or colors is None:
        return {}
    per_vertex = {}
    for loop in mesh.loops:
        rgb = colors.data[loop.index].color[:3]
        per_vertex.setdefault(loop.vertex_index, []).append(rgb)
    groups = {}
    for index, samples in per_vertex.items():
        code = codes.data[index].value
        if code:
            rgb = tuple(sum(sample[k] for sample in samples) / len(samples) for k in range(3))
            groups.setdefault(RAM_MEASURES[code - 1], []).append(rgb)
    return {label: tuple(sum(rgb[k] for rgb in samples) / len(samples) for k in range(3))
            for label, samples in groups.items()}


def bounds_gap(a, b):
    if not a or not b:
        return math.inf
    gaps = [max(0.0, min(p[k] for p in a) - max(p[k] for p in b),
                min(p[k] for p in b) - max(p[k] for p in a)) for k in range(3)]
    return math.sqrt(sum(gap * gap for gap in gaps))


def radial_extent(points, origin, axis):
    return max(((point - origin).cross(axis).length for point in points), default=0.0)


def material_slot_checks(root):
    path = os.path.join(common.SKETCH, "src", "presentation", "hero_assets.gd")
    with open(path) as source:
        text = source.read()
    block = re.search(r"^const SLOTS\s*:=\s*\{(.*?)^\}", text, re.MULTILINE | re.DOTALL)
    slots = set(re.findall(r'^\s*"([^"\n]+)"\s*:', block[1], re.MULTILINE)) if block else set()
    fails = []
    if not sil_say(bool(slots), "reactor", "runtime", "SLOTS", "parsed_keys", len(slots), ">0 from hero_assets.gd"):
        fails.append("runtime SLOTS parse")
    for obj in common.tree(root):
        if obj.type != "MESH":
            continue
        for index in sorted({poly.material_index for poly in obj.data.polygons}):
            material = obj.data.materials[index]
            slot = material.name if material else "<missing>"
            if not sil_say(slot in slots, "reactor", "runtime", obj.name + "/" + slot,
                           "material_slot_known", int(slot in slots), "=1 in hero_assets.gd SLOTS"):
                fails.append(obj.name + " material slot " + slot)
    return fails


def tagged(part, label, fn, *a, **kw):
    layer = part.bm.verts.layers.int.get(SIL_LAYER) or part.bm.verts.layers.int.new(SIL_LAYER)
    faces = fn(*a, **kw)
    if label not in TAGS:
        TAGS.append(label)
    for f in faces:
        for v in f.verts:
            v[layer] = TAGS.index(label) + 1
    return faces


def ram_label(deg):
    return "ram%03d" % (int(round(deg)) % 360)


def _labelled_points(root):
    bpy.context.view_layer.update()
    pts, labels, faces = [], [], []
    for o in common.tree(root):
        if o.type != "MESH":
            continue
        base = len(pts)
        mw = o.matrix_world
        codes = o.data.attributes.get(SIL_LAYER)
        for i, v in enumerate(o.data.vertices):
            w = mw @ v.co
            pts.append((w.x, w.z, -w.y))
            code = codes.data[i].value if codes is not None else 0
            labels.append(TAGS[code - 1] if code else o.name)
        for poly in o.data.polygons:
            faces.append((o.name, [base + i for i in poly.vertices]))
    return pts, labels, faces


def _jaw_standoff(pts, labels, faces, jaw):
    """The least radial gap from the jaw slab's vertices to the drum surface (Drum without the rams,
    the jacket quarters and their seams) at the same height and bearing; faces stand in for the
    surface by their outermost vertex, so a chord never reads as a gap."""
    drum = set(["Drum"] + ["Jacket%d" % k for k in range(4)] + ["SeamV%d" % k for k in range(4)])
    spans = []
    for name, idx in faces:
        if name not in drum or any(labels[i].startswith("ram") for i in idx):
            continue
        ys = [pts[i][1] for i in idx]
        rs = [math.hypot(pts[i][0], pts[i][2]) for i in idx]
        angs = [math.atan2(pts[i][2], pts[i][0]) for i in idx]
        spans.append((min(ys), max(ys), max(rs), angs))
    worst = math.inf
    for p, lab in zip(pts, labels):
        if lab != "jawslab_" + jaw:
            continue
        r = math.hypot(p[0], p[2])
        a = math.atan2(p[2], p[0])
        surface = 0.0
        for y0, y1, rmax, angs in spans:
            if not (y0 - 0.05 <= p[1] <= y1 + 0.05):
                continue
            rel = [math.remainder(b - a, math.tau) for b in angs]
            if min(abs(x) for x in rel) < math.radians(3.0) or (min(rel) <= 0.0 <= max(rel) and max(rel) - min(rel) < math.pi):
                surface = max(surface, rmax)
        worst = min(worst, r - surface)
    return worst


def ram_world(rig, key):
    obj, point = rig[key]
    if isinstance(obj, bpy.types.PoseBone):
        return obj.id_data.matrix_world @ obj.matrix @ Vector(point)
    return obj.matrix_world @ Vector(point)


def ram_checks(root):
    """Fixed pins, cylinder proportions and jaw-following motion, sampled at each baked frame."""
    fails = []
    snapshot = rest(root)
    objs = {o.name: o for o in common.tree(root)}
    points = measured_points(root)
    colors = measured_ram_colors(root)
    sandstone = Vector(common.to_linear(common.srgb(common.HEX["sandstone"])))
    bone = Vector(common.to_linear(common.srgb(common.HEX["bone"])))
    luma = Vector((0.2126, 0.7152, 0.0722))
    moving = [clip for clip in CLIPS if any(n in controls(clip) for n in ("JawL", "JawR"))]
    for rig in RAM_RIG:
        label = rig["label"]
        base = ram_world(rig, "base")
        barrel_r = radial_extent(points.get(label + "_barrel", []), base, rig["rest_axis"])
        rod_r = radial_extent(points.get(label + "_rod", []), base, rig["rest_axis"])
        diameter_ratio = barrel_r / rod_r if rod_r > 0 else 0.0
        seat_gap = bounds_gap(points.get(label + "_base_clevis", []), points.get("clamp_ring", []))
        print("CHECK ram_mesh %s barrel_r_m=%.4f rod_r_m=%.4f clamp_gap_m=%.4f" %
              (label, barrel_r, rod_r, seat_gap))
        barrel_rgb = Vector(colors.get(label + "_barrel", (0, 0, 0)))
        rod_rgb = Vector(colors.get(label + "_rod", (0, 0, 0)))
        barrel_luma, rod_luma = barrel_rgb.dot(luma), rod_rgb.dot(luma)
        rod_saturation = max(rod_rgb) - min(rod_rgb)
        sand_distance, bone_distance = (rod_rgb - sandstone).length, (rod_rgb - bone).length
        contrast_ok = (label + "_barrel" in colors and label + "_rod" in colors
                       and rod_luma - barrel_luma >= 0.45
                       and rod_luma >= 0.6 and rod_saturation <= 0.12
                       and sand_distance >= 0.15 and bone_distance >= 0.15)
        if not sil_say(contrast_ok, "reactor", "3d", label, "ram_value_contrast",
                       rod_luma - barrel_luma,
                       ">=0.45 rod_luma>=0.6 rod_saturation<=0.12 sandstone_distance>=0.15 bone_distance>=0.15 "
                       "barrel_luma=%.6f rod_luma=%.6f rod_saturation=%.6f sandstone_distance=%.6f bone_distance=%.6f" %
                       (barrel_luma, rod_luma, rod_saturation, sand_distance, bone_distance)):
            fails.append(label + " ram_value_contrast")
        for metric, value, ok, want in (
            ("base_pin_z_m", base.z, base.z >= SIL_RAM_BASE_Z, ">=2.0"),
            ("base_on_clamp", int(seat_gap <= 0.05), seat_gap <= 0.05, "=1 built bounds gap<=0.05m"),
            ("barrel_rod_diameter_ratio", diameter_ratio,
             diameter_ratio >= SIL_RAM_DIAMETER_RATIO, ">=2.0"),
        ):
            if not sil_say(ok, "reactor", "3d", label, metric, value, want):
                fails.append(label + " " + metric)
        axis = (ram_world(rig, "mouth") - base).normalized()
        closed = (ram_world(rig, "eye") - ram_world(rig, "mouth")).dot(axis) - rig["eye_r"]
        max_eye = max_axis = max_rod_axis = max_base = 0.0
        samples = 0
        opened = 0.0
        for clip in moving:
            frames = max(10, int(round(CLIPS[clip][0] * FPS)))
            for f in range(frames + 1):
                reset_pose(root, snapshot)
                pose(clip, f / frames, objs, snapshot)
                bpy.context.view_layer.update()
                eye, lug = ram_world(rig, "eye"), ram_world(rig, "lug")
                b, mouth = ram_world(rig, "base"), ram_world(rig, "mouth")
                axis = (mouth - b).normalized()
                max_eye = max(max_eye, (eye - lug).length)
                max_axis = max(max_axis, (eye - b).cross(axis).length)
                max_rod_axis = max(max_rod_axis, (ram_world(rig, "rod_inner") - b).cross(axis).length)
                max_base = max(max_base, (b - rig["barrel"].matrix.translation).length)
                samples += 1
                if clip == "active" and f == frames:
                    opened = (eye - mouth).dot(axis) - rig["eye_r"]
        ratio = opened / closed if closed > 0 else 0.0
        print("CHECK ram_motion %s rest_exposed_m=%.4f active_exposed_m=%.4f samples=%d clips=%s" %
              (label, closed, opened, samples, ",".join(moving)))
        for metric, value, ok, want in (
            ("active_rest_exposed_ratio", ratio, closed > 0 and ratio >= SIL_RAM_EXTENSION_RATIO, ">=2.0"),
            ("eye_lug_error_m", max_eye, max_eye <= SIL_RAM_EYE_ERROR, "<=0.05 every jaw frame"),
            ("barrel_axis_eye_error_m", max_axis, max_axis <= SIL_RAM_EYE_ERROR, "<=0.05 every jaw frame"),
            ("rod_axis_error_m", max_rod_axis, max_rod_axis <= SIL_RAM_EYE_ERROR, "<=0.05 every jaw frame"),
            ("barrel_base_pin_error_m", max_base, max_base <= SIL_RAM_EYE_ERROR, "<=0.05 every jaw frame"),
        ):
            if not sil_say(ok, "reactor", "animation", label, metric, value, want):
                fails.append(label + " " + metric)
        reset_pose(root, snapshot)
    if len(RAM_RIG) != 2:
        fails.append("exactly two jaw rams required")
    return fails


def silhouette(root):
    """Prints a SILHOUETTE line per rule; returns the failures."""
    pts, labels, faces = _labelled_points(root)
    for o in common.tree(root):
        if o.type == "MESH" and o.data.attributes.get(SIL_LAYER) is not None:
            o.data.attributes.remove(o.data.attributes[SIL_LAYER])
    fails = material_slot_checks(root)
    axes = {name: sil_axes(off) for name, off in sil_cameras("warden_body_reactor", "WARDEN_BODY_CAMERAS", fails)}
    rams = sorted(set(l for l in labels if l.startswith("ram")))
    teeth = sorted(set(l for l in labels if l.startswith("tooth_")))
    by_label = {}
    for p, l in zip(pts, labels):
        by_label.setdefault(l, []).append(p)
    best_ram = best_tooth = (-1, "")
    tooth_counts = {}
    for cam in [c[0] for c in SIL_CAMERAS]:
        good_rams = good_teeth = 0
        for part in rams + teeth:
            outline = [p for p, l in zip(pts, labels) if l != part]
            out_m, frac = sil_part_outside(by_label[part], outline, axes[cam])
            print("SILHOUETTE row reactor %s %s outside_m=%.3f outside_frac=%.3f" % (cam, part, out_m, frac))
            if part.startswith("ram") and out_m >= SIL_RAM_OUT_M and frac >= SIL_RAM_OUT_FRAC:
                good_rams += 1
            if part.startswith("tooth_") and out_m >= SIL_TOOTH_OUT_M:
                good_teeth += 1
        tooth_counts[cam] = good_teeth
        if cam in SIL_APPROACH:
            best_ram = max(best_ram, (good_rams, cam))
            best_tooth = max(best_tooth, (good_teeth, cam))
    if not sil_say(best_ram[0] >= SIL_RAM_COUNT, "reactor", best_ram[1], "rams",
                   "count(outside_m>=%.1f,outside_frac>=%.1f)" % (SIL_RAM_OUT_M, SIL_RAM_OUT_FRAC),
                   best_ram[0], ">=%d on over_shoulder or three_q" % SIL_RAM_COUNT):
        fails.append("ram camera count")
    sil_info("reactor", best_tooth[1], "teeth", "count(outside_m>=%.1f)" % SIL_TOOTH_OUT_M, best_tooth[0],
             ">=%d on over_shoulder or three_q" % SIL_TOOTH_COUNT,
             "KF7c round 4, jaw read at 7d87f33 came from under (count there %d), look5 read decides"
             % tooth_counts.get("under", 0))
    fails.extend(ram_checks(root))
    for obj in common.tree(root):
        if obj.type == "MESH" and obj.data.attributes.get(RAM_MEASURE_LAYER) is not None:
            obj.data.attributes.remove(obj.data.attributes[RAM_MEASURE_LAYER])
    rows = {}
    for t in teeth:
        ys = [p[1] for p in by_label[t]]
        if not sil_say(max(ys) - min(ys) >= SIL_TOOTH_MIN_H, "reactor", "3d", t, "height_m", max(ys) - min(ys),
                       ">=%.1f" % SIL_TOOTH_MIN_H):
            fails.append(t + " height")
        rows.setdefault(t.rsplit("_", 1)[0], []).append(t)
    for row, members in sorted(rows.items()):
        if not sil_say(len(members) <= SIL_TOOTH_PER_ROW, "reactor", "3d", row, "teeth", len(members),
                       "<=%d" % SIL_TOOTH_PER_ROW):
            fails.append(row + " count")
    for jaw in ("JawL", "JawR"):
        gap = _jaw_standoff(pts, labels, faces, jaw)
        if not sil_say(gap >= SIL_JAW_STANDOFF, "reactor", "3d", jaw, "standoff_m", gap, ">=%.1f" % SIL_JAW_STANDOFF):
            fails.append(jaw + " standoff")
    return fails


def drum(root):
    p = Part("Drum")
    p.cyl("ancient_enamel", PED_R[0], PED_R[1], 2.0, 16, loc=(0, 0, 1.0), color=ENAMEL)
    p.ring("rubber", PED_R[1] - 0.05, PED_R[1] + 0.14, 0.18, 16, loc=(0, 0, 1.5))
    p.cyl("ancient_enamel", PED_R[1], DRUM_R, DRUM_Z[0] - LOW, 24, loc=(0, 0, (LOW + DRUM_Z[0]) / 2), color=ENAMEL,
          caps=False)
    p.cyl("ancient_enamel", DRUM_R, DRUM_R, DRUM_Z[1] - DRUM_Z[0], 24, loc=(0, 0, sum(DRUM_Z) / 2), color=IRON,
          caps=False)
    p.cyl("ancient_enamel", DRUM_R, 2.0, 0.55, 24, loc=(0, 0, DRUM_Z[1] + 0.275), color=DUST, caps=False)
    p.cyl("ancient_enamel", 2.0, 2.0, 0.1, 24, loc=(0, 0, DRUM_Z[1] + 0.6), color=IRON)
    for z in (DRUM_Z[0] + 0.02, DRUM_Z[1] - 0.02):
        p.ring("rubber", BAND_R[0], BAND_R[1], 0.14, 16, loc=(0, 0, z))
    p.ring("rubber", 0.85, 1.25, 0.24, 16, loc=(0, 0, DRUM_Z[1] + 0.68))
    return finish(p, (0, 0, 0), root)


def jacket(root, k):
    """One ribbed cooling-jacket quarter, 90 degrees round its centre, with a lit seam."""
    mid = 45 + 90 * k
    a0, a1 = math.radians(mid - 45), math.radians(mid + 45)
    skin, rib = JACKET_R
    prof = [(DRUM_R - 0.02, DRUM_Z[0] + 0.1), (skin, DRUM_Z[0] + 0.1)]
    for zc in (3.1, 4.1, 5.1):
        prof += [(skin, zc - 0.16), (rib, zc - 0.1), (rib, zc + 0.1), (skin, zc + 0.16)]
    prof += [(skin, DRUM_Z[1] - 0.1), (DRUM_R - 0.02, DRUM_Z[1] - 0.1)]
    p = Part("Jacket%d" % k)
    sweep(p, "ancient_enamel", prof, a0, a1, 4, ENAMEL)
    seam_deg = SEAM_ANGLES[k]
    p.beam("ancient_enamel", polar(rib + 0.005, seam_deg, 2.7), polar(rib + 0.005, seam_deg, 5.55), 0.06, 0.26,
           color=IRON, roll=math.radians(seam_deg))
    centre = polar(skin, mid, sum(DRUM_Z) / 2)
    obj = finish(p, centre, root)
    s = Part("SeamV%d" % k)
    s.beam("ancient_light", polar(rib + 0.045, seam_deg, 2.8), polar(rib + 0.045, seam_deg, 5.45), 0.05, 0.12,
           roll=math.radians(seam_deg))
    finish(s, polar(rib + 0.045, seam_deg, 4.125), obj)
    return obj


def stack(root, k):
    deg = STACK_ANGLES[k]
    c = polar(STACK_R, deg, 0)
    top = STACK_BASE + 4.0 + (0.4 if k == 0 else 0.0)
    glow0, glow1 = 7.3, top - 1.0
    p = Part("Stack%d" % k)
    p.cyl("ancient_enamel", 0.5, 0.42, 0.55, 10, loc=c + Vector((0, 0, STACK_BASE + 0.275)), color=ENAMEL)
    p.cyl("ancient_enamel", 0.34, 0.34, glow0 - STACK_BASE - 0.55, 12,
          loc=c + Vector((0, 0, (STACK_BASE + 0.55 + glow0) / 2)), color=ENAMEL)
    p.cyl("ancient_enamel", 0.4, 0.4, 0.14, 10, loc=c + Vector((0, 0, glow0 - 0.1)), color=COPPER)
    for j in range(4):
        a = math.radians(45 + 90 * j)
        off = Vector((0.36 * math.cos(a), 0.36 * math.sin(a), 0))
        p.beam("ancient_enamel", c + off + Vector((0, 0, glow0)), c + off + Vector((0, 0, glow1)), 0.08,
               color=IRON)
    p.cyl("ancient_enamel", 0.4, 0.4, 0.14, 10, loc=c + Vector((0, 0, glow1 + 0.1)), color=COPPER)
    p.cyl("ancient_enamel", 0.32, 0.3, top - glow1 - 0.45, 10, loc=c + Vector((0, 0, (glow1 + 0.17 + top - 0.28) / 2)),
          color=ENAMEL)
    p.cyl("ancient_enamel", 0.36, 0.32, 0.28, 10, loc=c + Vector((0, 0, top - 0.14)), color=IRON)
    obj = finish(p, c + Vector((0, 0, STACK_BASE)), root)
    g = Part("StackGlow%d" % k)
    smooth(g.cyl("ancient_light", 0.29, 0.29, glow1 - glow0, 10, loc=c + Vector((0, 0, (glow0 + glow1) / 2)),
                 caps=False))
    finish(g, c + Vector((0, 0, (glow0 + glow1) / 2)), obj)
    return obj


def cage_half(root, side):
    """Half the dome lattice: three meridian bars and two half rings, a lit base arc."""
    p = Part("CageR" if side > 0 else "CageL")
    centre = Vector((0, 0, CAGE_BASE))
    for j in range(3):
        a = (-60 + 60 * j) if side > 0 else (120 + 60 * j)
        pts = []
        for i in range(4):
            phi = (math.pi / 2) * i / 3 * 0.92
            r = CAGE_R * math.cos(phi)
            pts.append(polar(r, a, CAGE_BASE + (CAGE_TOP - CAGE_BASE) * math.sin(phi)))
        for u, v in zip(pts, pts[1:]):
            smooth(p.rod("bare_metal", u, v, 0.07, 5))
    arc = (-math.pi / 2, math.pi / 2) if side > 0 else (math.pi / 2, 3 * math.pi / 2)
    p.ring("bare_metal", CAGE_R - 0.08, CAGE_R + 0.1, 0.16, 8, loc=centre, arc=arc)
    p.ring("bare_metal", CAGE_R * 0.72 - 0.06, CAGE_R * 0.72 + 0.06, 0.1, 8,
           loc=centre + Vector((0, 0, (CAGE_TOP - CAGE_BASE) * 0.68)), arc=arc)
    p.ring("ancient_light", CAGE_R + 0.1, CAGE_R + 0.16, 0.07, 8, loc=centre + Vector((0, 0, 0.02)), arc=arc)
    return finish(p, centre, root)


def core(root):
    p = Part("WeakPoint")
    smooth(p.uv("ancient_light", 0.9, 12, 8, loc=(0, 0, CORE_Z)))
    return finish(p, (0, 0, CORE_Z), root)


def tooth(part, r0, r1, deg, z, width, height, color, r_tip=None, width_out=None):
    """A fang in the jaw's arc at angle deg: a base width wide at r0 (width_out at r1) on z, its
    point height above it (negative points down) as an edge from r0 to r_tip, so the outer face
    slopes back toward the drum and only the root stands proud of the lip (KF7c). The narrower
    outer root keeps its corners inside the 3.8 m reach. Returns its faces."""
    a = math.radians(deg)
    t = Vector((-math.sin(a), math.cos(a), 0.0))
    n = Vector((math.cos(a), math.sin(a), 0.0))
    up = Vector((0.0, 0.0, 1.0))
    base = Vector((0.0, 0.0, z))
    r_tip = r1 if r_tip is None else r_tip
    bm = part.bm
    wo = width if width_out is None else width_out
    b = [bm.verts.new(base + n * r + t * s) for r, s in ((r0, -width / 2), (r1, -wo / 2), (r1, wo / 2),
                                                         (r0, width / 2))]
    tip = [bm.verts.new(base + n * r + up * height) for r in (r0, r_tip)]
    faces = [bm.faces.new(b), bm.faces.new((b[1], b[2], tip[1])), bm.faces.new((b[3], b[0], tip[0])),
             bm.faces.new((b[0], b[1], tip[1], tip[0])), bm.faces.new((b[2], b[3], tip[0], tip[1]))]
    return part.paint(faces, "ancient_enamel", color)


def jaw(root, side):
    """One cast jaw, modelled in the +X frame and turned to its side.

    2026-10-11 (w13 KF7b): the KF8-LOOK blind read saw these jaws as a tapered skirt and their
    copper rods as thin pipes: the jaws now wrap 100 degrees of the drum, with
    sandstone lips and light fangs over the dark jacket.
    2026-10-11 (w13 KF7c fix round): now two lips that close at the corners round a lens-shaped
    maw, three fangs per lip (see LIP_H and TEETH), the rams' lugs on the corners."""
    p = Part("JawR" if side > 0 else "JawL")
    r0, r1 = JAW_R
    z0, z1 = JAW_Z
    slab = "jawslab_" + p.name
    tagged(p, slab, sweep_var, p, "ancient_enamel",
           lambda a: [(r0 + 0.05, z0), (r1, z0 + 0.35), (r1, maw(a)[0]), (r0, maw(a)[0])], -JAW_SPAN, JAW_SPAN, JAW_SEGS, SAND)
    tagged(p, slab, sweep_var, p, "ancient_enamel",
           lambda a: [(r0, maw(a)[1]), (r1, maw(a)[1]), (r1, z1 - 0.3), (r0 + 0.05, z1)], -JAW_SPAN, JAW_SPAN, JAW_SEGS, SAND)
    for n, (deg, h_low, h_up, width) in enumerate(TEETH):
        low, up = maw(math.radians(deg))
        root_r = TOOTH_R[1] if deg == 0.0 else TOOTH_SIDE_R
        tagged(p, "tooth_%s_lower_%d" % (p.name, n), tooth, p, TOOTH_R[0], root_r, deg, low - 0.05, width,
               h_low, TOOTH, min(root_r, TOOTH_R[2]), TOOTH_W_OUT)
        tagged(p, "tooth_%s_upper_%d" % (p.name, n), tooth, p, TOOTH_R[0], root_r, deg, up + 0.05, width,
               -h_up, TOOTH, min(root_r, TOOTH_R[2]), TOOTH_W_OUT)
    label = ram_label(0.0 if side > 0 else 180.0)
    bearing = math.atan2(RAM_LUG.y, RAM_LUG.x)
    seat = Vector((3.08 * math.cos(bearing), 3.08 * math.sin(bearing), RAM_LUG.z - 0.18))
    tagged(p, label, p.beam, "ancient_enamel", seat, RAM_LUG, 0.46, 0.42, color=SAND_DARK)
    tagged(p, label, p.cyl, "ancient_enamel", 0.15, 0.15, 0.66, 8, loc=RAM_LUG,
           rot=(math.pi / 2, 0, 0), color=TOOTH)
    p.cyl("ancient_enamel", 0.1, 0.1, 0.75, 8, loc=(r0 + 0.06, 0.0, z0 + 0.12), rot=(math.pi / 2, 0, 0), color=IRON)
    return finish(p, HINGE, root, rot_z=0.0 if side > 0 else math.pi)


def gate(root, side):
    """A spillway leaf lying on the back rim, hinged on its outer edge (+X frame)."""
    p = Part("GateR" if side > 0 else "GateL")
    p.box("ancient_enamel", (1.0, 1.3, 0.14), loc=(2.85 - 0.5, 0, 6.12), color=DUST)
    for y in (-0.45, 0.0, 0.45):
        p.box("ancient_enamel", (1.0, 0.1, 0.12), loc=(2.35, y, 6.24), color=IRON)
    p.cyl("ancient_enamel", 0.1, 0.1, 1.4, 8, loc=(2.85, 0, 6.08), rot=(math.pi / 2, 0, 0), color=COPPER)
    return finish(p, (2.85, 0, 6.08), root, rot_z=math.radians(90 + 42 * (-side)))


def pour_lip(root):
    """The slag spout at the front foot of the drum, hinged at the drum (+X frame)."""
    p = Part("PourLip")
    p.box("ancient_enamel", (0.5, 1.1, 0.12), loc=(2.7, 0, 2.55), color=IRON)
    for y in (-0.55, 0.55):
        p.box("ancient_enamel", (0.5, 0.1, 0.3), loc=(2.7, y, 2.66), color=ENAMEL)
    return finish(p, (2.45, 0, 2.6), root, rot_z=math.radians(270))


def steam(root):
    p = Part("SteamRing")
    res = bmesh.ops.create_cone(p.bm, cap_ends=False, segments=12, radius1=3.0, radius2=3.2, depth=0.3,
                                matrix=common.mtx((0, 0, 2.25)))
    smooth(p.paint(p._faces(res["verts"]), "glass"))
    obj = finish(p, (0, 0, 2.25), root)
    obj.scale = (0.02, 0.02, 0.02)
    return obj


def hardpoint(root):
    p = Part("Hardpoint")
    p.cyl("ancient_enamel", 0.42, 0.32, 0.25, 10, loc=(0, 0, CAGE_TOP + 0.05), color=IRON)
    p.ring("ancient_enamel", 0.22, 0.4, 0.14, 10, loc=(0, 0, CAGE_TOP + 0.55), rot=(math.pi / 2, 0, 0), color=ENAMEL)
    p.ring("ancient_light", 0.4, 0.45, 0.06, 10, loc=(0, 0, CAGE_TOP + 0.55), rot=(math.pi / 2, 0, 0))
    return finish(p, (0, 0, CAGE_TOP - 0.08), root)


def seam_ring(root):
    p = Part("SeamRing")
    p.ring("ancient_light", PED_R[1] + 0.09, PED_R[1] + 0.17, 0.07, 16, loc=(0, 0, 1.5))
    return finish(p, (0, 0, 1.5), root)


def ram_columns(root):
    """One rigidly skinned mesh keeps the four moving pieces to one draw."""
    RAM_RIG.clear()
    RAM_MEASURES.clear()
    mount = Part("RamMounts")
    measured(mount, "clamp_ring", mount.ring, "ancient_enamel", 2.38, 3.12, 0.18, 12,
             loc=(0, 0, 2.45), color=IRON)
    moving = Part("JawRams")
    layer = moving.bm.verts.layers.int.new("ram_bone")
    bones = []
    records = []
    for side in (1, -1):
        label = ram_label(0 if side > 0 else 180)
        base = Vector((side * RAM_BASE.x, side * RAM_BASE.y, RAM_BASE.z))
        eye = Vector((side * RAM_LUG.x, side * RAM_LUG.y, RAM_LUG.z))
        axis = (eye - base).normalized()
        foot = polar(2.92, math.degrees(math.atan2(base.y, base.x)), 2.55)
        measured(mount, label + "_base_clevis", tagged, mount, label, mount.beam,
                 "ancient_enamel", foot, base, 0.40, 0.38, color=SAND_DARK)
        measured(mount, label + "_base_clevis", tagged, mount, label, mount.cyl,
                 "ancient_enamel", 0.16, 0.16, 0.72, 8, loc=base,
               rot=(math.pi / 2, 0, 0), color=TOOTH)

        def piece(bone_name, fn, *args, **kwargs):
            measure = kwargs.pop("measure", None)
            if bone_name not in bones:
                bones.append(bone_name)
            if measure:
                faces = measured(moving, measure, tagged, moving, label, fn, *args, **kwargs)
            else:
                faces = tagged(moving, label, fn, *args, **kwargs)
            for face in faces:
                for vertex in face.verts:
                    vertex[layer] = bones.index(bone_name) + 1
            return faces

        barrel_name, rod_name = label + "_barrel", label + "_rod"
        piece(barrel_name, moving.beam, "hydraulic", base, base + axis * RAM_BASE_NECK, 0.32, color=common.mix("charcoal", "petrol", 0.1))
        smooth(piece(barrel_name, moving.rod, "hydraulic", base + axis * RAM_BASE_NECK,
                     base + axis * (RAM_BASE_NECK + RAM_BARREL_LENGTH), RAM_BARREL_R, 8,
                     color=common.mix("charcoal", "petrol", 0.1), measure=label + "_barrel"))
        piece(barrel_name, moving.rod, "hydraulic", base + axis * (RAM_MOUTH - RAM_GLAND_LENGTH),
              base + axis * RAM_MOUTH, RAM_GLAND_R, 10, color=COPPER)
        for offset in (-0.20, 0.20):
            piece(barrel_name, moving.cyl, "hydraulic", 0.28, 0.28, 0.10, 8,
                  loc=base + Vector((0, offset, 0)), rot=(math.pi / 2, 0, 0), color=COPPER)
        smooth(piece(rod_name, moving.rod, "hydraulic", eye - axis * 1.95,
                     eye - axis * RAM_EYE_R, RAM_ROD_R, 10, color=ROD_STEEL, measure=label + "_rod"))
        for offset in (-0.20, 0.20):
            piece(rod_name, moving.cyl, "hydraulic", RAM_EYE_R, RAM_EYE_R, 0.10, 8,
                  loc=eye + Vector((0, offset, 0)), rot=(math.pi / 2, 0, 0), color=COPPER)
        records.append((label, side, base, eye, axis, barrel_name, rod_name, foot))
    mounts = finish(mount, (0, 0, 0), root)
    mesh = finish(moving, (0, 0, 0), root)
    codes = mesh.data.attributes["ram_bone"]
    for i, name in enumerate(bones):
        group = mesh.vertex_groups.new(name=name)
        group.add([v.index for v in mesh.data.vertices if codes.data[v.index].value == i + 1], 1.0, "REPLACE")
    mesh.data.attributes.remove(codes)
    arm = bpy.data.objects.new("RamRig", bpy.data.armatures.new("RamRig"))
    bpy.context.scene.collection.objects.link(arm)
    arm.parent = root
    arm["world_origin"] = [0, 0, 0]
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for label, side, base, eye, axis, bn, rn, foot in records:
        for name, head in ((bn, base), (rn, eye)):
            bone = arm.data.edit_bones.new(name)
            bone.head, bone.tail = head, head + axis
    bpy.ops.object.mode_set(mode="OBJECT")
    arm.select_set(False)
    mod = mesh.modifiers.new("Rigid ram pieces", "ARMATURE")
    mod.object = arm
    for label, side, base, eye, axis, bn, rn, foot in records:
        barrel, rod = arm.pose.bones[bn], arm.pose.bones[rn]
        barrel.rotation_mode = rod.rotation_mode = "QUATERNION"
        jaw_obj = bpy.data.objects["JawR" if side > 0 else "JawL"]
        RAM_RIG.append({"label": label, "base": (mounts, base),
                        "mouth": (barrel, (0, RAM_MOUTH, 0)), "eye": (rod, (0, 0, 0)),
                        "lug": (jaw_obj, RAM_LUG - HINGE), "rod_inner": (rod, (0, -1.95, 0)),
                        "barrel": barrel, "rod": rod, "rest_axis": axis,
                        "barrel_rest": barrel.bone.matrix_local.copy(),
                        "rod_rest": rod.bone.matrix_local.copy(),
                        "eye_r": RAM_EYE_R})
    solve_rams()


def solve_rams():
    bpy.context.view_layer.update()
    for rig in RAM_RIG:
        base, eye = ram_world(rig, "base"), ram_world(rig, "lug")
        axis = (eye - base).normalized()
        delta = rig["rest_axis"].rotation_difference(axis).to_matrix().to_4x4()
        for name, target in (("barrel", base), ("rod", eye)):
            mat = delta @ rig[name + "_rest"]
            mat.translation = target
            rig[name].matrix = mat
    bpy.context.view_layer.update()


def build():
    common.reset()
    del TAGS[:]
    root = common.empty("WardenReactor")
    drum(root)
    for k in range(4):
        jacket(root, k)
    for k in range(3):
        stack(root, k)
    cage_half(root, -1)
    cage_half(root, 1)
    core(root)
    jaw(root, -1)
    jaw(root, 1)
    gate(root, -1)
    gate(root, 1)
    pour_lip(root)
    steam(root)
    hardpoint(root)
    seam_ring(root)
    bpy.context.view_layer.update()
    ram_columns(root)
    return root


def smoothstep(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


QUIET_ORDER = ["SeamV0", "SeamV1", "SeamV2", "SeamV3", "StackGlow0", "StackGlow1", "StackGlow2", "SeamRing"]


def controls(clip):
    stacks = ["Stack%d" % k for k in range(3)]
    seams = ["SeamV%d" % k for k in range(4)]
    if clip == "idle":
        return stacks + seams
    if clip == "pulse_warn":
        return stacks + seams + ["CageL", "CageR", "WeakPoint"]
    if clip == "pulse":
        return stacks + ["SteamRing"]
    if clip == "active":
        return ["JawL", "JawR", "CageL", "CageR", "WeakPoint", "RamRig"]
    if clip.startswith("chunk_lost"):
        return ["Jacket%d" % (int(clip[-1]) if clip[-1].isdigit() else 0)]
    if clip == "shrug":
        return ["Hardpoint"]
    if clip == "gates_open":
        return ["GateL", "GateR"]
    if clip == "pour":
        return ["PourLip"]
    if clip == "final_quiet":
        return QUIET_ORDER + stacks + ["WeakPoint"]
    return []


def pose(clip, t, objs, rest):
    """Sets every control of the clip at normalised time t, from its rest."""
    for name in controls(clip):
        o = objs[name]
        loc, rot, scale = rest[name]
        o.location, o.rotation_euler, o.scale = loc.copy(), rot.copy(), scale.copy()
    u = smoothstep(t)
    if clip == "idle":
        for k in range(3):
            objs["Stack%d" % k].location.z += 0.025 * math.sin(math.tau * 2 * t + k * 2.1) - 0.025 * math.sin(k * 2.1)
        breath = 1.0 + 0.12 * (0.5 - 0.5 * math.cos(math.tau * t))
        for k in range(4):
            objs["SeamV%d" % k].scale = rest["SeamV%d" % k][2] * breath
    elif clip == "pulse_warn":
        for k in range(3):
            objs["Stack%d" % k].location.z += STACK_RISE * u
        for k in range(4):
            objs["SeamV%d" % k].scale = rest["SeamV%d" % k][2] * (1.0 + 0.3 * u)
        for name in ("CageL", "CageR"):
            objs[name].scale = rest[name][2] * (1.0 + 0.05 * u)
        objs["WeakPoint"].scale = rest["WeakPoint"][2] * (1.0 + 0.1 * u)
    elif clip == "pulse":
        for k in range(3):
            objs["Stack%d" % k].location.z += STACK_RISE * (1.0 - t * t)
        puff = math.sin(math.pi * min(t / 0.85, 1.0))
        s = 0.02 + 1.3 * puff
        objs["SteamRing"].scale = Vector((s, s, 0.02 + puff))
        objs["SteamRing"].location.z += 0.6 * t
    elif clip == "active":
        objs["JawL"].rotation_euler.y += JAW_LEAN * u
        objs["JawR"].rotation_euler.y += JAW_LEAN * u
        objs["CageL"].location.x -= 0.6 * u
        objs["CageL"].rotation_euler.y -= math.radians(20) * u
        objs["CageR"].location.x += 0.6 * u
        objs["CageR"].rotation_euler.y += math.radians(20) * u
        objs["WeakPoint"].scale = rest["WeakPoint"][2] * (1.0 + 0.3 * u)
    elif clip.startswith("chunk_lost"):
        k = int(clip[-1]) if clip[-1].isdigit() else 0
        o = objs["Jacket%d" % k]
        out = polar(1.0, 45 + 90 * k, 0)
        o.location += out * (1.4 * t) + Vector((0, 0, -4.6 * t * t))
        tangent = Vector((-out.y, out.x, 0))
        o.rotation_euler = (tangent * (-math.radians(35) * t)).to_tuple()
    elif clip == "shrug":
        kick = math.sin(math.pi * t)
        objs["Hardpoint"].location.z += 0.5 * kick
        objs["Hardpoint"].rotation_euler.x += math.radians(18) * kick
    elif clip == "gates_open":
        for name in ("GateL", "GateR"):
            objs[name].rotation_euler.y += math.radians(80) * u
    elif clip == "pour":
        objs["PourLip"].rotation_euler.y += math.radians(30) * math.sin(math.pi * t)
    elif clip == "final_quiet":
        for i, name in enumerate(QUIET_ORDER):
            start = 0.05 + 0.11 * i
            f = smoothstep((t - start) / 0.08)
            objs[name].scale = rest[name][2] * (1.0 - 0.99 * f)
        for k in range(3):
            objs["Stack%d" % k].location.z -= 0.15 * u
        objs["WeakPoint"].scale = rest["WeakPoint"][2] * (1.0 - 0.4 * smoothstep((t - 0.9) / 0.1))

    if any(n in controls(clip) for n in ("JawL", "JawR")):
        solve_rams()


def rest(root):
    return {o.name: (o.location.copy(), o.rotation_euler.copy(), o.scale.copy()) for o in common.tree(root)}


def reset_pose(root, snapshot):
    for o in common.tree(root):
        o.location, o.rotation_euler, o.scale = snapshot[o.name]
    solve_rams()
    bpy.context.view_layer.update()


def animate(root, snapshot):
    scene = bpy.context.scene
    scene.render.fps = FPS
    scene.frame_start = 1
    scene.frame_end = 1 + int(round(max(d for d, _ in CLIPS.values()) * FPS))
    objs = {o.name: o for o in common.tree(root)}
    for clip, (duration, _blend) in CLIPS.items():
        frames = int(round(duration * FPS))
        for name in controls(clip):
            o = objs[name]
            o.animation_data_create()
            act = bpy.data.actions.new(clip + "_" + name)
            act.use_fake_user = True
            o.animation_data.action = act
            for f in range(frames + 1):
                pose(clip, f / frames, objs, snapshot)
                if name == "RamRig":
                    for bone in o.pose.bones:
                        for path in ("location", "rotation_quaternion", "scale"):
                            bone.keyframe_insert(data_path=path, frame=1 + f, group=bone.name)
                else:
                    for path in ("location", "rotation_euler", "scale"):
                        o.keyframe_insert(data_path=path, frame=1 + f, group=name)
            for layer in act.layers:
                for strip in layer.strips:
                    for bag in strip.channelbags:
                        for curve in bag.fcurves:
                            for key in curve.keyframe_points:
                                key.interpolation = "LINEAR"
            o.animation_data.action = None
            track = o.animation_data.nla_tracks.new()
            track.name = clip
            strip = track.strips.new(clip, 1, act)
            strip.extrapolation = "NOTHING"
            track.mute = True
        reset_pose(root, snapshot)


def freeze_rest_export(path, snapshot):
    """NLA export can leave static defaults at the last evaluated pose; pin every node to
    its authored rest (mind_body.py freeze_rest_export) and re-encode the JSON sorted."""
    data = open(path, "rb").read()
    length = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + length])
    for node in doc["nodes"]:
        if node["name"] not in snapshot:
            continue
        loc, rot, scale = snapshot[node["name"]]
        q = rot.to_quaternion()
        node.pop("matrix", None)
        node["translation"] = [loc.x, loc.z, -loc.y]
        node["rotation"] = [q.x, q.z, -q.y, q.w]
        node["scale"] = [scale.x, scale.z, scale.y]
    encoded = json.dumps(doc, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()
    encoded += b" " * ((-len(encoded)) % 4)
    binary = data[20 + length:]
    open(path, "wb").write(struct.pack("<III", 0x46546C67, 2, 20 + len(encoded) + len(binary)) +
                           struct.pack("<II", len(encoded), 0x4E4F534A) + encoded + binary)


def export(root, path, snapshot):
    reset_pose(root, snapshot)
    bpy.context.view_layer.update()
    if common.POLISH is not None:
        polish.bake(root, common.POLISH)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in common.tree(root):
        obj.select_set(True)
        if obj.animation_data:
            for track in obj.animation_data.nla_tracks:
                track.mute = False
    bpy.context.view_layer.objects.active = root
    bpy.context.scene.frame_set(0)
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                              export_yup=True, export_materials="EXPORT", export_vertex_color="ACTIVE",
                              export_animations=True, export_animation_mode="NLA_TRACKS",
                              export_merge_animation="NLA_TRACK", export_anim_slide_to_zero=True,
                              export_frame_range=False, export_force_sampling=True,
                              export_optimize_animation_keep_anim_object=True, export_extras=False,
                              export_cameras=False, export_lights=False)
    for obj in common.tree(root):
        if obj.animation_data:
            for track in obj.animation_data.nla_tracks:
                track.mute = True
    freeze_rest_export(path, snapshot)
    common.canonical_indices(path, vertices=common.POLISH is not None)
    reset_pose(root, snapshot)
    print("EXPORTED", path)


def glb_info(path):
    data = open(path, "rb").read()
    n = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + n])
    tris = verts = draws = 0
    for mesh in doc["meshes"]:
        for prim in mesh["primitives"]:
            tris += doc["accessors"][prim["indices"]]["count"] // 3
            verts += doc["accessors"][prim["attributes"]["POSITION"]]["count"]
            draws += 1
    clips = {}
    for anim in doc.get("animations", []):
        clips[anim["name"]] = max(doc["accessors"][s["input"]]["max"][0] for s in anim["samplers"])
    lights = "KHR_lights_punctual" in doc.get("extensionsUsed", []) or any(
        "KHR_lights_punctual" in node.get("extensions", {}) for node in doc["nodes"])
    textures = [(img.get("name"), ) for img in doc.get("images", [])]
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(), "tris": tris, "verts": verts,
            "draws": draws, "clips": clips, "lights": lights, "images": textures,
            "nodes": sorted(node["name"] for node in doc["nodes"])}


def blender_counts(root):
    tris = draws = 0
    for o in common.tree(root):
        if o.type != "MESH":
            continue
        tris += common.tris(o)
        draws += len({p.material_index for p in o.data.polygons})
    return tris, draws


def collider_rule(root):
    """Rest-pose vertices in the body frame: (lowest, max r under 2 m, max r above)."""
    bpy.context.view_layer.update()
    low = high = 0.0
    bottom = math.inf
    worst = ("", "")
    for o in common.tree(root):
        if o.type != "MESH":
            continue
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            r = math.hypot(w.x, w.y)
            bottom = min(bottom, w.z)
            if w.z <= LOW:
                if r > low:
                    low, worst = r, (o.name, worst[1])
            elif r > high:
                high, worst = r, (worst[0], o.name)
    return bottom, low, high, worst


def check(root, info=None):
    """Fails loud on the budget, the clips, the collider rule and any light node."""
    problems = []
    tris, draws = blender_counts(root)
    bottom, low, high, worst = collider_rule(root)
    print("REACTOR_BLENDER tris=%d draws=%d bottom=%.3f low_r=%.3f (%s) high_r=%.3f (%s)" %
          (tris, draws, bottom, low, worst[0], high, worst[1]))
    if tris > BUDGET["tris"] or draws > BUDGET["draws"]:
        problems.append("budget (blender) tris %d draws %d" % (tris, draws))
    if bottom < -1e-4:
        problems.append("geometry below the base origin: %.3f" % bottom)
    if low > RADIUS + 1e-4:
        problems.append("below 2 m r %.3f passes the collider %.1f (%s)" % (low, RADIUS, worst[0]))
    if high > RADIUS + REACH + 1e-4:
        problems.append("above 2 m r %.3f passes collider + 1 m (%s)" % (high, worst[1]))
    if info is not None:
        print("REACTOR_GLB tris=%d verts=%d draws=%d bytes=%d sha256=%s" %
              (info["tris"], info["verts"], info["draws"], info["bytes"], info["sha256"]))
        for key in ("tris", "verts", "draws"):
            if info[key] > BUDGET[key]:
                problems.append("budget %s %d > %d" % (key, info[key], BUDGET[key]))
        for clip in REQUIRED:
            got = info["clips"].get(clip)
            want = CLIPS[clip][0]
            print("REACTOR_CLIP %s %s want %.2f" % (clip, "missing" if got is None else "%.3f" % got, want))
            if got is None or abs(got - want) > 0.05:
                problems.append("clip %s length %s, want %.2f" % (clip, got, want))
        if info["lights"]:
            problems.append("a light node in the GLB")
        if info["images"]:
            problems.append("textures in the GLB: %s" % info["images"])
    if problems:
        raise SystemExit("warden_reactor check FAILED: " + "; ".join(problems))
    print("warden_reactor check: PASS")


def look_frames(root, out_dir):
    """Cycles CPU frames of the body at rest at 20, 60 and 150 m, front three-quarter at
    the ball's eye height range; plus the hero turntable. The coordinator's in-engine
    look rows are in look_subjects.json beside these frames (KF8 wires the body)."""
    os.makedirs(out_dir, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.cycles.seed = 1979
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("LookSky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.62, 0.72, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    scene.world = world
    bpy.ops.mesh.primitive_plane_add(size=800, location=(0, 0, 0))
    ground = bpy.context.object
    ground.data.materials.append(common._flat("LookGround", "sandstone"))
    sun = bpy.data.lights.new("LookSun", "SUN")
    sun.energy = 3.5
    sun_obj = bpy.data.objects.new("LookSun", sun)
    scene.collection.objects.link(sun_obj)
    sun_obj.rotation_euler = (math.radians(50), 0, math.radians(30))
    cam_data = bpy.data.cameras.new("LookCam")
    cam_data.angle = math.radians(62)
    cam = bpy.data.objects.new("LookCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    shots = []
    for dist in (20, 60, 150):
        eye = Vector((dist * math.sin(math.radians(25)), -dist * math.cos(math.radians(25)), 3.0 + dist * 0.12))
        target = Vector((0, 0, 4.5))
        cam.location = eye
        cam.rotation_euler = (target - eye).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(out_dir, "reactor_%dm.png" % dist)
        bpy.ops.render.render(write_still=True)
        shots.append(scene.render.filepath)
    print("LOOK_FRAMES", " ".join(shots))
    return shots


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    a = common.args()
    root = build()
    snapshot = rest(root)
    animate(root, snapshot)
    reset_pose(root, snapshot)
    silhouette_fails = silhouette(root)
    if silhouette_fails:
        if "--count-only" in argv:
            check(root)
        raise SystemExit("warden_reactor silhouette FAILED: " + ", ".join(silhouette_fails))
    if "--count-only" in argv:
        check(root)
        return
    out = a["out"] or common.default_out("warden_reactor")
    export(root, out, snapshot)
    info = glb_info(out)
    print("REACTOR_NODES", ",".join(info["nodes"]))
    check(root, info)
    if a["render"]:
        look_frames(root, a["render"])


main()
