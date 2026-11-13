"""Kit plates for the twelve grey item panels (card IL-01), one GLB each.

Built from the details sheets in docs/art/reference/item_panels/<panel>/ (23 Oct): face, edge and
back at one scale. Range Sight has no sheet (the image filter refused it); it is built from its
written spec in that folder's PROMPTS.md (coordinator ruling 24 Oct, DECISIONS section 6).

Each plate is a stamped hex (or chamfered) plate about 0.45 m across with a steel rim, four
charcoal bolts and its stat's hardware, in the sheets' grey-tier tones: bone #d2c5a5, steel
#9aa0a0, charcoal #242a28. Two vertex-colour surfaces, so the panel shell keeps one MultiMesh
of two draws per silhouette: `panel_face` (painted, not metal: bone, rubber, rope, recesses)
and `panel_hardware` (metal: steel and charcoal fittings). The runtime multiplies its patina
over both.

Axes (Blender): X across the plate, Y up the sheet's face view (the roll direction for the fin),
Z out of the ball. Godot reads Z as +Y, the panel shell's outward axis. The origin is the
centre of the plate's back. Plates are flat, like the stand-ins they replace: the sheets' 0.92 m
seat curve is left off, because the shell stretches each face 1.5x (panel_shell.gd PLATE_FACE)
and a curve on so few faces bends the corners away from the hardware on them. Moving parts are built in their rest pose; the sheets' fleet numbers are left off (too small
to read at 0.45 m from the gameplay camera).

  blender -b --factory-startup --python-exit-code 1 -P item_panels.py [-- --out DIR] [--render DIR]
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common

sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")))
import palette_gd  # noqa: E402
import cycles_device
import polish
from common import Part

FACE = "panel_face"
HARD = "panel_hardware"
BONE = common.HEX["bone"]
STEEL = palette_gd.HEX["STEEL"]
CHARCOAL = common.HEX["charcoal"]
ROPE = "b8a77f"  # bone in shade: rope reads apart from the plate it sits on
TOP = 0.03       # the plate's face height above its back
TRIS_CAP = 1200  # 128 drawn plates stay near 150k triangles at the worst mix
HEIGHT_CAP = 0.25

ALONG_X = (0, math.pi / 2, 0)
ALONG_Y = (math.pi / 2, 0, 0)


def hexo(w, h, c=None):
    """A long hex, pointed at both X ends."""
    c = h * 0.5 if c is None else c
    return [(-w / 2, 0), (-w / 2 + c, -h / 2), (w / 2 - c, -h / 2), (w / 2, 0), (w / 2 - c, h / 2), (-w / 2 + c, h / 2)]


def hexy(w, h, c=None):
    """A long hex, pointed at both Y ends."""
    return [(y, -x) for x, y in hexo(h, w, c)]


def chamfer(w, h, c):
    return [(-w / 2 + c, -h / 2), (w / 2 - c, -h / 2), (w / 2, -h / 2 + c), (w / 2, h / 2 - c),
            (w / 2 - c, h / 2), (-w / 2 + c, h / 2), (-w / 2, h / 2 - c), (-w / 2, -h / 2 + c)]


def scaled(outline, sx, sy):
    return [(x * sx, y * sy) for x, y in outline]


def plate(p, outline, w, h, bolts, rim=0.012):
    """Steel back slab and rim under an inset bone face, and four charcoal bolts."""
    p.prism(HARD, outline, 0.016, matrix=common.mtx((0, 0, 0.008)), color=STEEL)
    face = scaled(outline, 1 - 2 * rim / w, 1 - 2 * rim / h)
    p.prism(FACE, face, 0.014, matrix=common.mtx((0, 0, 0.023)), color=BONE, side_slot=HARD, side_color=STEEL)
    for x, y in bolts:
        p.cyl(HARD, 0.017, 0.017, 0.012, segs=6, loc=(x, y, TOP + 0.006), color=CHARCOAL)
        p.cyl(HARD, 0.022, 0.022, 0.003, segs=8, loc=(x, y, TOP + 0.0015), color=STEEL)


def corners(x, y):
    return [(-x, -y), (x, -y), (x, y), (-x, y)]


def louvre(p):
    plate(p, hexo(0.45, 0.30, 0.09), 0.45, 0.30, corners(0.125, 0.112))
    p.box(FACE, (0.30, 0.19, 0.004), loc=(0, 0, TOP + 0.002), color=CHARCOAL)
    for x in (-0.158, 0.158):
        p.box(FACE, (0.018, 0.188, 0.032), loc=(x, 0, TOP + 0.016), color=BONE)
    for y in (-0.103, 0.103):
        p.box(FACE, (0.334, 0.018, 0.032), loc=(0, y, TOP + 0.016), color=BONE)
    # Five slats on their hinge pins, opened 35 degrees (the working state reads as a grille).
    for k in range(5):
        y = -0.076 + k * 0.038
        p.box(FACE, (0.29, 0.042, 0.008), loc=(0, y, TOP + 0.022), rot=(-0.61, 0, 0), color=BONE)
        p.rod(HARD, (0.14, y, TOP + 0.022), (0.152, y, TOP + 0.022), 0.007, segs=6, color=STEEL)
    p.box(HARD, (0.012, 0.18, 0.012), loc=(0.152, 0, TOP + 0.038), color=STEEL)


def rivet(p):
    plate(p, chamfer(0.45, 0.45, 0.035), 0.45, 0.45, corners(0.18, 0.18))
    p.cyl(HARD, 0.1, 0.1, 0.02, segs=20, loc=(0, 0, TOP + 0.01), color=CHARCOAL)
    p.uv(HARD, 0.09, u=16, v=8, loc=(0, 0, TOP + 0.02), scale=(1, 1, 0.82), color=STEEL)
    for k in range(8):
        a = k * math.tau / 8
        p.uv(HARD, 0.016, u=6, v=3, loc=(0.135 * math.cos(a), 0.135 * math.sin(a), TOP), scale=(1, 1, 0.8), color=STEEL)


def skirt(p):
    upper = [(-0.225, -0.03), (0.225, -0.03), (0.225, 0.09), (0.17, 0.15), (-0.17, 0.15), (-0.225, 0.09)]
    plate(p, upper, 0.45, 0.18, [(-0.11, 0.02), (0.11, 0.02), (0.11, 0.095), (-0.11, 0.095)])
    p.rod(HARD, (-0.222, -0.03, 0.022), (0.222, -0.03, 0.022), 0.013, segs=8, color=STEEL)
    for x in (-0.15, -0.075, 0.0, 0.075, 0.15):
        p.cyl(HARD, 0.016, 0.016, 0.03, segs=8, loc=(x, -0.03, 0.022), rot=ALONG_X, color=STEEL)
    # Three scalloped lip segments fanned 35 degrees off the hinge, out and down.
    lip = [(-0.07, 0), (0.07, 0), (0.07, -0.075), (0.04, -0.105), (-0.04, -0.105), (-0.07, -0.075)]
    for x in (-0.148, 0.0, 0.148):
        m = common.mtx((x, -0.03, 0.022)) @ Matrix.Rotation(-0.61, 4, "X") @ common.mtx((0, -0.012, 0))
        p.prism(FACE, lip, 0.014, matrix=m, color=BONE, side_slot=HARD, side_color=STEEL)


def sight(p):
    plate(p, hexo(0.45, 0.28, 0.08), 0.45, 0.28, corners(0.13, 0.1))
    z = TOP + 0.065
    for x in (-0.085, 0.085):
        p.box(HARD, (0.035, 0.08, 0.04), loc=(x, 0, TOP + 0.02), color=STEEL)
        p.ring(HARD, 0.04, 0.052, 0.035, segs=12, loc=(x, 0, z), rot=ALONG_X, color=STEEL)
    # The sighting tube along the plate, a ring of distance marks, the lens and its cap flipped up.
    p.cyl(FACE, 0.04, 0.04, 0.3, segs=16, loc=(0, 0, z), rot=ALONG_X, color=BONE)
    p.cyl(HARD, 0.05, 0.044, 0.04, segs=16, loc=(0.165, 0, z), rot=ALONG_X, color=STEEL)
    p.cyl(FACE, 0.036, 0.036, 0.004, segs=16, loc=(0.186, 0, z), rot=ALONG_X, color=CHARCOAL)
    p.cyl(HARD, 0.043, 0.043, 0.04, segs=16, loc=(-0.16, 0, z), rot=ALONG_X, color=STEEL)
    for k in range(3):
        p.ring(FACE, 0.039, 0.044, 0.01, segs=12, loc=(-0.04 + k * 0.04, 0, z), rot=ALONG_X, color=CHARCOAL)
    p.box(HARD, (0.016, 0.02, 0.016), loc=(0.19, 0, z + 0.045), color=STEEL)
    p.cyl(HARD, 0.05, 0.05, 0.01, segs=16, loc=(0.192, 0, z + 0.088), rot=ALONG_X, color=STEEL)


def fin(p):
    outline = [(-0.225, -0.06), (-0.15, -0.18), (0.15, -0.18), (0.225, -0.06),
               (0.225, 0.06), (0.12, 0.18), (-0.12, 0.18), (-0.225, 0.06)]
    plate(p, outline, 0.45, 0.36, corners(0.15, 0.12))
    p.box(HARD, (0.05, 0.3, 0.02), loc=(0, -0.01, TOP + 0.01), color=STEEL)
    for y in (-0.11, 0.0, 0.1):
        p.cyl(HARD, 0.009, 0.009, 0.008, segs=6, loc=(0.017, y, TOP + 0.022), color=CHARCOAL)
        p.cyl(HARD, 0.009, 0.009, 0.008, segs=6, loc=(-0.017, y, TOP + 0.022), color=CHARCOAL)
    # The swept fin, rising toward the trailing edge (-Y) like the side view, with three pressed
    # speed lines and the trim tab on its hinge.
    side = Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, TOP + 0.01), (0, 0, 0, 1)))
    p.prism(FACE, [(0.15, 0), (-0.1, 0), (-0.1, 0.195), (-0.075, 0.2)], 0.022, matrix=side, color=BONE,
            side_slot=HARD, side_color=STEEL)
    for k in range(3):
        p.box(FACE, (0.024, 0.085 - k * 0.012, 0.008), loc=(0, -0.035 + k * 0.006, TOP + 0.1 + k * 0.03), color=CHARCOAL)
    p.rod(HARD, (0, -0.1, TOP + 0.03), (0, -0.1, TOP + 0.13), 0.009, segs=6, color=STEEL)
    p.box(HARD, (0.012, 0.045, 0.09), loc=(0, -0.125, TOP + 0.08), color=STEEL)


def drum(p):
    plate(p, hexo(0.45, 0.3, 0.09), 0.45, 0.3, corners(0.12, 0.112))
    z = TOP + 0.085
    p.rod(HARD, (-0.17, 0, z), (0.17, 0, z), 0.012, segs=8, color=STEEL)
    for x in (-0.12, 0.12):
        p.cyl(HARD, 0.085, 0.085, 0.022, segs=16, loc=(x, 0, z), rot=ALONG_X, color=STEEL)
        p.box(HARD, (0.03, 0.06, 0.05), loc=(x * 1.12, 0, TOP + 0.025), color=STEEL)
    p.cyl(HARD, 0.045, 0.045, 0.22, segs=12, loc=(0, 0, z), rot=ALONG_X, color=CHARCOAL)
    for k in range(5):
        p.ring(FACE, 0.044, 0.066, 0.034, segs=8, loc=(-0.084 + k * 0.042, 0, z), rot=ALONG_X, color=ROPE)
    # The ratchet wheel and pawl on the right cheek.
    p.cyl(HARD, 0.04, 0.04, 0.012, segs=12, loc=(0.137, 0, z), rot=ALONG_X, color=STEEL)
    for k in range(8):
        a = k * math.tau / 8
        p.box(HARD, (0.012, 0.016, 0.016), loc=(0.137, 0.045 * math.cos(a), z + 0.045 * math.sin(a)),
              rot=(a, 0, 0), color=STEEL)
    p.box(HARD, (0.012, 0.016, 0.06), loc=(0.15, 0.06, z - 0.02), rot=(0.4, 0, 0), color=CHARCOAL)


def collar(p):
    plate(p, chamfer(0.45, 0.45, 0.1), 0.45, 0.45, corners(0.165, 0.165))
    p.cyl(FACE, 0.09, 0.09, 0.006, segs=20, loc=(0, 0, TOP + 0.003), color=CHARCOAL)
    p.ring(FACE, 0.09, 0.13, 0.025, segs=20, loc=(0, 0, TOP + 0.0125), color=BONE)
    # Sixteen ramp-and-stop teeth: each rises along its ramp and drops at a radial stop face.
    teeth = 16
    for k in range(teeth):
        a0 = k * math.tau / teeth
        a1 = a0 + math.tau / teeth * 0.9
        pts = [(0.128, a0), (0.128, a1), (0.165, a1), (0.165, a1 - 0.08), (0.14, a0 + 0.03)]
        tooth = [(r * math.cos(a), r * math.sin(a)) for r, a in pts]
        p.prism(FACE, tooth, 0.022, matrix=common.mtx((0, 0, TOP + 0.011)), color=BONE, side_slot=HARD, side_color=STEEL)
    p.cyl(HARD, 0.06, 0.06, 0.05, segs=20, loc=(0, 0, TOP + 0.025), color=STEEL)
    p.cyl(HARD, 0.03, 0.03, 0.006, segs=12, loc=(0, 0, TOP + 0.053), color=CHARCOAL)
    # The sprung pawl, engaged at the ring's right side.
    p.box(HARD, (0.07, 0.03, 0.02), loc=(0.175, 0.03, TOP + 0.03), rot=(0, 0, 0.35), color=STEEL)
    p.cyl(HARD, 0.016, 0.016, 0.035, segs=8, loc=(0.2, 0.045, TOP + 0.0175), color=STEEL)
    p.rod(HARD, (0.19, -0.03, TOP + 0.02), (0.15, -0.0, TOP + 0.02), 0.008, segs=6, color=CHARCOAL)


def spool(p):
    plate(p, hexy(0.34, 0.45, 0.08), 0.34, 0.45, corners(0.12, 0.15))
    z = TOP + 0.08
    p.rod(HARD, (0, -0.2, z), (0, 0.2, z), 0.012, segs=8, color=STEEL)
    for y in (-0.19, 0.19):
        p.box(HARD, (0.04, 0.025, 0.09), loc=(0, y, TOP + 0.04), color=STEEL)
    for y in (-0.135, 0.135):
        p.cyl(FACE, 0.07, 0.07, 0.016, segs=20, loc=(0, y, z), rot=ALONG_Y, color=BONE)
    p.cyl(HARD, 0.035, 0.035, 0.26, segs=12, loc=(0, 0, z), rot=ALONG_Y, color=CHARCOAL)
    for k in range(6):
        p.ring(FACE, 0.034, 0.058, 0.035, segs=8, loc=(0, -0.105 + k * 0.042, z), rot=ALONG_Y, color=ROPE)
    # The loose rope end tucked under its clip.
    p.rod(FACE, (0.03, -0.14, z - 0.04), (0.085, -0.17, TOP + 0.01), 0.011, segs=6, color=ROPE)
    p.box(HARD, (0.035, 0.03, 0.012), loc=(0.09, -0.172, TOP + 0.012), color=STEEL)


def tank(p):
    plate(p, hexo(0.45, 0.27, 0.08), 0.45, 0.27, corners(0.145, 0.1))
    z = TOP + 0.085
    # The pressure tank in two strap bands, its gauge on the left end and a pipe stub on the right.
    p.cyl(FACE, 0.072, 0.072, 0.22, segs=16, loc=(0, 0, z), rot=ALONG_X, color=BONE)
    for side in (-1, 1):
        p.cyl(FACE, 0.072, 0.04, 0.035, segs=16, loc=(side * 0.1275, 0, z), rot=(0, side * math.pi / 2, 0), color=BONE)
    for x in (-0.055, 0.055):
        p.ring(HARD, 0.072, 0.08, 0.026, segs=16, loc=(x, 0, z), rot=ALONG_X, color=STEEL)
        p.box(HARD, (0.03, 0.17, 0.014), loc=(x, 0, TOP + 0.007), color=STEEL)
        p.box(HARD, (0.03, 0.02, 0.03), loc=(x, 0.06, TOP + 0.02), color=CHARCOAL)
    p.ring(HARD, 0.045, 0.056, 0.02, segs=16, loc=(-0.15, 0, z), rot=ALONG_X, color=STEEL)
    p.cyl(FACE, 0.046, 0.046, 0.008, segs=16, loc=(-0.148, 0, z), rot=ALONG_X, color=BONE)
    p.box(FACE, (0.004, 0.006, 0.036), loc=(-0.153, -0.01, z - 0.008), rot=(0.7, 0, 0), color=CHARCOAL)
    p.cyl(HARD, 0.026, 0.026, 0.05, segs=12, loc=(0.165, 0, z), rot=ALONG_X, color=STEEL)
    p.ring(HARD, 0.016, 0.032, 0.01, segs=12, loc=(0.19, 0, z), rot=ALONG_X, color=STEEL)


def bumper(p):
    plate(p, chamfer(0.45, 0.32, 0.06), 0.45, 0.32, corners(0.17, 0.11))
    # Two shock struts (bone housing, charcoal sleeve, steel rod) under the rubber-faced bar.
    for x in (-0.11, 0.11):
        p.box(HARD, (0.07, 0.07, 0.008), loc=(x, 0, TOP + 0.004), color=STEEL)
        p.cyl(FACE, 0.03, 0.03, 0.04, segs=12, loc=(x, 0, TOP + 0.024), color=BONE)
        p.cyl(FACE, 0.022, 0.022, 0.035, segs=12, loc=(x, 0, TOP + 0.06), color=CHARCOAL)
        p.cyl(HARD, 0.013, 0.013, 0.05, segs=10, loc=(x, 0, TOP + 0.1), color=STEEL)
    p.box(FACE, (0.37, 0.075, 0.055), loc=(0, 0, TOP + 0.15), color=CHARCOAL)
    p.box(HARD, (0.37, 0.08, 0.01), loc=(0, 0, TOP + 0.12), color=STEEL)


def tile(p):
    # A regular hex armour tile: steel back, bone face, a heavy steel rim standing proud of the
    # face (one hex annulus) and the pressed cross-brace.
    p.prism(HARD, hexo(0.45, 0.39, 0.1125), 0.03, matrix=common.mtx((0, 0, 0.015)), color=STEEL)
    p.prism(FACE, hexo(0.39, 0.338, 0.0975), 0.016, matrix=common.mtx((0, 0, 0.038)), color=BONE)
    p.ring(HARD, 0.19, 0.225, 0.034, segs=6, loc=(0, 0, 0.047), color=STEEL, taper=0.01)
    a, b = 0.15, 0.032
    cross = [(-a, -b), (-b, -b), (-b, -a + 0.02), (b, -a + 0.02), (b, -b), (a, -b),
             (a, b), (b, b), (b, a - 0.02), (-b, a - 0.02), (-b, b), (-a, b)]
    p.prism(FACE, cross, 0.014, matrix=common.mtx((0, 0, 0.053)), color=BONE)
    for x, y in corners(0.085, 0.085):
        p.cyl(HARD, 0.014, 0.014, 0.01, segs=6, loc=(x, y, 0.051), color=CHARCOAL)


def bracket(p):
    plate(p, chamfer(0.45, 0.34, 0.05), 0.45, 0.34, corners(0.19, 0.13))
    z = TOP + 0.055
    # Three cells lying along the plate, ribbed steel caps up, in a wire bracket with its flag.
    for x in (-0.115, 0.0, 0.115):
        p.cyl(FACE, 0.05, 0.05, 0.17, segs=12, loc=(x, -0.02, z), rot=ALONG_Y, color=BONE)
        p.cyl(HARD, 0.053, 0.053, 0.045, segs=16, loc=(x, 0.085, z), rot=ALONG_Y, color=STEEL)
        p.cyl(HARD, 0.03, 0.03, 0.01, segs=12, loc=(x, 0.11, z), rot=ALONG_Y, color=STEEL)
        p.ring(HARD, 0.05, 0.053, 0.01, segs=12, loc=(x, -0.1, z), rot=ALONG_Y, color=STEEL)
    p.rod(HARD, (-0.19, 0.0, z + 0.06), (0.19, 0.0, z + 0.06), 0.008, segs=6, color=STEEL)
    for x in (-0.19, 0.19):
        p.rod(HARD, (x, 0.0, TOP), (x, 0.0, z + 0.06), 0.008, segs=6, color=STEEL)
        p.box(HARD, (0.03, 0.035, 0.03), loc=(x, 0.0, TOP + 0.015), color=STEEL)
    p.box(FACE, (0.03, 0.07, 0.008), loc=(0.2, -0.06, TOP + 0.03), color=BONE)


# silhouette (panels.gd ROWS) -> builder. Recipe order is the GLB names' order.
PLATES = {
    "louvre": louvre, "rivet": rivet, "skirt": skirt, "sight": sight, "fin": fin, "drum": drum,
    "collar": collar, "spool": spool, "tank": tank, "bumper": bumper, "tile": tile, "bracket": bracket,
}


def build(name):
    common.reset()
    common.SLOTS[FACE] = {"vc": True, "rough": 0.72}
    common.SLOTS[HARD] = {"vc": True, "rough": 0.42, "metal": 0.7}
    polish.enable(detail=1, bevel=0.006, bevel_min=0.1, ao_strength=0.35, ao_reach=0.3, edge=0.14)
    root = common.empty("Panel_" + name)
    part = Part("panel_" + name)
    PLATES[name](part)
    bmesh.ops.recalc_face_normals(part.bm, faces=part.bm.faces[:])
    obj = part.to_object(parent=root)
    tris = common.tris(obj)
    top = max(v.co.z for v in obj.data.vertices)
    span = max(max(abs(v.co.x), abs(v.co.y)) for v in obj.data.vertices)
    print("PANEL %s %d T %d V top %.3f m half-span %.3f m" % (name, tris, len(obj.data.vertices), top, span))
    assert tris <= TRIS_CAP, name + " triangle cap"
    assert top <= HEIGHT_CAP + 1e-6, name + " sticks out past the sheets' 0.25 m"
    assert [m.name for m in obj.data.materials] == [HARD, FACE] or [m.name for m in obj.data.materials] == [FACE, HARD]
    return root


def render(root, name, outdir):
    """Cycles CPU stills (the cloud box has no EGL for Eevee): face, three-quarter and edge."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples = 16
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x, scene.render.resolution_y = 420, 320
    world = bpy.data.worlds.new("preview")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = common.rgba("8fa3ad")
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(35), math.radians(15), math.radians(30))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 0.6
    scene.collection.objects.link(cam)
    scene.camera = cam
    os.makedirs(outdir, exist_ok=True)
    paths = []
    for label, loc in (("face", (0, 0, 2)), ("quarter", (1.2, -1.2, 1.2)), ("edge", (0, -2, 0.05))):
        cam.location = loc
        common._look(cam, (0, 0, 0.05))
        path = os.path.join(outdir, "%s_%s.png" % (name, label))
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        paths.append(path)
    return paths


if __name__ == "__main__":
    opts = common.args()
    out = opts["out"] or os.path.join(common.MODELS, "item_panels")
    for name in PLATES:
        root = build(name)
        common.export(root, os.path.join(out, "panel_%s.glb" % name))
        if opts["render"]:
            render(root, name, opts["render"])
