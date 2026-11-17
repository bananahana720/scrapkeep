"""Soft-toy Fleet clerk and its sluice ledger bench. Godot metres, facing -Z.

Build with Blender 5.2.2 in background mode. WorkMachines poses the clerk's arm and the desk press.
"""
import os
from pathlib import Path
import sys

import bmesh
import bpy

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import common

common.reset()
SLOT = "tally_paint"
common.SLOTS[SLOT] = {"vc": True, "rough": 0.78, "metal": 0.0}

SHIRT = "a697bf"
BIB = "807195"
FUR = "bcaed0"
MUZZLE = "d0c5dd"
DARK = "594c69"
OXIDE = "9f523d"
FRAME = "5f6965"
BASE = "737b75"
WOOD = "857563"
PAPER = "dad0b9"
INK = "908577"
CLIP = "696e66"
ARM_PIVOT = (0.235, 0.94, -0.015)
STAMP_FACE = (0.235, 0.787, -0.505)


def g(x, y, z):
    return (x, -z, y)


def oval(part, size, at, color, segs=10):
    for face in part.uv(SLOT, 1.0, u=segs, v=7, loc=g(*at), scale=g(size[0], size[1], -size[2]), color=color):
        face.smooth = True


def board(part, size, at, color):
    part.box(SLOT, (size[0], size[2], size[1]), loc=g(*at), color=color)


def rod(part, a, b, radius, color):
    for face in part.rod(SLOT, g(*a), g(*b), radius, segs=8, color=color):
        face.smooth = True


def finish(part, parent):
    bmesh.ops.recalc_face_normals(part.bm, faces=part.bm.faces[:])
    return part.to_object(origin=parent.location, parent=parent)


root = common.empty("TallyStation")
stand = common.Part("ClerkAndBench")
# Low broad feet, lilac overalls, a paddle tail and a soft cap. The stamp cuff is the Fleet's single accent.
for side in (-1, 1):
    oval(stand, (0.11, 0.26, 0.105), (side * 0.135, 0.3, 0.02), BIB)
    oval(stand, (0.135, 0.09, 0.17), (side * 0.135, 0.085, -0.061), DARK)
oval(stand, (0.14, 0.058, 0.27), (0.03, 0.19, 0.28), DARK)
oval(stand, (0.28, 0.34, 0.21), (0.0, 0.67, 0.005), SHIRT, 14)
oval(stand, (0.202, 0.218, 0.079), (0.0, 0.61, -0.174), BIB)
for side in (-1, 1):
    rod(stand, (side * 0.123, 0.88, -0.13), (side * 0.13, 0.65, -0.218), 0.025, BIB)
oval(stand, (0.244, 0.223, 0.211), (0.0, 1.024, -0.025), FUR, 14)
oval(stand, (0.161, 0.09, 0.079), (0.0, 0.963, -0.211), MUZZLE)
oval(stand, (0.054, 0.038, 0.046), (0.0, 1.011, -0.273), DARK)
for side in (-1, 1):
    oval(stand, (0.061, 0.068, 0.035), (side * 0.205, 1.165, -0.005), FUR)
    oval(stand, (0.023, 0.035, 0.019), (side * 0.094, 1.063, -0.210), DARK, 8)
    board(stand, (0.035, 0.052, 0.038), (side * 0.023, 0.924, -0.26), MUZZLE)
oval(stand, (0.27, 0.112, 0.235), (0.0, 1.18, -0.034), BIB)
oval(stand, (0.229, 0.039, 0.15), (0.0, 1.132, -0.195), DARK)
rod(stand, (-0.216, 0.89, 0), (-0.28, 0.78, -0.24), 0.08, SHIRT)
rod(stand, (-0.28, 0.78, -0.24), (-0.22, 0.79, -0.43), 0.069, SHIRT)
oval(stand, (0.08, 0.056, 0.092), (-0.22, 0.79, -0.464), FUR)

# The ledger lies open across the bench. The remaining marked sheets fit in the sorting tray.
for side in (-1, 1):
    rod(stand, (side * 0.47, 0.03, -0.49), (side * 0.38, 0.72, -0.59), 0.075, FRAME)
    board(stand, (0.26, 0.06, 0.45), (side * 0.47, 0.03, -0.57), BASE)
rod(stand, (-0.43, 0.38, -0.52), (0.43, 0.38, -0.52), 0.051, FRAME)
board(stand, (1.31, 0.11, 0.58), (0.045, 0.72, -0.58), WOOD)
board(stand, (0.58, 0.024, 0.38), (-0.04, 0.782, -0.554), INK)
for side in (-1, 1):
    x = -0.04 + side * 0.142
    board(stand, (0.267, 0.017, 0.34), (x, 0.799, -0.555), PAPER)
    for i in range(4):
        board(stand, (0.19, 0.003, 0.008), (x, 0.809, -0.65 + i * 0.055), INK)
board(stand, (0.26, 0.059, 0.29), (0.477, 0.802, -0.642), BASE)
for i in range(3):
    board(stand, (0.216, 0.01, 0.21), (0.47 - 0.012 * i, 0.834 + 0.01 * i, -0.638), PAPER)

# Benchtop stamp: the upright die travels in a fixed guide and never swings away from the page.
board(stand, (0.12, 0.084, 0.22), (0.235, 0.812, -0.70), FRAME)
rod(stand, (0.235, 0.82, -0.73), (0.235, 1.10, -0.73), 0.058, FRAME)
rod(stand, (0.235, 1.10, -0.73), (0.235, 1.10, -0.575), 0.05, FRAME)
finish(stand, root)

arm = common.empty("StampArm", loc=g(*ARM_PIVOT), parent=root)
part = common.Part("StampSleeve")
rod(part, ARM_PIVOT, (0.25, 0.92, -0.29), 0.071, SHIRT)
rod(part, (0.25, 0.92, -0.29), (0.235, 0.946, -0.45), 0.071, SHIRT)
rod(part, (0.244, 0.934, -0.366), (0.240, 0.942, -0.410), 0.074, OXIDE)
oval(part, (0.083, 0.063, 0.085), (0.235, 0.946, -0.489), FUR)
finish(part, arm)

stamp = common.empty("StampDie", loc=g(*STAMP_FACE), parent=root)
part = common.Part("PressHead")
board(part, (0.17, 0.039, 0.16), (0.235, 0.990, -0.555), CLIP)
rod(part, (0.235, 0.99, -0.555), (0.235, 1.136, -0.555), 0.044, FRAME)
rod(part, (0.235, 1.136, -0.555), (0.235, 0.949, -0.53), 0.045, FRAME)
oval(part, (0.085, 0.042, 0.05), (0.235, 0.942, -0.51), DARK)
finish(part, stamp)

bpy.context.view_layer.update()
tris = common.tri_total(root)
draws = sum(len(obj.data.materials) for obj in common.tree(root) if obj.type == "MESH")
assert tris <= 4200 and draws == 3, (tris, draws)
print("TALLY_STATION_BUDGET", tris, "T", draws, "D")
common.export(root, common.args()["out"] or os.path.join(common.MODELS, "world_one", "works_tally_clerk.glb"))
