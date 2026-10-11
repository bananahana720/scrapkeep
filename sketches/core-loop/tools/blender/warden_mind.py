# The Mind's hand, the mind Warden's own body (wardens/mind.md sections 1, 5 and 9; unit KF7).
# An open hand with a lens on a stalk: a palm plate about 7 m across, four three-segment
# fingers and an opposed thumb, a telescoping wrist stalk and a lens cluster of one big lens
# ringed by five small ones. Dull petrol enamel over dark iron; only the seams glow, in
# uranium-glass green, and each finger's seam has its own material so the loader can put
# one out per chunk. Provenance: authored procedurally here from Blender primitives and
# bmesh operators; no external meshes, textures or scans. No light node.
#
# Convention (Godot frame, +Y up, the ball's approach along -Z, author in Godot metres and
# convert once with B()):
#   origin  the body's base centre: the stalk root, where the wrist stalk meets the hand.
#           The mind never touches the ground. The Warden's centre (warden.gd position) is
#           0, 1.6, 0 in this frame; the loader places the GLB at -HALF_HEIGHT as for the clamp.
#   collider  a cylinder of radius 2.8 and half height 1.6 at that centre (warden.gd RADIUS,
#           HALF_HEIGHT). Below 2 m above the base nothing passes r = 2.8; no finger passes
#           1 m beyond the collider's silhouette in the approach view (|x| <= 3.8,
#           -1.0 <= y <= 4.2). To keep a 16 m hand inside that, the fingers lie along the
#           approach axis (-Z), so the ball meets them end on.
#   pose    WardenMind > Pose > Rig (armature) > Body (one skinned mesh). The rest pose is the
#           island hang: palm up, fingers flat along -Z, the stalk hanging with the lens 10 m
#           under the palm surface (lens at y = -6.4, the weak point 8 m under the centre).
#           PoseHang and PosePerch are marker nodes beside Pose: copying PosePerch's transform
#           onto Pose turns the hand palm down (a 180 degree turn about Z through the Palm bone,
#           y 2.9, so the palm stays inside the collider and the fingers sit under it). The held
#           'perch' clip then gives the perch its shape: the stalk telescopes so the lens stands
#           6 m above the grip (the fingers' palm-side face, the perch top), and each finger's
#           last two segments hook down round the perch top like a bird's foot (mind.md
#           section 1). No clip animates Pose, so a played clip never resets the pose.
#   sockets WeakPoint on the Lens bone (the big lens's face) and Hardpoint0..2 on the Knuckle
#           bones (west, east, north on the back of the hand), as bone-attached nodes.
#   bones   every bone points along -Z with roll 0, so its local axes are the model's axes.
#
# Clips are section 5's table, one glTF animation per row, plus the per-finger and per-knuckle
# variants of chunk_lost and shrug (chunk_lost is the little finger, the first to go) and the
# held 'perch' grip. A lost finger folds shut under its neighbours: the last two segments drop
# about a metre and swing inward flat, so its held end pose stays inside the approach band in
# both poses (a fold toward the palm cannot: a 9 m finger at the band's edge has no room). Keyed
# on the armature as actions and exported the way anim_pilot_reactions.py does (ACTIONS mode,
# forced sampling at 30 fps, slid to zero).
#
# Run headless and memory-capped from the repository root:
#   prlimit --as=12884901888 -- blender --background --threads 2 --python-exit-code 1 \
#     --python sketches/core-loop/tools/blender/warden_mind.py -- [--out file.glb] [--count-only]

import hashlib
import json
import math
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Quaternion, Vector  # noqa: E402

import common  # noqa: E402

FPS = 30
HALF_HEIGHT = 1.6
RADIUS = 2.8
CENTRE = (0.0, HALF_HEIGHT, 0.0)
LOW_BAND = 2.0
REACH = 1.0
SIL_X = RADIUS + REACH
SIL_Y = (-REACH, 2 * HALF_HEIGHT + REACH)
LENS_Y = -6.4
POINT_OFFSET = (0.0, LENS_Y - HALF_HEIGHT, 0.0)
# The perch: palm down by a half turn about Z through the Palm bone's head, so the GLB's y maps
# to 2 * PERCH_PIVOT_Y - y and the stalk root (the base) sits at PERCH_BASE.
PERCH_PIVOT_Y = 2.9
PERCH_BASE = 2 * PERCH_PIVOT_Y
GRIP_TO_LENS = 6.0  # mind.md section 1: the lens 6 m above the perch
GRIP_DROP = 2.4  # how far a gripping finger's middle segment hooks down past the perch top
BUDGET = {"tris": 5000, "verts": 9600, "draws": 32}

# Section 5: name -> (length, blend) in seconds. The extras below repeat a row for the
# finger or knuckle the loader picks.
CLIPS = {
    "idle": (4.0, 1.0), "pulse_warn": (2.0, 2.0), "pulse": (0.3, 0.1), "active": (0.5, 0.5),
    "chunk_lost": (1.0, 0.8), "shrug": (0.4, 0.2), "quote": (1.4, 0.2), "grip_falter": (0.5, 0.5),
    "takeoff": (0.6, 0.3), "glide": (3.0, 0.3), "land": (0.5, 0.2), "knocked_down": (1.0, 0.2),
    "final_quiet": (2.0, 2.0),
}
EXTRA_CLIPS = {
    "chunk_lost_ring": (1.0, 0.8), "chunk_lost_middle": (1.0, 0.8), "chunk_lost_index": (1.0, 0.8),
    "shrug_1": (0.4, 0.2), "shrug_2": (0.4, 0.2),
    "perch": (1.0, 0.3),  # held: the grip and the short stalk while perched (stage 6)
}

ENAMEL = "petrol"
IRON = common.mix("charcoal", "petrol", 0.25)
DUST = common.mix("petrol", "sandstone", 0.35)
UNDER = common.mix("petrol", "charcoal", 0.4)

# Fingers, index to little (thumb side +X): x at the knuckle line, segment lengths, and the rest
# fan in radians about +Y (positive turns the tip toward -X), so the four read as a hand and not a
# rake while every tip stays inside the 3.8 m band.
FINGERS = [
    ("index", 2.25, (3.3, 2.75, 2.35), -0.095),
    ("middle", 0.75, (3.6, 3.0, 2.6), -0.03),
    ("ring", -0.75, (3.3, 2.75, 2.35), 0.035),
    ("little", -2.25, (2.8, 2.35, 2.0), 0.11),
]
FINGER_ORDER = ["little", "ring", "middle", "index"]  # the order chunks put them out
KNUCKLE_Z = -3.2
FINGER_Y = 3.55
FINGER_W = 1.25
FINGER_H = 1.0
PALM_Y = (2.4, 3.4)
THUMB = {"x": 3.3, "y": 2.85, "w": 0.8, "h": 0.8,
         "pts": [(3.25, 2.85, 1.6), (3.35, 2.85, -1.0), (3.3, 2.85, -3.1), (3.2, 2.85, -4.8)]}
KNUCKLES = [("west", (-2.0, 2.25, -2.4)), ("east", (2.0, 2.25, -2.4)), ("north", (0.0, 2.25, -2.95))]
STALK = [("Stalk0", 0.0, -1.6, 0.78), ("Stalk1", -1.9, -3.3, 0.7), ("Stalk2", -3.6, -5.0, 0.62)]
DROP = 10.0
SEAM_SLOTS = ["ancient_light_seam%d" % i for i in range(4)] + ["ancient_light_thumb", "ancient_light_knuckle",
                                                               "ancient_light_lens"]
for slot in SEAM_SLOTS:
    common.SLOTS[slot] = dict(common.SLOTS["ancient_light"])


def B(v):
    """Godot (x, y up, z) to Blender (x, y = -z, z up)."""
    return Vector((v[0], -v[2], v[1]))


def G(v):
    return Vector((v[0], v[2], -v[1]))


def qrot(axis, angle):
    return Quaternion(B(axis), angle)


class RigPart(common.Part):
    """A Part whose vertices each belong to one bone (a rigid skin)."""

    def __init__(self, name):
        super().__init__(name)
        self.deform = self.bm.verts.layers.deform.verify()
        self.groups = []

    def on(self, bone, fn, *a, **kw):
        n0 = len(self.bm.verts)
        out = fn(*a, **kw)
        if bone not in self.groups:
            self.groups.append(bone)
        gi = self.groups.index(bone)
        self.bm.verts.ensure_lookup_table()
        for i in range(n0, len(self.bm.verts)):
            self.bm.verts[i][self.deform][gi] = 1.0
        return out


def section(c, right, up, w, h, ch):
    """A chamfered rectangle (8 corners) round c in the plane of right and up."""
    hw, hh = w / 2, h / 2
    pts = [(hw - ch, hh), (-hw + ch, hh), (-hw, hh - ch), (-hw, -hh + ch), (-hw + ch, -hh), (hw - ch, -hh),
           (hw, -hh + ch), (hw, hh - ch)]
    return [c + right * x + up * y for x, y in pts]


def loft(part, rows, slot, color=None, caps=True):
    """Quads between consecutive rings of Godot points (same count each); caps close the ends."""
    vs = [[part.bm.verts.new(B(p)) for p in row] for row in rows]
    faces = []
    n = len(rows[0])
    for k in range(len(rows) - 1):
        for i in range(n):
            j = (i + 1) % n
            faces.append(part.bm.faces.new((vs[k][i], vs[k][j], vs[k + 1][j], vs[k + 1][i])))
    if caps:
        faces.append(part.bm.faces.new(vs[0]))
        faces.append(part.bm.faces.new(list(reversed(vs[-1]))))
    bmesh.ops.recalc_face_normals(part.bm, faces=faces)
    return part.paint(faces, slot, color)


def segment(part, bone, a, b, w0, h0, w1, h1, color=ENAMEL):
    """One finger or thumb segment from a to b (Godot), a chamfered box that tapers."""
    a, b = Vector(a), Vector(b)
    d = (b - a).normalized()
    up = Vector((0, 1, 0))
    right = d.cross(up).normalized()
    up = right.cross(d).normalized()
    rows = [section(a + d * 0.05, right, up, w0 * 0.9, h0 * 0.85, 0.22),
            section(a + d * 0.35, right, up, w0, h0, 0.25),
            section(b - d * 0.3, right, up, w1, h1, 0.22),
            section(b - d * 0.02, right, up, w1 * 0.86, h1 * 0.8, 0.2)]
    part.on(bone, loft, part, rows, "ancient_enamel", color)
    return right, up


def seam(part, bone, slot, a, b, out, width):
    """A lit seam over a dark groove twice its width, along a surface with normal out."""
    a, b, out = Vector(a), Vector(b), Vector(out).normalized()
    part.on(bone, part.beam, "rubber", B(a), B(b), width * 2.0, 0.08, roll=0.0)
    part.on(bone, part.beam, slot, B(a + out * 0.04), B(b + out * 0.04), width, 0.06, roll=0.0)


def joint(part, bone, at, r, length):
    """A dark iron knuckle drum across the finger (axis X)."""
    part.on(bone, part.cyl, "ancient_enamel", r, r, length, 8, loc=B(at), rot=(0, math.pi / 2, 0), color=IRON)


def finger_points(x, lengths, fan):
    d = Vector((-math.sin(fan), 0, -math.cos(fan)))
    pts = [Vector((x, FINGER_Y, KNUCKLE_Z))]
    for seg in lengths:
        pts.append(pts[-1] + d * seg)
    return pts


def build_body():
    p = RigPart("Body")
    bones = []  # (name, head, parent)
    bones.append(("Hand", CENTRE, None))
    # Wrist collar, origin to the palm: within r 1.6, below the 2 m band's 2.8.
    p.on("Hand", p.cyl, "ancient_enamel", 1.15, 1.45, 1.5, 12, loc=B((0, 0.75, 0)), color=ENAMEL)
    p.on("Hand", p.cyl, "ancient_enamel", 1.6, 1.6, 0.35, 12, loc=B((0, 1.65, 0)), color=IRON)
    p.on("Hand", p.cyl, "ancient_enamel", 1.45, 1.75, 0.6, 12, loc=B((0, 2.1, 0)), color=ENAMEL)
    # Palm plate: a chamfered slab, wider at the knuckle line, the heel at +Z.
    bones.append(("Palm", (0.0, 2.9, 0.0), "Hand"))
    outline = [(2.95, -3.35), (2.95, -1.0), (2.75, 1.5), (2.35, 3.0), (1.3, 3.75), (-1.3, 3.75), (-2.35, 3.0),
               (-2.75, 1.5), (-2.95, -1.0), (-2.95, -3.35), (-1.6, -3.6), (1.6, -3.6)]
    y0, y1 = PALM_Y

    def ring(y, inset):
        out = []
        for x, z in outline:
            v = Vector((x, 0, z))
            out.append(Vector((x - math.copysign(inset, x), y, z - math.copysign(inset, z))) if v.length else v)
        return out
    rows = [ring(y0, 0.3), ring(y0 + 0.25, 0.0), ring(y1 - 0.3, 0.0), ring(y1, 0.3)]
    p.on("Palm", loft, p, rows, "ancient_enamel", ENAMEL)
    # Thenar pad at the thumb root and a shallow lip round the palm's cup.
    p.on("Palm", p.ico, "ancient_enamel", 1.0, 1, loc=B((2.55, 3.0, 1.0)), scale=(0.85, 1.8, 0.55), color=ENAMEL)
    p.on("Palm", p.ring, "ancient_enamel", 1.2, 1.55, 0.18, 12, loc=B((0, y1 + 0.05, 0.4)), color=IRON)
    # The back of the hand: radial ribs from the wrist collar toward the fingers.
    for k, x in enumerate((-2.0, 0.0, 2.0)):
        p.on("Palm", p.beam, "ancient_enamel", B((x * 0.45, y0 - 0.05, -0.8)), B((x, y0 - 0.05, -3.1)), 0.5, 0.18,
             color=IRON)
    # Knuckle hardpoints on the back: a dome, a dark groove and a green rim, bottoms at 2.05 m.
    for i, (_, at) in enumerate(KNUCKLES):
        name = "Knuckle%d" % i
        bones.append((name, at, "Palm"))
        c = Vector(at)
        p.on(name, p.uv, "ancient_enamel", 0.62, 10, 4, loc=B(c + Vector((0, 0.05, 0))), scale=(1, 1, 0.42),
             color=ENAMEL)
        p.on(name, p.ring, "rubber", 0.6, 0.86, 0.14, 12, loc=B(c + Vector((0, 0.12, 0))))
        p.on(name, p.ring, "ancient_light_knuckle", 0.66, 0.8, 0.16, 12, loc=B(c + Vector((0, 0.1, 0))))
    # Fingers: three segments, a drum at each joint, the seam on top and underneath.
    for fi, (fname, x, lengths, fan) in enumerate(FINGERS):
        slot = "ancient_light_seam%d" % fi
        pts = finger_points(x, lengths, fan)
        parent = "Palm"
        scale = (1.0, 0.94, 0.86, 0.78)
        for s in range(3):
            name = "Finger%d_%d" % (fi, s)
            bones.append((name, tuple(pts[s]), parent))
            parent = name
            w0, w1 = FINGER_W * scale[s], FINGER_W * scale[s + 1]
            h0, h1 = FINGER_H * scale[s], FINGER_H * scale[s + 1]
            _, up = segment(p, name, pts[s], pts[s + 1], w0, h0, w1, h1)
            joint(p, name, pts[s], h0 * 0.5, w0 * 0.92)
            a = pts[s] + Vector((0, 0, -0.55))
            b = pts[s + 1] + Vector((0, 0, 0.45))
            seam(p, name, slot, a + up * (h0 + h1) / 4, b + up * (h0 + h1) / 4, up, 0.11)
            seam(p, name, slot, a - up * (h0 + h1) / 4, b - up * (h0 + h1) / 4, -up, 0.11)
        # The fingertip: a blunt cast cap.
        tip = pts[3]
        p.on(parent, p.ico, "ancient_enamel", 0.5, 1, loc=B(tip + Vector((0, 0, 0.1))), scale=(0.95, 0.75, 0.8),
             color=ENAMEL)
    # Thumb, opposed along the +X side, below the index.
    tp = [Vector(v) for v in THUMB["pts"]]
    parent = "Palm"
    for s in range(3):
        name = "Thumb_%d" % s
        bones.append((name, tuple(tp[s]), parent))
        parent = name
        k0, k1 = 1.0 - 0.1 * s, 0.9 - 0.1 * s
        _, up = segment(p, name, tp[s], tp[s + 1], THUMB["w"] * k0, THUMB["h"] * k0, THUMB["w"] * k1,
                        THUMB["h"] * k1)
        joint(p, name, tp[s], THUMB["h"] * k0 * 0.5, THUMB["w"] * k0 * 0.9)
        d = (tp[s + 1] - tp[s]).normalized()
        seam(p, name, "ancient_light_thumb", tp[s] + d * 0.4 + up * THUMB["h"] * k0 * 0.5,
             tp[s + 1] - d * 0.3 + up * THUMB["h"] * k1 * 0.5, up, 0.09)
    p.on(parent, p.ico, "ancient_enamel", 0.36, 1, loc=B(tp[3]), scale=(0.95, 0.85, 0.85), color=ENAMEL)
    # The wrist stalk: three ribbed sleeves, each with a dark core that hides in the sleeve
    # above it at rest and bridges the gap when the stalk telescopes down 10 m.
    parent = "Hand"
    for i, (name, ya, yb, r) in enumerate(STALK):
        bones.append((name, (0.0, ya, 0.0), parent))
        parent = name
        p.on(name, p.cyl, "ancient_enamel", r, r * 0.9, ya - yb, 10, loc=B((0, (ya + yb) / 2, 0)), color=ENAMEL)
        for yy in (ya - 0.25, yb + 0.25):
            p.on(name, p.cyl, "ancient_enamel", r * 1.12, r * 1.12, 0.22, 10, loc=B((0, yy, 0)), color=IRON)
        if i > 0:
            p.on(name, p.cyl, "rubber", 0.34, 0.34, 4.0, 8, loc=B((0, ya + 2.0, 0)))
    # LensMount carries the last core and the 10 m drop; Lens, its child, only turns and opens,
    # so a tracked lens never swings its core out of the stalk.
    bones.append(("LensMount", (0.0, LENS_Y, 0.0), parent))
    bones.append(("Lens", (0.0, LENS_Y, 0.0), "LensMount"))
    p.on("LensMount", p.cyl, "rubber", 0.3, 0.3, 4.0, 8, loc=B((0, LENS_Y + 2.6, 0)))
    # Lens cluster: a cast housing facing -Z (the loader turns the Lens bone toward the ball),
    # one big lens 1.8 m across ringed by five small ones.
    lc = Vector((0, LENS_Y, 0))
    p.on("Lens", p.uv, "ancient_enamel", 1.75, 12, 8, loc=B(lc), scale=(1.0, 0.72, 1.0), color=ENAMEL)
    p.on("Lens", p.cyl, "ancient_enamel", 0.95, 0.6, 0.6, 12, loc=B(lc + Vector((0, 0.95, 0.3))), color=IRON)
    face = lc + Vector((0, 0, -1.22))
    face_rot = (math.pi / 2, 0, 0)
    p.on("Lens", p.cyl, "ancient_enamel", 1.12, 1.18, 0.3, 16, loc=B(face + Vector((0, 0, 0.1))), rot=face_rot,
         color=IRON)
    p.on("Lens", p.cyl, "rubber", 0.98, 0.98, 0.14, 16, loc=B(face + Vector((0, 0, -0.04))), rot=face_rot)
    bones.append(("LensIris", tuple(face), "Lens"))
    p.on("LensIris", p.cyl, "ancient_light_lens", 0.9, 0.9, 0.12, 16, loc=B(face + Vector((0, 0, -0.1))),
         rot=face_rot)
    for k in range(5):
        a = math.pi / 2 + k * math.tau / 5
        at = lc + Vector((1.38 * math.cos(a), 1.38 * math.sin(a) * 0.95, -1.0))
        name = "SmallLens%d" % k
        p.on("Lens", p.cyl, "ancient_enamel", 0.33, 0.36, 0.3, 8, loc=B(at), rot=face_rot, color=IRON)
        p.on("Lens", p.cyl, "rubber", 0.27, 0.27, 0.1, 8, loc=B(at + Vector((0, 0, -0.12))), rot=face_rot)
        bones.append((name, tuple(at + Vector((0, 0, -0.18))), "Lens"))
        p.on(name, p.cyl, "ancient_light_lens", 0.23, 0.23, 0.08, 8, loc=B(at + Vector((0, 0, -0.18))),
             rot=face_rot)
    dust(p)
    return p, bones


def dust(part):
    """Sandstone dust on the enamel's up faces, shade on its under faces (hang pose)."""
    part.bm.normal_update()
    idx = part.slots.index("ancient_enamel")
    enamel = common.rgba(ENAMEL)
    for f in part.bm.faces:
        if f.material_index != idx:
            continue
        c = f.loops[0][part.col]
        if max(abs(c[i] - enamel[i]) for i in range(3)) > 1e-4:
            continue
        if f.normal.z > 0.6:
            part.paint([f], "ancient_enamel", DUST)
        elif f.normal.z < -0.3:
            part.paint([f], "ancient_enamel", UNDER)


def make_rig(bones):
    arm_data = bpy.data.armatures.new("Rig")
    arm = bpy.data.objects.new("Rig", arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    made = {}
    for name, head, parent in bones:
        eb = arm_data.edit_bones.new(name)
        eb.head = B(head)
        eb.tail = B(head) + Vector((0, 0.5, 0))
        eb.roll = 0.0
        eb.use_deform = True
        if parent:
            eb.parent = made[parent]
        made[name] = eb
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return arm


def socket(name, arm, bone, at):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_size = 0.3
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = arm
    obj.parent_type = "BONE"
    obj.parent_bone = bone
    bpy.context.view_layer.update()
    obj.matrix_world = Matrix.Translation(B(at))
    return obj


# --- clips -----------------------------------------------------------------------------

def bump(t, a, b):
    """0 outside [a, b], a smooth hump to 1 at its middle."""
    if t <= a or t >= b:
        return 0.0
    return math.sin(math.pi * (t - a) / (b - a)) ** 2


def ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def curl_finger(out, fi, angles):
    for s, a in enumerate(angles):
        name = "Finger%d_%d" % (fi, s)
        rot, loc, scl = out.get(name, (Quaternion(), Vector(), Vector((1, 1, 1))))
        out[name] = (qrot((1, 0, 0), a) @ rot, loc, scl)


def turn(out, name, axis, angle):
    rot, loc, scl = out.get(name, (Quaternion(), Vector(), Vector((1, 1, 1))))
    out[name] = (qrot(axis, angle) @ rot, loc, scl)


def move(out, name, v):
    rot, loc, scl = out.get(name, (Quaternion(), Vector(), Vector((1, 1, 1))))
    out[name] = (rot, loc + B(v), scl)


def scale(out, name, s):
    rot, loc, scl = out.get(name, (Quaternion(), Vector(), Vector((1, 1, 1))))
    sv = Vector(s) if hasattr(s, "__len__") else Vector((s, s, s))
    out[name] = (rot, loc, Vector((scl.x * sv.x, scl.y * sv.z, scl.z * sv.y)))


SPLAY = [-0.02, -0.01, 0.01, 0.03]  # extra fan about +Y, index to little, on top of the rest fan
CURL_SHUT = (1.2, 1.35, 1.15)
# A lost finger's fold: the middle segment pitches down, then both swing inward (toward the
# hand's middle) to these world yaws, the last segment flat, so the dead finger lies folded
# under its neighbours and never leaves |x| <= 3.8, 1.6 <= y <= 4.2 (both poses' band).
FOLD_PITCH = 0.36
FOLD_YAW = (2.0, 4.2)
# The perch stalk: the lens moves up the stalk by perch_lift(), shared Stalk1, Stalk2, LensMount.
PERCH_LIFT_SHARE = (0.22, 0.38, 0.40)


def grip_hang_y():
    """The fingers' palm-side face at rest (hang y), the face that sits on a perch top."""
    return FINGER_Y + FINGER_H / 2 + 0.064  # the top seam's lift; check() measures the real face


def perch_lift():
    lens_perch = PERCH_BASE - grip_hang_y() + GRIP_TO_LENS
    return (PERCH_BASE - lens_perch) - LENS_Y


def fold_finger(out, fi, c, shiver=0.0):
    """The chunk_lost fold of finger fi at progress c (0..1)."""
    s = 1.0 if FINGERS[fi][1] > 0 else -1.0
    drop = ease(c / 0.4)
    # The middle segment swings first; the last swings after it, the short way back toward the
    # finger's own side (FOLD_YAW[1] - tau), so mid-fold it never points out past the band.
    swing1 = ease(c / 0.7)
    swing2 = ease((c - 0.35) / 0.65)
    w1 = qrot((0, 1, 0), s * FOLD_YAW[0] * swing1) @ qrot((1, 0, 0), -FOLD_PITCH * drop + shiver)
    w2 = qrot((0, 1, 0), s * (FOLD_YAW[1] - math.tau) * swing2) @ qrot((1, 0, 0), shiver * 0.5)
    for name, rot in (("Finger%d_1" % fi, w1), ("Finger%d_2" % fi, w1.inverted() @ w2)):
        _, loc, scl = out.get(name, (Quaternion(), Vector(), Vector((1, 1, 1))))
        out[name] = (rot, loc, scl)


def pose(clip, t):
    """Bone -> (rotation, location, scale) in Blender pose space at clip time t (0..1)."""
    out = {}
    fidx = {f[0]: i for i, f in enumerate(FINGERS)}
    if clip == "idle":
        for k, fname in enumerate(FINGER_ORDER):
            w = bump(t, k * 0.25, k * 0.25 + 0.35) if k < 3 else bump(t, 0.72, 1.0)
            curl_finger(out, fidx[fname], (-0.05 * w, -0.03 * w, -0.02 * w))
        turn(out, "Lens", (0, 1, 0), 0.06 * math.sin(math.tau * t))
        turn(out, "Lens", (1, 0, 0), 0.03 * math.sin(math.pi * 2 * t))
    elif clip == "pulse_warn":
        narrow = ease(t / 0.6)
        scale(out, "LensIris", (1 - 0.45 * narrow, 1 - 0.45 * narrow, 1))
        for k in range(5):
            c = 0.1 + 0.17 * k
            s = 1 - 0.9 * bump(t, c - 0.06, c + 0.06)
            scale(out, "SmallLens%d" % k, (s, s, 1))
        for fi in range(4):
            tighten = ease(t)
            turn(out, "Finger%d_0" % fi, (0, 1, 0), -SPLAY[fi] * 0.6 * tighten)
            curl_finger(out, fi, (-0.025 * tighten, -0.02 * tighten, 0.0))
    elif clip == "pulse":
        snap = math.sin(math.pi * t)
        for fi in range(4):
            curl_finger(out, fi, (-0.06 * snap, -0.03 * snap, -0.02 * snap))
            turn(out, "Finger%d_0" % fi, (0, 1, 0), SPLAY[fi] * snap)
    elif clip == "active":
        o = ease(t)
        for fi in range(4):
            turn(out, "Finger%d_0" % fi, (0, 1, 0), SPLAY[fi] * o)
            curl_finger(out, fi, (-0.04 * o, -0.02 * o, 0.0))
        scale(out, "Lens", 1.0 + 0.3 * o)
        scale(out, "LensIris", 1.0 + 0.1 * o)
    elif clip.startswith("chunk_lost"):
        fname = {"chunk_lost": "little", "chunk_lost_ring": "ring", "chunk_lost_middle": "middle",
                 "chunk_lost_index": "index"}[clip]
        c = min(1.0, t / 0.8)
        shiver = 0.04 * math.sin(math.tau * 3 * t) * (1 - ease(c))
        fold_finger(out, fidx[fname], c, shiver)
    elif clip == "perch":
        # Held, one pose for the whole clip: the land clip and the mixer's blend bring it in.
        for fi, (_, _, lengths, _) in enumerate(FINGERS):
            c1 = math.asin(min(1.0, GRIP_DROP / lengths[1]))
            curl_finger(out, fi, (0.0, c1, math.pi + 0.1 - c1))
        turn(out, "Thumb_1", (1, 0, 0), 0.45)
        turn(out, "Thumb_2", (1, 0, 0), 0.6)
        lift = perch_lift()
        for name, share in zip(("Stalk1", "Stalk2", "LensMount"), PERCH_LIFT_SHARE):
            move(out, name, (0, lift * share, 0))
    elif clip.startswith("shrug"):
        k = {"shrug": 0, "shrug_1": 1, "shrug_2": 2}[clip]
        _, at = KNUCKLES[k]
        flick = math.sin(math.pi * t)
        out_dir = Vector((at[0], 0, at[2])).normalized() * 0.5 + Vector((0, -0.5, 0))
        move(out, "Knuckle%d" % k, out_dir * flick)
        scale(out, "Knuckle%d" % k, 1 + 0.25 * flick)
    elif clip == "quote":
        for k in range(5):
            s = 1 - 0.92 * bump(t, k / 5.0, (k + 1) / 5.0)
            scale(out, "SmallLens%d" % k, (s, s, 1))
        scale(out, "LensIris", 1 - 0.15 * math.sin(math.pi * t))
    elif clip == "grip_falter":
        d = ease(t)
        for name in ("Stalk1", "Stalk2", "LensMount"):
            move(out, name, (0, -DROP / 3 * d, 0))
        scale(out, "Lens", 1 + 0.3 * d)
        for fi in range(4):
            curl_finger(out, fi, (-0.05 * d, -0.03 * d, 0.0))
    elif clip == "takeoff":
        push = math.sin(math.pi * min(1.0, t / 0.5))
        move(out, "Hand", (0, -0.5 * push, 0))
        f = ease(t)
        for fi in range(4):
            curl_finger(out, fi, tuple(a * f for a in CURL_SHUT))
        for s, a in enumerate((0.5, 0.6, 0.5)):
            turn(out, "Thumb_%d" % s, (0, 1, 0), a * f)
    elif clip == "glide":
        for fi in range(4):
            wave = math.sin(math.tau * t + fi * 0.6)
            turn(out, "Finger%d_0" % fi, (0, 1, 0), SPLAY[fi])
            curl_finger(out, fi, (-0.03 + 0.025 * wave, -0.02 + 0.015 * wave, 0.01 * wave))
        turn(out, "Lens", (1, 0, 0), 0.25 + 0.05 * math.sin(math.tau * t))
        turn(out, "Hand", (0, 0, 1), 0.025 * math.sin(math.tau * t))
    elif clip == "land":
        opened = bump(t, 0.0, 0.7)
        clamp = ease((t - 0.45) / 0.55)
        for fi in range(4):
            turn(out, "Finger%d_0" % fi, (0, 1, 0), SPLAY[fi] * opened)
            curl_finger(out, fi, (-0.04 * opened + 0.75 * clamp, -0.02 * opened + 0.9 * clamp, 0.7 * clamp))
        turn(out, "Thumb_0", (0, 1, 0), 0.35 * clamp)
    elif clip == "knocked_down":
        r = ease(t)
        turn(out, "Hand", (0, 0, 1), math.pi * r)
        turn(out, "Hand", (1, 0, 0), 0.5 * math.sin(math.pi * t))
        scale(out, "Lens", 1 + 0.3 * ease((t - 0.6) / 0.4))
        for fi in range(4):
            turn(out, "Finger%d_0" % fi, (0, 1, 0), SPLAY[fi] * r)
    elif clip == "final_quiet":
        c = ease(t / 0.6)
        for s, a in enumerate((0.5, 0.7, 0.6)):
            turn(out, "Thumb_%d" % s, (0, 1, 0), a * c)
        shut = ease((t - 0.4) / 0.6)
        scale(out, "LensIris", (max(0.02, 1 - shut), max(0.02, 1 - shut), 1))
        for k in range(5):
            s = max(0.02, 1 - shut)
            scale(out, "SmallLens%d" % k, (s, s, 1))
        turn(out, "Lens", (1, 0, 0), 0.3 * shut)
    return out


def controls(clip):
    fingers = ["Finger%d_%d" % (f, s) for f in range(4) for s in range(3)]
    small = ["SmallLens%d" % k for k in range(5)]
    table = {
        "idle": fingers + ["Lens"], "pulse_warn": fingers + small + ["LensIris"], "pulse": fingers,
        "active": fingers + ["Lens", "LensIris"], "quote": small + ["LensIris"],
        "grip_falter": fingers + ["Stalk1", "Stalk2", "LensMount", "Lens"],
        "takeoff": fingers + ["Hand", "Thumb_0", "Thumb_1", "Thumb_2"],
        "glide": fingers + ["Lens", "Hand"], "land": fingers + ["Thumb_0"],
        "knocked_down": fingers + ["Hand", "Lens"],
        "final_quiet": ["Thumb_0", "Thumb_1", "Thumb_2", "LensIris", "Lens"] + small,
        "perch": fingers + ["Thumb_1", "Thumb_2", "Stalk1", "Stalk2", "LensMount"],
    }
    if clip.startswith("chunk_lost"):
        return fingers
    if clip.startswith("shrug"):
        return ["Knuckle0", "Knuckle1", "Knuckle2"]
    return table[clip]


def rest_pose(arm):
    for pb in arm.pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()
        pb.scale = Vector((1, 1, 1))


def animate(arm):
    scene = bpy.context.scene
    scene.render.fps = FPS
    arm.animation_data_create()
    actions = []
    for clip, (length, _) in list(CLIPS.items()) + list(EXTRA_CLIPS.items()):
        act = bpy.data.actions.new(clip)
        act.use_fake_user = True
        arm.animation_data.action = act
        last = 1 + round(length * FPS)
        names = controls(clip)
        for f in range(1, last + 1):
            rest_pose(arm)
            for name, (rot, loc, scl) in pose(clip, (f - 1) / (last - 1)).items():
                pb = arm.pose.bones[name]
                pb.rotation_quaternion, pb.location, pb.scale = rot, loc, scl
            for name in names:
                pb = arm.pose.bones[name]
                for path in ("location", "rotation_quaternion", "scale"):
                    pb.keyframe_insert(data_path=path, frame=f, group=name)
        for layer in act.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for k in curve.keyframe_points:
                            k.interpolation = "LINEAR"
        actions.append(act)
        arm.animation_data.action = None
    rest_pose(arm)
    return actions


# --- build, export, check ----------------------------------------------------------------

def build():
    common.reset()
    root = common.empty("WardenMind")
    pose_node = common.empty("Pose", (0, 0, 0), root)
    common.empty("PoseHang", (0, 0, 0), root)
    perch = common.empty("PosePerch", (0, 0, 0), root)
    # The perch: a half turn about the approach axis through the Palm bone's head.
    pivot = B((0.0, PERCH_PIVOT_Y, 0.0))
    perch.matrix_world = (Matrix.Translation(pivot) @ Matrix.Rotation(math.pi, 4, B((0, 0, 1)))
                          @ Matrix.Translation(-pivot))
    part, bones = build_body()
    groups = list(part.groups)
    body = part.to_object((0, 0, 0))
    for g in groups:
        body.vertex_groups.new(name=g)
    arm = make_rig(bones)
    arm.parent = pose_node
    body.parent = arm
    mod = body.modifiers.new("Rig", "ARMATURE")
    mod.object = arm
    socket("WeakPoint", arm, "Lens", (0, LENS_Y, -1.32))
    for i, (_, at) in enumerate(KNUCKLES):
        socket("Hardpoint%d" % i, arm, "Knuckle%d" % i, (at[0], at[1] - 0.2, at[2]))
    return root, arm, body


def rest_points(body):
    """Body vertices in the Godot frame, rest pose (the bind pose)."""
    mw = body.matrix_world
    return [G(mw @ v.co) for v in body.data.vertices]


def finger_vertex_mask(body):
    names = {i: g.name for i, g in enumerate(body.vertex_groups)}
    out = []
    for v in body.data.vertices:
        g = names[v.groups[0].group] if v.groups else ""
        out.append(g.startswith("Finger") or g.startswith("Thumb"))
    return out


def collider_rule(points, fingers, base_y=0.0):
    """Rows of (rule, worst value, limit, ok) for one pose's points; base_y is the stalk root."""
    low = [p for p in points if base_y <= p.y < base_y + LOW_BAND]
    low_r = max((math.hypot(p.x, p.z) for p in low), default=0.0)
    fx = max((abs(p.x) for p, f in zip(points, fingers) if f), default=0.0)
    fy0 = min((p.y for p, f in zip(points, fingers) if f), default=0.0)
    fy1 = max((p.y for p, f in zip(points, fingers) if f), default=0.0)
    return [("low_band_radius", low_r, RADIUS, low_r <= RADIUS + 1e-4),
            ("finger_abs_x", fx, SIL_X, fx <= SIL_X + 1e-4),
            ("finger_min_y", fy0, SIL_Y[0], fy0 >= SIL_Y[0] - 1e-4),
            ("finger_max_y", fy1, SIL_Y[1], fy1 <= SIL_Y[1] + 1e-4)]


def perch_points(points):
    return [Vector((-p.x, PERCH_BASE - p.y, p.z)) for p in points]


# Clips whose fingers must stay in the approach band at every frame, and the poses they play in.
# chunk_lost* are held after they play (a lost finger stays folded) and perch is held while the
# hand sits on a perch, so they are gated. The rest make a fist (takeoff), clamp in transit
# (land) or tumble the hand (knocked_down): transient, reported, not gated.
STEADY = {"idle": ("hang", "perch"), "pulse_warn": ("hang", "perch"), "pulse": ("hang", "perch"),
          "active": ("hang", "perch"), "quote": ("hang", "perch"), "shrug": ("hang", "perch"),
          "shrug_1": ("hang", "perch"), "shrug_2": ("hang", "perch"), "grip_falter": ("hang",),
          "glide": ("perch",), "chunk_lost": ("hang", "perch"), "chunk_lost_ring": ("hang", "perch"),
          "chunk_lost_middle": ("hang", "perch"), "chunk_lost_index": ("hang", "perch"),
          "perch": ("perch",)}


def clip_bands(arm, body, actions):
    """Per clip, the fingers' worst |x| and y range over every frame, in each pose it plays in."""
    mask = finger_vertex_mask(body)
    rows = []
    scene = bpy.context.scene
    for act in actions:
        arm.animation_data.action = act
        if getattr(act, "slots", None) and len(act.slots):
            arm.animation_data.action_slot = act.slots[0]
        last = int(round(act.frame_range[1]))
        worst = {"hang": [0.0, INF, -INF], "perch": [0.0, INF, -INF]}
        for f in range(1, last + 1):
            # Channels a clip does not key keep the last clip's pose in Blender (Godot adds rest
            # tracks for them), so every frame starts from the rest pose.
            rest_pose(arm)
            scene.frame_set(f)
            dg = bpy.context.evaluated_depsgraph_get()
            ev = body.evaluated_get(dg)
            mesh = ev.to_mesh()
            pts = [G(body.matrix_world @ v.co) for v, m in zip(mesh.vertices, mask) if m]
            ev.to_mesh_clear()
            for label, p in (("hang", pts), ("perch", perch_points(pts))):
                w = worst[label]
                w[0] = max(w[0], max(abs(q.x) for q in p))
                w[1] = min(w[1], min(q.y for q in p))
                w[2] = max(w[2], max(q.y for q in p))
        for label in ("hang", "perch"):
            x, y0, y1 = worst[label]
            ok = x <= SIL_X + 1e-3 and y0 >= SIL_Y[0] - 1e-3 and y1 <= SIL_Y[1] + 1e-3
            gated = label in STEADY.get(act.name, ())
            rows.append((act.name, label, x, y0, y1, ok, gated))
    arm.animation_data.action = None
    rest_pose(arm)
    scene.frame_set(1)
    return rows


INF = float("inf")


def perch_lens(arm, body, actions):
    """At the held perch clip, in the perch frame: the grip (the lowest point of the fingers'
    first segments, which sit on the perch top) and the lens centre (the Lens bone head)."""
    scene = bpy.context.scene
    act = next(a for a in actions if a.name == "perch")
    arm.animation_data.action = act
    if getattr(act, "slots", None) and len(act.slots):
        arm.animation_data.action_slot = act.slots[0]
    rest_pose(arm)
    scene.frame_set(int(round(act.frame_range[1])))
    names = {i: g.name for i, g in enumerate(body.vertex_groups)}
    dg = bpy.context.evaluated_depsgraph_get()
    ev = body.evaluated_get(dg)
    mesh = ev.to_mesh()
    first = []
    for v, src in zip(mesh.vertices, body.data.vertices):
        g = names[src.groups[0].group] if src.groups else ""
        if g.startswith("Finger") and g.endswith("_0"):
            first.append(G(body.matrix_world @ v.co))
    ev.to_mesh_clear()
    grip = min(PERCH_BASE - p.y for p in first)
    lens = G(arm.matrix_world @ arm.pose.bones["Lens"].head)
    arm.animation_data.action = None
    rest_pose(arm)
    scene.frame_set(1)
    return grip, PERCH_BASE - lens.y


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
    for a in doc.get("animations", []):
        clips[a["name"]] = max(doc["accessors"][s["input"]]["max"][0] for s in a["samplers"])
    return {"sha256": hashlib.sha256(data).hexdigest(), "tris": tris, "verts": verts, "draws": draws,
            "clips": clips, "nodes": [nd.get("name", "") for nd in doc["nodes"]],
            "materials": [m["name"] for m in doc.get("materials", [])],
            "lights": "KHR_lights_punctual" in json.dumps(doc.get("extensions", {}))}


def check(path, body, arm, actions):
    """Fails loud: budget, every clip by name and length, the collider rule in both poses, and the
    steady clips' fingers inside the band at every frame."""
    info = glb_info(path)
    problems = []
    for key in ("tris", "verts", "draws"):
        if info[key] > BUDGET[key]:
            problems.append("%s %d over %d" % (key, info[key], BUDGET[key]))
    for name, (length, _) in list(CLIPS.items()) + list(EXTRA_CLIPS.items()):
        got = info["clips"].get(name)
        if got is None:
            problems.append("clip %s missing" % name)
        elif abs(got - length) > 0.05:
            problems.append("clip %s is %.3f s, wants %.2f" % (name, got, length))
    for need in ["Pose", "PoseHang", "PosePerch", "WeakPoint", "Hardpoint0", "Hardpoint1", "Hardpoint2"]:
        if need not in info["nodes"]:
            problems.append("node %s missing" % need)
    for slot in SEAM_SLOTS[:4]:
        if slot not in info["materials"]:
            problems.append("seam material %s missing" % slot)
    if info["lights"]:
        problems.append("light in GLB")
    pts = rest_points(body)
    mask = finger_vertex_mask(body)
    rows = []
    for label, p, base_y in (("hang", pts, 0.0), ("perch", perch_points(pts), PERCH_BASE)):
        for rule, value, limit, ok in collider_rule(p, mask, base_y):
            rows.append((label, rule, value, limit, ok))
            if not ok:
                problems.append("%s %s %.3f past %.3f" % (label, rule, value, limit))
    lens = [p for p, v in zip(pts, body.data.vertices) if v.groups and
            body.vertex_groups[v.groups[0].group].name == "LensIris"]
    lens_c = sum(lens, Vector()) / len(lens)
    print("CHECK tris %d verts %d draws %d (budget %s)" % (info["tris"], info["verts"], info["draws"], BUDGET))
    print("CHECK clips %s" % json.dumps({k: round(v, 3) for k, v in sorted(info["clips"].items())}))
    for row in rows:
        print("CHECK collider %s %s %.3f limit %.3f %s" % (row[0], row[1], row[2], row[3], "ok" if row[4] else "OUT"))
    print("CHECK lens centre %.3f %.3f %.3f (point offset from the Warden's centre %s)" % (
        lens_c.x, lens_c.y, lens_c.z, POINT_OFFSET))
    for clip, label, x, y0, y1, ok, gated in clip_bands(arm, body, actions):
        state = ("ok" if ok else "OUT") if gated else ("in band" if ok else "leaves band, not gated")
        print("CHECK clip band %s %s |x| %.3f y %.3f..%.3f %s" % (clip, label, x, y0, y1, state))
        if gated and not ok:
            problems.append("clip %s (%s) moves a finger out of the band" % (clip, label))
    grip, lens_y = perch_lens(arm, body, actions)
    print("CHECK perch grip y %.3f lens y %.3f: lens %.3f above the grip (wants %.1f), %.3f above the "
          "Warden's centre" % (grip, lens_y, lens_y - grip, GRIP_TO_LENS, lens_y - HALF_HEIGHT))
    if abs(lens_y - grip - GRIP_TO_LENS) > 0.1:
        problems.append("perch lens %.3f above the grip, wants %.1f" % (lens_y - grip, GRIP_TO_LENS))
    print("CHECK sha256 %s" % info["sha256"])
    if problems:
        raise SystemExit("warden_mind check failed: " + "; ".join(problems))
    return info


def export(root, arm, path):
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action="DESELECT")
    for o in common.tree(root):
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    arm.animation_data.action = None
    rest_pose(arm)
    bpy.context.scene.frame_set(1)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                              export_animations=True, export_animation_mode="ACTIONS",
                              export_anim_slide_to_zero=True, export_frame_range=False,
                              export_force_sampling=True, export_def_bones=False, export_skins=True,
                              export_yup=True, export_materials="EXPORT", export_vertex_color="ACTIVE",
                              export_extras=False, export_cameras=False, export_lights=False)
    common.canonical_indices(path)
    print("EXPORTED", path)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = common.default_out("warden_mind")
    if "--out" in argv:
        out = argv[argv.index("--out") + 1]
    root, arm, body = build()
    print("TRIS warden_mind body %d (blender, before export)" % common.tris(body))
    if "--count-only" in argv:
        pts = rest_points(body)
        mask = finger_vertex_mask(body)
        for label, p, base_y in (("hang", pts, 0.0), ("perch", perch_points(pts), PERCH_BASE)):
            for rule, value, limit, ok in collider_rule(p, mask, base_y):
                print("COUNT collider %s %s %.3f limit %.3f %s" % (label, rule, value, limit, "ok" if ok else "OUT"))
        return
    actions = animate(arm)
    export(root, arm, out)
    check(out, body, arm, actions)


main()
