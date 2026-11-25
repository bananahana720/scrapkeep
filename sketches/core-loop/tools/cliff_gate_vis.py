"""Analytical depth raster for the cliff preconstruction gate (CLIFF-R3 section 3).

Read-only. Consumes the world-space triangles written by cliff_gate_export.gd (every visible mesh
of the frozen stage-1 game, double-sided as the capture tool's grey context material is) and
rasterises them with a depth buffer at the shared tool's 1920x1080 through the frozen launch and
overview cameras. A unit's visible mask is the set of pixels whose nearest triangle belongs to it,
which is what the tool's subject-context-depth mode draws (subject black, all else grey, all
writing depth). No bounding boxes and no per-ray terrain samples.
"""
import math
import numpy as np
from scipy import ndimage

W, H = 1920, 1080
NEAR = 0.05
CAMERAS = {
    "launch": ((-56.048587799, 19.613903046, -43.277446747), (-53.848587036, 19.113903046, -32.077445984), 62.0),
    "overview": ((145.0, 160.0, -240.0), (0.0, 44.0, 30.0), 65.0),
}


def cam_basis(eye, target):
    eye = np.array(eye, float)
    fwd = np.array(target, float) - eye
    fwd /= np.linalg.norm(fwd)
    right = np.cross(fwd, [0, 1, 0])
    right /= np.linalg.norm(right)
    up = np.cross(right, fwd)
    return eye, fwd, right, up


def rasterise(tris, ids, camera, size=(W, H)):
    """tris (N,3,3) world, ids (N,) int. Returns (idbuf int32 (H,W) with -1 background, invz)."""
    w, h = size
    eye, fwd, right, up = cam_basis(*camera[:2])
    tanf = math.tan(math.radians(camera[2]) / 2.0)
    d = tris - eye
    x = d @ right
    y = d @ up
    z = d @ fwd
    ndc_x = x / (z * tanf * (w / h))
    ndc_y = y / (z * tanf)
    front = z.max(axis=1) > NEAR
    idbuf = np.full((h, w), -1, np.int32)
    inv = np.zeros((h, w), np.float64)
    order = np.nonzero(front)[0]
    for t in order:
        zz = z[t]
        if zz.min() >= NEAR:
            polys = [(x[t], y[t], zz)]
        else:
            polys = _clip_near(x[t], y[t], zz)
        for px, py, pz in polys:
            sx = (px / (pz * tanf * (w / h)) + 1.0) * 0.5 * w
            sy = (1.0 - py / (pz * tanf)) * 0.5 * h
            x0 = max(int(math.floor(sx.min() - 0.5)), 0)
            x1 = min(int(math.ceil(sx.max() - 0.5)), w - 1)
            y0 = max(int(math.floor(sy.min() - 0.5)), 0)
            y1 = min(int(math.ceil(sy.max() - 0.5)), h - 1)
            if x1 < x0 or y1 < y0:
                continue
            det = (sy[1] - sy[2]) * (sx[0] - sx[2]) + (sx[2] - sx[1]) * (sy[0] - sy[2])
            if abs(det) < 1e-12:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            l0 = ((sy[1] - sy[2]) * (gx - sx[2]) + (sx[2] - sx[1]) * (gy - sy[2])) / det
            l1 = ((sy[2] - sy[0]) * (gx - sx[2]) + (sx[0] - sx[2]) * (gy - sy[2])) / det
            l2 = 1.0 - l0 - l1
            eps = -1e-9
            inside = (l0 >= eps) & (l1 >= eps) & (l2 >= eps)
            if not inside.any():
                continue
            iz = l0 / pz[0] + l1 / pz[1] + l2 / pz[2]
            view_inv = inv[y0:y1 + 1, x0:x1 + 1]
            view_id = idbuf[y0:y1 + 1, x0:x1 + 1]
            win = inside & (iz > view_inv)
            view_inv[win] = iz[win]
            view_id[win] = ids[t]
    return idbuf, inv


def _clip_near(x, y, z):
    pts = list(zip(x, y, z))
    out = []
    for i in range(3):
        a = pts[i]
        b = pts[(i + 1) % 3]
        ain = a[2] >= NEAR
        bin_ = b[2] >= NEAR
        if ain:
            out.append(a)
        if ain != bin_:
            t = (NEAR - a[2]) / (b[2] - a[2])
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, NEAR))
    if len(out) < 3:
        return []
    polys = []
    for i in range(1, len(out) - 1):
        tri = [out[0], out[i], out[i + 1]]
        polys.append((np.array([p[0] for p in tri]), np.array([p[1] for p in tri]), np.array([p[2] for p in tri])))
    return polys


def exposure(mask):
    """Section 3 measure on one boolean mask: area, column runs, longest connected R(t)."""
    h = np.zeros(mask.shape[1], int)
    for c in range(mask.shape[1]):
        col = mask[:, c]
        if not col.any():
            continue
        best = 0
        run = 0
        for v in col:
            run = run + 1 if v else 0
            if run > best:
                best = run
        h[c] = best
    labels, n = ndimage.label(mask, structure=np.ones((3, 3)))
    return {"area": int(mask.sum()), "max_h": int(h.max()), "h": h, "labels": labels, "n_components": int(n)}


def run_r(mask, e, t):
    """Longest run of consecutive columns with h >= t that a single connected component supplies."""
    best = 0
    best_lo = 0
    cols = e["h"] >= t
    c = 0
    n = len(cols)
    while c < n:
        if not cols[c]:
            c += 1
            continue
        s = c
        while c < n and cols[c]:
            c += 1
        seg = mask[:, s:c]
        lab = e["labels"][:, s:c]
        comp_at = []
        for k in range(seg.shape[1]):
            col = seg[:, k]
            best_run, best_lab, run, run_lab = 0, 0, 0, 0
            for yy in range(col.shape[0]):
                if col[yy]:
                    run += 1
                    run_lab = lab[yy, k]
                    if run > best_run:
                        best_run, best_lab = run, run_lab
                else:
                    run = 0
            comp_at.append(best_lab)
        k = 0
        while k < len(comp_at):
            j = k
            while j < len(comp_at) and comp_at[j] == comp_at[k]:
                j += 1
            if j - k > best:
                best = j - k
                best_lo = s + k
            k = j
    return best, best_lo
