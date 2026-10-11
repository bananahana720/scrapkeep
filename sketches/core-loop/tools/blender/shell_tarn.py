"""Tarn's Hoberman mecha (PD-TARN): the shared base from shell_base.hoberman() in one iron
oxide lattice enamel, a bone seat, two hooked claw arms on gap brackets at 4 and 8 o'clock,
two curved claw blades on the WeaponRing's front arc at 11 and 1 o'clock, and a rope pull
drum low at the rear. Heft layers come from shell_tarn_plates.py.
Concept: artifacts/local/alpha/push/w13/concepts/codex/tarn/hero.png, chase.png and sheet.png
with concepts/codex/base/base-hero.png and mechanism.png (the approved set, docs/decisions.tsv
w13-look rows of 2026-10-10). Where a picture and ROSTER-LOOK disagree the sheet wins: oxide
goes on the lattice struts only (section 6, "Tarn's colour clash"), so the blade housings that
the picture paints oxide are petrol here.

  Under the 12 GiB prlimit address-space cap of tools/blender/PILOT-RIG.md:72:
    blender --background --threads 2 --python-exit-code 1 \
    --python tools/blender/shell_tarn.py -- [--out <file.glb>] [--variant teeth] [--count-only]

--variant teeth builds the earned Redjaw Teeth shell (CUSTOMIZE section 8,
shell_tarn_redjaw_teeth): the same machinery, sockets and sight cone; only the hub tread caps
change, to ten-sided toothed caps whose rims alternate long and short teeth.

Draws: PD-0's base already spends the 10-draw shell cap (Core 3, Pod 3, Gyro, GyroInner,
WeaponRing 2). Tarn's seven moving parts are each their own mesh so code can hinge, spin and
swing them: four claw jaws, each a bone paint body plus a toothed class_accent strip along its
biting edge (the tooth edges are the working device, the only class_accent), the pull drum on
rubber and two blades on bare_metal. 21 draws; the registry fragment carries the exception,
pending the owner's call on the shell draw cap for Hoberman pilots with moving parts.

Claw reach by class (CLAW_REACH) is not carried on the jaws: the base GLB's jaws and ClawTip
sit at class I reach and the layers' bone hooks show the longer reach. Moving the reach onto
the jaws needs loader or clip code outside this recipe (P-UNITS PD-TARN review, 2026-10-10).
"""
import math
from pathlib import Path
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
SKETCH = HERE.parents[1]
sys.path.insert(0, str(HERE))
import common  # noqa: E402
from common import Part  # noqa: E402
import shell_base as sb  # noqa: E402

SHELL_BAND = (3000, 11000)
TARGET_TRIS = 6600
VERT_CAP = 11600
REACH_CAP = 1.25

# The slot 2 and slot 3 controls in the bank beside the right yoke (PILOT-CLIPS section 5).
BANK = (("ClampLever", "lever"), ("DrumLever", "lever"))
# Control name to Pod-space point (Blender metres), the table the clip units read
# (PILOT-CLIPS section 4.3 "controls": tools/blender/shell_tarn.py:CONTROLS).
CONTROLS = dict(sb.CONTROLS)
CONTROLS.update({name: point for (name, _), point in zip(BANK, sb.BANK)})

# Claw arms (pilots/tarn.md section 5): tips past the lattice's outer face by class I to V.
CLAW_REACH = (0.15, 0.15, 0.18, 0.21, 0.25)
# Clock angle below 3 o'clock seen from the chase camera (26 degrees reads as 4 o'clock and
# keeps the class V hook above Z -0.6), and the forward lean of the arm.
CLAW_CLOCK = math.radians(26)
CLAW_LEAN = math.radians(25)
HINGE_RADIUS = 0.88       # outside the gimbal sweep (0.862), inside the lattice inner face
JAW_THICK = 0.04
BRACKET_R = 0.022         # a slim dark-steel arm, 0.044 m across (ROSTER-LOOK section 2)
# Blades on the ring's front arc at 11 and 1 o'clock, edges forward.
BLADE_X = 0.53
BLADE_THICK = 0.026
# Pull drum low at the rear, inside the gimbal sweep (0.829).
DRUM_CENTRE = Vector((0.0, -0.44, -0.54))
DRUM_RADIUS = 0.10
DRUM_HALF = 0.17


def claw_frame(sign):
    """(direction, hinge axis, opening direction) for the claw arm on side sign (+1 right)."""
    d = Vector((sign * math.cos(CLAW_LEAN) * math.cos(CLAW_CLOCK), math.sin(CLAW_LEAN),
                -math.cos(CLAW_LEAN) * math.sin(CLAW_CLOCK))).normalized()
    axis = d.cross(Vector((0, 0, 1))).normalized()
    up = axis.cross(d).normalized()
    if up.z < 0:
        axis, up = -axis, -up
    return d, axis, up


TOOTH_TOP = 0.014         # the seam between the bone jaw body and its tooth strip


def jaw_outlines(length, sign_v):
    """A jaw plate from the hinge (u 0) to its hooked tip (u length) as two outlines that share
    the seam at v TOOTH_TOP: the bone body (back and hook) and the toothed strip along its
    biting edge, the only class_accent (P-UNITS PD-TARN; pilots/tarn.md section 5). sign_v +1
    is the upper jaw, teeth on its lower edge. (u, v) pairs, counter-clockwise either way."""
    # Each traced clockwise for the upper jaw, then reversed.
    body = [(0.0, 0.0), (0.0, 0.045), (0.55 * length, 0.060), (0.86 * length, 0.048),
            (length, 0.006), (0.95 * length, -0.034), (0.88 * length, -0.004),
            (0.86 * length, TOOTH_TOP), (0.12 * length, TOOTH_TOP)]
    teeth = [(0.12 * length, TOOTH_TOP), (0.86 * length, TOOTH_TOP), (0.88 * length, -0.004)]
    for k in range(4):
        u0 = 0.80 * length - k * 0.15 * length
        teeth.append((u0 - 0.04 * length, -0.024))
        teeth.append((u0 - 0.075 * length, 0.004))
    teeth.append((0.12 * length, 0.004))
    out = []
    for pts in (body, teeth):
        out.append([(u, -v) for u, v in pts] if sign_v < 0 else list(reversed(pts)))
    return out


def claw_points(sign, reach):
    d, axis, up = claw_frame(sign)
    hinge = d * HINGE_RADIUS
    tip = d * (sb.LATTICE_OUTER + reach)
    return d, axis, up, hinge, tip


def socket(name, location, parent, direction=(0, 1, 0)):
    node = common.empty(name, location, parent)
    node.rotation_euler = Vector((0, 1, 0)).rotation_difference(Vector(direction)).to_euler()
    return node


def _plane_prism(part, slot, outline, depth, origin, eu, ev, color=None):
    """part.prism with a frame: outline (u, v) in the plane spanned by eu and ev at origin."""
    ew = eu.cross(ev).normalized()
    m = Matrix((
        (eu.x, ev.x, ew.x, origin.x),
        (eu.y, ev.y, ew.y, origin.y),
        (eu.z, ev.z, ew.z, origin.z),
        (0, 0, 0, 1)))
    return part.prism(slot, outline, depth, matrix=m, color=color)


def claws(pod):
    """Brackets and hinge bosses on the Pod mesh; four single-material jaws hinged at the
    bracket ends; ClawPivot and ClawTip sockets. Returns the sockets' rest points."""
    extra = Part("TarnPodClaws")
    points = {}
    for side, sign in (("R", 1), ("L", -1)):
        d, axis, up, hinge, tip = claw_points(sign, CLAW_REACH[0])
        root = Vector((sign * 0.24, -0.02, -0.44))
        elbow = d * 0.62 + Vector((0, -0.06, -0.02))
        extra.rod("rubber", root, elbow, BRACKET_R, 6)
        extra.rod("rubber", elbow, hinge - d * 0.03, BRACKET_R, 6)
        extra.uv("copper", 0.034, 6, 4, loc=tuple(elbow))
        extra.rod("copper", hinge - axis * 0.055, hinge + axis * 0.055, 0.032, 8)
        length = (tip - hinge).length
        for label, sign_v in (("Upper", 1), ("Lower", -1)):
            jaw = Part("Claw" + label + "." + side)
            body, teeth = jaw_outlines(length, sign_v)
            _plane_prism(jaw, "paint", body, JAW_THICK, hinge, d, up, color="bone")
            _plane_prism(jaw, "class_accent", teeth, JAW_THICK, hinge, d, up)
            sb._sharpen(jaw)
            jaw.to_object(tuple(hinge), pod)
        socket("ClawPivot." + side, tuple(hinge), pod, tuple(axis))
        socket("ClawTip." + side, tuple(tip), pod, tuple(d))
        points[side] = {"pivot": hinge, "tip": tip, "dir": d}
    sb._sharpen(extra)
    return extra, points


def drum_parts(pod):
    """The rope pull drum (its own rubber mesh, so code can spin it on X), its copper cheeks
    and rubber axle stays on the Pod mesh, and the PullExit socket at the rope mouth."""
    extra = Part("TarnPodDrum")
    c = DRUM_CENTRE
    for sx in (-1, 1):
        extra.cyl("copper", 0.125, 0.125, 0.02, 10, loc=(sx * (DRUM_HALF + 0.012), c.y, c.z), rot=(0, math.pi / 2, 0))
        extra.rod("rubber", (sx * 0.15, -0.10, -0.40), (sx * (DRUM_HALF + 0.012), c.y, c.z), 0.018, 6)
    drum = Part("PullDrum")
    drum.cyl("rubber", DRUM_RADIUS, DRUM_RADIUS, 2 * DRUM_HALF, 12, rot=(0, math.pi / 2, 0))
    # Three raised rope wraps read as the winding at the chase camera.
    for k in (-1, 0, 1):
        drum.ring("rubber", DRUM_RADIUS - 0.002, DRUM_RADIUS + 0.012, 0.03, 12, loc=(k * 0.095, 0, 0), rot=(0, math.pi / 2, 0))
    sb._sharpen(drum)
    # Built at the origin, then placed: the drum's origin is its axle, so a spin stays put.
    drum_obj = drum.to_object((0, 0, 0), pod)
    drum_obj.location = c
    drum_obj["world_origin"] = list(c)
    exit_point = c + Vector((0, -(DRUM_RADIUS + 0.012), 0))
    socket("PullExit", tuple(exit_point), pod, (0, -1, 0))
    sb._sharpen(extra)
    return extra, exit_point


def blade_outline():
    """A sickle in (forward u, vertical v) from the root at the band: outer edge forward.
    Counter-clockwise: up the root, back along the inner curve, round the point, up the edge."""
    return list(reversed([(0.0, 0.035), (0.07, 0.030), (0.125, -0.010), (0.150, -0.080), (0.140, -0.170),
                          (0.105, -0.250), (0.085, -0.255), (0.098, -0.170), (0.090, -0.095), (0.060, -0.045),
                          (0.0, -0.035)]))


def blades(ring):
    """Two curved claw blades, each its own bare_metal mesh with its origin at its root on the
    band so a swing turns it about the root, and their petrol housings on the ring's paint."""
    housing = Part("TarnRingHousing")
    for side, sign in (("R", 1), ("L", -1)):
        x = sign * BLADE_X
        y0 = math.sqrt(sb.RING_BAND[1] ** 2 - x * x) - 0.012
        housing.box("paint", (0.10, 0.06, 0.10), loc=(x, y0 + 0.01, sb.RING_BAND[3]), color="petrol")
        blade = Part("Blade." + side)
        root = Vector((x, y0 + 0.035, sb.RING_BAND[3]))
        _plane_prism(blade, "bare_metal", blade_outline(), BLADE_THICK, root,
                     Vector((0, 1, 0)), Vector((0, 0, 1)))
        sb._sharpen(blade)
        blade.to_object(tuple(root), ring)
    sb._sharpen(housing)
    return housing


def join_into(target, part_obj):
    """Joins part_obj's mesh into target's and folds duplicate material slots, so the target
    keeps one surface per slot (one draw each)."""
    bpy.ops.object.select_all(action="DESELECT")
    part_obj.select_set(True)
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.join()
    mesh = target.data
    first = {}
    remap = {}
    for i, mat in enumerate(mesh.materials):
        first.setdefault(mat.name, i)
        remap[i] = first[mat.name]
    for poly in mesh.polygons:
        poly.material_index = remap[poly.material_index]
    for i in reversed(range(len(mesh.materials))):
        if remap[i] != i:
            mesh.materials.pop(index=i)
    order = sorted(set(remap.values()))
    if order != list(range(len(order))):
        dense = {old: new for new, old in enumerate(order)}
        for poly in mesh.polygons:
            poly.material_index = dense[poly.material_index]


def drop_neutral_seat(ring):
    """Removes PD-0's neutral weapon seat (box and rod at 12 o'clock past the band); Tarn's
    blades take the front arc. The 12 o'clock clamp block on the band stays."""
    bm = bmesh.new()
    bm.from_mesh(ring.data)
    gone = [v for v in bm.verts if v.co.y > sb.RING_BAND[1] + 0.01 and abs(v.co.x) < 0.08]
    bmesh.ops.delete(bm, geom=gone, context="VERTS")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(ring.data)
    bm.free()


def toothed_caps(core):
    """Redjaw Teeth: every hub's ten-sided tread cap alternates long and short teeth."""
    hubs, _, _ = sb.lattice_layout()
    rubber = [i for i, m in enumerate(core.data.materials) if m.name == "rubber"][0]
    bm = bmesh.new()
    bm.from_mesh(core.data)
    cap_verts = {v for f in bm.faces if f.material_index == rubber for v in f.verts}
    groups = {}
    for v in cap_verts:
        n = v.co.normalized()
        h = max(range(len(hubs)), key=lambda i: n.dot(hubs[i]))
        groups.setdefault(h, []).append(v)
    for h, verts in groups.items():
        d = hubs[h]
        e1, e2 = sb._frame(d)
        angles = sorted({round(math.atan2((v.co - d * v.co.dot(d)).dot(e2), (v.co - d * v.co.dot(d)).dot(e1)), 4) for v in verts})
        rank = {a: i for i, a in enumerate(angles)}
        for v in verts:
            along = d * v.co.dot(d)
            off = v.co - along
            a = round(math.atan2(off.dot(e2), off.dot(e1)), 4)
            if rank[a] % 2:
                v.co = along + off * 0.62
    bm.to_mesh(core.data)
    bm.free()
    return len(groups)


def build_shell(variant=""):
    common.SLOTS["class_accent"] = {"color": "oxide", "emit": 0.5, "rough": 0.5}
    sides = 10 if variant == "teeth" else 8
    shell = sb.hoberman("Tarn", enamel="oxide", seat="bone", bank=BANK, cap_sides=sides)
    root, pod, ring, core = shell["root"], shell["pod"], shell["ring"], shell["core"]
    if variant == "teeth":
        print("TEETH caps toothed on %d hubs" % toothed_caps(core))
    drop_neutral_seat(ring)
    claw_extra, points = claws(pod)
    join_into(pod, claw_extra.to_object((0, 0, 0), pod))
    drum_extra, exit_point = drum_parts(pod)
    join_into(pod, drum_extra.to_object((0, 0, 0), pod))
    join_into(ring, blades(ring).to_object((0, 0, 0), ring))
    socket("RendContact", (0, 0.23, -0.79), pod, (0, 0, -1))
    bpy.context.view_layer.update()
    return shell, points, exit_point


def counts(root, skip):
    tris = verts = draws = 0
    for o in common.tree(root):
        if o.type != "MESH" or o.name in skip:
            continue
        tris += common.tris(o)
        verts += len(o.data.vertices)
        draws += len({p.material_index for p in o.data.polygons})
    return tris, verts, draws


def check(shell, points):
    """Tarn's own checks on top of finish(): claw reach and clock, every mesh inside the reach
    cap, the jaws single-material, oxide only on the lattice."""
    ok = True
    for side, p in points.items():
        reach = p["tip"].length - sb.LATTICE_OUTER
        clock = math.degrees(math.atan2(-p["dir"].z, abs(p["dir"].x)))
        print("CLAW %s tip reach %.3f past the lattice at radius %.3f, Z %.3f, %.1f degrees below 3/9 o'clock"
              % (side, reach, p["tip"].length, p["tip"].z, clock))
        ok &= abs(reach - CLAW_REACH[0]) < 0.005 and p["tip"].z > sb.LOW_Z
    far = max(common.max_radius(o) for o in common.tree(shell["root"]) if o.type == "MESH" and o.name != shell["pilot"].name)
    print("REACH max radius %.3f cap %.2f %s" % (far, REACH_CAP, "ok" if far <= REACH_CAP else "OUT"))
    ok &= far <= REACH_CAP
    for o in common.tree(shell["pod"]):
        if o.name.startswith("Claw") and o.type == "MESH":
            names = sorted(m.name for m in o.data.materials)
            used = {o.data.materials[p.material_index].name for p in o.data.polygons}
            ok &= names == ["class_accent", "paint"] and used == {"class_accent", "paint"}
    oxide = Vector(common.rgba("oxide")[:3])
    for o in common.tree(shell["root"]):
        if o.type != "MESH" or o == shell["core"] or not o.data.color_attributes:
            continue
        col = o.data.color_attributes["Color"]
        paint = [i for i, m in enumerate(o.data.materials) if m.name == "paint"]
        for poly in o.data.polygons:
            if poly.material_index in paint:
                c = Vector(col.data[poly.loop_indices[0]].color[:3])
                if (c - oxide).length < 0.01:
                    print("OXIDE off the lattice on", o.name)
                    ok = False
                    break
    return ok


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    variant = argv[argv.index("--variant") + 1] if "--variant" in argv else ""
    common.reset()
    shell, points, _ = build_shell(variant)
    tris, verts, draws = counts(shell["root"], (shell["pilot"].name,))
    print("HOBERMAN Tarn%s tris=%d verts=%d draws=%d target=%d %s; vert cap %d %s"
          % (" teeth" if variant else "", tris, verts, draws, TARGET_TRIS,
             "fits" if tris <= TARGET_TRIS else "over target", VERT_CAP, "ok" if verts <= VERT_CAP else "OUT"))
    ok = check(shell, points)
    if "--count-only" in argv:
        return
    default = "shell_tarn_redjaw_teeth.glb" if variant == "teeth" else "shell_tarn.glb"
    out = common.args()["out"] or str(SKETCH / "assets/models/world_one" / default)
    sb.finish("Tarn", shell["root"], shell["core"], shell["pilot"], shell_band=SHELL_BAND,
              pod_obj=shell["pod"], out=out)
    if not ok or verts > VERT_CAP:
        raise SystemExit("Tarn shell checks failed")
    print("TARN_SHELL: PASS", tris, "triangles", verts, "vertices", draws, "draws")


if __name__ == "__main__":
    main()
