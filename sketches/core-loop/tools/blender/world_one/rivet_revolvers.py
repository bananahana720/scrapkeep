# E1-09 (wave 46, ruling ek): Rivet's twin rivet revolvers, rivet_revolvers.glb. Two mirrored
# tools clamped on the weapon ring band at about 34 degrees either side of straight ahead, bores
# parallel and forward, in place of the twin laser pods. hero_assets.gd mounts the file at identity
# under the shell's WeaponRing (its origin is the ball centre), so the tools yaw to the aim and bank
# with the ring. Build plan: wave 46 3D blueprint sections 2.1, 2.2 and 3.1 and the 3D review
# section 1.5 (scratch/w46-gate-handoff/art/); concept artifacts/local/w46-concept-art/
# 01-rivet-twin-revolvers.png, corrected as the blueprint's table says: no grip, trigger guard or
# hammer; a bolted clamp saddle on the band where the grip was; a copper rivet-header knuckle where
# the hammer was; mirrored, never staggered; six flutes on the drum side for the chase camera and
# six capped chamber recesses on its face for close views.
#
#   prlimit --as=12884901888 -- blender --background --threads 2 --python-exit-code 1 \
#     --python world_one/rivet_revolvers.py -- [--out <file.glb>]
#
# Node tree (Blender axes, +Y forward, +Z up; glTF and Godot +Y up, -Z forward):
#   RivetRevolvers (empty) > RevolverRig (armature) > Revolvers (skinned mesh: paint, copper)
#   bones  mount (the ball centre)
#          tool.L > slide.L (the barrel and its lug, recoil along the bore)
#                 > crane.L (hinge front inboard of the drum, axis along the bore) > drum.L
#          and the same for R (x > 0). Bones point along the bore with no roll, so in a bone's own
#          rest frame Y is the bore (Blender +Y), X is +X and Z is up: a drum indexes and a crane
#          swings about its bone's Y, a tool kicks about its bone's X, a slide recoils along -Y.
# Every vertex is weighted whole to one bone (PILOT-RIG.md): the clamp saddles and their bolts to
# mount, the frame and knuckle to tool, the barrel to slide, the crane arm, hinge pin and ejector
# rod to crane, the drum to drum. Paint faces carry vertex alpha 0, so an equipped paint never
# recolours the tools (hero_assets.gd PAINT_TAKE); copper is the one metal (SIGHT-PERSONA rule 5).
# Every piece is a closed island; the build fails on an open, non-manifold or inside-out island.
# shell_rivet.py reads MUZZLES for its LaserMuzzle.L/R markers, so the flash sits on these tips.

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import common  # noqa: E402
import polish  # noqa: E402
import shell_base as sb  # noqa: E402  (also registers the copper slot)
from common import Part  # noqa: E402

# Budgets: the detail class (assets/asset_budgets.json) is 4,000 tris and 2 draws; the blueprint
# plans about 1,700 tris. REACH is the 3D review's weapon reach rule (section 1.3).
TRIS = (1200, 2200)
DRAWS = 2
REACH = 1.35
# Ring band (Blender metres): radius 1.03 to 1.08, 0.08 m tall at Z 0.
BAND = sb.RING_BAND
# One tool, the left (x < 0); the right is its mirror. The bore runs along +Y at x -SIDE_X,
# Z BORE_Z. The band crosses under the frame's rear block, where the saddle clamps it, at about
# 34.6 degrees from straight ahead.
SIDE_X = 0.60
BORE_Z = 0.17
MUZZLE_Y = 1.14
BORE_R = 0.016
BORE_DEPTH = 0.02
BARREL = (1.008, MUZZLE_Y, 0.032)                  # y0, y1, radius
GROOVES = (1.045, 1.075, 1.105)                    # three shallow ring grooves on the shroud
GROOVE = (0.004, 0.0035)                           # half width, depth
BARREL_SIDES = 10
# Drum: 12 sides, six flutes (crest over each chamber, valley between), axis 0.045 m below the bore.
DRUM_Z = BORE_Z - 0.045
DRUM_Y = (0.932, 1.005)
DRUM_R = (0.058, 0.050)                            # crest, valley
CHAMBER = (0.042, 0.011, 0.012)                    # centre radius, hole radius, depth
# Frame boxes (y0, y1, half width in x, z0, z1); x is about the bore axis, lower rail inboard.
FRAME_Z0 = 0.055
REAR = (0.845, 0.930, 0.035, FRAME_Z0, BORE_Z + 0.035)
STRAP = (0.930, 1.012, 0.025, BORE_Z + 0.018, BORE_Z + 0.035)
LUG = (1.012, 1.045, 0.036, BORE_Z - 0.030, BORE_Z + 0.035)
RAIL = (0.845, 1.030, 0.012, FRAME_Z0, DRUM_Z - DRUM_R[0] - 0.002)
RAIL_IN = 0.030
# The lower front lug the crane hinge pin turns in, inboard, in front of the drum.
HINGE_LUG = (1.014, 1.040, 0.014, FRAME_Z0, DRUM_Z - 0.035 + 0.014)
# The clamp saddle straddles the band where it crosses under the rear block: radial 1.022 to
# 1.098 m, 0.10 m along the band, Z -0.052 to 0.062 (its top sinks 7 mm into the frame).
SADDLE = (1.022, 1.098, 0.10, -0.052, 0.062)
BOLT = (0.011, 0.014, 0.028, 0.005)                # radius, length, offset along the band, Z
# Crane: a hinge pin front inboard of the drum, an arm to the drum axle, the ejector rod under the
# barrel on the drum axis.
HINGE = (0.035, DRUM_Z - 0.035, 1.007, 1.030, 0.010)  # inboard x, z, y0, y1, radius
ARM = (1.006, 1.013, 0.010)                        # y0, y1, thickness
EJECTOR = (1.005, 1.100, 0.009)                    # y0, y1, radius
# Rivet-header knuckle where a hammer would be: a short stem off the rear block and a squat dome.
KNUCKLE_Z = BORE_Z + 0.012
KNUCKLE = ((0.850, 0.0), (0.850, 0.011), (0.836, 0.011), (0.836, 0.022), (0.824, 0.018), (0.818, 0.0))

BONES = ("mount", "tool.L", "slide.L", "crane.L", "drum.L", "tool.R", "slide.R", "crane.R", "drum.R")
PARENT = {"tool": "mount", "slide": "tool", "crane": "tool", "drum": "crane"}
TAG = "rig_part"


def side_x(side):
    return side * SIDE_X


def inboard(side):
    return -side


def saddle_centre(side):
    """Where the band's mid radius crosses under the bore line."""
    mid = (BAND[0] + BAND[1]) / 2
    return Vector((side_x(side), math.sqrt(mid * mid - SIDE_X * SIDE_X), 0.0))


def heads(side):
    """Bone heads for one tool, Blender metres."""
    x = side_x(side)
    tag = "L" if side < 0 else "R"
    s = saddle_centre(side)
    return {
        "tool." + tag: Vector((x, s.y, FRAME_Z0)),
        "slide." + tag: Vector((x, BARREL[0], BORE_Z)),
        "crane." + tag: Vector((x + inboard(side) * HINGE[0], HINGE[2], HINGE[1])),
        "drum." + tag: Vector((x, (DRUM_Y[0] + DRUM_Y[1]) / 2, DRUM_Z)),
    }


# Muzzle markers (shell_rivet.py LaserMuzzle.L/R): 1 cm past each barrel's crown, on the bore.
MUZZLES = {"L": (-SIDE_X, MUZZLE_Y + 0.01, BORE_Z), "R": (SIDE_X, MUZZLE_Y + 0.01, BORE_Z)}


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

    def span(self, bone, slot, x, spec, color):
        y0, y1, half, z0, z1 = spec
        return self.box(bone, slot, (2 * half, y1 - y0, z1 - z0), ((x), (y0 + y1) / 2, (z0 + z1) / 2), color=color)

    def rod(self, bone, slot, a, b, r, segs, color=None):
        return self.mark(self.part.rod(slot, a, b, r, segs, color=color, alpha=0.0), bone)

    def lathe(self, bone, origin, profile, sides, slots, color=None, roll=0.0):
        """A closed surface of revolution about +Y through origin. profile: (y, r) from one end to
        the other, r 0 only at the two ends (a pole). slots[i] paints the band from point i to i + 1."""
        bm = self.part.bm
        o = Vector(origin)
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

    def drum(self, bone, side):
        """The fluted drum: 12 sides alternating crest and valley, six hexagonal chamber recesses
        12 mm deep in its front face, every chamber under a crest; the top chamber lines up with
        the bore. One closed island, charcoal."""
        bm = self.part.bm
        x = side_x(side)
        y0, y1 = DRUM_Y
        rc, rh, depth = CHAMBER

        def at(y, a, r, cx=0.0, cz=0.0):
            return bm.verts.new(Vector((x + cx + r * math.cos(a), y, DRUM_Z + cz + r * math.sin(a))))

        crest = [math.pi / 2 + k * math.pi / 3 for k in range(6)]
        outline_a = []
        for k in range(6):
            outline_a += [(crest[k] - math.pi / 6, DRUM_R[1]), (crest[k], DRUM_R[0])]
        front = [at(y1, a, r) for a, r in outline_a]
        back = [at(y0, a, r) for a, r in outline_a]
        faces = []
        n = len(front)
        for i in range(n):
            j = (i + 1) % n
            faces.append(bm.faces.new((back[i], back[j], front[j], front[i])))
        cb = bm.verts.new(Vector((x, y0, DRUM_Z)))
        for i in range(n):
            faces.append(bm.faces.new((back[(i + 1) % n], back[i], cb)))
        cf = bm.verts.new(Vector((x, y1, DRUM_Z)))
        for k in range(6):
            t = crest[k]
            cx, cz = rc * math.cos(t), rc * math.sin(t)
            # Hexagon corners at 0, 60 ... 300 degrees from the chamber's outward direction.
            hole = [at(y1, t + m * math.pi / 3, rh, cx, cz) for m in range(6)]
            floor = [at(y1 - depth, t + m * math.pi / 3, rh, cx, cz) for m in range(6)]
            vm, vc, vp = front[(2 * k) % n], front[(2 * k + 1) % n], front[(2 * k + 2) % n]
            h = hole
            for tri in ((cf, vm, h[4]), (cf, h[4], h[3]), (vm, h[5], h[4]), (vm, vc, h[5]), (vc, h[0], h[5]),
                        (vc, h[1], h[0]), (vc, vp, h[1]), (vp, h[2], h[1]), (vp, cf, h[2]), (cf, h[3], h[2])):
                faces.append(bm.faces.new(tri))
            for m in range(6):
                q = (m + 1) % 6
                faces.append(bm.faces.new((hole[m], hole[q], floor[q], floor[m])))
            faces.append(bm.faces.new(floor[::-1]))
        self.part.paint(faces, "paint", "charcoal", alpha=0.0)
        return self.mark(faces, bone)


def tool(kit, side):
    tag = "L" if side < 0 else "R"
    x = side_x(side)
    inb = inboard(side)
    tool_b, slide_b, crane_b, drum_b = ("tool." + tag, "slide." + tag, "crane." + tag, "drum." + tag)
    # Clamp saddle on the band, its two copper bolt heads facing out (keeper gear shows its fasteners).
    s = saddle_centre(side)
    phi = math.atan2(s.y, s.x)
    r_in, r_out, along, z0, z1 = SADDLE
    radial = Vector((math.cos(phi), math.sin(phi), 0.0))
    tangent = Vector((-math.sin(phi), math.cos(phi), 0.0))
    centre = radial * ((r_in + r_out) / 2) + Vector((0, 0, (z0 + z1) / 2))
    kit.box("mount", "paint", (r_out - r_in, along, z1 - z0), centre, rot=(0, 0, phi), color="charcoal")
    br, blen, boff, bz = BOLT
    for t in (-1, 1):
        base = radial * (r_out - blen / 2) + tangent * (t * boff) + Vector((0, 0, bz))
        kit.rod("mount", "copper", base, base + radial * blen, br, 6)
    # Frame: rear block (the recoil shield behind the drum), top strap over the drum, front lug
    # round the barrel (it recoils with the barrel), and a lower rail inboard under the drum to the
    # lug the crane hinge turns in. Bone paint.
    with kit.part.region(bevel=0.006):
        kit.span(tool_b, "paint", x, REAR, "bone")
        kit.span(tool_b, "paint", x, STRAP, "bone")
        kit.span(tool_b, "paint", x + inb * RAIL_IN, RAIL, "bone")
        kit.span(slide_b, "paint", x, LUG, "bone")
        kit.span(tool_b, "paint", x + inb * HINGE[0], HINGE_LUG, "bone")
    # The rivet-header knuckle off the rear block, copper.
    kit.lathe(tool_b, (x, 0, KNUCKLE_Z), KNUCKLE, 8, [("copper", None)] * (len(KNUCKLE) - 1))
    # Barrel shroud with three shallow ring grooves, the crown, and the charcoal bore 20 mm deep.
    y0, y1, rb = BARREL
    half, deep = GROOVE
    profile = [(y0, 0.0), (y0, rb)]
    for g in GROOVES:
        profile += [(g - half, rb), (g, rb - deep), (g + half, rb)]
    profile += [(y1, rb), (y1, BORE_R), (y1 - BORE_DEPTH, BORE_R), (y1 - BORE_DEPTH, 0.0)]
    slots = [("copper", None)] * (len(profile) - 3) + [("paint", "charcoal")] * 2
    kit.lathe(slide_b, (x, 0, BORE_Z), profile, BARREL_SIDES, slots, roll=math.pi / BARREL_SIDES)
    # Crane: hinge pin, arm to the drum axle, ejector rod. Bone paint.
    hx, hz, hy0, hy1, hr = HINGE
    kit.rod(crane_b, "paint", (x + inb * hx, hy0, hz), (x + inb * hx, hy1, hz), hr, 6, color="bone")
    a0, a1, thick = ARM
    arm_a = Vector((x + inb * hx, 0, hz))
    arm_b = Vector((x, 0, DRUM_Z))
    mid = (arm_a + arm_b) / 2
    reach = (arm_b - arm_a).length + 0.016
    tilt = math.atan2(arm_b.z - arm_a.z, arm_b.x - arm_a.x)
    kit.box(crane_b, "paint", (reach, a1 - a0, 0.016), (mid.x, (a0 + a1) / 2, mid.z), rot=(0, -tilt, 0), color="bone")
    e0, e1, er = EJECTOR
    kit.rod(crane_b, "paint", (x, e0, DRUM_Z), (x, e1, DRUM_Z), er, 6, color="bone")
    kit.drum(drum_b, side)


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
        tool(kit, side)
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
    print("REVOLVERS tris=%d verts=%d draws=%d reach=%.4f (limit %.2f)" % (tris, len(obj.data.vertices), draws, reach, REACH))
    arm = rig(root, obj)
    ok = TRIS[0] <= tris <= TRIS[1] and draws == DRAWS and reach <= REACH and closed
    out = common.args()["out"] or os.path.join(common.MODELS, "world_one", "rivet_revolvers.glb")
    export(root, arm, out)
    if not ok:
        raise SystemExit("rivet_revolvers out of budget, reach or watertight")


if __name__ == "__main__":
    main()
