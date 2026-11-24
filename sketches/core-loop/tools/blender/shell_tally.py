"""Tally's Hoberman mecha (unit PD-TALLY): a mulberry lattice on shell_base.hoberman(), ledger
drums at 3 and 9 o'clock whose punched windows show pressure, the reader carriage with three
tabbed cards beside the right yoke, a stamp sole on the bottom hub, and a drum magazine on the
weapon ring whose card slot is the only class_accent. --variant abacus builds the earned
Abacus Lattice shell (CUSTOMIZE section 8): cream enamel with a copper bead threaded on each
chain and six-sided tread caps; the machinery, its sockets and the sight cone do not move.

Pictures (approved as one set, docs/decisions.tsv w13-look rows of 2026-10-10 18:30):
artifacts/local/alpha/push/w13/concepts/codex/tally/{hero,chase,sheet}.png and
concepts/codex/base/{base-hero,mechanism}.png. Design: ROSTER-LOOK sections 0, 2 to 6 and 9,
pilots/tally.md section 5, PILOTS.md section 1, PILOT-CLIPS section 5, CUSTOMIZE section 8.

  blender --background --threads 2 --python-exit-code 1 \
    --python sketches/core-loop/tools/blender/shell_tally.py -- [--out <glb>] [--variant abacus]
wrapped in prlimit with a 12884901888-byte address-space cap, as world_one/shell_neutral.py runs.

Calls made here (P-UNITS PD common rule C6 reading, listed in the PD-TALLY report):
- Struts 0.06 m and tread caps 0.10 m, inherited from shell_base.py's defaults (PD-0b strut
  rule, ROSTER-LOOK section 3 rule 7 as amended 2026-10-10); this recipe passes no width.
- One X-pair per link on the default shell as well as the variant (fix round 2026-10-11):
  ROSTER-LOOK section 3 rule 1 names it the first cut when the lattice hides the pilot, and it
  brings the base under the 6,600 target (section 5 cut order).
- The drums ride the upright Pod on gap brackets off the outer gimbal axle bosses, not the
  WeaponRing. The heft layers mount under Pod (B5's loader), so the class IV hoods and the
  class V heavy drums only stay on their drums if the drums share that carrier, and the Pod
  holds 3 and 9 o'clock to the heading, which the chase camera sits behind. (Accepted by the
  coordinator: docs/decisions.tsv w13-PD register 2026-10-10T21:29:13, which amends ROSTER-LOOK
  section 4 and tally.md:246.)
- Draws, 11 under the Hoberman pilot mecha cap of 16 (docs/decisions.tsv w13-PD
  register 2026-10-10T21:29:13): Core 3 (paint, copper, rubber), Pod 2, Gyro 1,
  GyroInner 1, WeaponRing 2 (paint, class_accent), one drum mesh and DrumBrackets (paint only, one
  draw, the 11th, a per-asset registry exception for the bank split). Both drums sit on one
  axis (X, through Z DRUM_Z), so they are one mesh, Flywheel.R, that spins about that axis;
  Flywheel.L is an empty at the left drum's centre. The rubber parts hoberman() puts on Pod and
  WeaponRing fold into their paint surface in charcoal vertex colour, as the drum's punch marks
  and hub boss already do.
- The beat read (unit E2-05, PILOT-CADENCE.md section 5.3; wave 46 3D review section 1.5): each
  light drum's flanges are closed brass rings (paint surface, brass vertex colour at alpha 0, so
  no equipped paint tints them) with one square index notch at NOTCH_AT, a charcoal index slot
  across the tape in it, and a charcoal index shoe on DrumBrackets just inboard of each drum whose
  tip stands past the rim at the same angle. clips/tally.json turns Flywheel.R one whole turn per
  shot, so the notch always comes back under the shoe. The tape is a capped (closed) cylinder.
  The heavy drums (shell_tally_plates.py) call drum() without index and are unchanged.
- Pressure windows: four per drum face, on the drum mesh's one paint surface. Vertex colour
  alpha carries the window index (0.2, 0.4, 0.6, 0.8 for windows 0 to 3; 1.0 elsewhere), so a
  cached shader with a per-instance lit count can light windows 0..n-1 cream on the drum mesh
  (ROSTER-LOOK section 8: no material_override). At rest windows 0 to 2 show cream and window 3
  is the dark blank the shop part lifts.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import common  # noqa: E402
from common import Part  # noqa: E402
import shell_base as sb  # noqa: E402

OUT = os.path.join(common.MODELS, "world_one", "shell_tally.glb")
ABACUS_OUT = os.path.join(common.MODELS, "world_one", "shell_tally_abacus.glb")
SHELL_BAND = (3000, 11000)
TARGET_TRIS = 6600

# Mulberry lattice enamel (ROSTER-LOOK 0.2; hero_assets_test MULBERRY, sampled from tally/hero.png).
MULBERRY = "8a3d46"
CREAM = "f7f1e3"
# Ledger drums (pilots/tally.md section 5): 0.34 m across, 0.07 m deep, axis along X, centred
# 0.23 m up so they clear the weapon band (top at Z 0.04). The inner face sits outside the
# tread-cap sphere (0.985) so the tumbling lattice never passes through a drum; the outer face
# stands 0.12 m past the lattice at that height, and the top rim breaks the outline by 0.165 m.
DRUM_R = 0.17
DRUM_DEPTH = 0.07
DRUM_Z = 0.23
DRUM_X = 1.033
WINDOW_R = 0.032
WINDOW_AT = 0.095
# Window index rides vertex colour alpha (see the header).
WINDOW_ALPHA = (0.2, 0.4, 0.6, 0.8)
# The index notch (E2-05): its centre angle in the drum's Y-Z plane (0 is +Y, the aim; 90 is up;
# 180 is the back, toward the chase camera), 11.25 degrees above the back so it faces the camera
# 17 degrees down and sits between two of the flange's 16 corners (the drum keeps its 0.34 m
# bounds). NOTCH_HALF is its half-width in degrees and NOTCH_R its floor, below the tape face.
NOTCH_AT = 168.75
NOTCH_HALF = 10.0
NOTCH_R = 0.148
# The index shoe: a charcoal tooth on DrumBrackets just inboard of the drum, its tip SHOE_R out
# (past the 0.17 m rim), at NOTCH_AT; its inner face clears the rim by SHOE_GAP.
SHOE_R = 0.198
SHOE_GAP = 0.006
# One punch mark gives way to the index slot (it sat 23 degrees from the notch and read as one).
PUNCH_AT = (0.3, 1.4, 2.2, 3.5, 4.1, 5.3)
INDEX_PUNCH_AT = (0.3, 1.4, 2.2, 3.5, 4.1)
# Reader carriage: the three card bays in a row beside the right yoke, front to back, on the
# bank line (shell_base.BANK); bay 0 is slot 1, bay 1 slot 2, bay 2 slot 3.
BAY_X = sb.BANK[0][0]
BAY_YS = (0.42, sb.BANK[0][1], sb.BANK[1][1])
BAY_Z = -0.262
# Drum magazine on the ring's front arc; the card slot points forward along the aim.
MAG_FRONT = 1.20


def flag(name, default=None):
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if name not in argv:
        return default
    i = argv.index(name)
    return argv[i + 1] if i + 1 < len(argv) and not argv[i + 1].startswith("--") else True


def merge(obj, part):
    """Appends a Part's faces to an existing mesh object at the same origin, mapping each slot
    onto the object's material list, so the part costs no draw for a slot the object has."""
    tmp = part.to_object((0, 0, 0), None)
    remap = []
    for m in tmp.data.materials:
        idx = next((i for i, om in enumerate(obj.data.materials) if om == m), None)
        if idx is None:
            obj.data.materials.append(m)
            idx = len(obj.data.materials) - 1
        remap.append(idx)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    col = bm.loops.layers.float_color.get("Color")
    src = tmp.data
    src_col = src.color_attributes["Color"]
    vs = [bm.verts.new(v.co) for v in src.vertices]
    new = []
    for p in src.polygons:
        f = bm.faces.new([vs[i] for i in p.vertices])
        f.material_index = remap[p.material_index]
        for loop, li in zip(f.loops, p.loop_indices):
            loop[col] = src_col.data[li].color
        new.append(f)
    bm.normal_update()
    for f in new:
        f.smooth = True
        for e in f.edges:
            if e.is_manifold and e.calc_face_angle() > 0.9:
                e.smooth = False
    bm.to_mesh(obj.data)
    bm.free()
    bpy.data.objects.remove(tmp)
    bpy.data.meshes.remove(src)


def drop_islands(obj, test):
    """Deletes every connected island of obj's mesh whose vertices all pass test(co)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    seen = set()
    doomed = []
    for v in bm.verts:
        if v.index in seen:
            continue
        island = []
        stack = [v]
        seen.add(v.index)
        while stack:
            u = stack.pop()
            island.append(u)
            for e in u.link_edges:
                w = e.other_vert(u)
                if w.index not in seen:
                    seen.add(w.index)
                    stack.append(w)
        if all(test(u.co) for u in island):
            doomed += island
    bmesh.ops.delete(bm, geom=doomed, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    return len(doomed)


def tint_alpha(part, faces, alpha):
    for f in faces:
        for loop in f.loops:
            c = loop[part.col]
            loop[part.col] = (c[0], c[1], c[2], alpha)


def drum(name, side, centre, radius=DRUM_R, depth=DRUM_DEPTH, reel=False, part=None, index=False):
    """One ledger drum on one paint surface, axis along X, outer face toward side: a cream
    punched-tape reel between petrol flanges, a charcoal hub boss and four windows in a square
    on the outer face. reel adds the class V second tape reel ring on the face. Every vertex
    stays inside x in [-depth/2, depth/2] and radius in the drum's local frame. part appends
    the drum to an existing Part (both drums share one mesh) instead of a new one. index builds
    the light drum's beat read (E2-05, see the header): a capped tape, closed brass flanges
    with the index notch, and the charcoal index slot in place of one punch mark."""
    p = part if part is not None else Part(name)
    c = Vector(centre)
    half = depth / 2
    flange = 0.008
    face = half - 0.003          # outer flange face; windows and boss stand to half
    rot = (0, math.pi / 2, 0)

    def at(x):
        return (c.x + side * x, c.y, c.z)

    tape = face - flange + half - flange
    p.cyl("paint", radius * 0.91, radius * 0.91, tape, 16,
          loc=at((face - flange - half + flange) / 2), rot=rot, color=CREAM, caps=index)
    if index:
        for x in (face - flange / 2, -half + flange / 2):
            tint_alpha(p, notched_flange(p, at(x), radius, flange), 0.0)
        tint_alpha(p, index_slot(p, at((face - flange - half + flange) / 2), radius * 0.91, tape), 0.0)
    else:
        p.cyl("paint", radius, radius, flange, 16, loc=at(face - flange / 2), rot=rot, color="petrol")
        p.cyl("paint", radius, radius, flange, 16, loc=at(-half + flange / 2), rot=rot, color="petrol")
    # Punch marks on the tape: a few charcoal slots, unevenly spaced (rule 8).
    for k, a in enumerate(INDEX_PUNCH_AT if index else PUNCH_AT):
        r = radius * 0.91 + 0.002
        x, y, z = at(-0.01 + 0.012 * (k % 2))
        # Local Z of the box turns to the radial direction (0, sin a, cos a).
        p.box("paint", (0.018, 0.026, 0.010), loc=(x, y + r * math.sin(a), z + r * math.cos(a)),
              rot=(-a, 0, 0), color="charcoal")
    p.cyl("paint", 0.04, 0.04, half - face, 8, loc=at((half + face) / 2), rot=rot, color="charcoal")
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        y, z = WINDOW_AT * math.cos(a), WINDOW_AT * math.sin(a)
        colour = CREAM if k < 3 else "charcoal"
        faces = p.cyl("paint", WINDOW_R, WINDOW_R, half - face, 6, loc=(at((half + face) / 2)[0], c.y + y, c.z + z),
                      rot=rot, color=colour)
        tint_alpha(p, faces, WINDOW_ALPHA[k])
    if reel:
        p.ring("paint", radius * 0.62, radius * 0.72, half - face, 16, loc=at((half + face) / 2), rot=rot, color=CREAM)
    sb._sharpen(p)
    return p


def _yz(deg, r):
    """A point r out from the drum axis at deg in the Y-Z plane (see NOTCH_AT)."""
    a = math.radians(deg)
    return r * math.cos(a), r * math.sin(a)


def _radial(deg):
    """Box rotation about X that turns local Z to the radial direction at deg (local Y is then
    the tangent and local X the drum axis)."""
    return (math.radians(deg - 90.0), 0, 0)


def notched_flange(p, loc, radius, thick):
    """One closed brass flange: the drum's 16-corner outline with one square notch at NOTCH_AT
    down to NOTCH_R, extruded thick along X at loc. The notch sits between two corners, so the
    outline keeps the corners at 0, 90, 180 and 270 degrees. Returns its faces."""
    lo, hi = NOTCH_AT - NOTCH_HALF, NOTCH_AT + NOTCH_HALF
    ring = [(lo, radius), (lo, NOTCH_R), (hi, NOTCH_R), (hi, radius)]
    ring += [(k * 22.5, radius) for k in range(16) if hi < k * 22.5 < lo + 360] + \
            [(k * 22.5 + 360, radius) for k in range(16) if hi < k * 22.5 + 360 < lo + 360]
    # prism() extrudes along local Z: local (x, y) = (-z, y) under a quarter turn about Y keeps
    # the outline counter-clockwise, so its faces point out.
    outline = []
    for deg, r in ring:
        y, z = _yz(deg, r)
        outline.append((-z, y))
    m = Matrix.Translation(Vector(loc)) @ Matrix.Rotation(math.pi / 2, 4, "Y")
    return p.prism("paint", outline, thick, matrix=m, color="brass")


def index_slot(p, loc, tape_r, length):
    """The charcoal index slot across the tape in the notch: it stands just proud of the tape
    and inside the notch, so from behind the notch reads as one dark gap across the rim."""
    y, z = _yz(NOTCH_AT, (NOTCH_R + tape_r + 0.004) / 2)
    width = 2 * NOTCH_R * math.sin(math.radians(NOTCH_HALF)) - 0.003
    return p.box("paint", (length - 0.001, width, tape_r + 0.004 - NOTCH_R),
                 loc=(loc[0], loc[1] + y, loc[2] + z), rot=_radial(NOTCH_AT), color="charcoal")


def index_shoe(p, side):
    """The fixed index shoe beside one drum: a charcoal arm up the drum's inner face from the
    bracket disc and the shoe at its tip, past the rim at NOTCH_AT, inboard of the inner flange.
    Alpha 0, as the brackets: no paint tints it."""
    inner = DRUM_X - DRUM_DEPTH / 2
    for x0, x1, r0, r1, w in ((inner - 0.013, inner - 0.005, 0.02, DRUM_R + SHOE_GAP + 0.004, 0.018),
                              (inner - 0.014, inner - 0.002, DRUM_R + SHOE_GAP, SHOE_R, 0.032)):
        y, z = _yz(NOTCH_AT, (r0 + r1) / 2)
        tint_alpha(p, p.box("paint", (x1 - x0, w, r1 - r0), loc=(side * (x0 + x1) / 2, y, DRUM_Z + z),
                            rot=_radial(NOTCH_AT), color="charcoal"), 0.0)


def bracket(p, side):
    """The gap bracket: a dark-steel arm from the outer gimbal axle boss (on the ring axis, so the
    gimbal's sweep never reaches it) out through the side gap to the drum's inner face."""
    inner = DRUM_X - DRUM_DEPTH / 2
    p.rod("paint", (side * 0.885, 0, 0), (side * (inner + 0.004), 0, DRUM_Z), 0.018, 6, color="charcoal", alpha=0.0)
    # Alpha 0 is the paint take mask (PAINT_SHADER): the brackets keep their charcoal under any paint.
    tint_alpha(p, p.cyl("paint", 0.035, 0.035, 0.012, 8, loc=(side * (inner - 0.002), 0, DRUM_Z),
                        rot=(0, math.pi / 2, 0), color="charcoal"), 0.0)
    index_shoe(p, side)


def carriage(p):
    """Reader carriage beside the right yoke: a petrol box under the bank, three cream punched
    cards lying in a row (bay 0 front), and the copper tab of card 0 (the bank builds tabs 1, 2)."""
    # Inside the gimbal sweep (radius 0.829, shell_base.cockpit).
    p.box("paint", (0.10, 0.32, 0.05), loc=(BAY_X, 0.30, -0.335), color="petrol")
    for y in BAY_YS:
        p.box("paint", (0.09, 0.10, 0.006), loc=(BAY_X, y, BAY_Z), color=CREAM)
        for dx in (-0.025, 0.0, 0.025):
            p.box("paint", (0.012, 0.012, 0.002), loc=(BAY_X + dx, y - 0.02, BAY_Z + 0.004), color="charcoal")
    p.box("copper", (0.03, 0.05, 0.08), loc=(BAY_X, BAY_YS[0], -0.27 + 0.06))
    # Return vent low behind the seat: the surge steam leaves through the rear gaps.
    p.box("rubber", (0.18, 0.03, 0.08), loc=(0, -0.255, -0.47))


def magazine(r):
    """Drum magazine on the ring's front arc: a petrol housing, two dark side reels, the card
    slot (class_accent, the only light on the mecha) and a cream card leaving it."""
    r.box("paint", (0.26, 0.125, 0.14), loc=(0, 1.1375, 0), color="petrol")
    for s in (-1, 1):
        r.cyl("rubber", 0.06, 0.06, 0.05, 8, loc=(s * 0.155, 1.13, 0), rot=(0, math.pi / 2, 0))
        r.box("rubber", (0.012, 0.13, 0.15), loc=(s * 0.10, 1.14, 0))
    r.box("class_accent", (0.14, 0.012, 0.026), loc=(0, MAG_FRONT + 0.006, 0.0))
    r.box("paint", (0.10, 0.04, 0.004), loc=(0, MAG_FRONT + 0.025, -0.004), rot=(-0.12, 0, 0), color=CREAM)


def stamp_sole(p):
    """Square copper stamp around the bottom hub's tread cap (Hub.11 points straight down)."""
    p.box("copper", (0.24, 0.24, 0.016), loc=(0, 0, -0.952))


def beads(core_part):
    """Abacus Lattice: one copper bead (pilots/tally.md section 6) threaded on each of the 60
    chains, pushed to one end or the other by link, like counted beads (two per chain is 12,609
    verts, over the 11,600 cap). Copper is a surface Core already has, so beads cost no draw."""
    hubs, links, _ = sb.lattice_layout()
    for n, (i, j) in enumerate(links):
        a, b = hubs[i], hubs[j]
        for t in ((0.30,) if n % 2 else (0.70,)):
            c = sb._slerp(a, b, t)
            d = (sb._slerp(a, b, t + 0.01) - sb._slerp(a, b, t - 0.01)).normalized()
            centre = c * sb.HUB_RADIUS
            core_part.rod("copper", centre - d * 0.018, centre + d * 0.018, 0.026, 6)


def fold_rubber(obj):
    """Moves obj's rubber faces onto its paint surface in charcoal vertex colour and drops the
    rubber slot, so the object spends one draw fewer. Returns the faces moved."""
    names = [m.name for m in obj.data.materials]
    if "rubber" not in names or "paint" not in names:
        return 0
    rub, pai = names.index("rubber"), names.index("paint")
    charcoal = common.rgba("charcoal")
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    col = bm.loops.layers.float_color.get("Color")
    moved = 0
    for f in bm.faces:
        if f.material_index == rub:
            f.material_index = pai
            for loop in f.loops:
                loop[col] = charcoal
            moved += 1
    bm.to_mesh(obj.data)
    bm.free()
    # pop() shifts the face indices above the removed slot down by one.
    obj.data.materials.pop(index=rub)
    return moved


def build(variant=""):
    """Builds the shell under a new root "ShellTally" (pilot_tally.previews() calls this too) and
    returns the hoberman() dict plus the drum objects."""
    abacus = variant == "abacus"
    caps = 6 if abacus else 8
    shell = sb.hoberman("Tally", enamel=CREAM if abacus else MULBERRY, seat="petrol", pairs=1, hub_sides=8,
                        cap_sides=caps,
                        bank=(("CardTab.1", "tab"), ("CardTab.2", "tab")))
    root, core, pod, ring = shell["root"], shell["core"], shell["pod"], shell["ring"]
    # Tally's pilot is its own GLB (pilot_tally_anim.glb); the shell carries no Pilot node.
    bpy.data.objects.remove(shell["pilot"])
    extra = Part("CoreTally")
    stamp_sole(extra)
    if abacus:
        beads(extra)
    merge(core, extra)
    # The neutral weapon seat on the front arc gives way to the magazine.
    dropped = drop_islands(ring, lambda co: co.y > 1.07 and abs(co.x) < 0.1 and abs(co.z) < 0.1)
    mag = Part("RingTally")
    magazine(mag)
    sb._sharpen(mag)
    merge(ring, mag)
    cab = Part("PodTally")
    carriage(cab)
    sb._sharpen(cab)
    merge(pod, cab)
    shell["folded"] = fold_rubber(pod) + fold_rubber(ring)
    # The two drum brackets end in discs 1.016 m out, past the ball on a wall, so they are their own
    # mesh, DrumBrackets, under Pod for hero_assets to bank with the carrier. They paint on the paint
    # slot in charcoal vertex colour, as the Pod's folded rubber did, so the pair costs one draw.
    brackets = Part("DrumBrackets")
    for side in (1, -1):
        bracket(brackets, side)
    sb._sharpen(brackets)
    brackets.to_object((0, 0, 0), pod)
    # Both drums in one mesh on the shared X axis, origin at the right drum's centre.
    wheels = Part("Flywheel.R")
    for name, side in (("R", 1), ("L", -1)):
        centre = (side * DRUM_X, 0.0, DRUM_Z)
        drum("Flywheel." + name, side, centre, part=wheels, index=True)
        axis = common.empty("FlywheelAxis." + name, centre, pod)
        axis.rotation_euler = (0, math.pi / 2, 0)
    drums = [wheels.to_object((DRUM_X, 0.0, DRUM_Z), pod)]
    common.empty("Flywheel.L", (-DRUM_X, 0.0, DRUM_Z), pod)
    reader = common.empty("ReaderCarriage", (BAY_X, 0.30, -0.30), pod)
    for i, y in enumerate(BAY_YS):
        common.empty("CardBay." + str(i), (BAY_X, y, BAY_Z), reader)
    common.empty("Control.CardTab.0", (BAY_X, BAY_YS[0], -0.27), pod)
    # Socket local -Z is the outgoing axis after glTF/Godot conversion (as before the mecha).
    for name, pos, parent, rot in [
            ("ReaderExit", (0, MAG_FRONT + 0.012, 0.0), ring, (math.pi / 2, 0, 0)),
            ("ReturnExit", (0, -0.27, -0.47), pod, (math.pi / 2, 0, 0)),
            ("StampContact", (0, 0, -0.985), pod, (0, 0, 0)),
            ("LedgerMount", (-0.255, 0.045, -0.20), pod, (math.pi / 2, 0, 0))]:
        common.empty(name, pos, parent).rotation_euler = rot
    bpy.context.view_layer.update()
    shell["drums"] = drums
    shell["dropped"] = dropped
    return shell


def main():
    common.reset()
    variant = flag("--variant", "")
    if variant not in ("", "abacus"):
        raise SystemExit("unknown variant %s" % variant)
    shell = build(variant)
    root = shell["root"]
    dome = sb.bpy_object(shell["pod"], "Dome")
    tris = common.tri_total(root)
    print("HOBERMAN Tally variant=%s tris=%d core=%d target=%d %s; neutral mount verts dropped %d; rubber faces folded %d"
          % (variant or "default", tris, common.tris(shell["core"]), TARGET_TRIS,
             "fits" if tris <= TARGET_TRIS else "over target", shell["dropped"], shell["folded"]))
    draws = sum(len(o.data.materials) for o in common.tree(root) if o.type == "MESH")
    print("DRAWS Tally %d (unit budget 10 plus DrumBrackets, Hoberman pilot cap 16) %s" % (draws, "ok" if draws <= 11 else "OVER"))
    if draws > 11:
        raise SystemExit("Tally shell spends %d draws, over the unit's budget of 11" % draws)
    for d in shell["drums"]:
        print("DRUM %s radius %.4f" % (d.name, common.max_radius(d)))
    out = flag("--out") or (ABACUS_OUT if variant == "abacus" else OUT)
    sb.finish("Tally", root, shell["core"], dome, shell_band=SHELL_BAND, pod_obj=shell["pod"], out=out)


if __name__ == "__main__":
    main()
