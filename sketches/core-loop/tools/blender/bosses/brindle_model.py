"""Brindle's rigid Fleet fortress and escape scooter, in metres.

blender -b --threads 2 --python-exit-code 1 --python sketches/core-loop/tools/blender/bosses/brindle_model.py
Add -- --render to make CPU previews, or --out-dir PATH for a scratch rebuild.
BUILD-SPEC.md (D4, 2026-10-06) owns dimensions and allocation. Gameplay owns
root transforms, MagnetSocket transforms, cable spans, target tint and visibility.
No collider, target, weapon or root trajectory is exported.
"""
import argparse
import json
import math
from pathlib import Path
import random
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent))
import common
import polish
from common import Part

polish.enable(detail=2, bevel=0.06, bevel_angle=46.0)

ROOT = HERE.parents[4]
MODELS = HERE.parents[2] / "assets/models/bosses"
PREVIEW = ROOT / "artifacts/local/dress-preview/BRI"
STEEL, JOINT, GLASS, SIGNAL = "M0_workshop_steel", "M2_dark_joint", "M3_glass", "M4_signal_surface"
KIT_NAMES = ["CraneMasts", "CranePort", "CraneStarboard", "MagnetSocketPort", "MagnetSocketStarboard",
             "CableSpans", "CablePort", "CableStarboard", "CapSocket0", "CapSocket1", "CapSocket2", "AdmiralSeat"]
CAPS = [(0, 5.4, -4.5), (-2.6, 5.4, .8), (2.6, 5.4, .8)]
PIVOTS = [(-4.5, 7.5, -2), (4.5, 7.5, 2)]


def xyz(p):
    return Vector((p[0], -p[2], p[1]))


def slots():
    common.SLOTS[STEEL] = {"vc": True, "rough": .8, "metal": .18}
    common.SLOTS[JOINT] = {"vc": True, "rough": .85, "metal": .22}
    common.SLOTS[GLASS] = {"color": "ffffff", "alpha": .16, "rough": .12}
    common.SLOTS[SIGNAL] = {"vc": True, "rough": .75}


def box(p, size, at, color="petrol", slot=STEEL):
    return p.box(slot, (size[0], size[2], size[1]), loc=xyz(at), color=color)


def cyl(p, radius, height, at, color="bone", slot=STEEL, segs=12, axial=False):
    return p.cyl(slot, radius, radius, height, segs, loc=xyz(at),
                 rot=(0, math.pi / 2, 0) if axial else (0, 0, 0), color=color)


def beam(p, a, b, width, color="bone", slot=STEEL, height=None):
    p.beam(slot, xyz(a), xyz(b), width, height, color=color)


def rod(p, a, b, radius, color="charcoal", slot=STEEL, segs=8):
    p.rod(slot, xyz(a), xyz(b), radius, segs, color=color)


def node(name, at=(0, 0, 0), parent=None):
    return common.empty(name, xyz(at), parent)


def finish(p, at, parent):
    return p.to_object(xyz(at), parent)


def worn(p):
    """Broad paint loss, seeded by part name; no extra surfaces or texture cost."""
    rng = random.Random("brindle:" + p.name)
    for f in list(p.bm.faces):
        if p.slots[f.material_index] == STEEL and f.calc_area() < .15 and rng.random() < .14:
            p.paint([f], STEEL, common.mix("oxide", "bone", .3))


def bolt(p, at, normal, radius=.065):
    p.bolt(xyz(at), xyz(normal), r=radius, h=.04, segs=6, slot=STEEL)
    p.paint(p._faces(list(p.bm.verts)[-12:]), STEEL, "copper")


def stripe_rectangle(p, width, height, at):
    """Clip diagonal bands to a vertical working face, so the mask never spills."""
    x0, y0, z0 = at
    def clip(poly, axis, value, above):
        out = []
        for a, b in zip(poly, poly[1:] + poly[:1]):
            ia, ib = (a[axis] >= value) == above, (b[axis] >= value) == above
            if ia:
                out.append(a)
            if ia != ib:
                t = (value - a[axis]) / (b[axis] - a[axis])
                out.append(tuple(a[j] + t * (b[j] - a[j]) for j in range(2)))
        return out
    for k in range(-16, 17):
        left = k * .9
        poly = [(left - height, -height / 2), (left + .9 - height, -height / 2),
                (left + .9 + height, height / 2), (left + height, height / 2)]
        poly = clip(clip(poly, 0, -width / 2, True), 0, width / 2, False)
        if len(poly) < 3:
            continue
        verts = [p.bm.verts.new(xyz((x0 + x, y0 + y, z0))) for x, y in poly]
        p.paint([p.bm.faces.new(verts)], SIGNAL, "hazard" if k % 2 else "charcoal")


def striped_disc(p, radius, at, down=False, segs=12):
    centre = xyz(at)
    polygon = [(radius * math.cos(k * math.tau / segs), radius * math.sin(k * math.tau / segs)) for k in range(segs)]
    def clip(poly, edge, keep_greater):
        result = []
        for a, b in zip(poly, poly[1:] + poly[:1]):
            va, vb = a[0] + a[1], b[0] + b[1]
            ia, ib = (va >= edge) == keep_greater, (vb >= edge) == keep_greater
            if ia:
                result.append(a)
            if ia != ib:
                t = (edge - va) / (vb - va)
                result.append((a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1])))
        return result
    for k in range(-6, 7):
        poly = clip(clip(polygon, k * .5, True), (k + 1) * .5, False)
        if len(poly) > 2:
            coords = [centre + Vector((x, y, 0)) for x, y in poly]
            if down:
                coords.reverse()
            p.paint([p.bm.faces.new([p.bm.verts.new(v) for v in coords])], SIGNAL,
                    "hazard" if k % 2 else "charcoal")


def hull(root):
    p = Part("Hull")
    outline = [(-3.5, -7), (3.5, -7), (4.5, -5.8), (4.5, 5.8),
               (3.6, 7), (-3.6, 7), (-4.5, 5.8), (-4.5, -5.8)]
    recessed = [(max(-4.2, min(4.2, x)), max(z, -6.3)) for x, z in outline]
    p.prism(STEEL, [(x, -z) for x, z in reversed(recessed)], 2.5,
            matrix=common.mtx((0, 0, 2.9)), color="petrol")
    p.prism(STEEL, [(x, -z) for x, z in reversed(outline)], .85,
            matrix=common.mtx((0, 0, 4.575)), color="petrol")
    box(p, (5.6, 1.8, 11.2), (0, .9, 0), "charcoal", JOINT)
    for side in (-1, 1):
        for z in (-5.6, -3.5, -1.4, 1.4, 3.5, 5.6):
            beam(p, (side * 4.42, 1.6, z), (side * 4.42, 4.85, z), .15, "copper")
        for z in (-4.8, -1.6, 1.6, 4.8):
            cyl(p, .32, .14, (side * 3.8, .8, z), "copper", axial=True, segs=8)
        for z in (-5.5, -2.3, 1.4, 5.4):
            box(p, (.3, .12, .8), (side * 3.7, 4.94, z), "bone")
        for z in (-5.8, 5.8):
            box(p, (.4, .55, .4), (side * 3.8, 4.4, z), "charcoal", JOINT)
            box(p, (.31, .33, .045), (side * 3.8, 4.4, z - .22), "ffffff")
        beam(p, (side * 4.0, 4.93, -5.5), (side * 4.0, 4.93, 5.7), .1, "bone")
        for z in (-5.5, 0, 5.7):
            beam(p, (side * 4., 4.5, z), (side * 4., 4.98, z), .1, "bone")
    body = finish(p, (0, 2.5, 0), root)
    p = Part("CraneMasts")
    for x, y, z in PIVOTS:
        box(p, (.8, 3, .8), (x, y - 1.5, z), "petrol")
        beam(p, (x, 5.1, z), (x, 7.35, z), .17, "copper")
    finish(p, (0, 5, 0), root)
    p = Part("DeckDressing")
    for x, y, z in CAPS:
        cyl(p, .8, .4, (x, 4.85, z), "charcoal", JOINT)
    for x in (-1.9, 1.9):
        cyl(p, .18, 1.4, (x, 5.4, 5.8), "copper", segs=8)
        cyl(p, .23, .15, (x, 6.04, 5.8), "charcoal", JOINT, 8)
    for z in (2, 2.3, 2.6, 2.9, 3.2):
        box(p, (2, .045, .11), (0, 5, z), "charcoal", JOINT)
    for x in (-3, 3):
        for z in (-5.9, -5.65, -5.4, 5.4, 5.65, 5.9):
            box(p, (.24, .04, .12), (x, 5, z), "copper")
    worn(p)
    finish(p, (0, 5, 0), root)
    return body


def drums(parent):
    def keep(segs):
        return max(2, segs // common.DETAIL)
    for side, letter in ((-1, "L"), (1, "R")):
        for k, z in enumerate((-4.8, -1.6, 1.6, 4.8)):
            at = (side * 4.05, .8, z)
            p = Part("Drum%s%d" % (letter, k))
            cyl(p, .75, .8, at, "charcoal", JOINT, keep(16), True)
            cyl(p, .57, .04, (side * 4.43, .8, z), common.mix("charcoal", "bone", .25), JOINT, keep(12), True)
            cyl(p, .22, .045, (side * 4.4275, .8, z), "copper", JOINT, keep(8), True)
            for j in range(8):
                a = j * math.tau / 8
                rod(p, (side * 3.68, .8 + .69 * math.cos(a), z + .69 * math.sin(a)),
                    (side * 4.42, .8 + .69 * math.cos(a), z + .69 * math.sin(a)), .05,
                    common.mix("charcoal", "bone", .12), JOINT, keep(4))
            finish(p, at, parent)


def armour(parent):
    """Fleet plating bolted over the hull (SIGHT-PERSONA: Fleet paint, charcoal bands, one
    brass tag riveted on). Gameplay overrides surface 0 (the STEEL slab) with the slate or
    amber plating tint, so everything that must survive that tint, the bands, rivets, tag
    and scuffs, is built on the JOINT surface, which keeps its own colours."""
    rivet = common.mix("charcoal", "bone", .45)
    for k, (side, z) in enumerate(((-1, -3.5), (-1, 3.5), (1, -3.5), (1, 3.5))):
        p = Part("Armour%d" % k)
        face = side * 4.76
        box(p, (.26, 3.2, 6), (side * 4.63, 2.8, z), "bone")
        box(p, (.07, 1.9, 4.9), (face + side * .03, 2.8, z), "bone")
        for y in (1.48, 4.12):
            box(p, (.09, .36, 6), (face + side * .04, y, z), "charcoal", JOINT)
        with p.region(bevel=0, detail=1):
            for y in (1.48, 4.12):
                for j in range(8):
                    dz = -2.62 + j * 5.24 / 7
                    rod(p, (face + side * .07, y, z + dz), (face + side * .14, y, z + dz), .055,
                        rivet, JOINT, 4)
            tag_z = z + (1.9 if z < 0 else -1.9)
            box(p, (.03, .5, .78), (face + side * .085, 3.4, tag_z), "brass", JOINT)
            for dz in (-.29, .29):
                rod(p, (face + side * .095, 3.4, tag_z + dz), (face + side * .125, 3.4, tag_z + dz), .04,
                    "charcoal", JOINT, 4)
            rng = random.Random("brindle:scuffs%d" % k)
            for y, dz, width, height in ((1.95, -1.7, 1.1, .16), (2.2, .6, 1.4, .12), (3.1, -.2, .7, .1)):
                dz += rng.uniform(-.3, .3)
                x_face = face + side * .068
                polygon = [(x_face, y, z + dz), (x_face, y + height, z + dz + width * .2),
                           (x_face, y + height * .5, z + dz + width), (x_face, y - height * .3, z + dz + width * .6)]
                vertices = [p.bm.verts.new(xyz(v)) for v in (polygon if side == 1 else list(reversed(polygon)))]
                p.paint([p.bm.faces.new(vertices)], JOINT, common.mix("bone", "charcoal", .4))
        finish(p, (side * 4.5, 2.8, z), parent)


def cockpit(root):
    p = Part("CockpitShield")
    rings = []
    for height, radius in ((5, 1.5), (6.1, 1.5), (6.85, 1.05), (7.2, .28)):
        rings.append([p.bm.verts.new(xyz((radius * math.cos(k * math.tau / 12), height,
                                         4.8 + radius * math.sin(k * math.tau / 12)))) for k in range(12)])
    for j in range(3):
        for k in range(12):
            f = p.bm.faces.new((rings[j][k], rings[j][(k + 1) % 12], rings[j + 1][(k + 1) % 12], rings[j + 1][k]))
            p.paint([f], STEEL if j == 0 else GLASS, "petrol" if j == 0 else None)
    p.paint([p.bm.faces.new(rings[-1])], GLASS)
    p.ring(STEEL, 1.35, 1.5, .15, 12, loc=xyz((0, 5.12, 4.8)), color="bone")
    for side in (-1, 1):
        beam(p, (side * 1.3, 5.1, 5.3), (side * .65, 6.96, 5.5), .09, "copper")
    finish(p, (0, 5, 6.3), root)


def pilot(p, centre):
    """One continuous low-poly seated badger surface, with integrated snout/ears."""
    x, y, z = centre
    rows = []
    for h, w, d in ((-.48, .38, .35), (-.3, .52, .38), (-.05, .43, .30),
                     (.04, .29, .23), (.18, .35, .28), (.36, .30, .27), (.46, .40, .32), (.5, .28, .23)):
        row = []
        for k in range(10):
            a = k * math.tau / 10
            xx, zz = w * math.cos(a), d * math.sin(a)
            hh = h
            if h == .36 and k in (1, 4):
                hh += .11
            if h == .18 and k in (6, 7, 8):
                zz -= .12
            row.append(p.bm.verts.new(xyz((x + xx, y + hh, z + zz))))
        rows.append(row)
    for j in range(len(rows) - 1):
        for k in range(10):
            f = p.bm.faces.new((rows[j][k], rows[j][(k + 1) % 10], rows[j + 1][(k + 1) % 10], rows[j + 1][k]))
            color = "petrol" if j < 3 else ("bone" if k in (6, 9) else "charcoal")
            if j >= 5:
                color = "bone"
            p.paint([f], STEEL, color)
    p.paint([p.bm.faces.new(list(reversed(rows[0])))], STEEL, "petrol")
    p.paint([p.bm.faces.new(rows[-1])], STEEL, "bone")
    box(p, (.20, .09, .08), (x, y + .17, z - .4), "charcoal")
    for side in (-1, 1):
        box(p, (.055, .055, .03), (x + side * .19, y + .27, z - .255), "charcoal")
        beam(p, (x + side * .45, y - .14, z), (x + side * .44, y - .31, z - .35), .14, "oxide")
    box(p, (.16, .05, .035), (x, y + .43, z - .3), "copper")


def cranes(root):
    cables = Part("CableSpans")
    for i, (side, tag) in enumerate(((-1, "Port"), (1, "Starboard"))):
        pivot = PIVOTS[i]
        node("CranePivot" + tag, pivot, root)
        crane = node("Crane" + tag, pivot, root)
        p = Part("CraneElbow" + tag)
        x, y, z = pivot
        reach = 2.0 if i == 0 else 1.8
        a, b, c = pivot, (x + side * reach, y + 1.5, z), (side * 6, 6.8, z)
        beam(p, a, b, .58, "bone", height=.7)
        beam(p, b, c, .42, "petrol", height=.52)
        rod(p, (x, y - .18, z), (b[0], b[1] - .25, z), .09, "copper")
        cyl(p, .32, .66, a, "charcoal", STEEL, 10, True)
        cyl(p, .3, .56, b, "copper", STEEL, 10, True)
        worn(p)
        finish(p, pivot, crane)
        at = (side * 6, 3.5, z)
        socket = node("MagnetSocket" + tag, at, root)
        p = Part("Magnet" + tag)
        faces = cyl(p, 1.4, .9, at, "bone", STEEL, 12)
        bottom = [f for f in faces if len(f.verts) == 12 and f.calc_center_median().z < at[1]]
        bmesh.ops.delete(p.bm, geom=bottom, context="FACES_ONLY")
        cyl(p, .6, .12, (at[0], at[1] + .39, z), "petrol", STEEL, 8)
        striped_disc(p, 1.4, (at[0], at[1] - .45, z), True)
        worn(p)
        finish(p, at, socket)
        node("Cable" + tag, tuple((pivot[j] + at[j]) / 2 for j in range(3)), root)
        beam(cables, pivot, (at[0], at[1] + .45, z), .25, "charcoal", JOINT)
    finish(cables, (0, 0, 0), root)
    for k, at in enumerate(CAPS):
        socket = node("CapSocket%d" % k, at, root)
        p = Part("Cap%d" % k)
        p.bevel = 0
        p.cyl(STEEL, 1.1, .95, .8, 12, loc=xyz(at), color="bone")
        striped_disc(p, 1.05, (at[0], at[1] - .401, at[2]), True)
        worn(p)
        finish(p, at, socket)


def furnace(root, parent):
    p = Part("SlagThroat")
    p.ring(STEEL, .65, .9, .25, 12, loc=xyz((0, 5, -2)), color="copper")
    cyl(p, .64, .05, (0, 4.91, -2), "charcoal", JOINT, 12)
    striped_disc(p, .64, (0, 4.94, -2))
    finish(p, (0, 4.85, -2), root)
    for side, tag in ((-1, "L"), (1, "R")):
        p = Part("Hatch" + tag)
        box(p, (.16, 1.8, 2.2), (side * 4.4, 3.5, 0), "petrol")
        box(p, (.18, 1.4, 1.8), (side * 4.4, 3.5, 0), "charcoal", JOINT)
        box(p, (.2, 1.25, 1.65), (side * 4.4, 3.5, 0), "bone")
        worn(p)
        finish(p, (side * 4.4, 2.6, 0), parent)
        node("DroneSocket" + tag, (side * 9, 0, 0), root)


def build_ship():
    root = node("BrindleRoot")
    h = hull(root)
    drums(h)
    armour(h)
    p = Part("BowRam")
    box(p, (9, 3.2, .35), (0, 2.5, -6.625), "bone")
    stripe_rectangle(p, 7.6, .8, (0, 1.6, -6.801))
    for x in (-4.35, 4.35):
        for y in (1.0, 4.0):
            bolt(p, (x, y, -6.76), (0, 0, -1))
    worn(p)
    finish(p, (0, 2.5, -6.8), h)
    cockpit(root)
    seat = node("AdmiralSeat", (0, 6, 4.8), root)
    launch = node("ScooterSeat", (0, 6, 4.8), seat)
    p = Part("Admiral")
    p.bevel, p.subsurf = 0, 1
    pilot(p, (0, 6, 4.8))
    box(p, (1.2, .13, 1), (0, 5.565, 4.8), "petrol")
    finish(p, (0, 6, 4.8), launch)
    node("EjectSocket", (0, 6.5, 4.8), root)
    cranes(root)
    furnace(root, h)
    return root


def build_scooter():
    root = node("ScooterRoot")
    seat = node("ScooterSeat", (0, 0, .25), root)
    p = Part("ScooterBody")
    box(p, (1.6, .45, 2.3), (0, -.18, 0), "petrol")
    box(p, (2, .25, .45), (0, -.15, -1.175), "bone")
    box(p, (1.4, .18, .4), (0, -.18, 1.2), "bone")
    box(p, (1.5, .1, 1.1), (0, -.4, .2), "charcoal")
    pilot(p, (0, 0, .25))
    for side in (-1, 1):
        beam(p, (side * .45, -.22, -.38), (side * .45, .12, -.38), .055, "copper")
    box(p, (1.0, .12, .25), (0, .02, -.48), "bone")
    box(p, (1.2, .32, .04), (0, .12, -.52), color=None, slot=GLASS)
    worn(p)
    finish(p, (0, 0, .25), seat)
    p = Part("Drums")
    for side in (-1, 1):
        cyl(p, .22, .24, (side * .84, -.28, 0), "charcoal", JOINT, max(2, 12 // common.DETAIL), True)
        cyl(p, .13, .02, (side * .965, -.28, 0), "copper", JOINT, max(2, 8 // common.DETAIL), True)
    finish(p, (0, -.28, 0), root)
    return root


def export(root, path):
    bpy.context.view_layer.update()
    if common.POLISH is not None:
        polish.bake(root, common.POLISH)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in common.tree(root):
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
        export_yup=True, export_materials="EXPORT", export_vertex_color="ACTIVE",
        export_animations=True, export_animation_mode="NLA_TRACKS", export_anim_slide_to_zero=True,
        export_optimize_animation_keep_anim_object=True,
        export_force_sampling=True, export_frame_range=False, export_skins=False,
        export_cameras=False, export_lights=False, export_extras=False)
    common.canonical_indices(str(path), vertices=common.POLISH is not None)
    print("EXPORTED", path)


def measure(path):
    import struct
    data = path.read_bytes()
    gltf = json.loads(data[20:20 + struct.unpack_from("<I", data, 12)[0]])
    counts = {"body": [0, 0, 0], "kit": [0, 0, 0]}
    def visit(index, kit=False):
        n = gltf["nodes"][index]
        kit = kit or n["name"] in KIT_NAMES or path.stem.endswith("scooter")
        if "mesh" in n:
            for p in gltf["meshes"][n["mesh"]]["primitives"]:
                row = counts["kit" if kit else "body"]
                row[0] += gltf["accessors"][p["indices"]]["count"] // 3
                row[1] += gltf["accessors"][p["attributes"]["POSITION"]]["count"]
                row[2] += 1
        for child in n.get("children", []):
            visit(child, kit)
    for index in gltf["scenes"][gltf.get("scene", 0)]["nodes"]:
        visit(index)
    print("BUDGET", path.name, counts)
    return counts


def main():
    args = argparse.ArgumentParser()
    args.add_argument("--out-dir", type=Path, default=MODELS)
    args.add_argument("--render", action="store_true")
    a = args.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    common.reset()
    slots()
    ship = build_ship()
    # Names are file-global in Blender. Export each scene separately, keeping exact
    # ScooterSeat in both files and never Blender's .001 suffix.
    import brindle_animation as anim
    anim.author_ship(ship)
    export(ship, a.out_dir / "boss_brindle.glb")
    budget = measure(a.out_dir / "boss_brindle.glb")
    common.reset()
    slots()
    scooter = build_scooter()
    anim.author_scooter(scooter)
    export(scooter, a.out_dir / "boss_brindle_scooter.glb")
    scooter_budget = measure(a.out_dir / "boss_brindle_scooter.glb")
    combined = [budget["kit"][i] + scooter_budget["kit"][i] for i in range(3)]
    assert all(n <= cap for n, cap in zip(budget["body"], (14500, 11500, 32))), budget
    assert all(n <= cap for n, cap in zip(combined, (5000, 5000, 18))), combined
    print("BRI budget: PASS body=%s combined_kit=%s" % (budget["body"], combined))
    if a.render:
        import brindle_preview
        brindle_preview.preview_files(a.out_dir)


if __name__ == "__main__":
    main()
