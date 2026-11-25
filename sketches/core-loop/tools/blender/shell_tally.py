"""Tally's Hoberman mecha, the wire-tapper rebuild (unit W47-TALLY-A-3D, 24 Nov 2026): an oxblood
lattice on shell_base.hoberman(), open-reel tape decks at 3 and 9 o'clock, brown tape run round the
weapon ring through a read/write head block at 12 o'clock, the copper jumper-spike injector on that
head with its insulated alligator clamp and the spring lead spool under it (her grapple, rule G1),
a capacitor jar bank behind the seat, a patch bay with copper jumper cords, a card-punch keypad, a
monocle oscilloscope visor on a swing arm, and the override card-punch press with its "III" maker
mark on the bottom hub. --variant abacus builds the earned Abacus Lattice shell (CUSTOMIZE section
8): cream enamel with a copper bead threaded on each chain and six-sided tread caps; the machinery,
its sockets and the sight cone do not move.

Sources: SCRAPKEEP-REBASELINE-MASTER-BIBLE.md sections 2.3 and 3.1 and
OPUS-TASTE-AND-MECHANICS-RUBRIC.md section 2 (Tally) and 6b in artifacts/local/w46-gate/ (the
coordinator's artifact store), the grounded sheets g06-pilots-trio-b-tarn-tally-cannon.png and
g11-universal-grapple-rigs-b.png, and Andrew's call 2 (24 Nov 2026): oxblood #5E232D lattice, never
Kindness purple; every filament, trace and spark amber #E5A044 or copper #B77843; no green, mint or
purple, no screens and no PAID stamp.

  blender --background --threads 2 --python-exit-code 1 \\
    --python sketches/core-loop/tools/blender/shell_tally.py -- [--out <glb>] [--variant abacus]
wrapped in prlimit with a 12884901888-byte address-space cap, as world_one/shell_neutral.py runs.

Kept from the earlier shell, so no game code changes (hero_assets.gd, mecha_motion.gd and
clips/tally.json read these by name):
- Node names and sockets: Flywheel.R (both decks in one mesh, turning on their shared X axis),
  Flywheel.L (an empty), FlywheelAxis.R/L, DrumBrackets with the index shoe, ReaderCarriage and
  CardBay.0 to 2, Control.CardTab.0, ReaderExit (the injector muzzle), ReturnExit, StampContact
  and LedgerMount.
- Deck size and place: 1.01 m across, 0.24 m deep, centre 1.384 m out and 0.28 m up (the largest
  the carrier bank's slope and wall laws allow, carrier_bank_test); the brass notched flanges, the
  charcoal index slot, the three charcoal timing bands and the face bar, all at vertex alpha 0 so no
  equipped paint tints them (the beat read of unit E2-05, PILOT-CADENCE.md section 5.3).
- Four window indices in vertex alpha (0.2, 0.4, 0.6, 0.8) on each deck's outer face. They are now
  the four dark cut-outs of an open reel, flat discs on the flange.
- Draws, 11 under the Hoberman pilot mecha cap of 16 (docs/decisions.tsv w13-PD register
  2026-10-10T21:29:13): Core 3 (paint, copper, rubber), Pod 2 (paint, copper), Gyro 1, GyroInner 1,
  WeaponRing 2 (paint, class_accent), Flywheel.R 1, DrumBrackets 1. The rubber parts hoberman() puts
  on Pod and WeaponRing fold into their paint surface in charcoal vertex colour. WeaponRing has no
  copper slot, so its copper parts are copper vertex colour on paint.
- The only class_accent is the punched-card eject slot on the injector (pilot_tally_asset_test).

Calls made here (each one a call Andrew can overturn):
- Copper hubs drop from eight sides to six, and the decks' windows are flat discs, to pay for the
  new hardware inside today's triangle budget (hero_six_pilot_budget_test CLASS_V and OVER_CAP).
- The tape: the weapon ring's band turns from bone to brown oxide (Palette.RUST #9B513A), so the
  tape reads as one loop round the equator, entering the read/write head through brass pole pieces
  at 12 o'clock. The ring yaws to the aim, so the head stays with the injector.
- Every weapon part stays inside 1.25 m of the axis between the decks' bottom and top, so the ring
  can aim sideways past the decks' inner faces (1.264 m).
- The monocle oscilloscope is a swing-arm visor on the Pod in front of her right eye, not a new
  pilot outfit, so the pilot GLB and outfit_tally_eyeshade do not change.
- The capacitor jar glass is ledger cream (Palette.LEDGER_CREAM) on the paint surface: a glass slot
  would add a draw. Each lit filament is an amber bar on the jar's back, where the chase camera sees
  it.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import common
from common import Part
import shell_base as sb

OUT = os.path.join(common.MODELS, "world_one", "shell_tally.glb")
ABACUS_OUT = os.path.join(common.MODELS, "world_one", "shell_tally_abacus.glb")
SHELL_BAND = (3000, 11000)
TARGET_TRIS = 6600

OXBLOOD = "5e232d"
CREAM = "f7f1e3"
TAPE_BROWN = "oxide"
GLASS = CREAM
HUB_SIDES = 6
DRUM_R = 0.505
DRUM_DEPTH = 0.24
DRUM_Z = 0.28
TAPE = 0.95
DRUM_INNER = 1.264
DRUM_X = DRUM_INNER + DRUM_DEPTH / 2
REF_R = 0.17
WINDOW_R = 0.032
WINDOW_AT = 0.095
WINDOW_ALPHA = (0.2, 0.4, 0.6, 0.8)
NOTCH_AT = 123.75
NOTCH_HALF = 10.0
NOTCH_R = DRUM_R * 0.84
SHOE_R = DRUM_R + 0.10
SHOE_GAP = 0.016
SHOE_WIDTH = 0.14
SHOE_OVER = 0.04
PUNCH_AT = (0.3, 1.4, 2.2, 3.5, 4.1, 5.3)
TIMING_AT = (NOTCH_AT + 90.0, NOTCH_AT + 180.0, NOTCH_AT + 270.0)
TIMING_WIDTH = 0.07
BAY_X = sb.BANK[0][0]
BAY_YS = (0.42, sb.BANK[0][1], sb.BANK[1][1])
BAY_Z = -0.262
MAG_FRONT = 1.20
SWEEP = 1.252


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


def recolour(obj, slot, src, dst):
    """Repaints every face of obj's slot surface whose vertex colour is src in dst (same alpha).
    Returns the faces repainted."""
    names = [m.name for m in obj.data.materials]
    if slot not in names:
        return 0
    idx = names.index(slot)
    want = common.rgba(src)
    to = common.rgba(dst)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    col = bm.loops.layers.float_color.get("Color")
    done = 0
    for f in bm.faces:
        if f.material_index != idx:
            continue
        if all(all(abs(loop[col][i] - want[i]) < 0.004 for i in range(3)) for loop in f.loops):
            for loop in f.loops:
                loop[col] = (to[0], to[1], to[2], loop[col][3])
            done += 1
    bm.to_mesh(obj.data)
    bm.free()
    return done


def tint_alpha(part, faces, alpha):
    for f in faces:
        for loop in f.loops:
            c = loop[part.col]
            loop[part.col] = (c[0], c[1], c[2], alpha)


def drum(name, side, centre, radius=DRUM_R, depth=DRUM_DEPTH, reel=False, part=None, index=False):
    """One open-reel tape deck on one paint surface, axis along X, outer face toward side: a pack
    of brown oxide tape between two solid flanges, a bone (aluminium) hub boss and four dark window
    cut-outs in a square on the outer flange. reel adds the class V second reel ring on the face.
    Every vertex stays inside x in [-depth/2, depth/2] and radius in the deck's local frame. part
    appends the deck to an existing Part (both decks share one mesh) instead of a new one. index
    builds the light deck's beat read (E2-05, see the header): closed brass flanges with the index
    notch, the charcoal index slot and timing bands across the tape and a charcoal bar across the
    face; without it (the class V heavy decks) the flanges are copper and the tape carries a few
    charcoal splice marks. The tape is capped (closed)."""
    p = part if part is not None else Part(name)
    c = Vector(centre)
    k = radius / REF_R
    half = depth / 2
    flange = 0.008 * k
    face = half - 0.003 * k
    rot = (0, math.pi / 2, 0)

    def at(x):
        return (c.x + side * x, c.y, c.z)

    tape = face - flange + half - flange
    p.cyl("paint", radius * TAPE, radius * TAPE, tape, 16,
          loc=at((face - flange - half + flange) / 2), rot=rot, color=TAPE_BROWN)
    if index:
        for x in (face - flange / 2, -half + flange / 2):
            tint_alpha(p, notched_flange(p, at(x), radius, flange), 0.0)
        tint_alpha(p, index_slot(p, at((face - flange - half + flange) / 2), radius * TAPE, tape, k), 0.0)
    else:
        p.cyl("paint", radius, radius, flange, 16, loc=at(face - flange / 2), rot=rot, color="copper")
        p.cyl("paint", radius, radius, flange, 16, loc=at(-half + flange / 2), rot=rot, color="copper")
    if index:
        for deg in TIMING_AT:
            tint_alpha(p, timing_band(p, at((face - flange - half + flange) / 2), radius * TAPE, tape, k, deg), 0.0)
        bar = half - face - 0.001
        tint_alpha(p, p.box("paint", (bar, 1.6 * radius, 0.016 * k), loc=at(face + bar / 2),
                            color="charcoal"), 0.0)
    for n, a in enumerate(() if index else PUNCH_AT):
        r = radius * TAPE + 0.002 * k
        x, y, z = at((-0.01 + 0.012 * (n % 2)) * k)
        p.box("paint", (0.018 * k, 0.026 * k, 0.010 * k), loc=(x, y + r * math.sin(a), z + r * math.cos(a)),
              rot=(-a, 0, 0), color="charcoal")
    p.cyl("paint", 0.045 * k, 0.045 * k, half - face, 8, loc=at((half + face) / 2), rot=rot, color="bone")
    for n in range(4):
        a = math.pi / 4 + n * math.pi / 2
        y, z = WINDOW_AT * k * math.cos(a), WINDOW_AT * k * math.sin(a)
        faces = sb._disc(p, (at(face + 0.0008)[0], c.y + y, c.z + z), (side, 0, 0), WINDOW_R * k, 6,
                         "paint", "charcoal")
        tint_alpha(p, faces, WINDOW_ALPHA[n])
    if reel:
        p.ring("paint", radius * 0.62, radius * 0.72, half - face, 16, loc=at((half + face) / 2), rot=rot, color="bone")
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
    outline = []
    for deg, r in ring:
        y, z = _yz(deg, r)
        outline.append((-z, y))
    m = Matrix.Translation(Vector(loc)) @ Matrix.Rotation(math.pi / 2, 4, "Y")
    return p.prism("paint", outline, thick, matrix=m, color="brass")


def index_slot(p, loc, tape_r, length, k):
    """The charcoal index slot across the tape in the notch: it stands just proud of the tape
    and inside the notch, so from behind the notch reads as one dark gap across the rim."""
    proud = 0.004 * k
    y, z = _yz(NOTCH_AT, (NOTCH_R + tape_r + proud) / 2)
    width = 2 * NOTCH_R * math.sin(math.radians(NOTCH_HALF)) - 0.003 * k
    return p.box("paint", (length - 0.001, width, tape_r + proud - NOTCH_R),
                 loc=(loc[0], loc[1] + y, loc[2] + z), rot=_radial(NOTCH_AT), color="charcoal")


def timing_band(p, loc, tape_r, length, k, deg):
    """One charcoal timing band across the tape at deg, standing as proud as the index slot."""
    proud = 0.004 * k
    y, z = _yz(deg, tape_r + proud / 2 - 0.002 * k)
    return p.box("paint", (length - 0.001, TIMING_WIDTH, proud + 0.004 * k),
                 loc=(loc[0], loc[1] + y, loc[2] + z), rot=_radial(deg), color="charcoal")


def index_shoe(p, side):
    """The fixed index shoe beside one drum: a charcoal arm up the drum's inner face from the
    bracket disc and a tooth at its tip clamped over the rim at NOTCH_AT, SHOE_GAP clear of the
    turning drum. Alpha 0, as the brackets: no paint tints it."""
    inner = DRUM_X - DRUM_DEPTH / 2
    for x0, x1, r0, r1, w in ((inner - 0.030, inner - 0.008, 0.06, DRUM_R + SHOE_GAP + 0.01, 0.07),
                              (inner - 0.036, inner + SHOE_OVER, DRUM_R + SHOE_GAP, SHOE_R, SHOE_WIDTH)):
        y, z = _yz(NOTCH_AT, (r0 + r1) / 2)
        tint_alpha(p, p.box("paint", (x1 - x0, w, r1 - r0), loc=(side * (x0 + x1) / 2, y, DRUM_Z + z),
                            rot=_radial(NOTCH_AT), color="charcoal"), 0.0)


def bracket(p, side):
    """The gap bracket: two stout square dark-steel beams, a riser from the outer gimbal axle boss
    (on the ring axis, so the gimbal's sweep never reaches it) up through the side gap (it crosses
    the lattice 10 degrees up, where the heft plates leave the bracket line clear) inside the
    weapon band, and an arm level over the band to a broad hub disc on the drum's inner face."""
    inner = DRUM_X - DRUM_DEPTH / 2
    elbow = (side * 1.0, 0, DRUM_Z)
    p.beam("paint", (side * 0.885, 0, 0), elbow, 0.07, color="charcoal", alpha=0.0)
    p.beam("paint", elbow, (side * (inner - 0.004), 0, DRUM_Z), 0.07, color="charcoal", alpha=0.0)
    tint_alpha(p, p.cyl("paint", 0.12, 0.12, 0.02, 8, loc=(side * (inner - 0.012), 0, DRUM_Z),
                        rot=(0, math.pi / 2, 0), color="charcoal"), 0.0)
    index_shoe(p, side)


def patch_bay(p):
    """The patch bay beside the right yoke, where the reader carriage was: a bone jack panel under
    the three card bays (the bays are its jacks, and the copper card tabs its plugs), copper jack
    studs, and two copper jumper cords looping between jacks for her paw to re-plug. Then the
    card-punch keypad beside her left knee: a bone box with two charcoal key rows and a cream
    punched card standing in its slot. Inside the gimbal sweep (radius 0.829, shell_base.cockpit)."""
    p.box("paint", (0.11, 0.34, 0.025), loc=(BAY_X, 0.30, BAY_Z - 0.0125), color="bone")
    p.box("copper", (0.03, 0.05, 0.08), loc=(BAY_X, BAY_YS[0], -0.27 + 0.06))
    jacks = ((BAY_X - 0.035, 0.42), (BAY_X - 0.035, 0.24), (BAY_X + 0.035, 0.36), (BAY_X + 0.035, 0.18))
    for x, y in jacks:
        sb._stud(p, (x, y, BAY_Z + 0.002), (0, 0, 1), 0.013, 0.01, "copper")
    for (x0, y0), (x1, y1), bow in ((jacks[0], jacks[1], -0.04), (jacks[2], jacks[3], 0.04)):
        mid = (x0 + bow, (y0 + y1) / 2, BAY_Z + 0.06)
        p.rod("copper", (x0, y0, BAY_Z), mid, 0.008, 4)
        p.rod("copper", mid, (x1, y1, BAY_Z), 0.008, 4)
    kx, ky, kz = -BAY_X + 0.02, 0.28, -0.27
    p.box("paint", (0.10, 0.14, 0.04), loc=(kx, ky, kz), color="bone")
    for dy in (-0.03, 0.03):
        p.box("paint", (0.08, 0.014, 0.008), loc=(kx, ky + dy, kz + 0.022), color="charcoal")
    p.box("paint", (0.06, 0.005, 0.07), loc=(kx, ky - 0.075, kz + 0.04), rot=(-0.2, 0, 0), color=CREAM)
    p.box("rubber", (0.18, 0.03, 0.08), loc=(0, -0.255, -0.47))


def jar_bank(p):
    """The capacitor jar bank on the seat back's top, behind her shoulders: a charcoal rack, three
    glass jars with copper caps, each with an amber filament on the side the chase camera sees, and
    a fourth copper-capped slot standing empty for the fourth Pressure. Every point stays outside
    the sight cone from the head to the chase eyes (shell_base.sight_cone_hits)."""
    y, base = -0.27, sb.SEAT_BACK_TOP + 0.005
    p.box("paint", (0.6, 0.11, 0.03), loc=(0, y, base), color="charcoal")
    top = base + 0.015
    jar_r, jar_h = 0.05, 0.13
    for n, x in enumerate((-0.21, -0.07, 0.07, 0.21)):
        if n < 3:
            p.cyl("paint", jar_r, jar_r, jar_h, 6, loc=(x, y, top + jar_h / 2), color=GLASS)
            p.box("paint", (0.022, 0.006, jar_h * 0.8), loc=(x, y - jar_r * 0.87 - 0.002, top + jar_h / 2), color="amber")
            p.cyl("copper", jar_r + 0.004, jar_r + 0.004, 0.02, 6, loc=(x, y, top + jar_h + 0.01))
        else:
            p.cyl("copper", jar_r + 0.004, jar_r + 0.004, 0.02, 6, loc=(x, y, top + 0.01))


def monocle(p):
    """The monocle oscilloscope visor: a copper swing arm from the right yoke's head to a round
    copper bezel in front of her right eye, its charcoal face drawn with an amber sine trace (an
    analog scope, no screen). The trace faces forward so the front reads it; the head is at
    shell_base.HEAD and the probed eye line is about 0.13 m ahead of it."""
    centre = Vector((0.085, 0.185, 0.235))
    p.rod("copper", (0.30, 0.36, 0.13), (0.30, 0.30, 0.25), 0.01, 4)
    p.rod("copper", (0.30, 0.30, 0.25), centre + Vector((0.04, 0.0, 0.0)), 0.01, 4)
    p.cyl("copper", 0.042, 0.042, 0.012, 8, loc=centre, rot=(math.pi / 2, 0, 0))
    face = centre + Vector((0, 0.0065, 0))
    sb._disc(p, face, (0, 1, 0), 0.034, 8, "paint", "charcoal")
    for n, (dx, dz, tilt) in enumerate(((-0.019, 0.006, 0.9), (0.0, -0.002, -0.9), (0.019, 0.006, 0.9))):
        u = Vector((math.cos(tilt), 0, math.sin(tilt)))
        v = Vector((-math.sin(tilt), 0, math.cos(tilt)))
        c = face + Vector((dx, 0.0006, dz))
        vs = [p.bm.verts.new(c + u * (sx * 0.013) + v * (sy * 0.0025)) for sx, sy in ((-1, -1), (-1, 1), (1, 1), (1, -1))]
        p.paint([p.bm.faces.new(vs)], "paint", "amber")


def injector(r):
    """The read/write head and the copper jumper-spike injector at 12 o'clock on the weapon ring,
    with Tally's grapple (rule G1): the head is a charcoal block the brown tape band runs through,
    between brass pole pieces; the injector muzzle is a copper barrel ending in the insulated
    alligator clamp (copper jaws, charcoal sleeve) that she fires as a clip-dart and swings on; its
    sheathed patch lead drops to the spring lead spool hung under the head (copper lead wound on a
    drum between charcoal spring cases). On top, a bone receiver holds three more clip-darts on a
    spring rail and the punched-card eject slot, the only class_accent. Copper here is copper vertex
    colour on paint (the ring has no copper slot). Every point stays inside SWEEP horizontally."""
    band = sb.RING_BAND[1]
    hy = band - 0.025
    r.box("paint", (0.18, 0.09, 0.11), loc=(0, hy, 0), color="charcoal")
    for s in (-1, 1):
        r.box("paint", (0.014, 0.055, 0.06), loc=(s * 0.097, hy, 0), color="brass")
    r.cyl("paint", 0.038, 0.038, 0.07, 6, loc=(0, hy + 0.08, 0), rot=(math.pi / 2, 0, 0), color="copper")
    r.box("paint", (0.09, 0.04, 0.075), loc=(0, MAG_FRONT - 0.015, 0), color="charcoal")
    for s in (-1, 1):
        r.beam("paint", (0, MAG_FRONT + 0.005, s * 0.03), (0, SWEEP - 0.01, s * 0.006), 0.07, 0.018, color="copper")
    r.box("paint", (0.20, 0.13, 0.11), loc=(0, hy + 0.02, 0.11), color="bone")
    r.box("paint", (0.19, 0.022, 0.02), loc=(0, hy - 0.025, 0.175), color="charcoal")
    for x in (-0.06, 0.0, 0.06):
        r.box("paint", (0.032, 0.08, 0.026), loc=(x, hy + 0.0, 0.178), color="copper")
    r.box("class_accent", (0.10, 0.012, 0.022), loc=(0, hy + 0.08, 0.158))
    r.box("paint", (0.08, 0.004, 0.05), loc=(0, hy + 0.08, 0.185), rot=(0.25, 0, 0), color=CREAM)
    sy, sz = hy + 0.06, -0.16
    r.box("paint", (0.03, 0.05, 0.08), loc=(0, sy - 0.02, -0.09), color="charcoal")
    r.cyl("paint", 0.06, 0.06, 0.15, 6, loc=(0, sy, sz), rot=(0, math.pi / 2, 0), color="copper")
    for s in (-1, 1):
        r.cyl("paint", 0.088, 0.088, 0.02, 6, loc=(s * 0.085, sy, sz), rot=(0, math.pi / 2, 0), color="charcoal")
    elbow = (0, MAG_FRONT - 0.005, -0.10)
    r.rod("paint", (0, sy + 0.055, sz + 0.02), elbow, 0.014, 4, color="charcoal")
    r.rod("paint", elbow, (0, MAG_FRONT - 0.015, -0.035), 0.014, 4, color="charcoal")


def punch_press(p):
    """The override card-punch press on the bottom hub (Hub.11 points straight down), where the
    stamp sole was: a thick copper octagonal die collar round the tread cap, a ring of eight
    charcoal punched holes on its face and the "III" maker mark beside the cap. Inside the Core's
    0.985 m limit."""
    r, z0, z1 = 0.114, -0.977, -0.945
    outline = [(r * math.cos(math.pi / 8 + k * math.pi / 4), r * math.sin(math.pi / 8 + k * math.pi / 4)) for k in range(8)]
    p.prism("copper", outline, z1 - z0, matrix=common.mtx((0, 0, (z0 + z1) / 2)))
    face = z0 - 0.0006

    def mark(cx, cy, hx, hy):
        vs = [p.bm.verts.new((cx + sx * hx, cy + sy * hy, face)) for sx, sy in ((-1, -1), (-1, 1), (1, 1), (1, -1))]
        p.paint([p.bm.faces.new(vs)], "paint", "charcoal")

    for k in range(8):
        a = k * math.pi / 4
        mark(0.088 * math.cos(a), 0.088 * math.sin(a), 0.008, 0.008)
    for dx in (-0.012, 0.0, 0.012):
        mark(dx, -0.064, 0.003, 0.010)


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
    obj.data.materials.pop(index=rub)
    return moved


def sweep_reach(obj):
    """The furthest horizontal reach of obj's vertices between the decks' bottom and top."""
    lo, hi = DRUM_Z - DRUM_R - 0.02, DRUM_Z + DRUM_R + 0.02
    mw = obj.matrix_world
    far = 0.0
    for v in obj.data.vertices:
        w = mw @ v.co
        if lo <= w.z <= hi:
            far = max(far, math.hypot(w.x, w.y))
    return far


def build(variant=""):
    """Builds the shell under a new root "ShellTally" (pilot_tally.previews() calls this too) and
    returns the hoberman() dict plus the deck objects."""
    abacus = variant == "abacus"
    caps = 6 if abacus else 8
    shell = sb.hoberman("Tally", enamel=CREAM if abacus else OXBLOOD, seat="petrol", pairs=1, hub_sides=HUB_SIDES,
                        cap_sides=caps,
                        bank=(("CardTab.1", "tab"), ("CardTab.2", "tab")))
    root, core, pod, ring = shell["root"], shell["core"], shell["pod"], shell["ring"]
    bpy.data.objects.remove(shell["pilot"])
    extra = Part("CoreTally")
    punch_press(extra)
    if abacus:
        beads(extra)
    merge(core, extra)
    dropped = drop_islands(ring, lambda co: co.y > 1.07 and abs(co.x) < 0.1 and abs(co.z) < 0.1)
    shell["taped"] = recolour(ring, "paint", "bone", TAPE_BROWN)
    head = Part("RingTally")
    injector(head)
    sb._sharpen(head)
    merge(ring, head)
    cab = Part("PodTally")
    patch_bay(cab)
    jar_bank(cab)
    monocle(cab)
    sb._sharpen(cab)
    merge(pod, cab)
    shell["folded"] = fold_rubber(pod) + fold_rubber(ring)
    brackets = Part("DrumBrackets")
    for side in (1, -1):
        bracket(brackets, side)
    sb._sharpen(brackets)
    brackets.to_object((0, 0, 0), pod)
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
    print("HOBERMAN Tally variant=%s tris=%d core=%d target=%d %s; neutral mount verts dropped %d; rubber faces folded %d; tape faces %d"
          % (variant or "default", tris, common.tris(shell["core"]), TARGET_TRIS,
             "fits" if tris <= TARGET_TRIS else "over target", shell["dropped"], shell["folded"], shell["taped"]))
    draws = sum(len(o.data.materials) for o in common.tree(root) if o.type == "MESH")
    print("DRAWS Tally %d (unit budget 10 plus DrumBrackets, Hoberman pilot cap 16) %s" % (draws, "ok" if draws <= 11 else "OVER"))
    if draws > 11:
        raise SystemExit("Tally shell spends %d draws, over the unit's budget of 11" % draws)
    if shell["taped"] == 0:
        raise SystemExit("the weapon ring's bone band was not found to turn into tape")
    sweep = sweep_reach(shell["ring"])
    print("SWEEP Tally weapon ring %.4f m at deck height, decks' inner face %.3f m %s"
          % (sweep, DRUM_INNER, "ok" if sweep <= SWEEP + 1e-4 else "OVER"))
    if sweep > SWEEP + 1e-4:
        raise SystemExit("weapon ring parts reach %.4f m at deck height, past %.3f m" % (sweep, SWEEP))
    for d in shell["drums"]:
        print("DRUM %s radius %.4f" % (d.name, common.max_radius(d)))
    out = flag("--out") or (ABACUS_OUT if variant == "abacus" else OUT)
    sb.finish("Tally", root, shell["core"], dome, shell_band=SHELL_BAND, pod_obj=shell["pod"], out=out)


if __name__ == "__main__":
    main()
