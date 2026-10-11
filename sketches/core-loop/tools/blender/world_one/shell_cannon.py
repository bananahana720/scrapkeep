"""The remembered Cannon's Hoberman mecha (wave 13, unit PD-CANNON), on shell_base.hoberman().

Concept (approved as one set, docs/decisions.tsv w13-look rows of 2026-10-10):
  artifacts/local/alpha/push/w13/concepts/codex/cannon/hero.png, chase.png, sheet.png
  artifacts/local/alpha/push/w13/concepts/codex/base/base-hero.png, mechanism.png
Design: design-v3/ROSTER-LOOK.md sections 0, 2 to 6; pilots/cannon.md section 5; PILOT-CLIPS.md
section 5 (controls); CUSTOMIZE.md section 8 (the Choir Barrel variant).

  blender --background --threads 2 --python-exit-code 1 \
    --python world_one/shell_cannon.py -- [--variant choir] [--out <file.glb>] [--render <dir>]
under prlimit's 12 GiB address-space cap (tools/blender/PILOT-RIG.md:72).

Writes world_one/shell_cannon.glb, or shell_cannon_choir.glb with --variant choir (the earned
shell: only the barrel housing differs). The heft layers come from shell_cannon_plates.py.
pilot_cannon.py imports build() and MODEL; run it with sha256sum before and after.

Node tree, Blender +Y forward, +Z up (Godot -Z forward, +Y up):
  Core                        the petrol lattice from hoberman(), tumbling with the ball
  Pod                         seat (charcoal), controls, split ports at about 4 and 8 o'clock
                              from the chase eye on gap brackets, the rush ring at the bottom
  Pod > Gyro > GyroInner      the gimbal rings
  Pod > WeaponRing            bone band, charcoal clamps and collar, the barrel's trunnion cheeks;
                              yawed to the aim by hero_assets; BarrelPivot marks the trunnion axis
  Pod > WeaponRing > MainBarrel  the cast barrel at 12 o'clock on the equator; pitches on its
                              origin (the trunnion, BarrelPivot) from -10 to +35 degrees;
                              LaneMuzzle, SectorShutter and SectorPivot ride it
Draws: Core paint, copper, rubber; Pod rubber, copper; Gyro; GyroInner; WeaponRing paint;
MainBarrel ancient_enamel, class_accent. Ten, the shell cap. The seat rides rubber and the whole
ring rides paint so the barrel can carry the class glow in the same ten.
"""
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import common  # noqa: E402
from common import Part  # noqa: E402
import shell_base as sb  # noqa: E402

MODEL = HERE.parents[2] / "assets/models/world_one/shell_cannon.glb"
VARIANT_MODELS = {"choir": HERE.parents[2] / "assets/models/world_one/shell_cannon_choir.glb"}
SHELL_BAND = (3000, 11000)
TARGET_TRIS = 6600
DRAW_CAP = 10

# Lattice enamel, seat and controls (ROSTER-LOOK 0.2, 6; PILOT-CLIPS section 5).
ENAMEL = "petrol"
SEAT = "charcoal"
BANK = (("PlateCrank", "crank"), ("CableClamp", "lever"))
# Cast colours. ancient_enamel stays at or under HSV value and saturation 0.45 (the section 11
# enamel cap, hero_assets_test ENAMEL_CAP), so the bone barrel of the pictures is cast stone at
# the cap, with dark copper-brown family bands.
STONE = "736b5a"
STONE_DARK = common.mix(STONE, "charcoal", 0.35)
BAND = "5e4836"
BORE = "242a28"
CHOIR = common.mix("petrol", STONE, 0.35)

# The barrel (pilots/cannon.md section 5). Trunnion on the ring's front arc at the equator; the
# breech face clears the band (outer 1.08) at +35 degrees and the lattice (0.985) at every pitch.
PIVOT = Vector((0.0, 1.13, 0.0))
PITCH = (-10.0, 35.0)
BREECH_Y = 1.10
MUZZLE_Y = 1.47
BODY_R = (0.118, 0.108)
BANDS_Y = (1.20, 1.26, 1.32, 1.38)  # lane, split, rush, plate, breech to muzzle
BAND_R = 0.127
MUZZLE_R = (0.066, 0.132)
CHEEK_X = 0.165

# Split ports (bracket carriers): twin-bore copper blocks low on each side, 0.12 m past the
# lattice, above Z -0.6 (ROSTER-LOOK section 3 rule 6). From the chase eye they sit at about 4
# and 8 o'clock (rule 6 keeps them off 5 and 7); the bores face the rear for the recoil lanes.
PORT_DIR = Vector((0.84, -0.20, -0.47))
PORT_R = 1.045
PORT_SIZE = (0.11, 0.26, 0.12)   # radial, forward, up
BORE_R = 0.03
# Rush ring under the pod, inside the lattice and outside the gimbal sweep (0.862).
RUSH = (0.14, 0.21, 0.04, -0.88)  # r_in, r_out, depth, z


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
    import bmesh
    from mathutils import Matrix
    a, b, c = axes
    m = Matrix((
        (a.x * size[0], b.x * size[1], c.x * size[2], centre.x),
        (a.y * size[0], b.y * size[1], c.y * size[2], centre.y),
        (a.z * size[0], b.z * size[1], c.z * size[2], centre.z),
        (0, 0, 0, 1)))
    r = bmesh.ops.create_cube(part.bm, size=1.0, matrix=m)
    return part.paint(part._faces(r["verts"]), slot, color)


def split_ports(p):
    """Twin-bore copper blocks with rubber bores and copper flanges, on rubber gap brackets."""
    for side in (1, -1):
        c, n, f, u = port_axes(side)
        oriented_box(p, "copper", c, (n, f, u), PORT_SIZE)
        for along in (-0.09, 0.09):
            oriented_box(p, "copper", c + f * along, (n, f, u), (PORT_SIZE[0] + 0.012, 0.03, PORT_SIZE[2] + 0.012))
        for off in (-0.027, 0.027):
            mid = c + n * off
            p.rod("rubber", mid - f * (PORT_SIZE[1] / 2 + 0.02), mid + f * (PORT_SIZE[1] / 2 + 0.02), BORE_R, 8)
        p.rod("rubber", Vector((side * 0.50, -0.10, -0.36)), c - n * (PORT_SIZE[0] / 2), 0.022, 6)


def rush_ring(p):
    r_in, r_out, depth, z = RUSH
    p.ring("copper", r_in, r_out, depth, 12, loc=(0, 0, z))
    p.ring("rubber", r_out, r_out + 0.014, depth * 0.75, 12, loc=(0, 0, z))
    for y in (-1, 1):
        p.rod("rubber", (0, y * 0.10, sb.SEAT_TOP - 0.17), (0, y * (r_in + r_out) / 2, z + depth / 2), 0.018, 6)


_BASE_COCKPIT = sb.cockpit
_BASE_RING = sb.weapon_ring


def cannon_cockpit(seat, bank):
    """hoberman's cockpit with the Cannon's ports and rush ring; the seat moves to rubber."""
    p = _BASE_COCKPIT(seat, bank)
    split_ports(p)
    rush_ring(p)
    reslot(p, "paint", "rubber")
    sb._sharpen(p)
    return p


def cannon_ring():
    """The level band on one paint draw: worn bone segments, charcoal clamp blocks, the charcoal
    collar with its studs, and the trunnion cheeks at 12 o'clock that carry the barrel."""
    r = Part("WeaponRing")
    b_in, b_out, b_h, b_z = sb.RING_BAND
    r.ring("paint", b_in, b_out, b_h, sb.RING_SEGMENTS, loc=(0, 0, b_z), color="bone")
    for k in range(10):
        a = (k + 0.5) * math.tau / 10
        if abs(math.sin(a) - 1.0) < 0.2:
            continue  # the cheeks take the 12 o'clock clamp
        r.box("paint", (0.06, b_out - b_in + 0.012, b_h + 0.012), loc=((b_in + b_out) / 2 * math.cos(a),
              (b_in + b_out) / 2 * math.sin(a), b_z), rot=(0, 0, a + math.pi / 2), color="charcoal")
    c_in, c_out, c_h, c_z = sb.RING_COLLAR
    r.ring("paint", c_in, c_out, c_h, sb.RING_SEGMENTS, loc=(0, 0, c_z), color="charcoal")
    for k in range(12):
        a = k * math.tau / 12 + 0.13
        n = Vector((math.cos(a), math.sin(a), 0))
        sb._disc(r, n * (c_out + 0.002) + Vector((0, 0, c_z)), n, 0.012, 6, "paint", "charcoal")
    for side in (-1, 1):
        r.box("paint", (0.03, 0.12, 0.13), loc=(side * CHEEK_X, b_out + 0.045, 0.0), color="charcoal")
        r.rod("paint", (side * (CHEEK_X - 0.03), PIVOT.y, 0), (side * (CHEEK_X + 0.03), PIVOT.y, 0), 0.028, 8,
              color="bone")
    sb._sharpen(r)
    return r


def _dashes(part, r_in, r_out, depth, y, count, arc, phase=0.0):
    """A dashed glow ring facing +Y at y: the pattern cue that reads apart from brass."""
    step = math.tau / count
    for k in range(count):
        a0 = phase + k * step
        part.ring("class_accent", r_in, r_out, depth, 1, loc=(0, y, 0), rot=(math.pi / 2, 0, 0),
                  arc=(a0, a0 + arc))


def barrel(variant=""):
    """MainBarrel in Pod space: breech cap, tapering body, four raised family bands with dashed
    glow on their muzzle faces, the sector shutter on top of the breech and the muzzle. The
    Choir Barrel recasts the muzzle as a six-shuttered housing (src/boss/mind_dress.gd SHUTTERS)."""
    b = Part("MainBarrel")
    b.rod("ancient_enamel", (0, BREECH_Y, 0), (0, PIVOT.y + 0.005, 0), BODY_R[0] + 0.017, 16, color=STONE_DARK)
    b.rod("ancient_enamel", (0, PIVOT.y + 0.005, 0), (0, MUZZLE_Y - 0.04, 0), BODY_R[0], 16, color=STONE,
          r2=BODY_R[1])
    for k, y in enumerate(BANDS_Y):
        b.rod("ancient_enamel", (0, y - 0.016, 0), (0, y + 0.016, 0), BAND_R, 12, color=BAND)
        _dashes(b, BODY_R[0] + 0.002, BAND_R - 0.002, 0.004, y + 0.018, 4, 0.8, phase=0.4 * k)
    # Sector shutter: a cast shield over the top of the breech (arc 60 to 120 degrees).
    b.ring("ancient_enamel", BODY_R[0] - 0.004, 0.150, 0.05, 6, loc=(0, 1.165, 0), rot=(math.pi / 2, 0, 0),
           color=BAND, arc=(math.pi / 3, 2 * math.pi / 3))
    m_in, m_out = MUZZLE_R
    if variant == "choir":
        b.cyl("ancient_enamel", 0.150, 0.140, 0.07, 6, loc=(0, MUZZLE_Y - 0.035, 0), rot=(math.pi / 2, 0, 0),
              color=CHOIR, caps=False)
        b.ring("ancient_enamel", m_in, 0.142, 0.012, 6, loc=(0, MUZZLE_Y - 0.006, 0), rot=(math.pi / 2, 0, 0),
               color=CHOIR)
        for k in range(6):
            a = k * math.tau / 6 + math.pi / 6
            d = Vector((math.cos(a), 0, math.sin(a)))
            root = d * 0.10 + Vector((0, MUZZLE_Y, 0))
            tip = d * 0.165 + Vector((0, MUZZLE_Y + 0.07, 0))
            b.beam("ancient_enamel", root, tip, 0.075, 0.014, color=STONE, roll=a)
            g = a + math.pi / 6
            b.ring("class_accent", 0.085, 0.13, 0.004, 1, loc=(0, MUZZLE_Y + 0.002, 0), rot=(math.pi / 2, 0, 0),
                   arc=(g - 0.05, g + 0.05))
    else:
        b.ring("ancient_enamel", m_in, m_out, 0.045, 16, loc=(0, MUZZLE_Y - 0.0225, 0), rot=(math.pi / 2, 0, 0),
               color=STONE)
        _dashes(b, 0.085, 0.115, 0.004, MUZZLE_Y + 0.002, 6, 0.55)
    sb._disc(b, (0, MUZZLE_Y - 0.0395, 0), (0, 1, 0), m_in + 0.001, 12, "ancient_enamel", BORE)
    sb._sharpen(b)
    return b


def socket(name, loc, forward, parent):
    """An empty whose local +Y (Godot -Z after export) points along forward."""
    obj = common.empty(name, loc, parent)
    obj.rotation_euler = Vector((0, 1, 0)).rotation_difference(Vector(forward).normalized()).to_euler()
    return obj


def build(variant=""):
    """The Cannon's shell root (pilot_cannon.py calls this and exports it)."""
    return build_shell(variant)["root"]


def build_shell(variant=""):
    """The Cannon's shell under ShellCannon; returns hoberman()'s dict plus barrel.
    variant "" or "choir"."""
    sb.cockpit, sb.weapon_ring = cannon_cockpit, cannon_ring
    try:
        shell = sb.hoberman("Cannon", enamel=ENAMEL, seat=SEAT, pairs=2, bank=BANK)
    finally:
        sb.cockpit, sb.weapon_ring = _BASE_COCKPIT, _BASE_RING
    # The animated pilot is fitted at run time; a Pilot node here would be a second pilot.
    bpy.data.objects.remove(shell["pilot"], do_unlink=True)
    pod, ring = shell["pod"], shell["ring"]
    main = barrel(variant).to_object(PIVOT, ring)
    socket("BarrelPivot", PIVOT, (0, 1, 0), ring)
    socket("LaneMuzzle", (0, MUZZLE_Y + 0.002, 0), (0, 1, 0), main)
    socket("SectorShutter", (0, 1.165, 0.135), (0, 1, 0), main)
    socket("SectorPivot", (0, 1.165, BODY_R[0]), (0, 1, 0), main)
    for side, tag in ((1, "R"), (-1, "L")):
        c, n, f, u = port_axes(side)
        socket("SplitExit." + tag, c - f * (PORT_SIZE[1] / 2), (side * 0.22, -1, 0), pod)
    socket("RushContact", (0, 0, RUSH[3] - RUSH[2] / 2), (0, 0, -1), pod)
    bpy.context.view_layer.update()
    shell["barrel"] = main
    return shell


def draws(root):
    return sum(len(o.data.materials) for o in common.tree(root) if o.type == "MESH")


def _pitched(v, deg):
    a = math.radians(deg)
    d = v - PIVOT
    return Vector((v.x, PIVOT.y + d.y * math.cos(a) - d.z * math.sin(a), d.y * math.sin(a) + d.z * math.cos(a)))


def sweep_bins(ring, barrel_obj, step=0.01):
    """The volume WeaponRing and MainBarrel sweep as the ring yaws a full turn and the barrel
    pitches over PITCH, as {z bin: [r min, r max]} in Pod space (r from the vertical axis)."""
    bins = {}

    def add(p):
        k = round(p.z / step)
        r = math.hypot(p.x, p.y)
        lo, hi = bins.get(k, (r, r))
        bins[k] = (min(lo, r), max(hi, r))
    for v in ring.data.vertices:
        add(ring.matrix_world @ v.co)
    pitches = [PITCH[0] + (PITCH[1] - PITCH[0]) * i / 18 for i in range(19)]
    for v in barrel_obj.data.vertices:
        w = barrel_obj.matrix_world @ v.co
        for deg in pitches:
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


def main():
    common.reset()
    variant = flag("--variant", "") or ""
    if variant not in ("",) + tuple(VARIANT_MODELS):
        raise SystemExit("unknown variant %s" % variant)
    shell = build_shell(variant)
    root, pod = shell["root"], shell["pod"]
    bins = sweep_bins(shell["ring"], shell["barrel"])
    hits = sweep_hits(pod, bins)
    n_draws = draws(root)
    tris = common.tri_total(root)
    reach = max(common.max_radius(o) for o in common.tree(pod) if o.type == "MESH"
                and o.name not in ("WeaponRing", "MainBarrel", "Gyro", "GyroInner"))
    tip = common.max_radius(shell["barrel"])
    print("CANNON variant=%s tris=%d target=%d %s draws=%d cap=%d" % (variant or "default", tris, TARGET_TRIS,
          "fits" if tris <= TARGET_TRIS else "over", n_draws, DRAW_CAP))
    print("CANNON_REACH pod modules %.3f (cap 1.25), barrel tip %.3f" % (reach, tip))
    print("BARREL_SWEEP %d Pod vertices inside the ring and barrel sweep (pitch %+.0f to %+.0f) %s"
          % (hits, PITCH[0], PITCH[1], "ok" if hits == 0 else "OUT"))
    if hits or n_draws > DRAW_CAP or reach > 1.25:
        raise SystemExit("cannon shell out of contract")
    # finish() reads a pilot node; the shell carries none, so it gets a detached empty.
    no_pilot = common.empty("NoPilot")
    out = common.args()["out"] or str(VARIANT_MODELS.get(variant, MODEL))
    sb.finish("Cannon", root, shell["core"], no_pilot, shell_band=SHELL_BAND, pod_obj=pod, out=out)


if __name__ == "__main__":
    main()
