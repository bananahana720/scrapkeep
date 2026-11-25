"""Patch (hidden 7th pilot, line_splicer) — possum hacker pilot, cutaway-first heroic shell,
and paw-print husk overlay (design-v3/pilots/patch.md, rulings dl & en).

Three closed, watertight graphic-novel GLBs:
  1. assets/models/pilot_patch_anim.glb          - Chunky soft-toy possum hacker seated/hanging in cockpit
                                                   with 2010 stickered netbook, USB lanyard, oversized visor,
                                                   pointed snout, round dark-rimmed ears & curled prehensile tail.
  2. assets/models/world_one/shell_patch.glb     - Cutaway-first heroic Hoberman shell (Core, Pod, Dome, WeaponRing)
                                                   carrying the wok-cut satellite signal dish, spliced patch-cable
                                                   spool, and twin heroic side cable-splicer pods (reach <= 1.72 m,
                                                   Y > -0.55 m clearance, <= 6500 tris, <= 10 draws).
  3. assets/models/world_one/patch_husk_sticker.glb - Paw-print sticker badge + dangling cut command cable +
                                                      punch-card timer overlay for Patch's raised hands.

Colour discipline (pilots/patch.md §4):
  Patch's test-card pink (#f29ec4, CVD-safe & distinct from HAZARD #ff5a3c and KINDNESS #d936b0)
  with cold white (#e8f0f2) fallback accent, charcoal, bone, copper & verdigris Keeper hardware.

Run headless:
  blender -b --factory-startup --python-exit-code 1 -P pilot_patch.py [-- --out DIR]
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..")))

import common  # noqa: E402
import palette_gd  # noqa: E402
import polish  # noqa: E402
from common import Part  # noqa: E402

BONE = palette_gd.HEX["SAND"]
COPPER = palette_gd.HEX["COPPER"]
CHARCOAL = palette_gd.HEX["CHARCOAL"]
VERDIGRIS = palette_gd.HEX["VERDIGRIS"]
STEEL = palette_gd.HEX["STEEL"]
BRASS = palette_gd.HEX["BRASS"]
LEDGER_CREAM = palette_gd.HEX["LEDGER_CREAM"]

# Possum soft-toy fur & Patch's test-card pink / cold-white accent (distinct from HAZARD & KINDNESS).
POSSUM_FUR = "7e8488"
POSSUM_FACE = "e8e4da"
POSSUM_EAR = "2b2d30"
PATCH_PINK = "f29ec4"
COLD_WHITE = "e8f0f2"

ALONG_X = (0.0, math.pi / 2.0, 0.0)
ALONG_Y = (math.pi / 2.0, 0.0, 0.0)


def _setup_slots():
    common.SLOTS["pilot"] = {"vc": True, "rough": 0.88, "metal": 0.0}
    common.SLOTS["paint"] = {"vc": True, "rough": 0.76, "metal": 0.0}
    common.SLOTS["hydraulic"] = {"vc": True, "rough": 0.36, "metal": 0.54}
    common.SLOTS["class_accent"] = {"color": PATCH_PINK, "emit": 0.65, "rough": 0.42}
    common.SLOTS["bare_metal"] = {"color": BONE, "lighten": 0.25, "metal": 0.6, "rough": 0.45}
    common.SLOTS["rubber"] = {"color": CHARCOAL, "rough": 0.95}
    common.SLOTS["copper"] = {"color": COPPER, "metal": 0.6, "rough": 0.4}


def build_pilot_patch(out_path):
    """Chunky soft-toy possum hacker in cockpit space (+Z up, +Y forward -> Godot +Y up, -Z forward)."""
    common.reset()
    _setup_slots()
    polish.enable(detail=1, bevel=0.0, ao_strength=0.28, ao_reach=0.22, edge=0.04)
    root = common.empty("PilotPatch")
    p = Part("Pilot")

    # Plump seated possum torso wearing a patched charcoal/verdigris Keeper vest.
    p.uv("pilot", 0.24, u=12, v=8, loc=(0.0, -0.02, -0.08), scale=(1.05, 0.92, 1.18), color=POSSUM_FUR)
    p.uv("pilot", 0.22, u=10, v=6, loc=(0.0, 0.03, -0.06), scale=(0.95, 0.85, 0.95), color=VERDIGRIS)
    # Stick-on USB drive lanyard draped across chest (3 colorful 2010 USB sticks!).
    for sx, col in ((-0.09, PATCH_PINK), (0.0, COLD_WHITE), (0.09, COPPER)):
        p.box("hydraulic", (0.045, 0.035, 0.095), loc=(sx, 0.21, -0.04),
              rot=(math.radians(-16.0), 0.0, sx * 2.0), color=col)

    # Oversized graphic-novel possum head with pale cheek mask, pointed pink-tipped snout & round dark ears.
    p.uv("pilot", 0.22, u=14, v=10, loc=(0.0, 0.02, 0.22), scale=(1.08, 1.04, 0.96), color=POSSUM_FACE)
    # Dark crown ruff sweeping back over head.
    p.uv("pilot", 0.19, u=10, v=8, loc=(0.0, -0.04, 0.26), scale=(1.02, 1.0, 0.88), color=POSSUM_FUR)
    # Pointed possum snout projecting forward along +Y with bright pink button nose!
    p.cyl("pilot", 0.115, 0.042, 0.20, segs=10, loc=(0.0, 0.21, 0.18),
          rot=(math.radians(-82.0), 0.0, 0.0), color=POSSUM_FACE)
    p.uv("pilot", 0.046, u=8, v=6, loc=(0.0, 0.31, 0.17), scale=(1.1, 0.9, 0.85), color=PATCH_PINK)

    # Big expressive round dark-rimmed possum ears with pink inner cups.
    for sx in (-1.0, 1.0):
        p.cyl("pilot", 0.105, 0.105, 0.040, segs=12, loc=(sx * 0.18, -0.01, 0.38),
              rot=(math.radians(78.0), sx * math.radians(24.0), 0.0), color=POSSUM_EAR)
        p.cyl("pilot", 0.072, 0.072, 0.044, segs=10, loc=(sx * 0.18, 0.00, 0.38),
              rot=(math.radians(78.0), sx * math.radians(24.0), 0.0), color=PATCH_PINK)

    # Chunky 2010 flip-up hacker visor goggles across brow (charcoal rim + glowing pink lens bar).
    p.box("hydraulic", (0.36, 0.12, 0.10), loc=(0.0, 0.15, 0.27), color=CHARCOAL)
    p.box("class_accent", (0.30, 0.06, 0.062), loc=(0.0, 0.195, 0.27))

    # Paws reaching forward to type on the 2010 stickered netbook held in lap/console!
    for sx in (-1.0, 1.0):
        p.rod("pilot", (sx * 0.22, 0.02, 0.02), (sx * 0.20, 0.24, 0.04), 0.065, segs=8, color=POSSUM_FUR)
        p.uv("pilot", 0.062, u=8, v=6, loc=(sx * 0.16, 0.28, 0.04), color=PATCH_PINK)
        # Seated feet tucked below.
        p.uv("pilot", 0.085, u=8, v=6, loc=(sx * 0.14, 0.14, -0.26), scale=(0.9, 1.3, 0.65), color=POSSUM_EAR)

    # Stickered 2010 clamshell netbook right in front of Patch's paws!
    p.box("hydraulic", (0.34, 0.22, 0.032), loc=(0.0, 0.30, -0.01), color=CHARCOAL)
    p.box("hydraulic", (0.34, 0.030, 0.20), loc=(0.0, 0.40, 0.08),
          rot=(math.radians(-18.0), 0.0, 0.0), color=STEEL)
    p.box("class_accent", (0.28, 0.022, 0.15), loc=(0.0, 0.39, 0.08),
          rot=(math.radians(-18.0), 0.0, 0.0))

    # Long prehensile pink possum tail curling up behind Patch's back to hook the upper cockpit rail!
    tail_pts = [
        Vector((0.0, -0.18, -0.20)),
        Vector((0.05, -0.30, -0.06)),
        Vector((0.08, -0.32, 0.18)),
        Vector((0.02, -0.24, 0.42)),
        Vector((-0.08, -0.10, 0.50)),
        Vector((-0.14, 0.04, 0.44)),
    ]
    for a_pt, b_pt in zip(tail_pts, tail_pts[1:]):
        p.rod("pilot", a_pt, b_pt, 0.044, segs=8, r2=0.036, color=PATCH_PINK)
    for pt in tail_pts[1:-1]:
        p.ico("pilot", 0.044, subdiv=1, loc=tuple(pt), color=PATCH_PINK)

    bmesh.ops.recalc_face_normals(p.bm, faces=p.bm.faces[:])
    obj = p.to_object(parent=root)
    common.empty("SeatOrigin", loc=(0.0, 0.0, -0.28), parent=root)

    tris = common.tris(obj)
    verts = len(obj.data.vertices)
    draws = len(obj.data.materials)
    print(f"PILOT_PATCH {tris:4d}T {verts:4d}V {draws}D")
    assert tris <= 12000 and verts <= 8100 and draws <= 5
    common.export(root, out_path)


def build_shell_patch(out_path):
    """Cutaway-first heroic Hoberman ball shell for Patch (ruling en: <= 6500 tris, <= 10 draws,
    heroic side mounts reaching ~1.65 m, safe ground clearance Y > -0.55 m)."""
    common.reset()
    _setup_slots()
    polish.enable(detail=1, bevel=0.010, bevel_min=0.05, ao_strength=0.30, ao_reach=0.28, edge=0.10)
    root = common.empty("ShellPatch")

    # 1. Core (rolling sphere cage, replaced by cutaway plating under --ball-look=cutaway).
    core = Part("Core")
    for rot_e in ((0.0, 0.0, 0.0), (math.pi / 2.0, 0.0, 0.0), (0.0, math.pi / 2.0, 0.0)):
        core.ring("paint", 0.86, 0.96, 0.09, segs=18, rot=rot_e, color=VERDIGRIS)
    for sx in (-1.0, 1.0):
        core.cyl("paint", 0.16, 0.16, 0.10, segs=10, loc=(sx * 0.92, 0.0, 0.0), rot=ALONG_X, color=COPPER)
    bmesh.ops.recalc_face_normals(core.bm, faces=core.bm.faces[:])
    core_obj = core.to_object((0, 0, 0), root)

    # 2. Pod (level cockpit cradle + side hub mounts + rear wok-cut signal dish!).
    pod = Part("Pod")
    # Cockpit floor pan & low seat ring inside ball (stays visible inside cutaway window).
    pod.cyl("paint", 0.42, 0.42, 0.06, segs=12, loc=(0.0, 0.0, -0.34), color=CHARCOAL)
    pod.ring("paint", 0.44, 0.56, 0.08, segs=14, loc=(0.0, 0.0, -0.30), color=COPPER)
    # Rear upper tail-hang bar inside dome.
    pod.rod("bare_metal", (-0.34, -0.14, 0.48), (0.34, -0.14, 0.48), 0.032, segs=8)
    # Chunky side hub-collar yokes flanking the cutaway sphere (clearance Z >= -0.35 m).
    for sx in (-1.0, 1.0):
        pod.box("paint", (0.22, 0.44, 0.34), loc=(sx * 1.08, 0.0, 0.05), color=VERDIGRIS)
        pod.cyl("paint", 0.18, 0.18, 0.24, segs=10, loc=(sx * 1.18, 0.0, 0.05), rot=ALONG_X, color=COPPER)

    # Wok-cut satellite dish mounted proudly on rear-top shoulder (pilots/patch.md §1!).
    dish_c = Vector((0.0, -0.92, 0.66))
    pod.rod("bare_metal", (0.0, -0.60, 0.24), dish_c, 0.065, segs=8)
    pod.cyl("paint", 0.50, 0.34, 0.12, segs=14, loc=tuple(dish_c),
            rot=(math.radians(52.0), 0.0, 0.0), color=STEEL)
    pod.ring("paint", 0.44, 0.52, 0.06, segs=14, loc=tuple(dish_c + Vector((0.0, -0.04, 0.04))),
             rot=(math.radians(52.0), 0.0, 0.0), color=COPPER)
    # Glowing test-card pink feed-horn dipole sticking out of wok dish center.
    pod.rod("bare_metal", dish_c, dish_c + Vector((0.0, -0.20, 0.24)), 0.032, segs=6)
    pod.ico("class_accent", 0.085, subdiv=1, loc=tuple(dish_c + Vector((0.0, -0.22, 0.26))))

    bmesh.ops.recalc_face_normals(pod.bm, faces=pod.bm.faces[:])
    pod_obj = pod.to_object((0, 0, 0), root)

    # 3. Dome placeholder node (expected by hero_assets.gd & hero_six_pilot_budget_test conventions).
    dome_root = common.empty("Dome", (0.0, 0.0, 0.0), pod_obj)
    common.empty("PilotSeat", (0.0, 0.0, 0.0), dome_root)

    # 4. WeaponRing — Ruling en heroic cutaway-first side mounts (~1.62 m reach, Z >= -0.20 m):
    #    Right side: chunky Patch-Cable splice reel & RJ-45 jack lance!
    #    Left side: Pointer signal-burst emitter & twin USB-stick capacitor rack!
    wring = Part("WeaponRing")
    # Outer azimuth carrier yoke ring hugging the equator.
    wring.ring("paint", 1.00, 1.08, 0.09, segs=18, loc=(0.0, 0.0, 0.04), color=CHARCOAL)

    # Right (+X) heroic Patch-Cable splice cannon + flanged cable drum (reaches ~1.65 m).
    wring.box("paint", (0.38, 0.54, 0.34), loc=(1.30, 0.06, 0.10), color=CHARCOAL)
    wring.cyl("paint", 0.22, 0.22, 0.32, segs=12, loc=(1.34, -0.20, 0.16), rot=ALONG_X, color=COPPER)
    wring.ring("class_accent", 0.20, 0.25, 0.07, segs=12, loc=(1.34, -0.20, 0.16), rot=ALONG_X)
    # Chunky forward splice barrel + bracket fork muzzle.
    wring.box("bare_metal", (0.18, 0.62, 0.20), loc=(1.32, 0.48, 0.10))
    for sz in (-0.11, 0.11):
        wring.box("class_accent", (0.14, 0.22, 0.055), loc=(1.32, 0.80, 0.10 + sz))

    # Left (-X) heroic Pointer emitter pod + twin vertical bracket antennae (reaches ~1.64 m).
    wring.box("paint", (0.38, 0.52, 0.34), loc=(-1.30, 0.06, 0.10), color=VERDIGRIS)
    wring.cyl("bare_metal", 0.13, 0.10, 0.64, segs=10, loc=(-1.32, 0.44, 0.10), rot=ALONG_Y)
    wring.ring("class_accent", 0.12, 0.19, 0.07, segs=12, loc=(-1.32, 0.74, 0.10), rot=ALONG_Y)
    for sy in (-0.10, 0.10):
        wring.rod("paint", (-1.36, sy, 0.26), (-1.44, sy, 0.58), 0.032, segs=6, color=COPPER)
        wring.ico("class_accent", 0.058, subdiv=1, loc=(-1.45, sy, 0.60))

    bmesh.ops.recalc_face_normals(wring.bm, faces=wring.bm.faces[:])
    wring_obj = wring.to_object((0, 0, 0), pod_obj)

    tris = sum(common.tris(o) for o in (core_obj, pod_obj, wring_obj))
    verts = sum(len(o.data.vertices) for o in (core_obj, pod_obj, wring_obj))
    draws = sum(len(o.data.materials) for o in (core_obj, pod_obj, wring_obj))
    max_r = max(common.max_radius(o) for o in (core_obj, pod_obj, wring_obj))
    min_z = min(min((o.matrix_world @ v.co).z for v in o.data.vertices) for o in (pod_obj, wring_obj))
    print(f"SHELL_PATCH {tris:4d}T {verts:4d}V {draws}D reach={max_r:.2f}m pod_minZ={min_z:.2f}m")
    assert tris <= 6500 and verts <= 11600 and draws <= 10
    assert max_r <= 1.75, f"shell_patch reach {max_r:.2f}m exceeds Ruling en 1.75 m cap"
    assert min_z >= -0.55, f"shell_patch pod/weapon minZ {min_z:.2f}m breaks ground clearance"
    common.export(root, out_path)


def build_patch_husk_sticker(out_path):
    """Patch's hand-ownership overlay (pilots/patch.md §4): paw-print sticker over Fleet tag +
    trailing cut command cable + overhead punch-card timer badge."""
    common.reset()
    _setup_slots()
    polish.enable(detail=1, bevel=0.006, bevel_min=0.04, ao_strength=0.28, ao_reach=0.22, edge=0.10)
    root = common.empty("PatchHuskSticker")
    p = Part("PatchHuskStickerMesh")

    # Rounded paw-print sticker plate slapped onto machine chassis.
    p.cyl("paint", 0.24, 0.24, 0.036, segs=12, loc=(0.0, 0.0, 0.24), rot=ALONG_Y, color=COLD_WHITE)
    # Central paw pad + 4 toe beans in Patch's test-card pink!
    p.cyl("class_accent", 0.085, 0.085, 0.046, segs=10, loc=(0.0, -0.005, 0.20), rot=ALONG_Y)
    for tx, tz in ((-0.10, 0.30), (-0.036, 0.34), (0.036, 0.34), (0.10, 0.30)):
        p.cyl("class_accent", 0.038, 0.038, 0.048, segs=8, loc=(tx, -0.006, tz), rot=ALONG_Y)

    # Cut command cable whipping rearward with frayed copper tip.
    pts = [
        Vector((0.0, 0.04, 0.24)),
        Vector((0.14, 0.22, 0.20)),
        Vector((0.06, 0.44, 0.12)),
        Vector((0.18, 0.66, 0.06)),
    ]
    for a_pt, b_pt in zip(pts, pts[1:]):
        p.rod("paint", a_pt, b_pt, 0.028, segs=6, color=CHARCOAL)
    for pt in pts[1:-1]:
        p.ico("paint", 0.030, subdiv=1, loc=tuple(pt), color=CHARCOAL)
    p.ico("class_accent", 0.052, subdiv=1, loc=tuple(pts[-1]))

    bmesh.ops.recalc_face_normals(p.bm, faces=p.bm.faces[:])
    obj = p.to_object(parent=root)
    common.empty("SocketSticker", loc=(0.0, 0.0, 0.24), parent=root)

    tris = common.tris(obj)
    verts = len(obj.data.vertices)
    draws = len(obj.data.materials)
    print(f"PATCH_HUSK_STICKER {tris:4d}T {verts:4d}V {draws}D")
    assert tris <= 2000 and verts <= 4600 and draws <= 2
    common.export(root, out_path)


def main():
    opts = common.args()
    models_root = opts["out"] or common.MODELS
    build_pilot_patch(os.path.join(models_root, "pilot_patch_anim.glb"))
    build_shell_patch(os.path.join(models_root, "world_one", "shell_patch.glb"))
    build_patch_husk_sticker(os.path.join(models_root, "world_one", "patch_husk_sticker.glb"))


if __name__ == "__main__":
    main()
