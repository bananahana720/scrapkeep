"""The remembered Cannon's Hoberman mecha (wave 13, unit PD-CANNON; rebuilt wave 46, unit E2-06),
on shell_base.hoberman().

Concept: E2-06 holds to the heroic cutaway sheet (Andrew, 23 Nov 2026), held in another worktree's
artifacts/local/w46-concept-art/heroic-cutaway/06-cannon-heroic-cutaway.png and not committed:
a massive stepped Old-Works barrel flanking the solid cutaway ball on a bone side yoke, raised
unlit petrol bands with one notched ancient-green seam each, a heavy sliding breech collar,
and bold split ports with closing jaws. Earlier set: artifacts/local/alpha/push/w13/concepts/codex/cannon/.
Design: design-v3/ROSTER-LOOK.md sections 0, 2 to 6; pilots/cannon.md section 5; PILOT-CLIPS.md
section 5 (controls); PILOT-CADENCE.md sections 3.6 and 5.3 (the brackets close to the lock);
CUSTOMIZE.md section 8 (the Choir Barrel variant).

  blender --background --threads 2 --python-exit-code 1 \
    --python world_one/shell_cannon.py -- [--variant choir] [--out <file.glb>] [--render <dir>]
under prlimit's 12 GiB address-space cap (tools/blender/PILOT-RIG.md:72).

Writes world_one/shell_cannon.glb, or shell_cannon_choir.glb with --variant choir (the earned
shell: only the muzzle differs). The heft layers come from shell_cannon_plates.py.
pilot_cannon.py imports build() and MODEL; run it with sha256sum before and after.

Node tree, Blender +Y forward, +Z up (Godot -Z forward, +Y up):
  Core                        the petrol lattice from hoberman(), tumbling with the ball; its
                              rubber tread caps fold into paint in charcoal (one draw fewer)
  Pod                         seat (charcoal), controls, the rush ring at the bottom
  Pod > SplitPorts            an armature holding the two split ports at 5 and 7 o'clock from
                              the mid chase eye; carrier bank tilts it (hero_assets BRACKET_PARTS)
  Pod > SplitPorts > SplitPortsMesh  both ports in one skinned mesh (copper, rubber): blocks,
                              bores and gap brackets on bone Root; each port's rear jaws on
                              JawUpper.R/L and JawLower.R/L, which slide on the port's up axis
                              (bone +Y) and meet flush at the lock (clips/cannon.json machinery)
  Pod > Gyro > GyroInner      the gimbal rings
  Pod > WeaponRing            bone band, charcoal clamps and collar, the bone side yoke (saddle,
                              cheek and trunnion pin) on the pilot's left; yawed to the aim by
                              hero_assets; BarrelPivot marks the trunnion
  Pod > WeaponRing > MainBarrel  the stepped cast barrel beside the ball, parallel to the aim;
                              pitches on its origin (the trunnion) from -10 to +35 degrees;
                              LaneMuzzle, SectorShutter and SectorPivot ride it
  Pod > WeaponRing > MainBarrel > BreechCollar  the heavy ribbed collar on the breech step; it
                              slides back COLLAR_KICK along the bore on each shot (machinery)
Draws: Core paint, copper; Pod rubber, copper; Gyro; GyroInner; WeaponRing paint; MainBarrel
ancient_enamel, class_accent; BreechCollar ancient_enamel; SplitPortsMesh copper, rubber. Twelve,
the registry exception (assets/registry.d/shell_cannon.json) and hero_six_pilot_budget_test's
class V row: the collar's draw is the one the Core's rubber fold frees, and the four jaws ride
bones of the ports' one mesh, so they cost none.

Silhouette (E2-06, Andrew's ruling of 23 Nov 2026 and the concept sheet): the barrel rides the
weapon ring beside the ball, X_C out on the pilot's left and Z_C above the band, parallel to the
aim, so from the chase camera it breaks the left outline at every aim, not only when the aim
swings off the camera's line (PILOT-CADENCE section 5.1's hidden nose). The ruling lifts the
weapon reach cap from 1.48 m to REACH_CAP; main() prints it on CANNON_REACH. Nothing outside the
ball stands below GROUND_Z. The split ports stay at 5 and 7 o'clock (the low read) on the same
port frame, so the class V hoods of shell_cannon_plates.py still seat on them.
"""
import math
from pathlib import Path
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import common
from common import Part
import shell_base as sb

MODEL = HERE.parents[2] / "assets/models/world_one/shell_cannon.glb"
VARIANT_MODELS = {"choir": HERE.parents[2] / "assets/models/world_one/shell_cannon_choir.glb"}
SHELL_BAND = (3000, 11000)
TRI_HOLD = {"": 7738, "choir": 7742}
DRAW_CAP = 12
REACH_CAP = 1.75
GROUND_Z = -0.55

ENAMEL = "petrol"
SEAT = "charcoal"
BANK = (("PlateCrank", "crank"), ("CableClamp", "lever"))
STONE = "736b5a"
SLATE = common.mix("petrol", "charcoal", 0.55)
DARK = common.mix("charcoal", "petrol", 0.15)
PETROL = common.mix("petrol", "charcoal", 0.05)
BAND = "5e4836"
BORE = "242a28"
CHOIR = common.mix("petrol", STONE, 0.35)

SIDE = -1
X_C = 1.22
Z_C = 0.28
PIVOT = Vector((SIDE * X_C, -0.18, Z_C))
PITCH = (-10.0, 35.0)
PROFILE = (
    (-0.43, -0.39, 0.185, 0.185, DARK),
    (-0.40, 0.11, 0.215, 0.215, SLATE),
    (0.105, 0.15, 0.215, 0.172, SLATE),
    (0.145, 0.62, 0.172, 0.158, SLATE),
    (0.615, 0.66, 0.158, 0.138, SLATE),
)
MUZZLE_Y = 1.035
MUZZLE_R = (0.075, 0.155)
MUZZLE = ((0.655, 0.97, 0.138, 0.132, SLATE), (0.965, MUZZLE_Y, 0.155, 0.155, DARK))
BREECH_R = 0.215
BANDS_Y = (-0.22, 0.30, 0.48, 0.80)
BAND_W = 0.045
BAND_PROUD = 0.02
SEAM_W = 0.006
SEAM_PROUD = 0.004
NOTCH_ARC = 0.035
STRAP = (-0.33, -0.30, 0.226)
SHUTTER = (-0.15, 0.21, 0.255)
COLLAR_Y = (-0.02, 0.10)
COLLAR_R = 0.235
COLLAR_KICK = 0.09
RING_SEGS = 32
COLLAR_SEGS = 20


def body_r(y):
    """The cast body's radius at y (the muzzle section's for y past the profile)."""
    for y0, y1, r0, r1, _ in PROFILE + MUZZLE[:1]:
        if y0 <= y <= y1:
            return r0 + (r1 - r0) * (y - y0) / (y1 - y0)
    return MUZZLE[0][3]


def ax(y):
    """The barrel axis at y, in Pod space."""
    return Vector((SIDE * X_C, y, Z_C))


PORT_DIR = Vector((0.37, -0.83, -0.415))
PORT_R = 1.045
PORT_SIZE = (0.11, 0.26, 0.12)
BORE_R = 0.034
BLOCK = (0.15, (-0.13, 0.045), 0.15)
JAW = (0.20, 0.05, 0.075)
JAW_F = -0.20
JAW_N = 0.035
JAW_TRAVEL = 0.07
JAW_BONES = ("JawUpper.R", "JawLower.R", "JawUpper.L", "JawLower.L")
RUSH = (0.14, 0.21, 0.04, -0.88)


def flag(name, default=None):
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if name not in argv:
        return default
    i = argv.index(name)
    return argv[i + 1] if i + 1 < len(argv) and not argv[i + 1].startswith("--") else True


def reslot(part, old, new):
    """Moves every face on slot old to slot new and drops old from the part (one draw less)."""
    if old not in part.slots:
        return
    oi = part.slots.index(old)
    ni = part._slot(new)
    for f in part.bm.faces:
        if f.material_index == oi:
            f.material_index = ni
    part.slots.pop(oi)
    for f in part.bm.faces:
        if f.material_index > oi:
            f.material_index -= 1


def fold_slot(obj, slot, color):
    """Moves obj's faces on slot onto its paint surface in color (vertex colour, full paint take)
    and drops the slot, so obj spends one draw fewer (shell_tally.py fold_rubber). Returns the
    faces moved."""
    names = [m.name for m in obj.data.materials]
    if slot not in names or "paint" not in names:
        return 0
    src, pai = names.index(slot), names.index("paint")
    rgba = common.rgba(color)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    col = bm.loops.layers.float_color.get("Color")
    moved = 0
    for f in bm.faces:
        if f.material_index == src:
            f.material_index = pai
            for loop in f.loops:
                loop[col] = rgba
            moved += 1
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.materials.pop(index=src)
    return moved


def smooth_studs(core):
    """Shades the Core's closed pin studs (shell_base._stud: four triangles round four corners)
    smooth, so the exporter writes each with 4 vertices instead of 12. E1-03's closed lattice
    (72469a0ff) faceted them; this keeps the rebuilt Cannon inside the shell class's 11,600
    vertices until the base's _stud shades them itself (a no-op then). Returns the studs shaded."""
    bm = bmesh.new()
    bm.from_mesh(core.data)
    seen = set()
    count = 0
    for f in bm.faces:
        if f in seen:
            continue
        island, todo = [], [f]
        seen.add(f)
        while todo:
            g = todo.pop()
            island.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h not in seen:
                        seen.add(h)
                        todo.append(h)
        verts = {v for g in island for v in g.verts}
        if len(island) == 4 and len(verts) == 4 and all(len(g.verts) == 3 for g in island):
            for g in island:
                g.smooth = True
                for e in g.edges:
                    e.smooth = True
            count += 1
    bm.to_mesh(core.data)
    bm.free()
    return count


def port_axes(side):
    """(centre, radial, forward, up) of one split port block; side +1 right, -1 left."""
    n = Vector((side * PORT_DIR.x, PORT_DIR.y, PORT_DIR.z)).normalized()
    f = Vector((0, 1, 0))
    f = (f - n * n.dot(f)).normalized()
    u = n.cross(f)
    if u.z < 0:
        u = -u
    return n * PORT_R, n, f, u


def oriented_box(part, slot, centre, axes, size, color=None):
    """A box with edges along the three given unit axes."""
    a, b, c = axes
    m = Matrix((
        (a.x * size[0], b.x * size[1], c.x * size[2], centre.x),
        (a.y * size[0], b.y * size[1], c.y * size[2], centre.y),
        (a.z * size[0], b.z * size[1], c.z * size[2], centre.z),
        (0, 0, 0, 1)))
    r = bmesh.ops.create_cube(part.bm, size=1.0, matrix=m)
    return part.paint(part._faces(r["verts"]), slot, color)


def jaw_centre(side, upper, closed=False):
    """A rear jaw's centre in Pod space, open (the rest pose) or at the flush lock."""
    c, n, f, u = port_axes(side)
    lift = JAW[2] / 2 + (0.0 if closed else JAW_TRAVEL)
    return c + f * JAW_F + n * JAW_N + u * (lift if upper else -lift)


def split_port(p, side, weigh):
    """One port: a chunky twin-bore copper block with copper flanges and rubber bores on a rubber
    gap bracket (bone Root), and its two rear copper jaws, each a bar and a lip (its own bone)."""
    c, n, f, u = port_axes(side)
    tag = "R" if side > 0 else "L"
    rad, (f0, f1), up = BLOCK
    mid = c + f * ((f0 + f1) / 2)
    weigh(oriented_box(p, "copper", mid, (n, f, u), (rad, f1 - f0, up)), "Root")
    for along in (f0 + 0.03, f1 - 0.015):
        weigh(oriented_box(p, "copper", c + f * along, (n, f, u), (rad + 0.01, 0.03, up + 0.01)), "Root")
    for off in (-0.035, 0.035):
        m = c + n * off
        weigh(p.rod("rubber", m + f * (f0 - 0.012), m + f * (f1 + 0.012), BORE_R, 8), "Root")
    weigh(p.rod("rubber", Vector((side * 0.30, -0.20, -0.36)), c - n * (rad / 2), 0.03, 6), "Root")
    for upper in (True, False):
        bone = ("JawUpper." if upper else "JawLower.") + tag
        j = jaw_centre(side, upper)
        sign = 1 if upper else -1
        weigh(oriented_box(p, "copper", j, (n, f, u), JAW), bone)
        lip = j + f * (JAW[1] / 2 + 0.028) + u * (sign * (JAW[2] / 2 - 0.012))
        weigh(oriented_box(p, "copper", lip, (n, f, u), (JAW[0] - 0.004, 0.06, 0.02)), bone)


def split_ports(pod):
    """Both split ports as one skinned mesh under the SplitPorts armature (origin at the pod's).
    The armature is not part of the Pod mesh, so hero_assets banks it with the carrier; one mesh
    for the pair costs two draws (copper, rubber), and the four rear jaws ride bones of it, so
    they move on their own ports' axes for no draw (mecha_motion.gd bone rows)."""
    groups = ("Root",) + JAW_BONES
    p = Part("SplitPortsMesh")
    deform = p.bm.verts.layers.deform.verify()

    def weigh(faces, bone):
        g = groups.index(bone)
        for v in p.verts_of(faces):
            v[deform][g] = 1.0
    for side in (1, -1):
        split_port(p, side, weigh)
    sb._sharpen(p)
    arm = bpy.data.armatures.new("SplitPortsRig")
    rig = bpy.data.objects.new("SplitPorts", arm)
    bpy.context.scene.collection.objects.link(rig)
    common.place(rig, (0, 0, 0), pod)
    bpy.context.view_layer.update()
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    root = arm.edit_bones.new("Root")
    root.head, root.tail = Vector((0, 0, 0)), Vector((0, 0, 0.1))
    for name in JAW_BONES:
        side = 1 if name.endswith("R") else -1
        _, n, _, u = port_axes(side)
        head = jaw_centre(side, name.startswith("JawUpper"))
        b = arm.edit_bones.new(name)
        b.head, b.tail = head, head + u * 0.08
        b.align_roll(n)
        b.parent = root
    bpy.ops.object.mode_set(mode="OBJECT")
    mesh = p.to_object((0, 0, 0), rig)
    for name in groups:
        mesh.vertex_groups.new(name=name)
    mod = mesh.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    return rig, mesh


def rush_ring(p):
    r_in, r_out, depth, z = RUSH
    p.ring("copper", r_in, r_out, depth, 12, loc=(0, 0, z))
    p.ring("rubber", r_out, r_out + 0.014, depth * 0.75, 12, loc=(0, 0, z))
    for y in (-1, 1):
        p.rod("rubber", (0, y * 0.10, sb.SEAT_TOP - 0.17), (0, y * (r_in + r_out) / 2, z + depth / 2), 0.018, 6)


_BASE_COCKPIT = sb.cockpit
_BASE_RING = sb.weapon_ring


def cannon_cockpit(seat, bank):
    """hoberman's cockpit with the Cannon's rush ring; the seat moves to rubber."""
    p = _BASE_COCKPIT(seat, bank)
    rush_ring(p)
    reslot(p, "paint", "rubber")
    sb._sharpen(p)
    return p


def cannon_ring():
    """The level band on one paint draw: worn bone segments, charcoal clamp blocks, the charcoal
    collar with closed studs, and the bone side yoke that carries the barrel on the pilot's left:
    a saddle from the band up under the breech, an outer cheek and the trunnion pin."""
    r = Part("WeaponRing")
    b_in, b_out, b_h, b_z = sb.RING_BAND
    r.ring("paint", b_in, b_out, b_h, RING_SEGS, loc=(0, 0, b_z), color="bone")
    for k in range(10):
        a = (k + 0.5) * math.tau / 10
        if SIDE * math.cos(a) > 0.8:
            continue
        r.box("paint", (0.06, b_out - b_in + 0.012, b_h + 0.012), loc=((b_in + b_out) / 2 * math.cos(a),
              (b_in + b_out) / 2 * math.sin(a), b_z), rot=(0, 0, a + math.pi / 2), color="charcoal")
    c_in, c_out, c_h, c_z = sb.RING_COLLAR
    r.ring("paint", c_in, c_out, c_h, COLLAR_SEGS, loc=(0, 0, c_z), color="charcoal")
    for k in range(12):
        a = k * math.tau / 12 + 0.13
        n = Vector((math.cos(a), math.sin(a), 0))
        sb._stud(r, n * (c_out + 0.002) + Vector((0, 0, c_z)), n, 0.012, 0.006, "paint", "charcoal")
    py = PIVOT.y
    r.box("paint", (0.30, 0.12, 0.11), loc=(SIDE * 1.19, py, 0.02), color="bone")
    cheek_x = X_C + BREECH_R + 0.03
    r.box("paint", (0.04, 0.12, Z_C + 0.135), loc=(SIDE * cheek_x, py, (Z_C + 0.065) / 2), color="bone")
    r.rod("paint", (SIDE * (X_C - 0.07), py, Z_C), (SIDE * (cheek_x + 0.035), py, Z_C), 0.045, 8, color="bone")
    r.rod("paint", (SIDE * (cheek_x + 0.015), py, Z_C), (SIDE * (cheek_x + 0.045), py, Z_C), 0.065, 8,
          color="charcoal")
    sb._sharpen(r)
    return r


def _band(b, y, k):
    """One raised petrol band at y with its 6 mm seam and the seam's notch at its own angle."""
    band_r = body_r(y) + BAND_PROUD
    b.rod("ancient_enamel", ax(y - BAND_W / 2), ax(y + BAND_W / 2), band_r, 12, color=PETROL)
    seam = b.rod("class_accent", ax(y - SEAM_W / 2), ax(y + SEAM_W / 2), band_r + SEAM_PROUD, 12)
    b.paint([f for f in seam if len(f.verts) > 4], "ancient_enamel", PETROL)
    a = math.pi / 2 + SIDE * (0.6 + 0.5 * k)
    d = Vector((math.cos(a), 0, math.sin(a)))
    y_axis = Vector((0, 1, 0))
    oriented_box(b, "ancient_enamel", ax(y) + d * (band_r + 0.002), (d, y_axis, y_axis.cross(d)),
                 (0.016, 0.014, NOTCH_ARC), PETROL)


def barrel(variant=""):
    """MainBarrel in Pod space: the stepped slate casting from rear cap to muzzle, the keeper strap,
    four raised petrol bands with notched seams, the sector shield on top of the breech and the
    muzzle. The Choir Barrel recasts the muzzle as a six-shuttered housing
    (src/boss/mind_dress.gd SHUTTERS)."""
    b = Part("MainBarrel")
    for k, (y0, y1, r0, r1, color) in enumerate(PROFILE):
        b.rod("ancient_enamel", ax(y0), ax(y1), r0, 12 if k == 0 else 16, color=color, r2=r1)
    b.rod("ancient_enamel", ax(STRAP[0]), ax(STRAP[1]), STRAP[2], 12, color=BAND)
    for k, y in enumerate(BANDS_Y):
        _band(b, y, k)
    s_y, s_in, s_out = SHUTTER
    b.ring("ancient_enamel", s_in, s_out, 0.04, 6, loc=ax(s_y), rot=(math.pi / 2, 0, 0),
           color=BAND, arc=(math.pi / 3, 2 * math.pi / 3))
    if variant == "choir":
        y0, y1, r0, r1, color = MUZZLE[0]
        b.rod("ancient_enamel", ax(y0), ax(0.905), r0, 12, color=color, r2=r1)
        b.cyl("ancient_enamel", 0.168, 0.160, 0.065, 6, loc=ax(0.93), rot=(math.pi / 2, 0, 0), color=CHOIR)
        for k in range(6):
            a = k * math.tau / 6 + math.pi / 6
            d = Vector((math.cos(a), 0, math.sin(a)))
            b.beam("ancient_enamel", ax(0.962) + d * 0.10, ax(1.02) + d * 0.152, 0.07, 0.014, color=STONE, roll=a)
            g = a + math.pi / 6
            b.ring("class_accent", 0.085, 0.13, 0.004, 1, loc=ax(0.9635), rot=(math.pi / 2, 0, 0),
                   arc=(g - 0.05, g + 0.05))
        b.rod("ancient_enamel", ax(0.958), ax(0.968), 0.07, 8, color=BORE)
    else:
        for y0, y1, r0, r1, color in MUZZLE:
            b.rod("ancient_enamel", ax(y0), ax(y1), r0, 16, color=color, r2=r1)
        b.rod("ancient_enamel", ax(MUZZLE_Y - 0.004), ax(MUZZLE_Y + 0.004), 0.075, 8, color=BORE)
    sb._sharpen(b)
    return b


def breech_collar():
    """BreechCollar: the heavy dark collar on the breech step with six petrol ribs, its origin on
    the bore axis at its centre, so a machinery row slides it back along the bore."""
    c = Part("BreechCollar")
    y0, y1 = COLLAR_Y
    c.rod("ancient_enamel", ax(y0), ax(y1), COLLAR_R, 16, color=DARK)
    y_axis = Vector((0, 1, 0))
    inward = math.atan2(-Z_C, -SIDE * X_C)
    for k in range(6):
        a = inward + math.pi / 6 + k * math.tau / 6
        d = Vector((math.cos(a), 0, math.sin(a)))
        oriented_box(c, "ancient_enamel", ax((y0 + y1) / 2) + d * (COLLAR_R + 0.008), (d, y_axis, y_axis.cross(d)),
                     (0.034, y1 - y0 - 0.02, 0.05), PETROL)
    sb._sharpen(c)
    return c


def socket(name, loc, forward, parent):
    """An empty whose local +Y (Godot -Z after export) points along forward."""
    obj = common.empty(name, loc, parent)
    obj.rotation_euler = Vector((0, 1, 0)).rotation_difference(Vector(forward).normalized()).to_euler()
    return obj


def build(variant=""):
    """The Cannon's shell root (pilot_cannon.py calls this and exports it)."""
    return build_shell(variant)["root"]


def build_shell(variant=""):
    """The Cannon's shell under ShellCannon; returns hoberman()'s dict plus barrel, collar and
    ports. variant "" or "choir"."""
    sb.cockpit, sb.weapon_ring = cannon_cockpit, cannon_ring
    try:
        shell = sb.hoberman("Cannon", enamel=ENAMEL, seat=SEAT, pairs=2, bank=BANK)
    finally:
        sb.cockpit, sb.weapon_ring = _BASE_COCKPIT, _BASE_RING
    bpy.data.objects.remove(shell["pilot"], do_unlink=True)
    pod, ring, core = shell["pod"], shell["ring"], shell["core"]
    print("CORE rubber folded into paint: %d faces; studs shaded smooth: %d"
          % (fold_slot(core, "rubber", "charcoal"), smooth_studs(core)))
    rig, ports = split_ports(pod)
    main = barrel(variant).to_object(PIVOT, ring)
    collar = breech_collar().to_object(ax(sum(COLLAR_Y) / 2), main)
    socket("BarrelPivot", PIVOT, (0, 1, 0), ring)
    socket("LaneMuzzle", ax(MUZZLE_Y + 0.002), (0, 1, 0), main)
    socket("SectorShutter", ax(SHUTTER[0]) + Vector((0, 0, (SHUTTER[1] + SHUTTER[2]) / 2)), (0, 1, 0), main)
    socket("SectorPivot", ax(SHUTTER[0]) + Vector((0, 0, SHUTTER[1])), (0, 1, 0), main)
    for side, tag in ((1, "R"), (-1, "L")):
        c, n, f, u = port_axes(side)
        socket("SplitExit." + tag, c - f * (PORT_SIZE[1] / 2), (side * 0.22, -1, 0), pod)
    socket("RushContact", (0, 0, RUSH[3] - RUSH[2] / 2), (0, 0, -1), pod)
    bpy.context.view_layer.update()
    shell.update({"barrel": main, "collar": collar, "ports": ports, "rig": rig})
    return shell


def draws(root):
    return sum(len(o.data.materials) for o in common.tree(root) if o.type == "MESH")


def _pitched(v, deg):
    a = math.radians(deg)
    d = v - PIVOT
    return Vector((v.x, PIVOT.y + d.y * math.cos(a) - d.z * math.sin(a), PIVOT.z + d.y * math.sin(a) + d.z * math.cos(a)))


def gun_points(shell):
    """Pod-space vertices of MainBarrel and of BreechCollar at rest and at full kick."""
    pts = [shell["barrel"].matrix_world @ v.co for v in shell["barrel"].data.vertices]
    for v in shell["collar"].data.vertices:
        w = shell["collar"].matrix_world @ v.co
        pts += [w, w - Vector((0, COLLAR_KICK, 0))]
    return pts


PITCHES = [PITCH[0] + (PITCH[1] - PITCH[0]) * i / 18 for i in range(19)]


def sweep_bins(ring, points, step=0.01):
    """The volume WeaponRing and the gun sweep as the ring yaws a full turn and the gun pitches
    over PITCH, as {z bin: [r min, r max]} in Pod space (r from the vertical axis). points is
    gun_points() or, for shell_cannon_plates.py, the MainBarrel object."""
    bins = {}
    if hasattr(points, "data"):
        points = [points.matrix_world @ v.co for v in points.data.vertices]

    def add(p):
        k = round(p.z / step)
        r = math.hypot(p.x, p.y)
        lo, hi = bins.get(k, (r, r))
        bins[k] = (min(lo, r), max(hi, r))
    for v in ring.data.vertices:
        add(ring.matrix_world @ v.co)
    for w in points:
        for deg in PITCHES:
            add(_pitched(w, deg))
    return bins


SWEEP_SKIP = ("WeaponRing", "Gyro", "Dome")


def sweep_hits(obj, bins, step=0.01, margin=0.01):
    """Vertices of obj's meshes (minus the ring, gimbal and pilot subtrees) inside the sweep."""
    hits = 0
    for o in sb.cone_meshes(obj):
        if o.name.split(".")[0] in SWEEP_SKIP:
            continue
        mw = o.matrix_world
        for v in o.data.vertices:
            p = mw @ v.co
            for k in (math.floor(p.z / step), math.ceil(p.z / step)):
                span = bins.get(k)
                if span and span[0] - margin <= math.hypot(p.x, p.y) <= span[1] + margin:
                    hits += 1
                    break
    return hits


def barrel_clearance(points):
    """(band hits, lattice clearance): gun vertices inside the ring's band or collar box at any
    pitch over PITCH, and the gun's smallest radius from the ball centre at any pitch."""
    boxes = [(b_in, b_out, b_z - b_h / 2, b_z + b_h / 2) for b_in, b_out, b_h, b_z in (sb.RING_BAND, sb.RING_COLLAR)]
    hits, closest = 0, 9.0
    for w in points:
        for deg in PITCHES:
            p = _pitched(w, deg)
            closest = min(closest, p.length)
            r = math.hypot(p.x, p.y)
            if any(lo <= r <= hi and z0 <= p.z <= z1 for lo, hi, z0, z1 in boxes):
                hits += 1
                break
    return hits, closest


def ground_hits(pod):
    """Pod-subtree vertices outside the ball (past the lattice) that stand below GROUND_Z."""
    low, bad = 9.0, 0
    for o in common.tree(pod):
        if o.type != "MESH":
            continue
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            if w.length > sb.CORE_LIMIT:
                low = min(low, w.z)
                bad += w.z < GROUND_Z
    return bad, low


def clock(point, eye=sb.CHASE_EYES[1]):
    """(degrees below horizontal, clock hour) of point about the ball centre, as projected from
    eye looking at the centre, 12 at the top."""
    fwd = (-eye).normalized()
    right = fwd.cross(Vector((0, 0, 1))).normalized()
    up = right.cross(fwd)

    def proj(q):
        d = q - eye
        z = d.dot(fwd)
        return Vector((d.dot(right) / z, d.dot(up) / z))
    o = proj(point) - proj(Vector())
    below = math.degrees(math.atan2(-o.y, abs(o.x)))
    hour = (math.degrees(math.atan2(o.x, o.y)) % 360) / 30
    return below, hour


GUN = ("WeaponRing", "MainBarrel", "BreechCollar")


def main():
    common.reset()
    variant = flag("--variant", "") or ""
    if variant not in ("",) + tuple(VARIANT_MODELS):
        raise SystemExit("unknown variant %s" % variant)
    shell = build_shell(variant)
    root, pod = shell["root"], shell["pod"]
    points = gun_points(shell)
    hits = sweep_hits(pod, sweep_bins(shell["ring"], points))
    n_draws = draws(root)
    tris = common.tri_total(root)
    hold = TRI_HOLD[variant]
    reach = max(common.max_radius(o) for o in common.tree(pod) if o.type == "MESH"
                and o.name not in GUN + ("Gyro", "GyroInner"))
    tip = max(common.max_radius(o) for o in common.tree(shell["ring"]) if o.type == "MESH")
    print("CANNON variant=%s tris=%d hold=%d %s draws=%d cap=%d" % (variant or "default", tris, hold,
          "fits" if tris <= hold else "OVER", n_draws, DRAW_CAP))
    print("CANNON_REACH pod modules %.3f (cap 1.25), ring and gun %.3f (cap %.2f)" % (reach, tip, REACH_CAP))
    print("BARREL_SWEEP %d Pod vertices inside the ring and gun sweep (pitch %+.0f to %+.0f, collar kicked) %s"
          % (hits, PITCH[0], PITCH[1], "ok" if hits == 0 else "OUT"))
    band_hits, closest = barrel_clearance(points)
    print("BREECH face %.3f m across; band hits %d; nearest to centre %.3f (lattice %.3f) %s"
          % (2 * BREECH_R, band_hits, closest, sb.CORE_LIMIT,
             "ok" if band_hits == 0 and closest > sb.CORE_LIMIT else "OUT"))
    low_bad, low_z = ground_hits(pod)
    print("GROUND %d Pod vertices outside the ball below Z %.2f; lowest outside %.3f %s"
          % (low_bad, GROUND_Z, low_z, "ok" if low_bad == 0 else "OUT"))
    print("COLLAR kick %.3f m along the bore; JAW travel %.3f m each, %.3f m gap open, flush at the lock"
          % (COLLAR_KICK, JAW_TRAVEL, 2 * JAW_TRAVEL))
    ports_ok = True
    for side, tag in ((1, "R"), (-1, "L")):
        below, hour = clock(port_axes(side)[0])
        ok = 55.0 <= below <= 65.0
        ports_ok = ports_ok and ok
        print("CLOCK SplitExit.%s %.1f degrees below horizontal, %.2f o'clock from the mid chase eye %s"
              % (tag, below, hour, "ok" if ok else "OUT"))
    if (hits or band_hits or closest <= sb.CORE_LIMIT or not ports_ok or n_draws > DRAW_CAP or reach > 1.25
            or tip > REACH_CAP or low_bad or tris > hold):
        raise SystemExit("cannon shell out of contract")
    no_pilot = common.empty("NoPilot")
    out = common.args()["out"] or str(VARIANT_MODELS.get(variant, MODEL))
    sb.finish("Cannon", root, shell["core"], no_pilot, shell_band=SHELL_BAND, pod_obj=pod, out=out)


if __name__ == "__main__":
    main()
