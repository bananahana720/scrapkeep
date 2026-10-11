# PD-KEST: Kest's ball as a Hoberman mecha on shell_base.hoberman() (ROSTER-LOOK section 0,
# pilots/kest.md section 5). Concept: artifacts/local/alpha/push/w13/concepts/codex/kest/hero.png,
# chase.png and sheet.png with base/base-hero.png and mechanism.png (approved as one set,
# docs/decisions.tsv w13-look rows of 2026-10-10). Where chase.png puts the launchers on the
# near arc it is a picture error; they sit on the front arc at 11 and 1 o'clock as hero.png shows.
#
#   prlimit --as=12884901888 -- blender --background --threads 2 --python-exit-code 1 \
#     --python world_one/shell_kest.py -- [--out <file.glb>] [--variant roost]
#
# Default writes assets/models/world_one/shell_kest.glb; --variant roost writes
# shell_kest_roost.glb, the Roost Frame (CUSTOMIZE section 8): one X-pair per link, a wide
# open frame like a roost's perch rails, with the same machinery, sockets and sight cone.
# The heft layers come from world_one/shell_kest_plates.py.
#
# Kest's parts and where they ride (ROSTER-LOOK sections 2 and 4):
#   WeaponRing  two short launcher tubes in recoil cradles at 11 and 1 o'clock, parallel and
#               pointing forward, an amber fuse tip in each mouth (class_accent, the only glow);
#               three canvas satchels strapped flat at 3, 6 and 9 o'clock, each with a horizontal
#               band; Mortar marks the cradle pair, MortarMouth.L/R the mouths. All of it folds
#               into the ring mesh (paint, rubber, class_accent), so the ring is three draws.
#   Pod         the petrol seat (the sheet's "Perch"), FusePlunger (slot 2) and ChargeKey
#               (slot 3) in the bank, the lap bar, two pedals; a gap bracket from each gimbal
#               boss to a vent hinge (rubber).
#   VaneL/R     the slotted vents, hinged at the side gaps (shell_kest_plates.vane_part).
#   Dome>Pilot  a static head placeholder, hidden in play by fit_pilot_into; hero_assets_test
#               reads it, and the animated pilot is pilot_kest_anim.glb.
# Draws: Core 3, Pod 3, Gyro 1, GyroInner 1, WeaponRing 3, VaneL 1, VaneR 1, Pilot 1 = 14. The
# base alone spends 10 (shell_base.hoberman header), so the shell keeps a registry exception.

import json
import math
import os
import struct
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh  # noqa: E402
import bpy  # noqa: E402
import common  # noqa: E402
import shell_base as sb  # noqa: E402
import shell_kest_plates as kp  # noqa: E402
from common import Part, Vector  # noqa: E402

# hero_assets_test SHELL_TRIS: the shell without its pilot, 3,000 to 6,500 (the 6,600 target).
SHELL_BAND = (3000, 6500)
REACH = 1.25                      # ROSTER-LOOK section 3 rule 6
TUBE_CLOCK = 28.0                 # 11 and 1 o'clock on the front arc
TUBE_R = 0.05
TUBE_Z = 0.03
TUBE_Y = (0.86, 1.09)
SATCHEL_CLOCKS = (90.0, 180.0, 270.0)
BANK = (("FusePlunger", "plunger"), ("ChargeKey", "key"))


def flag(name):
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if name not in argv:
        return None
    i = argv.index(name)
    return argv[i + 1] if i + 1 < len(argv) else True


def tube_x(side):
    return side * 1.10 * math.sin(math.radians(TUBE_CLOCK))


def ring_kit():
    """Kest's weapon ring parts in ring space (the ring sits at the Pod origin)."""
    r = Part("RingKit")
    for side in (-1, 1):
        x = tube_x(side)
        a, b = Vector((x, TUBE_Y[0], TUBE_Z)), Vector((x, TUBE_Y[1], TUBE_Z))
        r.rod("rubber", a, b, TUBE_R, 6, r2=TUBE_R + 0.008)
        # The recoil cradle: a charcoal saddle straddling the band under an oxide slide.
        r.box("rubber", (0.13, 0.05, 0.08), loc=(x, 0.95, TUBE_Z - 0.03))
        r.box("paint", (0.09, 0.13, 0.025), loc=(x, 0.975, TUBE_Z - 0.062), color="oxide")
        # The fuse tip of the loaded charge, amber in the mouth.
        sb._disc(r, (x, TUBE_Y[1] + 0.002, TUBE_Z), (0, 1, 0), 0.034, 6, "class_accent")
    for clock in SATCHEL_CLOCKS:
        kp.satchel(r, clock)
    return r


def strip_neutral_mount(ring):
    """Removes the neutral weapon seat (the mount block and rod at 12 o'clock) from the ring."""
    bm = bmesh.new()
    bm.from_mesh(ring.data)
    bm.verts.ensure_lookup_table()
    seen, doomed = set(), []
    for v in bm.verts:
        if v in seen:
            continue
        island, stack = [], [v]
        seen.add(v)
        while stack:
            u = stack.pop()
            island.append(u)
            for e in u.link_edges:
                w = e.other_vert(u)
                if w not in seen:
                    seen.add(w)
                    stack.append(w)
        if all(u.co.y > 1.07 and abs(u.co.x) < 0.08 for u in island):
            doomed += island
    bmesh.ops.delete(bm, geom=doomed, context="VERTS")
    bm.to_mesh(ring.data)
    bm.free()
    return len(doomed)


def merge_into(target, part):
    """Folds a Part into an existing mesh object (both at the shell origin), mapping slots onto
    the target's materials so no new surface appears for a slot it already has."""
    extra = part.to_object((0, 0, 0), None)
    mats = target.data.materials
    remap = {}
    for i, m in enumerate(extra.data.materials):
        names = [t.name for t in mats]
        if m.name not in names:
            mats.append(m)
            names.append(m.name)
        remap[i] = names.index(m.name)
    for poly in extra.data.polygons:
        poly.material_index = remap[poly.material_index]
    bm = bmesh.new()
    bm.from_mesh(target.data)
    bm.from_mesh(extra.data)
    bm.to_mesh(target.data)
    bm.free()
    mesh = extra.data
    bpy.data.objects.remove(extra)
    bpy.data.meshes.remove(mesh)


def brackets():
    """Gap brackets: a slim arm from each outer gimbal boss to its vent hinge."""
    p = Part("Brackets")
    for side in (-1, 1):
        h = kp.vane_hinge(side)
        p.beam("rubber", (side * 0.89, 0.0, 0.0), h, 0.04)
    return p


def pilot():
    """Static head placeholder, the C09 Kest head at lower resolution moved onto the Hoberman seat
    (head centre at shell_base.HEAD), smooth so it shares vertices; hidden in play under the
    animated pilot, kept because hero_assets_test reads a Pod > Dome > Pilot mesh."""
    f = Part("Pilot")
    crest = common.mix("oxide", "amber", 0.2)
    beak = common.mix("amber", "sandstone", 0.35)
    f.uv("pilot", 0.21, 16, 10, loc=(0, 0.2, 1.09), scale=(1.02, 0.88, 1.0), color="bone")
    for side in (-1, 1):
        f.uv("pilot", 0.08, 8, 6, loc=(side * 0.115, 0.302, 1.085), scale=(0.85, 0.40, 1.15), color="charcoal")
        f.ring("pilot", 0.044, 0.063, 0.03, 10, loc=(side * 0.088, 0.35, 1.155), rot=(math.pi / 2, 0, 0), color="copper")
        sb.eye(f, (side * 0.088, 0.374, 1.155), 0.040)
    f.uv("pilot", 0.08, 10, 6, loc=(0, 0.357, 1.035), scale=(0.8, 1.2, 0.6), color=beak)
    f.rod("pilot", (0, 0.39, 1.043), (0, 0.475, 0.99), 0.045, 8, color=beak, r2=0.006)
    for k in range(3):
        f.uv("pilot", 0.07, 8, 6, loc=(0, 0.16 - k * 0.05, 1.3 + k * 0.015), scale=(0.42, 0.65, 1.75),
             rot=(0.35 + k * 0.2, 0, 0), color=crest)
    shift = sb.HEAD - Vector((0, 0.2, 1.09))
    bmesh.ops.translate(f.bm, vec=shift, verts=f.bm.verts)
    for face in f.bm.faces:
        face.smooth = True
    return f


def stable_pilot_normals(path):
    """Two exports differed by 0.00009 in a static pilot smooth normal (C09).
    Round components to 0.001 and normalize; geometry stays intact."""
    with open(path, "rb") as f:
        data = bytearray(f.read())
    json_len = struct.unpack_from("<I", data, 12)[0]
    gltf = json.loads(data[20:20 + json_len])
    bin_start = 28 + json_len
    for mesh in gltf["meshes"]:
        if mesh["name"] != "Pilot":
            continue
        for primitive in mesh["primitives"]:
            accessor = gltf["accessors"][primitive["attributes"]["NORMAL"]]
            view = gltf["bufferViews"][accessor["bufferView"]]
            assert accessor["componentType"] == 5126 and accessor["type"] == "VEC3"
            start = bin_start + view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
            stride = view.get("byteStride", 12)
            for i in range(accessor["count"]):
                offset = start + i * stride
                normal = struct.unpack_from("<3f", data, offset)
                rounded = tuple(round(x, 3) or 0.0 for x in normal)
                length = math.sqrt(math.fsum(x * x for x in rounded))
                struct.pack_into("<3f", data, offset, *(x / length for x in rounded))
    with open(path, "wb") as f:
        f.write(data)
    common.canonical_indices(path)
    print("STABLE_NORMALS Kest static Pilot, component precision 0.001")


def world_verts(obj):
    mw = obj.matrix_world
    return [mw @ v.co for v in obj.data.vertices]


def vane_report(pod, ring, vanes):
    """Folded and open reach of each vent past the lattice, the open sight cone, and the
    clearance above the weapon band. Returns True when every check holds."""
    ok = True
    bpy.context.view_layer.update()
    folded = {v.name: max(p.length for p in world_verts(v)) for v in vanes}
    for v, side in zip(vanes, (-1, 1)):
        v.rotation_euler = (0.0, side * math.pi / 2, 0.0)
    bpy.context.view_layer.update()
    opened = {v.name: max(p.length for p in world_verts(v)) for v in vanes}
    band_top = sb.RING_BAND[2] / 2 + sb.RING_BAND[3]
    low = min(p.z for v in vanes for p in world_verts(v) if p.length > sb.RING_BAND[0] - 0.05)
    cone_open = sb.sight_cone_hits(pod)
    for v in vanes:
        v.rotation_euler = (0.0, 0.0, 0.0)
    bpy.context.view_layer.update()
    for name in folded:
        f_past, o_past = folded[name] - sb.LATTICE_OUTER, opened[name] - sb.LATTICE_OUTER
        good = abs(f_past - 0.10) <= 0.03 and abs(o_past - 0.25) <= 0.03 and opened[name] <= REACH
        ok = ok and good
        print("VANE %s folded %.3f m past the lattice, open %.3f m past (radius %.3f) %s"
              % (name, f_past, o_past, opened[name], "ok" if good else "OUT"))
    tip = max(world_verts(vanes[1]), key=lambda p: p.length)
    clock = math.degrees(math.atan2(tip.x, tip.z))
    print("VANE_CLOCK folded tip at %.0f degrees from the top (2 o'clock is 60) %s"
          % (clock, "ok" if 45 <= clock <= 75 else "OUT"))
    print("VANE_OPEN sight cone %d Pod vertices, lowest open vane point past r %.2f at Z %.3f (band top %.2f) %s"
          % (cone_open, sb.RING_BAND[0] - 0.05, low, band_top, "ok" if cone_open == 0 and low > band_top + 0.05 else "OUT"))
    return ok and 45 <= clock <= 75 and cone_open == 0 and low > band_top + 0.05


def draws(root):
    return sum(len({p.material_index for p in o.data.polygons}) for o in common.tree(root) if o.type == "MESH")


def main():
    common.reset()
    common.preview_class("amber")
    roost = flag("--variant") == "roost"
    name = "KestRoost" if roost else "Kest"
    shell = sb.hoberman(name, enamel="petrol", seat="petrol", pairs=1 if roost else 2, bank=BANK,
                        pilot=pilot(), hub_sides=8 if roost else 6, cap_sides=8)
    pod, ring = shell["pod"], shell["ring"]
    print("STRIP neutral weapon seat %d vertices" % strip_neutral_mount(ring))
    merge_into(ring, ring_kit())
    merge_into(pod, brackets())
    mortar = common.empty("Mortar", (0, (TUBE_Y[0] + TUBE_Y[1]) / 2, TUBE_Z), ring)
    for side, tag in ((-1, "L"), (1, "R")):
        common.empty("MortarMouth." + tag, (tube_x(side), TUBE_Y[1], TUBE_Z), mortar)
    vanes = [kp.vane_part(vname, side).to_object(kp.vane_hinge(side), pod)
             for vname, side in (("VaneL", -1), ("VaneR", 1))]
    root = shell["root"]
    reach = max(p.length for o in common.tree(pod) if o.type == "MESH" and o.name != "Pilot" for p in world_verts(o))
    n_draws = draws(root)
    print("REACH Kest Pod subtree %.3f m, limit %.2f %s" % (reach, REACH, "ok" if reach <= REACH else "OUT"))
    print("DRAWS %s %d surfaces (Core 3, Pod 3, Gyro 1, GyroInner 1, WeaponRing 3, VaneL 1, VaneR 1, Pilot 1)"
          % (name, n_draws))
    vane_ok = vane_report(pod, ring, vanes)
    out = common.args()["out"] or os.path.join(common.MODELS, "world_one",
                                               "shell_kest_roost.glb" if roost else "shell_kest.glb")
    band = (3000, 11000) if roost else SHELL_BAND
    sb.finish(name, root, shell["core"], shell["pilot"], shell_band=band, pod_obj=pod, out=out)
    stable_pilot_normals(out)
    if reach > REACH or not vane_ok or n_draws != 14:
        raise SystemExit("Kest machinery checks failed")


main()
