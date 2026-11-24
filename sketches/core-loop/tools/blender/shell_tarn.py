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

Draws: 17, a documented exception to the 16-draw cap for Hoberman pilot mechas (cap:
docs/decisions.tsv 2026-10-10 w13-PD; exception: docs/decisions.tsv 2026-10-11 w13-PD, Tarn
17). The four claw jaws are each their own mesh so code can hinge them, each a bone paint body
plus a toothed class_accent strip along its biting edge (the tooth edges are the working
device, the only class_accent): 8. The two blades swing, one bare_metal mesh each: 2. Gyro and
GyroInner: 2. Core 2 (paint, copper; the rubber tread caps fold into paint in charcoal vertex
colour). Pod 2 (paint, copper): the copper lap bar is the ultimate control on every pilot, so
its copper keeps its own slot and never takes a paint tint (ROSTER-LOOK section 6; fix round 3
restores the slot that round 2 folded); its rubber folds into paint in charcoal. WeaponRing 1
(its rubber folds into paint in charcoal, as shell_tally.py does). The pull drum and its wraps
are rotationally symmetric and untextured, so they ride the Pod mesh and PullDrum is an empty
at the axle. check() prints COPPER and fails the build if copper slips under paint.

Rig (wave 46 E2-04, OPUS-FULL-3D-VISUAL-REVIEW section 1.5). Each jaw's origin is its hinge
pin and its local X is the pin (the right arm's hinge axis, the left arm's reversed, so the two
sides mirror): a clip row's turn about axis x swings the jaw cleanly about the pin, and a
negative angle opens the left upper jaw as a positive one opens the right (clips/tarn.json).
Each upper jaw drives a brass ram curved about its own hinge pin: the rod rides the jaw (paint
in brass, alpha 0 so no equipped paint tints it) and the sleeve hangs off the copper hinge boss
on the Pod (copper), so the rod slides along the sleeve at any jaw angle without code and keeps
at least RAM_MIN_OVERLAP of its length inside from rest to RAM_OPEN degrees open. No new draw:
the rod is on the jaw's paint surface and the sleeve on the Pod's copper. The tooth strip is its
own closed island sunk into the jaw body and a little thinner than it, never welded to it, so
every jaw is watertight (review section 1.4).

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
# The ram on each upper jaw, in the jaw's swing plane: angles about the hinge axis from the arm
# direction toward the jaw's up, the rod's end tied to the jaw at RAM_ATTACH, the sleeve's mouth
# RAM_GAP short of it, offset RAM_OFFSET along the hinge pin to the camera side so it clears the
# coplanar jaws. Rod length RAM_ROD >= (RAM_GAP + RAM_OPEN) / (1 - RAM_MIN_OVERLAP).
RAM_RADIUS = 0.085
RAM_OFFSET = 0.04
RAM_ROD_SECTION = 0.012
RAM_SLEEVE_SECTION = 0.024
RAM_ATTACH = 25.0
RAM_GAP = 8.0
RAM_ROD = 115.0
RAM_SLEEVE = 110.0
RAM_OPEN = 85.0
RAM_MIN_OVERLAP = 0.15
RAM_SEGS = 5
# The tooth strip sinks this far into the jaw body and is this much of its thickness.
TOOTH_SINK = 0.008
TOOTH_DEPTH = 0.75
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
    """A jaw plate from the hinge (u 0) to its hooked tip (u length) as two outlines: the bone
    body (back and hook) down to the seam at v TOOTH_TOP, and the toothed strip along its biting
    edge, the only class_accent (P-UNITS PD-TARN; pilots/tarn.md section 5). The strip's top
    edge sits TOOTH_SINK inside the body, so the two are separate closed pieces that overlap
    rather than share the seam (a shared seam welds into non-manifold edges). sign_v +1 is the
    upper jaw, teeth on its lower edge. (u, v) pairs, counter-clockwise either way."""
    # Each traced clockwise for the upper jaw, then reversed.
    body = [(0.0, 0.0), (0.0, 0.045), (0.55 * length, 0.060), (0.86 * length, 0.048),
            (length, 0.006), (0.95 * length, -0.034), (0.88 * length, -0.004),
            (0.86 * length, TOOTH_TOP), (0.12 * length, TOOTH_TOP)]
    top = TOOTH_TOP + TOOTH_SINK
    teeth = [(0.12 * length, top), (0.86 * length, top), (0.88 * length, -0.004)]
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


def jaw_frame(sign):
    """The jaw's local X in Pod space: the hinge axis on the right, reversed on the left, so a
    positive turn opens the right upper jaw and a negative one the left (mirrored)."""
    _, axis, _ = claw_frame(sign)
    return axis * sign


def ram_overlap(open_deg):
    """The share of the ram rod's length inside its sleeve with the jaw open_deg open."""
    rod = (RAM_ATTACH - RAM_ROD + open_deg, RAM_ATTACH + open_deg)
    sleeve = (RAM_ATTACH - RAM_GAP - RAM_SLEEVE, RAM_ATTACH - RAM_GAP)
    return max(0.0, min(rod[1], sleeve[1]) - max(rod[0], sleeve[0])) / RAM_ROD


def _swing_matrix(hinge, d, up, axis, phi_deg=0.0, offset=0.0):
    """A frame at the hinge pin (offset along it) whose X points phi_deg round from d toward up
    in the jaw's swing plane, Y the tangent, Z the pin axis."""
    phi = math.radians(phi_deg)
    eu = d * math.cos(phi) + up * math.sin(phi)
    ev = up * math.cos(phi) - d * math.sin(phi)
    o = hinge + axis * offset
    return Matrix(((eu.x, ev.x, axis.x, o.x), (eu.y, ev.y, axis.y, o.y), (eu.z, ev.z, axis.z, o.z), (0, 0, 0, 1)))


def _arc_bar(part, slot, frame, radius, section, phi0, phi1, segs, color=None, alpha=1.0):
    """A closed square-section bar curved about the frame's Z from phi0 to phi1 degrees at
    radius, capped at both ends (8 segs + 4 triangles)."""
    h = section / 2
    quad = [(radius - h, -h), (radius + h, -h), (radius + h, h), (radius - h, h)]
    rows = []
    for k in range(segs + 1):
        a = math.radians(phi0 + (phi1 - phi0) * k / segs)
        ca, sa = math.cos(a), math.sin(a)
        rows.append([part.bm.verts.new(frame @ Vector((r * ca, r * sa, z))) for r, z in quad])
    faces = []
    for k in range(segs):
        a, b = rows[k], rows[k + 1]
        for i in range(4):
            j = (i + 1) % 4
            faces.append(part.bm.faces.new((a[i], b[i], b[j], a[j])))
    faces.append(part.bm.faces.new(list(reversed(rows[0]))))
    faces.append(part.bm.faces.new(rows[-1]))
    return part.paint(faces, slot, color, alpha)


def _block(part, slot, frame, centre, size, color=None, alpha=1.0):
    """A box in frame coordinates: centre and size along the frame's X, Y and Z."""
    m = frame @ Matrix.Translation(Vector(centre)) @ Matrix.Diagonal((*size, 1.0))
    r = bmesh.ops.create_cube(part.bm, size=1.0, matrix=m)
    return part.paint(part._faces(r["verts"]), slot, color, alpha)


def ram(jaw, pod_part, hinge, d, up, axis, side_sign):
    """The upper jaw's ram: the brass rod and its tie lug on the jaw, the copper sleeve and its
    dark spoke to the hinge boss on the Pod. Both arcs are concentric with the hinge pin, so
    the rod slides along the sleeve as the jaw opens and never leaves it."""
    off = side_sign * RAM_OFFSET
    flat = _swing_matrix(hinge, d, up, axis, 0.0, off)
    _arc_bar(jaw, "paint", flat, RAM_RADIUS, RAM_ROD_SECTION, RAM_ATTACH - RAM_ROD, RAM_ATTACH, RAM_SEGS,
             color="brass", alpha=0.0)
    lug = _swing_matrix(hinge, d, up, axis, RAM_ATTACH, 0.0)
    _block(jaw, "paint", lug, (RAM_RADIUS, 0.0, off / 2), (0.024, 0.014, abs(off) + RAM_ROD_SECTION / 2),
           color="brass", alpha=0.0)
    bottom = RAM_ATTACH - RAM_GAP - RAM_SLEEVE
    _arc_bar(pod_part, "copper", flat, RAM_RADIUS, RAM_SLEEVE_SECTION, bottom, RAM_ATTACH - RAM_GAP, RAM_SEGS)
    spoke = _swing_matrix(hinge, d, up, axis, bottom + 4.0, off)
    inner = 0.026
    outer = RAM_RADIUS - RAM_SLEEVE_SECTION / 2 + 0.004
    _block(pod_part, "rubber", spoke, ((inner + outer) / 2, 0.0, 0.0), (outer - inner, 0.016, 0.016))


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
        x_axis = jaw_frame(sign)
        yaw = math.atan2(x_axis.y, x_axis.x)
        for label, sign_v in (("Upper", 1), ("Lower", -1)):
            jaw = Part("Claw" + label + "." + side)
            body, teeth = jaw_outlines(length, sign_v)
            _plane_prism(jaw, "paint", body, JAW_THICK, hinge, d, up, color="bone")
            _plane_prism(jaw, "class_accent", teeth, JAW_THICK * TOOTH_DEPTH, hinge, d, up)
            if sign_v > 0:
                ram(jaw, extra, hinge, d, up, axis, sign)
            # The mesh is built in Pod space, then turned so the object's own yaw carries the
            # hinge: local X is the pin, local Z stays up, the origin is the pin's centre.
            bmesh.ops.rotate(jaw.bm, cent=hinge, matrix=Matrix.Rotation(-yaw, 3, "Z"), verts=jaw.bm.verts[:])
            sb._sharpen(jaw)
            obj = jaw.to_object(tuple(hinge), pod)
            obj.rotation_euler = (0.0, 0.0, yaw)
        socket("ClawPivot." + side, tuple(hinge), pod, tuple(axis))
        socket("ClawTip." + side, tuple(tip), pod, tuple(d))
        points[side] = {"pivot": hinge, "tip": tip, "dir": d}
    sb._sharpen(extra)
    return extra, points


def drum_parts(pod):
    """The rope pull drum, its copper cheeks and rubber axle stays, all on the Pod mesh (fix
    round 2: the drum and its wraps are rotationally symmetric and untextured, so a spin of
    its own mesh showed nothing for a draw); PullDrum is an empty at the axle for the clip
    and loader code, and PullExit the socket at the rope mouth."""
    extra = Part("TarnPodDrum")
    c = DRUM_CENTRE
    for sx in (-1, 1):
        extra.cyl("copper", 0.125, 0.125, 0.02, 10, loc=(sx * (DRUM_HALF + 0.012), c.y, c.z), rot=(0, math.pi / 2, 0))
        extra.rod("rubber", (sx * 0.15, -0.10, -0.40), (sx * (DRUM_HALF + 0.012), c.y, c.z), 0.018, 6)
    extra.cyl("rubber", DRUM_RADIUS, DRUM_RADIUS, 2 * DRUM_HALF, 12, loc=tuple(c), rot=(0, math.pi / 2, 0))
    # Three raised rope wraps read as the winding at the chase camera.
    for k in (-1, 0, 1):
        extra.ring("rubber", DRUM_RADIUS - 0.002, DRUM_RADIUS + 0.012, 0.03, 12, loc=(c.x + k * 0.095, c.y, c.z),
                   rot=(0, math.pi / 2, 0))
    drum_obj = common.empty("PullDrum", tuple(c), pod)
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


def fold_slot(obj, slot, color):
    """Moves obj's faces on slot onto its paint surface in color (vertex colour) and drops the
    slot, so obj spends one draw fewer (shell_tally.py fold_rubber, generalised). Returns the
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
    # pop() shifts the face indices above the removed slot down by one.
    obj.data.materials.pop(index=src)
    return moved


def drop_neutral_seat(ring):
    """Removes PD-0's neutral weapon seat (box and rod at 12 o'clock past the band); Tarn's
    blades take the front arc. The 12 o'clock clamp block on the band stays."""
    bm = bmesh.new()
    bm.from_mesh(ring.data)
    gone = [v for v in bm.verts if v.co.y > sb.RING_BAND[1] + 0.01 and abs(v.co.x) < 0.08]
    bmesh.ops.delete(bm, geom=gone, context="VERTS")
    # The seat box's inner face (two triangles) survives the cut on its own; every piece the
    # cut leaves open goes with it, so the ring stays watertight.
    seen = set()
    remnants = []
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
        if any(e.is_boundary for g in island for e in g.edges):
            remnants.extend(island)
    bmesh.ops.delete(bm, geom=remnants, context="FACES_ONLY")
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


def smooth_studs(core):
    """Shades the Core's closed pin studs (shell_base._stud: four triangles round four corners)
    smooth, so the exporter writes each with 4 vertices instead of 12. E1-03's closed lattice
    (72469a0ff) faceted them and lifted a rebuilt Tarn to 12,684 split vertices, past the shell
    class's 11,600; this keeps Tarn inside it until the base's _stud shades them itself (a no-op
    then). Returns the studs shaded."""
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


def build_shell(variant=""):
    common.SLOTS["class_accent"] = {"color": "oxide", "emit": 0.5, "rough": 0.5}
    sides = 10 if variant == "teeth" else 8
    shell = sb.hoberman("Tarn", enamel="oxide", seat="bone", bank=BANK, cap_sides=sides)
    root, pod, ring, core = shell["root"], shell["pod"], shell["ring"], shell["core"]
    if variant == "teeth":
        print("TEETH caps toothed on %d hubs" % toothed_caps(core))
    print("STUDS shaded smooth: %d" % smooth_studs(core))
    drop_neutral_seat(ring)
    claw_extra, points = claws(pod)
    join_into(pod, claw_extra.to_object((0, 0, 0), pod))
    drum_extra, exit_point = drum_parts(pod)
    join_into(pod, drum_extra.to_object((0, 0, 0), pod))
    join_into(ring, blades(ring).to_object((0, 0, 0), ring))
    # Rubber folds into paint in charcoal on the static meshes, so the seven moving parts keep
    # their own meshes inside 17 draws (docs/decisions.tsv 2026-10-11 w13-PD, Tarn 17). Copper
    # never folds: paint must not tint the lap bar (ROSTER-LOOK section 6).
    folds = {
        "Core rubber": fold_slot(core, "rubber", "charcoal"),
        "Pod rubber": fold_slot(pod, "rubber", "charcoal"),
        "WeaponRing rubber": fold_slot(ring, "rubber", "charcoal"),
    }
    print("FOLDS " + ", ".join("%s %d faces" % kv for kv in folds.items()))
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
    for side, sign in (("R", 1), ("L", -1)):
        want = jaw_frame(sign)
        for label in ("Upper", "Lower"):
            o = bpy.data.objects["Claw%s.%s" % (label, side)]
            pivot = bpy.data.objects["ClawPivot." + side]
            x = o.matrix_world.to_3x3() @ Vector((1, 0, 0))
            at = (o.matrix_world.translation - pivot.matrix_world.translation).length
            good = (x - want).length < 1e-5 and at < 1e-6
            print("HINGE %s.%s origin %.6f from ClawPivot, local X off the pin by %.6f %s"
                  % (label, side, at, (x - want).length, "ok" if good else "BAD"))
            ok &= good
    shares = {deg: ram_overlap(deg) for deg in (0.0, 55.0, 70.0, 80.0, RAM_OPEN)}
    print("RAM rod inside its sleeve: " + ", ".join("%.0f deg open %.0f%%" % (k, 100 * v) for k, v in shares.items())
          + "; minimum %.0f%%" % (100 * RAM_MIN_OVERLAP))
    ok &= min(shares.values()) >= RAM_MIN_OVERLAP and ram_overlap(-1.0) <= 1.0
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
    # Copper keeps its own untinted slot (ROSTER-LOOK section 6): Pod (lap bar, bank knobs,
    # bosses, drum cheeks) and Core (hubs) each spend faces on a copper material at metallic
    # 0.6, and no paint face on any shell mesh carries copper vertex colour.
    copper = Vector(common.rgba("copper")[:3])
    for o in (shell["pod"], shell["core"]):
        mats = [m.name for m in o.data.materials]
        used = {mats[p.material_index] for p in o.data.polygons}
        metal = o.data.materials[mats.index("copper")].node_tree.nodes["Principled BSDF"].inputs["Metallic"].default_value \
            if "copper" in mats else -1.0
        good = "copper" in used and abs(metal - 0.6) < 1e-6
        print("COPPER %s slot %s, metallic %.2f %s" % (o.name, "used" if "copper" in used else "MISSING", metal, "ok" if good else "BAD"))
        ok &= good
    for o in common.tree(shell["root"]):
        if o.type != "MESH" or o.name == shell["pilot"].name or not o.data.color_attributes:
            continue
        col = o.data.color_attributes["Color"]
        paint = [i for i, m in enumerate(o.data.materials) if m.name == "paint"]
        for poly in o.data.polygons:
            if poly.material_index in paint:
                c = Vector(col.data[poly.loop_indices[0]].color[:3])
                if (c - copper).length < 0.01:
                    print("COPPER under paint on", o.name)
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
