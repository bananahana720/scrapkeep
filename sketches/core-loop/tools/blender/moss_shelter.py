"""Moss sandstone shelter: a carried stone shell around the existing 5 x 6 x 8 m cabin.
Blender +Z is up; coordinates below are the bay's Godot coordinates (Barge space, +X front).
Two side cheeks and a rear skin sit inside the cabin volume (X -19.5..-14.5, Z -4..4, Y 0..6),
a neck joins them up to the cap, and one asymmetrical cap spans X -19.5..-11.5, Z -6.3..6.3,
Y 7.35..9.2 over the awning (Y 7.1). No ground-level stone outside the cabin footprint, no
collision, no lights. One mesh, one slot: hero_assets.gd puts the scenery sandstone material
on it (matte, sandstone-strata, 6 m triplanar), so `paint` here only carries vertex colour.
"""
import math, os, random, sys
import bmesh
sys.path.insert(0, os.path.dirname(__file__))
import common
from common import Part
common.reset()
rng = random.Random(280929)
root = common.empty('MossShelter')
p = Part('SandstoneShelter')
bm = p.bm

CAP_LOW, CAP_HIGH = 7.35, 9.2
X_BACK, X_FRONT_CABIN = -19.5, -14.5


def point(g): return (g[0], -g[2], g[1])
def vert(g): return bm.verts.new(point(g))
def grey(v, warm=0.0):
    """Linear vertex colour multiplier on the sandstone albedo (tinted against the orange strata texture); warm > 0 lifts the crown."""
    return (v * (1.0 + 0.02 * warm), v * (1.0 + 0.02 * warm), v * (1.0 - 0.02 * warm), 1.0)
def colour(face, value):
    for loop in face.loops:
        loop[p.col] = value
def close(rows, top=None, bottom=None):
    """Quad strips between consecutive rings (each a list of verts in the same order)."""
    faces = []
    n = len(rows[0])
    for a, b in zip(rows, rows[1:]):
        for i in range(n):
            j = (i + 1) % n
            faces.append(bm.faces.new((a[i], a[j], b[j], b[i])))
    if bottom is not None:
        faces.append(bm.faces.new(bottom))
    if top is not None:
        faces.append(bm.faces.new(top))
    return faces


def slab(x0, x1, y0, y1, z0, z1, bevel, shade):
    """A chamfered stratum: horizontal section insets at both ends, full size between."""
    sections = [(y0, bevel), (y0 + bevel, 0.0), (y1 - bevel, 0.0), (y1, bevel)]
    rows = []
    for y, inset in sections:
        a, b = x0 + inset, x1 - inset
        c, d = z0 + inset, z1 - inset
        rows.append([vert((a, y, c)), vert((b, y, c)), vert((b, y, d)), vert((a, y, d))])
    faces = close(rows, top=rows[-1], bottom=list(reversed(rows[0])))
    for f in faces:
        colour(f, grey(shade * rng.uniform(0.93, 1.03), 0.4 if f.normal.z > 0.5 else 0.0))
    return faces


bands = [0.0, 1.05, 2.3, 3.55, 4.85, 6.15]
# Cheeks: irregular strips, 0.45 to 0.65 m thick inside |z| 3.3..4.0, fronts behind X -14.5.
# Each side breaks the 6 m height at its own heights, so the strata do not line up left to right.
cuts = {-1: [0.0, 2.1, 3.3, 4.8, 6.15], 1: [0.0, 1.4, 3.6, 4.4, 6.15]}
for side in (-1, 1):
    b = cuts[side]
    for k in range(4):
        outer = 4.0 - rng.uniform(0.0, 0.05)
        thick = rng.uniform(0.47, 0.64)
        z_a, z_b = sorted((side * outer, side * (outer - thick)))
        front = rng.uniform(-15.6, -14.6)
        slab(X_BACK, front, b[k], b[k + 1], z_a, z_b, rng.uniform(0.15, 0.18), rng.uniform(0.74, 1.0))
# Rear skin: strata across the back wall.
for k in range(5):
    thick = rng.uniform(0.47, 0.64)
    slab(X_BACK, X_BACK + thick, bands[k], bands[k + 1], -(4.0 - rng.uniform(0, 0.1)), 4.0 - rng.uniform(0, 0.1),
         rng.uniform(0.12, 0.18), 0.78 + 0.04 * k)
# Neck over the cabin footprint, Y 6..7.55 (the cap hides its top).
slab(X_BACK, -14.7, 6.0, 6.75, -3.95, 3.95, 0.12, 0.9)
slab(X_BACK, -14.78, 6.7, 7.55, -3.9, 3.9, 0.14, 0.88)

# Cap: one closed asymmetrical profile, 10 perimeter points, 6 height bands.
perimeter = [(-19.5, -5.0), (-18.5, -6.3), (-15.4, -5.85), (-12.4, -6.25), (-11.5, -4.2), (-11.9, -0.6),
             (-11.55, 3.6), (-12.7, 6.15), (-16.2, 6.3), (-19.3, 5.5)]
centre = (sum(x for x, _ in perimeter) / 10.0, sum(z for _, z in perimeter) / 10.0)
n = len(perimeter)
# Broken crest: the lip stays 1.1 to 1.7 m thick at the front and the back stands near the ceiling.
crest = []
for i, (x, z) in enumerate(perimeter):
    rear = max(0.0, min(1.0, (-11.5 - x) / 8.0))
    crest.append(min(CAP_HIGH - 0.06, 8.55 + 0.5 * rear + rng.uniform(-0.2, 0.12) + (0.12 if z > 0 else -0.05)))
# Ring k: height fraction, plane scale about the centre. The bulge is monotone (chamfered foot, full
# belly, shoulder rolling in), so the flank reads as one broken mass rather than stacked ledges.
ring_spec = [(0.0, 0.95), (0.14, 1.0), (0.42, 1.0), (0.68, 0.98), (0.86, 0.92), (1.0, 0.84)]
rows = []
for t, s in ring_spec:
    row = []
    for i, (x, z) in enumerate(perimeter):
        sx = s * (1.0 + rng.uniform(-0.03, 0.02))
        px = centre[0] + (x - centre[0]) * sx
        pz = centre[1] + (z - centre[1]) * sx
        px = max(X_BACK, min(-11.5, px))
        pz = max(-6.3, min(6.3, pz))
        row.append(vert((px, CAP_LOW + (crest[i] - CAP_LOW) * t, pz)))
    rows.append(row)
# Underside scooped up 0.40 toward the centre.
inner = [vert((centre[0] + (x - centre[0]) * 0.55, CAP_LOW + 0.26, centre[1] + (z - centre[1]) * 0.55)) for x, z in perimeter]
hub = vert((centre[0], CAP_LOW + 0.40, centre[1]))
under = []
for i in range(n):
    j = (i + 1) % n
    under.append(bm.faces.new((rows[0][j], rows[0][i], inner[i], inner[j])))
    under.append(bm.faces.new((inner[j], inner[i], hub)))
# Crown: an inner ring of two offset planes meeting at a fold, the rear-left plane lifted to the ceiling.
top = rows[-1]
plane_a = lambda x, z: CAP_HIGH - 0.03 - 0.10 * (x - X_BACK) / 8.0 - 0.06 * (z + 6.3) / 12.6
plane_b = lambda x, z: 8.86 - 0.16 * (x - X_BACK) / 8.0 + 0.10 * (z + 6.3) / 12.6
ring_in = []
for i, (x, z) in enumerate(perimeter):
    px = centre[0] + (x - centre[0]) * 0.5 + 0.35
    pz = centre[1] + (z - centre[1]) * 0.5
    ring_in.append((px, pz))
left = list(range(0, 6))
right = list(range(5, 10)) + [0]
crown = []
top_in = {}
for i, (px, pz) in enumerate(ring_in):
    h = plane_a(px, pz) if i in left else plane_b(px, pz)
    if i in (0, 5):
        h = 0.5 * (plane_a(px, pz) + plane_b(px, pz))
    top_in[i] = vert((px, h, pz))
for i in range(n):
    j = (i + 1) % n
    crown.append(bm.faces.new((top[i], top[j], top_in[j], top_in[i])))
crown.append(bm.faces.new([top_in[i] for i in left]))
crown.append(bm.faces.new([top_in[i] for i in right]))
sides = close(rows)
for f in under:
    colour(f, grey(0.62))
for k, f in enumerate(crown):
    colour(f, grey(0.98 * rng.uniform(0.96, 1.02), 1.0))
for k, f in enumerate(sides):
    band = k // n
    colour(f, grey((0.70 + 0.05 * band) * rng.uniform(0.94, 1.04), 0.9 if band >= 4 else 0.3))

bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
p.paint([], 'paint')  # registers the one slot
for f in bm.faces:
    f.material_index = 0
    f.smooth = False
p.to_object(parent=root)
tris = common.tri_total(root)
assert tris < 1600, tris
common.export(root, common.args()['out'] or os.path.join(common.MODELS, 'moss_shelter.glb'))
print('moss_shelter triangles', tris)
