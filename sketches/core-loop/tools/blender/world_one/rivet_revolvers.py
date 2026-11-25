# E1-09b (wave 46, ruling en): Rivet's twin side-sponson rotary rivet cannons, rivet_revolvers.glb.
# Two mirrored cannons hung outboard at 3 and 9 o'clock on stout bolted clamp sponsons that wrap the
# weapon ring band, bores parallel and forward, sized against the solid cutaway ball (ruling dm) so
# both silhouette beside it from the 7.5 m chase camera. hero_assets.gd mounts the file at identity
# under the shell's WeaponRing (its origin is the ball centre), so the cannons yaw to the aim and
# bank with the ring. Concept: artifacts/local/w46-concept-art/heroic-cutaway/
# 01-rivet-heroic-cutaway.png (bone clamp sponsons, a bone receiver with copper straps, a fat
# six-barrel cluster behind a fluted six-chamber drum, heavy copper band collars, a copper motor cap).
# E1-09's revolvers (ruling ek) sat at 34 degrees and 1.315 m and hid behind the cutaway ball.
#
#   prlimit --as=12884901888 -- blender --background --threads 2 --python-exit-code 1 \
#     --python world_one/rivet_revolvers.py -- [--out <file.glb>]
#
# Node tree (Blender axes, +Y forward, +Z up; glTF and Godot +Y up, -Z forward):
#   RivetRevolvers (empty) > RevolverRig (armature) > Revolvers (skinned mesh: paint, copper)
#   bones  mount (the ball centre)
#          tool.L > slide.L (the copper breech block on the receiver's back, recoils along the bore)
#                 > crane.L (the yoke hinge, inboard and below the cluster, axis along the bore)
#                   > drum.L (the rotary cluster: fluted drum, six barrels, collars, centre hub)
#          and the same for R (x > 0). Bones point along the bore with no roll, so in a bone's own
#          rest frame Y is the bore (Blender +Y), X is +X and Z is up: the cluster indexes and the
#          yoke swings about its bone's Y, a cannon bucks about its bone's X, the breech recoils -Y.
#          The bone names and hierarchy are E1-09's, so hero_assets.gd and the rivet.json rows
#          (mecha_motion.gd) drive the cannons unchanged: a shot bucks the cannon, kicks the breech
#          and indexes the cluster one barrel; a reload swings the cluster outboard and down on its
#          yoke and spins it one turn.
# Every vertex is weighted whole to one bone (PILOT-RIG.md): the clamp sponson, its jaws and bolts
# to mount; the receiver, straps, side plate, motor cap and hinge lug to tool; the breech block and
# its knob to slide; the yoke and hinge pin to crane; the drum, barrels, collars and hub to drum.
# Paint faces carry vertex alpha 0, so an equipped paint never recolours the cannons (hero_assets.gd
# PAINT_TAKE); copper is the one metal (SIGHT-PERSONA rule 5). Every piece is a closed island; the
# build fails on an open, non-manifold or inside-out island, or a pose that reaches past REACH,
# drops below FLOOR_Z or comes within CLEAR of the lattice, band or collar.
# shell_rivet.py reads MUZZLES for its LaserMuzzle.L/R markers, so the flash sits on the hub crowns;
# combat/bolts.gd RIVET_MUZZLE_SIDE_M and player_fx.gd SIDE_M carry SIDE_X.

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import common  # noqa: E402
import polish  # noqa: E402
import shell_base as sb  # noqa: E402  (also registers the copper slot)
from common import Part  # noqa: E402

# Budgets: the detail class (assets/asset_budgets.json) is 4,000 tris and 2 draws. REACH is ruling
# en's visual weapon reach (1.65 to 1.75 m from the ball centre); FLOOR_Z its ground clearance.
TRIS = (2400, 3900)
DRAWS = 2
REACH = 1.75
FLOOR_Z = -0.55
CLEAR = 0.01
# Ring band (Blender metres): radius 1.03 to 1.08, 0.08 m tall at Z 0; the collar under it.
BAND = sb.RING_BAND
COLLAR = sb.RING_COLLAR
LATTICE = sb.LATTICE_OUTER
# One cannon, the left (x < 0); the right is its mirror. u is the distance outboard of the centre
# line, so a point sits at x = side * u. The cluster axis runs along +Y at u SIDE_X, Z AXIS_Z.
SIDE_X = 1.26
AXIS_Z = 0.0
# Clamp sponson (mount): a bone block straddling the band at 3 or 9 o'clock, charcoal jaws top and
# bottom, four copper bolt heads on the top jaw. (u0, u1, y half, z0, z1)
CLAMP = (0.998, 1.14, 0.13, -0.10, 0.10)
JAW = (0.998, 1.15, 0.15, 0.035)                     # u0, u1, y half, thickness
JAW_BOLT = (0.02, 0.03, (1.03, 1.11), 0.10)          # radius, height, u, y offset
# Receiver (tool): the bone housing, two copper straps round it, a charcoal plate on its outboard
# face, the copper motor cap and charcoal end cap behind it, the hinge lug under its front.
HOUSING = (1.10, 1.42, -0.36, 0.30, -0.16, 0.18)    # u0, u1, y0, y1, z0, z1
STRAPS = (-0.20, 0.12)
STRAP = (0.025, 0.012)                              # y half, proud
SIDE_PLATE = (1.42, 1.445, -0.26, 0.20, -0.10, 0.12)
MOTOR = ((-0.36, 0.0), (-0.36, 0.14), (-0.40, 0.14), (-0.40, 0.125), (-0.46, 0.125), (-0.46, 0.0))
END_CAP = ((-0.455, 0.0), (-0.455, 0.09), (-0.50, 0.09), (-0.50, 0.035), (-0.53, 0.035), (-0.53, 0.0))
LUG = (1.10, 1.18, 0.26, 0.30, -0.17, -0.07)
# Breech block (slide) on the receiver's back, the copper knob on its rear.
BREECH = (0.065, -0.30, 0.06, 0.17, 0.25)           # u half, y0, y1, z0, z1
KNOB = (-0.25, 0.25, 0.31, 0.028)                    # y, z0, z1, radius
# Yoke (crane): the hinge pin inboard and below the cluster, a plate from it to a disc round the
# axle in front of the receiver. HINGE (u inboard of the axis, z below it).
HINGE = (0.12, 0.12)
PIN = (0.25, 0.352, 0.03)                            # y0, y1, radius
YOKE = (0.30, 0.352, 0.12, 0.075)                    # y0, y1, disc radius, plate width
# The rotary cluster (drum): a fluted drum, six barrels round a copper hub, a copper band on the
# drum, a mid collar and a heavy front collar, all charcoal but the copper.
DRUM_Y = (0.355, 0.52)
DRUM_R = (0.215, 0.188)                              # crest, valley
DRUM_BAND = (0.455, 0.495, 0.226)                    # y0, y1, radius
BARRELS = 6
PITCH = 0.12
BARREL = (0.50, 0.91, 0.05)                          # y0, y1, radius
BARREL_SIDES = 10
BARREL_BORE = (0.026, 0.03)                          # radius, depth
MUZZLE_RING = (0.86, 0.056)                          # y where the barrel swells (charcoal), radius
COLLARS = ((0.62, 0.66, 0.185), (0.77, 0.85, 0.205))  # y0, y1, radius
COLLAR_SIDES = 16
HUB = (0.50, 0.90, 0.055, 0.028, 0.03)               # y0, y1, radius, bore radius, bore depth
# Poses the rivet.json rows reach (left cannon; the right mirrors): the buck, the breech stroke,
# a half index, and the reload swing with a full spin.
BUCK_DEG = 6.0
STROKE_M = -0.035
SWING_DEG = -80.0

BONES = ("mount", "tool.L", "slide.L", "crane.L", "drum.L", "tool.R", "slide.R", "crane.R", "drum.R")
PARENT = {"tool": "mount", "slide": "tool", "crane": "tool", "drum": "crane"}
TAG = "rig_part"


def axis_at(side, y=0.0):
    return Vector((side * SIDE_X, y, AXIS_Z))


def hinge_at(side, y=0.0):
    return Vector((side * (SIDE_X - HINGE[0]), y, AXIS_Z - HINGE[1]))


def heads(side):
    """Bone heads for one cannon, Blender metres."""
    tag = "L" if side < 0 else "R"
    return {
        "tool." + tag: Vector((side * HOUSING[0], 0.0, AXIS_Z)),
        "slide." + tag: Vector((side * SIDE_X, BREECH[1], (BREECH[3] + BREECH[4]) / 2)),
        "crane." + tag: hinge_at(side, YOKE[0]),
        "drum." + tag: axis_at(side, (DRUM_Y[0] + BARREL[1]) / 2),
    }


# Muzzle markers (shell_rivet.py LaserMuzzle.L/R): 1 cm past each hub's crown, on the cluster axis.
MUZZLES = {"L": (-SIDE_X, HUB[1] + 0.01, AXIS_Z), "R": (SIDE_X, HUB[1] + 0.01, AXIS_Z)}


# --- closed builders -------------------------------------------------------------------------


class Kit:
    """One Part whose vertices carry the bone each piece is weighted to."""

    def __init__(self):
        self.part = Part("Revolvers")
        self.tag = self.part.bm.verts.layers.int.new(TAG)

    def mark(self, faces, bone):
        k = BONES.index(bone) + 1
        for f in faces:
            for v in f.verts:
                v[self.tag] = k
        return faces

    def box(self, bone, slot, size, loc, rot=(0, 0, 0), color=None):
        return self.mark(self.part.box(slot, size, loc=loc, rot=rot, color=color, alpha=0.0), bone)

    def span(self, bone, slot, side, u0, u1, y0, y1, z0, z1, color=None):
        """An axis-aligned box from u0 to u1 outboard, y0 to y1, z0 to z1."""
        return self.box(bone, slot, (u1 - u0, y1 - y0, z1 - z0), (side * (u0 + u1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
                        color=color)

    def post(self, bone, slot, loc, r, h, segs, color=None):
        """A short upright cylinder standing on loc."""
        faces = self.part.cyl(slot, r, r, h, segs, loc=(loc[0], loc[1], loc[2] + h / 2), color=color)
        self.part.paint(faces, slot, color, alpha=0.0)
        return self.mark(faces, bone)

    def lathe(self, bone, origin, profile, sides, slots, color=None, roll=None):
        """A closed surface of revolution about +Y through origin. profile: (y, r) from one end to
        the other, r 0 only at the two ends (a pole). slots[i] paints the band from point i to i + 1.
        An even side count with the default half-step roll keeps the rings mirror-symmetric."""
        bm = self.part.bm
        o = Vector(origin)
        roll = math.pi / sides if roll is None else roll
        rings = []
        for y, r in profile:
            if r == 0.0:
                rings.append([bm.verts.new(Vector((o.x, y, o.z)))])
                continue
            rings.append([bm.verts.new(Vector((o.x + r * math.cos(roll + k * math.tau / sides), y,
                                               o.z + r * math.sin(roll + k * math.tau / sides))))
                          for k in range(sides)])
        faces = []
        for i in range(len(rings) - 1):
            a, b = rings[i], rings[i + 1]
            band = []
            for k in range(sides):
                j = (k + 1) % sides
                if len(a) == 1:
                    band.append(bm.faces.new((a[0], b[j], b[k])))
                elif len(b) == 1:
                    band.append(bm.faces.new((a[k], a[j], b[0])))
                else:
                    band.append(bm.faces.new((a[k], a[j], b[j], b[k])))
            slot, col = slots[i]
            self.part.paint(band, slot, col if slot == "paint" else None, alpha=0.0)
            faces += band
        return self.mark(faces, bone)

    def tube(self, bone, slot, origin, y0, y1, r, sides, color=None):
        return self.lathe(bone, origin, [(y0, 0.0), (y0, r), (y1, r), (y1, 0.0)], sides, [(slot, color)] * 3)

    def fluted(self, bone, side):
        """The fluted drum: 12 sides alternating crest (over each barrel) and valley, capped by fans
        to its axis at both ends. One closed island, charcoal."""
        bm = self.part.bm
        c = axis_at(side)
        y0, y1 = DRUM_Y
        outline = []
        for k in range(BARRELS):
            crest = math.pi / 2 + k * math.tau / BARRELS
            outline += [(crest - math.pi / BARRELS, DRUM_R[1]), (crest, DRUM_R[0])]

        def ring(y):
            return [bm.verts.new(Vector((c.x + r * math.cos(a), y, c.z + r * math.sin(a)))) for a, r in outline]

        back, front = ring(y0), ring(y1)
        n = len(outline)
        faces = [bm.faces.new((back[i], back[(i + 1) % n], front[(i + 1) % n], front[i])) for i in range(n)]
        cb = bm.verts.new(Vector((c.x, y0, c.z)))
        cf = bm.verts.new(Vector((c.x, y1, c.z)))
        faces += [bm.faces.new((back[(i + 1) % n], back[i], cb)) for i in range(n)]
        faces += [bm.faces.new((front[i], front[(i + 1) % n], cf)) for i in range(n)]
        self.part.paint(faces, "paint", "charcoal", alpha=0.0)
        return self.mark(faces, bone)


def sponson(kit, side):
    """The clamp sponson on the band (mount): the bone block, charcoal jaws, copper bolt heads."""
    u0, u1, half, z0, z1 = CLAMP
    with kit.part.region(bevel=0.014):
        kit.span("mount", "paint", side, u0, u1, -half, half, z0, z1, "bone")
    j0, j1, jh, thick = JAW
    with kit.part.region(bevel=0.008):
        kit.span("mount", "paint", side, j0, j1, -jh, jh, z1 - 0.005, z1 - 0.005 + thick, "charcoal")
        kit.span("mount", "paint", side, j0, j1, -jh, jh, z0 + 0.005 - thick, z0 + 0.005, "charcoal")
    br, bh, us, off = JAW_BOLT
    for u in us:
        for t in (-1, 1):
            kit.post("mount", "copper", (side * u, t * off, z1 - 0.005 + thick - 0.004), br, bh, 6)


def receiver(kit, side):
    """The receiver (tool): bone housing, copper straps, charcoal side plate, motor and end caps,
    the hinge lug."""
    tool_b = "tool." + ("L" if side < 0 else "R")
    u0, u1, y0, y1, z0, z1 = HOUSING
    with kit.part.region(bevel=0.022):
        kit.span(tool_b, "paint", side, u0, u1, y0, y1, z0, z1, "bone")
    half, proud = STRAP
    with kit.part.region(bevel=0.006):
        for y in STRAPS:
            kit.span(tool_b, "copper", side, u0 - proud, u1 + proud, y - half, y + half, z0 - proud, z1 + proud)
        p = SIDE_PLATE
        kit.span(tool_b, "paint", side, p[0] - 0.01, p[1], p[2], p[3], p[4], p[5], "charcoal")
        l0, l1, ly0, ly1, lz0, lz1 = LUG
        kit.span(tool_b, "paint", side, l0, l1, ly0, ly1, lz0, lz1, "bone")
    kit.lathe(tool_b, axis_at(side), MOTOR, 16, [("copper", None)] * (len(MOTOR) - 1))
    kit.lathe(tool_b, axis_at(side), END_CAP, 12, [("paint", "charcoal")] * 3 + [("copper", None)] * 2)


def breech(kit, side):
    slide_b = "slide." + ("L" if side < 0 else "R")
    half, y0, y1, z0, z1 = BREECH
    with kit.part.region(bevel=0.01):
        kit.span(slide_b, "copper", side, SIDE_X - half, SIDE_X + half, y0, y1, z0, z1)
    ky, kz0, kz1, kr = KNOB
    kit.post(slide_b, "copper", (side * SIDE_X, ky, kz0 - 0.005), kr, kz1 - kz0 + 0.005, 8)


def yoke(kit, side):
    crane_b = "crane." + ("L" if side < 0 else "R")
    y0, y1, pr = PIN
    kit.tube(crane_b, "paint", hinge_at(side), y0, y1, pr, 8, "charcoal")
    a0, a1, disc, width = YOKE
    kit.tube(crane_b, "paint", axis_at(side), a0, a1, disc, 12, "bone")
    a, b = hinge_at(side), axis_at(side)
    mid = (a + b) / 2
    tilt = math.atan2(b.z - a.z, b.x - a.x)
    with kit.part.region(bevel=0.006):
        kit.box(crane_b, "paint", ((b - a).length + 0.06, a1 - a0, width), (mid.x, (a0 + a1) / 2, mid.z),
                rot=(0, -tilt, 0), color="bone")


def cluster(kit, side):
    drum_b = "drum." + ("L" if side < 0 else "R")
    kit.fluted(drum_b, side)
    b0, b1, br = DRUM_BAND
    kit.tube(drum_b, "copper", axis_at(side), b0, b1, br, COLLAR_SIDES)
    y0, y1, r = BARREL
    bore, depth = BARREL_BORE
    swell_y, swell_r = MUZZLE_RING
    profile = [(y0, 0.0), (y0, r), (swell_y - 0.012, r), (swell_y, swell_r), (y1, swell_r), (y1, bore),
               (y1 - depth, bore), (y1 - depth, 0.0)]
    slots = [("paint", "charcoal")] * (len(profile) - 1)
    c = axis_at(side)
    for k in range(BARRELS):
        a = math.pi / 2 + k * math.tau / BARRELS
        kit.lathe(drum_b, (c.x + PITCH * math.cos(a), 0, c.z + PITCH * math.sin(a)), profile, BARREL_SIDES, slots)
    for c0, c1, cr in COLLARS:
        kit.tube(drum_b, "copper", c, c0, c1, cr, COLLAR_SIDES)
    h0, h1, hr, hb, hd = HUB
    kit.lathe(drum_b, c, [(h0, 0.0), (h0, hr), (h1, hr), (h1, hb), (h1 - hd, hb), (h1 - hd, 0.0)], 12,
              [("copper", None)] * 3 + [("paint", "charcoal")] * 2)


def cannon(kit, side):
    sponson(kit, side)
    receiver(kit, side)
    breech(kit, side)
    yoke(kit, side)
    cluster(kit, side)


# --- poses and clearance -----------------------------------------------------------------------


def about(head, axis, deg):
    return Matrix.Translation(head) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-head)


def pose_matrices(side, buck=0.0, stroke=0.0, index=0.0, swing=0.0):
    """Each bone's world matrix for a pose of one cannon, the left's degrees mirrored for the right
    (the rivet.json rows: the buck is the same sign on both sides, the index and swing mirror)."""
    tag = "L" if side < 0 else "R"
    h = heads(side)
    tool = about(h["tool." + tag], "X", buck)
    slide = tool @ Matrix.Translation((0, stroke, 0))
    crane = tool @ about(h["crane." + tag], "Y", -side * swing)
    drum = crane @ about(h["drum." + tag], "Y", -side * index)
    return {"tool." + tag: tool, "slide." + tag: slide, "crane." + tag: crane, "drum." + tag: drum}


POSES = (
    ("rest", {}),
    ("shot", {"buck": BUCK_DEG, "stroke": STROKE_M, "index": 30.0}),
    ("reload", {"swing": SWING_DEG, "index": 180.0}),
    ("snap", {"buck": BUCK_DEG, "stroke": STROKE_M, "swing": SWING_DEG, "index": 30.0}),
)


def _rect_gap(rho, z, r0, r1, z0, z1):
    dr = max(r0 - rho, 0.0, rho - r1)
    dz = max(z0 - z, 0.0, z - z1)
    return math.hypot(dr, dz)


def clearance(obj):
    """Per pose: the furthest reach, the lowest point and the smallest gap from a moving part
    (everything but the clamp sponson, which wraps the band) to the lattice sphere, the band and
    the collar with its studs. Returns (lines, ok)."""
    tags = obj.data.attributes[TAG]
    verts = [(v.co.copy(), BONES[tags.data[v.index].value - 1]) for v in obj.data.vertices]
    lines, ok = [], True
    for name, kw in POSES:
        mats = {}
        for side in (-1, 1):
            mats.update(pose_matrices(side, **kw))
        reach, low, gap = 0.0, 9.0, 9.0
        for co, bone in verts:
            p = mats[bone] @ co if bone in mats else co
            reach = max(reach, p.length)
            low = min(low, p.z)
            if bone == "mount":
                continue
            rho = math.hypot(p.x, p.y)
            gap = min(gap, p.length - LATTICE,
                      _rect_gap(rho, p.z, BAND[0], BAND[1], BAND[3] - BAND[2] / 2, BAND[3] + BAND[2] / 2),
                      _rect_gap(rho, p.z, COLLAR[0], COLLAR[1] + 0.02, COLLAR[3] - COLLAR[2] / 2 - 0.016,
                                COLLAR[3] + COLLAR[2] / 2))
        line = "POSE %-6s reach=%.4f low=%.4f gap=%.4f" % (name, reach, low, gap)
        print(line)
        lines.append(line)
        ok = ok and reach <= REACH and low > FLOOR_Z and gap >= CLEAR
    return lines, ok


# --- checks ------------------------------------------------------------------------------------


def islands(bm):
    bm.faces.index_update()
    seen, out = set(), []
    for start in bm.faces:
        if start.index in seen:
            continue
        group, stack = [], [start]
        seen.add(start.index)
        while stack:
            f = stack.pop()
            group.append(f)
            for e in f.edges:
                for g in e.link_faces:
                    if g.index not in seen:
                        seen.add(g.index)
                        stack.append(g)
        out.append(group)
    return out


def closed_report(obj):
    """MANIFOLD line for one mesh: islands, open (boundary) and non-manifold edges after welding by
    position (as check_manifold.py does), and islands with negative signed volume (inside out)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    boundary = sum(1 for e in bm.edges if len(e.link_faces) == 1)
    nonmanifold = sum(1 for e in bm.edges if len(e.link_faces) > 2)
    groups = islands(bm)
    inverted = 0
    for g in groups:
        vol = 0.0
        for f in g:
            vs = [v.co for v in f.verts]
            for i in range(1, len(vs) - 1):
                vol += vs[0].dot(vs[i].cross(vs[i + 1])) / 6.0
        inverted += 1 if vol <= 0.0 else 0
    bm.free()
    line = "MANIFOLD %s islands=%d boundary=%d nonmanifold=%d inverted=%d" % (obj.name, len(groups), boundary,
                                                                            nonmanifold, inverted)
    print(line)
    return boundary == 0 and nonmanifold == 0 and inverted == 0


def reach_of(obj):
    mw = obj.matrix_world
    return max((mw @ v.co).length for v in obj.data.vertices)


# --- rig and export ----------------------------------------------------------------------------


def rig(root, obj):
    data = bpy.data.armatures.new("RevolverRig")
    arm = bpy.data.objects.new("RevolverRig", data)
    bpy.context.scene.collection.objects.link(arm)
    common.place(arm, (0, 0, 0), root)
    bpy.context.view_layer.objects.active = arm
    for o in bpy.context.scene.objects:
        o.select_set(False)
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    at = {"mount": Vector((0, 0, 0))}
    at.update(heads(-1))
    at.update(heads(1))
    for name in BONES:
        bone = data.edit_bones.new(name)
        bone.head = at[name]
        bone.tail = at[name] + Vector((0, 0.05, 0))
        bone.roll = 0.0
        if name != "mount":
            kind, tag = name.split(".")
            parent = PARENT[kind] if kind == "tool" else PARENT[kind] + "." + tag
            bone.parent = data.edit_bones[parent]
            bone.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.parent = arm
    obj.matrix_parent_inverse.identity()
    obj.location = (0, 0, 0)
    mod = obj.modifiers.new("Rig", "ARMATURE")
    mod.object = arm
    tags = obj.data.attributes[TAG]
    for i, name in enumerate(BONES):
        ids = [v.index for v in obj.data.vertices if tags.data[v.index].value == i + 1]
        obj.vertex_groups.new(name=name).add(ids, 1.0, "REPLACE")
    untagged = sum(1 for v in obj.data.vertices if tags.data[v.index].value == 0)
    if untagged:
        raise SystemExit("%d vertices carry no bone" % untagged)
    obj.data.attributes.remove(tags)
    return arm


def export(root, arm, path):
    polish.bake(root, polish.options())
    bpy.context.view_layer.update()
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in common.tree(root):
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_animations=False,
                              export_def_bones=False, export_skins=True, export_yup=True, export_materials="EXPORT",
                              export_vertex_color="ACTIVE", export_extras=False, export_cameras=False,
                              export_lights=False)
    common.canonical_indices(path, vertices=True)
    print("EXPORTED", path)


def build():
    root = common.empty("RivetRevolvers")
    kit = Kit()
    for side in (-1, 1):
        cannon(kit, side)
    bmesh.ops.recalc_face_normals(kit.part.bm, faces=kit.part.bm.faces[:])
    obj = kit.part.to_object((0, 0, 0), root)
    return root, obj


def main():
    common.reset()
    common.preview_class("copper")
    polish.enable(detail=1, bevel=0.0, edge=0.18)
    root, obj = build()
    tris = common.tris(obj)
    draws = len(obj.data.materials)
    reach = reach_of(obj)
    closed = closed_report(obj)
    print("REVOLVERS tris=%d verts=%d draws=%d reach=%.4f (limit %.2f) side_x=%.3f" % (tris, len(obj.data.vertices), draws,
                                                                                        reach, REACH, SIDE_X))
    _, posed = clearance(obj)
    arm = rig(root, obj)
    ok = TRIS[0] <= tris <= TRIS[1] and draws == DRAWS and reach <= REACH and closed and posed
    out = common.args()["out"] or os.path.join(common.MODELS, "world_one", "rivet_revolvers.glb")
    export(root, arm, out)
    if not ok:
        raise SystemExit("rivet_revolvers out of budget, reach, clearance or watertight")


if __name__ == "__main__":
    main()
