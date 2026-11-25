"""Moss sandstone shelter: one broken sandstone mass carried over the workshop.
Blender +Z is up; coordinates below are the bay's Godot coordinates (Barge space, +X front).
Two continuous cheek skins and a rear skin sit inside the cabin volume (X -19.5..-14.5, Z -4..4,
Y 0..6) and carry on through a neck to the cap, which spans X -19.5..-11.5, Z -6.3..6.3,
Y 7.35..9.2 over the awning (Y 7.1). Each cheek is one closed shell whose outer face breaks
into a few broad oblique planes (no stacked slabs); the cap keeps a full front belly with a
1.3 to 1.6 m lip and a crown of three planar regions folded along two offset ridges. No
ground-level stone outside the cabin footprint, no collision, no lights. One mesh, one slot;
vertex colour is neutral white because hero_assets.gd puts the cliff rock shader on it
(sandstone.gdshader, cliff_only, pattern anchored in Barge-local metres).
"""
import math, os, sys
import bmesh
sys.path.insert(0, os.path.dirname(__file__))
import common
import polish
from common import Part
polish.enable(bevel=0)
common.reset()
root = common.empty('MossShelter')
p = Part('SandstoneShelter')
bm = p.bm

CAP_LOW, CAP_HIGH = 7.35, 9.2
X_BACK = -19.5


def point(g): return (g[0], -g[2], g[1])
def vert(g): return bm.verts.new(point(g))


def shell(rows):
    """A closed prism through rows of (y, [(x, z) ring]); consecutive rings make the oblique side planes."""
    rings = [[vert((x, y, z)) for x, z in ring] for y, ring in rows]
    n = len(rings[0])
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])


NECK_TOP = 7.62
cheeks = {
    1: [(0.0, -14.6, 3.99, 0.50, -0.50), (1.5, -16.0, 3.94, 0.62, 0.60), (4.3, -14.85, 3.99, 0.47, -0.55),
        (6.0, -16.5, 3.93, 0.58, 0.60), (NECK_TOP, -15.8, 3.96, 0.55, -0.50)],
    -1: [(0.0, -15.9, 3.97, 0.56, 0.55), (1.2, -14.6, 4.0, 0.46, -0.50), (3.9, -16.2, 3.93, 0.64, 0.60),
         (6.0, -15.0, 3.98, 0.52, -0.55), (NECK_TOP, -15.4, 3.95, 0.60, 0.55)],
}
for side, stations in cheeks.items():
    rows = []
    for y, xf, zo, thick, sh in stations:
        xi = min(-14.52, xf + sh)
        rows.append((y, [(X_BACK, side * zo), (xf, side * zo), (xi, side * (zo - thick)), (X_BACK, side * (zo - thick))]))
    shell(rows)
shell([(0.0, [(X_BACK, -3.98), (X_BACK + 0.50, -3.98), (X_BACK + 0.50, 3.98), (X_BACK, 3.98)]),
       (3.1, [(X_BACK, -3.94), (X_BACK + 0.62, -3.94), (X_BACK + 0.62, 3.99), (X_BACK, 3.99)]),
       (6.0, [(X_BACK, -3.99), (X_BACK + 0.47, -3.99), (X_BACK + 0.47, 3.93), (X_BACK, 3.93)]),
       (NECK_TOP, [(X_BACK, -3.96), (X_BACK + 0.55, -3.96), (X_BACK + 0.55, 3.96), (X_BACK, 3.96)])])

perimeter = [(-19.5, -5.0), (-18.5, -6.3), (-15.5, -5.9), (-13.0, -6.2), (-11.9, -6.0), (-11.5, -4.2),
             (-11.9, -0.6), (-11.55, 3.6), (-12.6, 6.15), (-13.5, 6.3), (-15.7, 6.3), (-19.3, 5.5)]
n = len(perimeter)
centre = (sum(x for x, _ in perimeter) / n, sum(z for _, z in perimeter) / n)
FRONT = (5, 6, 7)
CORNER = (1, 4, 8, 9, 10)
t_rings = [0.0, 0.14, 0.42, 0.68, 0.86, 1.0]
inset = {'front': [0.10, 0.0, 0.0, 0.0, 0.03, 0.08],
         'corner': [0.20, 0.0, 0.0, 0.0, 0.45, 0.80],
         'side': [0.15, 0.0, 0.02, 0.02, 0.30, 0.55]}
CHIP = {0: 1.5, 1: 1.3, 2: 0.7, 3: 0.8, 4: 0.4, 8: 0.5, 9: 0.6, 10: 1.4, 11: 0.8}


def cls(i): return 'front' if i in FRONT else ('corner' if i in CORNER else 'side')
def moved(i, k):
    x, z = perimeter[i]
    dx, dz = centre[0] - x, centre[1] - z
    d = math.hypot(dx, dz)
    s = inset[cls(i)][k] * (CHIP.get(i, 1.0) if k >= 4 else 1.0)
    px, pz = x + dx / d * s, z + dz / d * s
    return (max(X_BACK, min(-11.5, px)), max(-6.3, min(6.3, pz)))
xz = [[moved(i, k) for i in range(n)] for k in range(len(t_rings))]
top_xz = xz[-1]


def plane(a, b, c):
    """Height plane h = h0 + gx*x + gz*z through three (x, z, h) points."""
    (x1, z1, h1), (x2, z2, h2), (x3, z3, h3) = a, b, c
    det = (x2 - x1) * (z3 - z1) - (x3 - x1) * (z2 - z1)
    gx = ((h2 - h1) * (z3 - z1) - (h3 - h1) * (z2 - z1)) / det
    gz = ((x2 - x1) * (h3 - h1) - (x3 - x1) * (h2 - h1)) / det
    return lambda x, z: h1 + gx * (x - x1) + gz * (z - z1)


P_R = lambda x, z: 9.18 - 0.040 * (x - X_BACK) - 0.004 * z
h = {}
for i in (10, 11, 0, 1, 2):
    h[i] = P_R(*top_xz[i])
P_M = plane((*top_xz[2], h[2]), (*top_xz[10], h[10]), (*top_xz[3], h[2] - 0.11))
for i in (2, 3, 10, 9):
    h[i] = P_M(*top_xz[i])
P_F = plane((*top_xz[3], h[3]), (*top_xz[9], h[9]), (*top_xz[7], 8.76))
for i in (3, 4, 5, 6, 7, 8, 9):
    h[i] = P_F(*top_xz[i])
REGIONS = {'R': [10, 11, 0, 1, 2], 'M': [2, 3, 9, 10], 'F': [3, 4, 5, 6, 7, 8, 9]}


def area(idx):
    pts = [top_xz[i] for i in idx]
    return 0.5 * abs(sum(pts[a][0] * pts[(a + 1) % len(pts)][1] - pts[(a + 1) % len(pts)][0] * pts[a][1] for a in range(len(pts))))
areas = {k: area(v) for k, v in REGIONS.items()}
total = sum(areas.values())

rings = []
for k, t in enumerate(t_rings):
    rings.append([vert((xz[k][i][0], CAP_LOW + (h[i] - CAP_LOW) * t, xz[k][i][1])) for i in range(n)])
for a, b in zip(rings, rings[1:]):
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))
inner = [vert((centre[0] + (x - centre[0]) * 0.55, CAP_LOW + 0.26, centre[1] + (z - centre[1]) * 0.55)) for x, z in xz[0]]
hub = vert((centre[0], CAP_LOW + 0.40, centre[1]))
for i in range(n):
    j = (i + 1) % n
    bm.faces.new((rings[0][j], rings[0][i], inner[i], inner[j]))
    bm.faces.new((inner[j], inner[i], hub))
for idx in REGIONS.values():
    bm.faces.new([rings[-1][i] for i in idx])

bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
p.paint([], 'paint')
for f in bm.faces:
    f.material_index = 0
    f.smooth = False
    for loop in f.loops:
        loop[p.col] = (1.0, 1.0, 1.0, 1.0)
p.to_object(parent=root)
tris = common.tri_total(root)
assert tris < 1600, tris
top = max(h.values())
assert top <= CAP_HIGH, top
common.export(root, common.args()['out'] or os.path.join(common.MODELS, 'moss_shelter.glb'))
print('moss_shelter triangles', tris, 'crown top %.3f' % top,
      'areas %s' % {k: round(v / total, 3) for k, v in areas.items()},
      'rim heights', {i: round(h[i], 3) for i in (4, 5, 6, 7, 8)})
