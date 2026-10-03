#!/usr/bin/env python3
"""terrain_bake.py v0: the throwaway probe bake (unit TP, TERRAIN-SPEC section 2).

Run in the genai venv (numpy and PIL only; the tiles are read-only):

    /home/andrew/.local/share/genai-venv/bin/python tools/terrain_bake.py \
        --dem <dir with <name>.tif> --out <dir for .bin/.json> --review <dir for pictures> \
        [--smooth S1|S2|S3] [--s-horse 0.09]

Pipeline (spec section 2): crop and rotate, mirror-pad, scale, vertical exaggeration into an
envelope remap (each 10 m z band keeps today's flank(z) and trough_floor(z)), a Gaussian blur,
a feather into today's corridors. Output is a 201 x 201 grid at 2 m:

    reach_probe.bin   two float32 planes, little endian: [0] bake height in metres, [1] the weight
                      of today's ground (1 = keep what Reach.sample() computes, 0 = the bake)
    crater_probe.bin  one float32 plane: the control zone's height

The probe map reads these through map.sample(); nothing in terrain.gd changes.
"""
import argparse
import hashlib
import json
import math
import os

import numpy as np
from PIL import Image

STEP = 2.0
HALF = 200.0
SIDE = 201
G = 26.0
V_LAUNCH = 30.0
KAPPA = G / (V_LAUNCH * V_LAUNCH)  # convex radius under 34.6 m throws a 30 m/s ball

XS = -HALF + STEP * np.arange(SIDE)
X, Z = np.meshgrid(XS, XS)  # [row = z, col = x]


# ---- today's numbers (map_gorge.gd, map_reach.gd) ----

def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def descent(s, s0, s1, h0, h1):
    t = np.clip((s - s0) / (s1 - s0), 0.0, 1.0)
    return h0 + (h1 - h0) * (t + (smoothstep(0, 1, t) - t) * 0.45)


def flank(z):
    z = np.asarray(z, dtype=np.float64)
    return np.where(z < -102.0, descent(z, -166.0, -102.0, 58.0, 44.0),
           np.where(z < -66.0, descent(z, -102.0, -66.0, 44.0, 32.0),
           np.where(z < 58.0, descent(z, -66.0, 58.0, 32.0, 24.0),
           np.where(z < 104.0, descent(z, 58.0, 104.0, 24.0, 0.0), 0.0))))


def trough_floor(z):
    z = np.asarray(z, dtype=np.float64)
    return np.where(z < -52.0, descent(z, -100.0, -52.0, 14.0, 5.0), descent(z, -52.0, 100.0, 5.0, 0.0))


def trough_half(z):
    return 38.0 + (90.0 - 38.0) * smoothstep(56.0, 100.0, z)


WALL = 12.0


def today_approx(x, z):
    """Gorge ground without the line features: for the review pictures only."""
    f = flank(z)
    w = trough_half(z)
    inner = w - WALL
    ax = np.abs(x)
    t = trough_floor(z)
    floor = t - 1.2 * (1.0 - (ax / inner) ** 2)
    s = np.clip((ax - inner) / WALL, 0.0, 1.0)
    wall = t + (f - t) * (1.0 - np.sqrt(np.maximum(0.0, 1.0 - s * s)))
    h = np.where(z < -100.0, f, np.where(ax < inner, floor, np.where(ax < w, wall, f)))
    return h


# ---- raster helpers ----

def load_tile(dem_dir, name):
    return np.array(Image.open(os.path.join(dem_dir, name + ".tif")), dtype=np.float32)


def reflect(c, n):
    period = 2.0 * (n - 1)
    m = np.mod(c, period)
    return np.where(m <= n - 1, m, period - m)


def bilinear(img, u, v, mirror=True):
    n_v, n_u = img.shape
    if mirror:
        u = reflect(u, n_u)
        v = reflect(v, n_v)
    else:
        u = np.clip(u, 0, n_u - 1.001)
        v = np.clip(v, 0, n_v - 1.001)
    u0 = np.floor(u).astype(int)
    v0 = np.floor(v).astype(int)
    u0 = np.clip(u0, 0, n_u - 2)
    v0 = np.clip(v0, 0, n_v - 2)
    fu = u - u0
    fv = v - v0
    a = img[v0, u0]
    b = img[v0, u0 + 1]
    c = img[v0 + 1, u0]
    d = img[v0 + 1, u0 + 1]
    return (a * (1 - fu) + b * fu) * (1 - fv) + (c * (1 - fu) + d * fu) * fv


def gaussian(grid, sigma_m):
    """Separable Gaussian blur, sigma in metres, edge padded."""
    if sigma_m <= 0.0:
        return grid.copy()
    sigma = sigma_m / STEP
    radius = max(1, int(math.ceil(3.0 * sigma)))
    k = np.exp(-0.5 * (np.arange(-radius, radius + 1) / sigma) ** 2)
    k /= k.sum()
    out = grid.astype(np.float64)
    for axis in (0, 1):
        pad = [(0, 0), (0, 0)]
        pad[axis] = (radius, radius)
        p = np.pad(out, pad, mode="edge")
        acc = np.zeros_like(out)
        for i, w in enumerate(k):
            sl = [slice(None), slice(None)]
            sl[axis] = slice(i, i + out.shape[axis])
            acc += w * p[tuple(sl)]
        out = acc
    return out


def launch_mask(h):
    """Cells whose convex radius along x or z is under V_LAUNCH^2 / g (34.6 m).

    The second derivative is the gradient of the gradient at 2 m spacing (a 4 m stencil). That is
    the definition that reproduces the spec's measured launch shares (crater 4.7, Horseshoe 10.6,
    Coyote 22.2 percent at the table's scales); a 2 m central second difference reads about 1.6 times higher.
    """
    gz, gx = np.gradient(h, STEP)
    dxx = np.gradient(gx, STEP, axis=1)
    dzz = np.gradient(gz, STEP, axis=0)
    return ((-dxx) > KAPPA) | ((-dzz) > KAPPA)


def slope_deg(h):
    gz, gx = np.gradient(h, STEP)
    return np.degrees(np.arctan(np.hypot(gx, gz)))


def seg_dist(px, pz, a, b):
    ax, az = a
    bx, bz = b
    dx, dz = bx - ax, bz - az
    L2 = dx * dx + dz * dz
    t = np.clip(((px - ax) * dx + (pz - az) * dz) / L2, 0.0, 1.0) if L2 > 0 else 0.0
    return np.hypot(px - (ax + t * dx), pz - (az + t * dz))


def poly_dist(px, pz, pts):
    d = np.full(px.shape, 1e9)
    for a, b in zip(pts[:-1], pts[1:]):
        d = np.minimum(d, seg_dist(px, pz, a, b))
    return d


def rect_mask(x0, x1, z0, z1, feather):
    """1 inside the rectangle, easing to 0 over `feather` metres inward from each edge."""
    dx = np.minimum(X - x0, x1 - X)
    dz = np.minimum(Z - z0, z1 - Z)
    d = np.minimum(dx, dz)
    return smoothstep(0.0, feather, d)


# ---- the three pilot lines and the other corridors (today's ground wins here) ----

PILOTS = {
    "sable": [[0, -160], [-24, -122], [-52, -120], [-75, -121], [-85, -108], [-91, -94], [-93, -78], [-91, -62],
              [-85, -47], [-75, -35], [-73, -23], [-58, -10], [-36, 9], [-13, 30], [-4, 50], [-1, 64], [0, 76], [0, 86]],
    "rivet": [[0, -160], [44, -126], [96, -104], [103, -100], [84, -34], [58, -4], [22, 26], [6, 44], [1, 60], [0, 74], [0, 86]],
    "kest": [[0, -160], [48, -132], [96, -104], [84, -34], [74.5, 26], [74, 60], [74, 86], [73.8, 93.9], [69.8, 109],
             [60.8, 121.8], [50.1, 129.7]],
}
LINE_HALF = 14.0  # a pilot line's own half width; the 12 m feather comes on top (spec rule 2)
FEATHER = 12.0
SWEEP_CENTRE = (-32.3, -78.0)
SWEEP_LINE = 68.0
TUNNELS = {"w1": [(-58, -10), (-24, 20)], "w2": [(-58, 44), (-24, 74)], "e1": [(58, -4), (22, 26)], "e2": [(58, -74), (22, -44)]}
DIVE_DIR = (0.74986, 0.66161)
MOUTH = (-58.0, -10.0)
BEACON = (0.0, 118.0)


def corridor_distance():
    """Distance to the nearest protected feature, minus that feature's half width (<= 0 inside)."""
    d = np.full(X.shape, 1e9)
    for pts in PILOTS.values():
        d = np.minimum(d, poly_dist(X, Z, pts) - LINE_HALF)
    # the sweeper's circle (SWEEP_LINE from 131.4 to 245 degrees plus 25 degrees of fade) and the banked width
    arc = []
    for deg in np.linspace(131.4 - 25, 245 + 25, 40):
        a = math.radians(deg)
        arc.append((SWEEP_CENTRE[0] + math.cos(a) * SWEEP_LINE, SWEEP_CENTRE[1] + math.sin(a) * SWEEP_LINE))
    d = np.minimum(d, poly_dist(X, Z, arc) - 22.0)
    # the dive: from 45 m before the mouth to 70 m past it
    a = (MOUTH[0] - DIVE_DIR[0] * 45, MOUTH[1] - DIVE_DIR[1] * 45)
    b = (MOUTH[0] + DIVE_DIR[0] * 70, MOUTH[1] + DIVE_DIR[1] * 70)
    d = np.minimum(d, seg_dist(X, Z, a, b) - 14.0)
    # the gorge tunnels w1, e1 (open, on pilot lines) and w2 (z 44 to 74). e2 (58,-74 to 22,-44) is left to the
    # bake: its channel lies across the east fork's wall, which the walls route needs, and the probe map drops its roof.
    for key, pts in TUNNELS.items():
        if key != "e2":
            d = np.minimum(d, seg_dist(X, Z, pts[0], pts[1]) - 9.0)
    # cable, thermals, activity sites, vault plinth, berm, kicker, halfpipe, bowl
    d = np.minimum(d, seg_dist(X, Z, (96, -104), (84, -34)) - 10.0)
    for (cx, cz, r) in [(80, -12, 12), (44, 132, 12), (-16, 44, 12), (68, -4, 14), (0, -88, 14), (120, -76, 24), (118, 58, 12), (76, -78, 10)]:
        d = np.minimum(d, np.hypot(X - cx, Z - cz) - r)
    berm = []
    for deg in np.linspace(-15 - 25, 100 + 25, 30):
        a = math.radians(deg)
        berm.append((29 + math.cos(a) * 40, 90 + math.sin(a) * 40))
    d = np.minimum(d, poly_dist(X, Z, berm) - 22.0)
    d = np.minimum(d, seg_dist(X, Z, (74, 24), (74, 96)) - 12.0)
    d = np.minimum(d, np.hypot(X - BEACON[0], Z - BEACON[1]) - 62.0)
    d = np.minimum(d, seg_dist(X, Z, (0, 80), (0, 92)) - 12.0)
    return d


GUARD = 6.0


def corridor_mask(d):
    """1 inside a corridor and a GUARD m margin, easing to 0 over the next FEATHER m (spec rule 2:
    the bake's weight is 0 in the corridor plus its feather)."""
    return 1.0 - smoothstep(GUARD, GUARD + FEATHER, d)


# ---- the sources ----

def dome_field(dem, smooth_m, rmax, scale, centre, size_m, tile_centre=None):
    """Coyote Buttes slickrock as a field that peaks at flank(z): domes are crests, valleys are depressions."""
    img = load_tile(dem, "coyote_buttes_wave")
    mpp = 0.977
    cx, cz = centre
    # rotate so the tile's mean downhill points to +z
    cs = img[256:768, 256:768]
    gv, gu = np.gradient(cs.reshape(64, 8, 64, 8).mean(axis=(1, 3)))
    t = np.array([-gu.mean(), -gv.mean()])
    t /= np.linalg.norm(t)
    p = np.array([-t[1], t[0]])
    tc = (512.0, 512.0) if tile_centre is None else tile_centre
    k = 1.0 / (scale * mpp)
    u = tc[0] + (X - cx) * p[0] * k + (Z - cz) * t[0] * k
    v = tc[1] + (X - cx) * p[1] * k + (Z - cz) * t[1] * k
    D = bilinear(img, u, v)
    return D, scale


def horseshoe_field(dem, s, centre_game, tile_centre):
    """Horseshoe Bend rotated so the U opens to -z: game +z is tile +u (east), game x is tile v."""
    img = load_tile(dem, "horseshoe_bend")
    mpp = 1.465
    k = 1.0 / (s * mpp)
    u = tile_centre[0] + (Z - centre_game[1]) * k
    v = tile_centre[1] + (X - centre_game[0]) * k
    return bilinear(img, u, v, mirror=True)  # mirror-pad the cut left edge (spec rule 2)


def wall_field(dem, s, foot_x, z_origin, v0, flip):
    """East bank of the Horseshoe as a wall strip: game |x| - foot is tile u across, game z along tile v."""
    img = load_tile(dem, "horseshoe_bend")
    mpp = 1.465
    k = 1.0 / (s * mpp)
    across = np.abs(X) - foot_x
    u = 330.0 + across * k
    v = v0 + (Z - z_origin) * k + np.where(X < 0, 260.0 if flip else 0.0, 0.0)
    return bilinear(img, u, v, mirror=True)


def region_stats(h, region, mask_weight=None):
    sel = region > 0.5
    lm = launch_mask(h)
    sl = slope_deg(h)
    n = int(sel.sum())
    if n == 0:
        return {"cells": 0}
    return {"cells": n, "launch_share": round(float(lm[sel].mean()) * 100.0, 1),
            "slope_p50": round(float(np.percentile(sl[sel], 50)), 1), "slope_p95": round(float(np.percentile(sl[sel], 95)), 1),
            "over_30": round(float((sl[sel] > 30).mean()) * 100.0, 1), "over_63": round(float((sl[sel] > 63).mean()) * 100.0, 1),
            "relief_m": round(float(h[sel].max() - h[sel].min()), 1)}


def build(args):
    smooth = args.smooth
    sigma = {"S1": 3.0, "S2": 6.0, "S3": 3.0}[smooth]
    relax = smooth == "S3"
    dem = args.dem
    cmask = corridor_mask(corridor_distance())

    # region masks (before corridors)
    m_dome = rect_mask(90, 164, -99, 99, 14.0)
    m_fork = rect_mask(-62, 62, -97, -22, 14.0) * smoothstep(-97.0, -80.0, Z)
    m_wall = rect_mask(-72, 72, -44, 64, 14.0) * smoothstep(20.0, 26.0, np.abs(X))
    stats = {}

    fl = flank(Z)
    tf = trough_floor(Z)

    # --- domes (east shelf) ---
    D, s_d = dome_field(dem, 3.0, 9.0, args.s_dome, (127, 0), None)
    region = m_dome > 0.5
    Dtop = np.percentile(D[region], 98)
    rel_raw = (D - Dtop) * s_d * args.e_dome
    rmax = args.dome_rmax
    dome_raw = fl - rmax * np.tanh(-np.minimum(rel_raw, 0.0) / rmax)
    dome_sm = fl - rmax * np.tanh(-np.minimum(gaussian(rel_raw, sigma), 0.0) / rmax)
    # --- forks and butte ---
    Hh = horseshoe_field(dem, args.s_horse, (-4.0, -58.0), (args.hs_u, args.hs_v))
    reg_f = m_fork > 0.5
    lo = np.percentile(Hh[reg_f], 3)
    hi = np.percentile(Hh[reg_f], 97)

    # the apex closes the real river; the game's trough runs on, so the centre is carved to floor past the apex
    # (z_apex = -58 + (332 - tile_u) * 1.465 * s) and the field rises to the rim at the zone's x edges
    carve = smoothstep(-38.0, -22.0, Z) * (1.0 - smoothstep(14.0, 26.0, np.abs(X)))
    taper = 1.0 - smoothstep(0.0, 18.0, 62.0 - np.abs(X))

    def fork_remap(field):
        u = np.clip((field - lo) / (hi - lo), 0.0, 1.0) ** args.gamma
        u = u * (1.0 - carve)
        u = u + (1.0 - u) * taper
        return tf + (fl - tf) * u
    fork_raw = fork_remap(Hh)
    fork_sm = fork_remap(gaussian(Hh, sigma))
    # --- lower walls ---
    foot = trough_half(Z) - WALL
    Ww = np.zeros_like(X)
    img = load_tile(dem, "horseshoe_bend")
    mpp = 1.465
    k = 1.0 / (args.s_wall * mpp)
    across = np.abs(X) - foot
    uu = 330.0 + across * k
    vv = 140.0 + (Z + 12.0) * k + np.where(X < 0, 260.0, 0.0)
    Ww = bilinear(img, uu, vv, mirror=True)
    reg_w = m_wall > 0.5
    wlo = np.percentile(Ww[reg_w & (across < 4)], 10)
    whi = np.percentile(Ww[reg_w], 97)

    def wall_remap(field):
        u = np.clip((field - wlo) / (whi - wlo), 0.0, 1.0) ** args.gamma
        return tf + (fl - tf) * u
    wall_raw = wall_remap(Ww)
    wall_sm = wall_remap(gaussian(Ww, sigma))

    def compose(dome, fork, wall):
        w1 = m_fork
        w2 = m_wall * (1.0 - m_fork)
        w3 = m_dome
        tot = np.maximum(w1 + w2 + w3, 1e-6)
        h = (dome * w3 + fork * w1 + wall * w2) / tot
        mask = np.clip(np.maximum(np.maximum(w1, w2), w3), 0, 1)
        return h, mask
    h_raw, mask = compose(dome_raw, fork_raw, wall_raw)
    h_sm, _ = compose(dome_sm, fork_sm, wall_sm)

    # --- S3: relax cells along the free-roam centrelines (spec step 6) ---
    if relax:
        routes = json.load(open(args.routes))["pilots"]
        for name in ("domes", "butte", "walls"):
            pts = [tuple(p) for p in routes[name]["waypoints"]]
            band = 1.0 - smoothstep(6.0, 12.0, poly_dist(X, Z, pts))
            for _ in range(3):
                h_sm = h_sm * (1.0 - band) + gaussian(h_sm, 8.0) * band

    weight_today = 1.0 - mask * (1.0 - cmask)
    chosen = h_sm
    # region reports: bake regions as they stand (no corridors) and the part outside corridors
    out_c = (cmask < 0.5)
    # every region is read off the composed field, so the three settings are measured the same way
    for key, reg in (("domes", m_dome), ("forks_butte", m_fork), ("lower_walls", m_wall)):
        stats[key] = {"raw": region_stats(h_raw, reg), "smoothed": region_stats(chosen, reg)}
        stats[key]["raw_outside_corridors"] = region_stats(h_raw, (reg > 0.5) & out_c)
        stats[key]["smoothed_outside_corridors"] = region_stats(chosen, (reg > 0.5) & out_c)
    # composed bake over everything the bake owns outside corridors
    own = (mask > 0.5) & out_c
    stats["composed_outside_corridors"] = {"raw": region_stats(h_raw, own), "smoothed": region_stats(chosen, own)}

    # --- crater control ---
    crater_raw, crater_sm, crater_stats = crater(dem, sigma, args)
    stats["crater"] = crater_stats

    # --- spec's measured rows reproduced (resample at table scale) ---
    rows = {}
    for name, s_t, e_t, mpp_t in (("meteor_crater", 0.12, 1.0, 1.953), ("horseshoe_bend", 0.27, 0.6, 1.465), ("coyote_buttes_wave", 0.4, 0.6, 0.977)):
        img_t = load_tile(args.dem, name)
        k_t = 1.0 / (s_t * mpp_t)
        u = 512.0 + X * k_t
        v = 512.0 + Z * k_t
        Dt = bilinear(img_t, u, v, mirror=(name != "meteor_crater")) * s_t * e_t
        rows[name] = {"raw": region_stats(Dt, np.ones_like(X)), "blur3": region_stats(gaussian(Dt, 3.0), np.ones_like(X))}
    stats["spec_rows_reproduced"] = rows

    return {"height": h_sm, "weight": weight_today, "raw_height": h_raw, "mask": mask, "cmask": cmask, "stats": stats,
            "crater": crater_sm, "crater_raw": crater_raw, "regions": (m_dome, m_fork, m_wall),
            "params": {"smooth": smooth, "sigma_m": sigma, "relax": relax, "lo": float(lo), "hi": float(hi), "wlo": float(wlo), "whi": float(whi)}}


def crater(dem, sigma, args):
    """Meteor Crater, s 0.12, e 1.0, floor centroid pixel (513, 508), natural heights (no envelope: a control)."""
    img = load_tile(dem, "meteor_crater")
    mpp = 1.953
    s = 0.12
    k = 1.0 / (s * mpp)
    u = 513.0 + X * k
    v = 508.0 + Z * k
    D = bilinear(img, u, v, mirror=False)
    floor_ref = np.percentile(D[np.hypot(X, Z) < 12.0], 50)
    H = (D - floor_ref) * s * 1.0
    H = H - H.min() + 1.0  # keep the floor above zero
    H = np.maximum(H, 1.0)
    # the 400 m map holds the tile (240 m wide at this scale); past it the edge value is held
    sm = gaussian(H, sigma)
    region = np.hypot(X, Z) < 90.0
    whole = np.ones_like(X)
    return H, sm, {"raw": region_stats(H, region), "smoothed": region_stats(sm, region),
                   "whole_grid_raw": region_stats(H, whole), "whole_grid_smoothed": region_stats(sm, whole),
                   "floor_ref_m": float(floor_ref), "rim_height_m": round(float(sm[region].max() - sm[np.hypot(X, Z) < 12].mean()), 1)}


# ---- pictures ----

def hillshade(h, az=315.0, alt=40.0):
    gz, gx = np.gradient(h, STEP)
    slope = np.arctan(np.hypot(gx, gz))
    aspect = np.arctan2(gz, -gx)
    a = math.radians(360.0 - az + 90.0)
    el = math.radians(alt)
    sh = np.sin(el) * np.cos(slope) + np.cos(el) * np.sin(slope) * np.cos(a - aspect)
    return np.clip(sh, 0, 1)


def save_png(arr, path, scale=3):
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    img = img.resize((arr.shape[1] * scale, arr.shape[0] * scale), Image.NEAREST)
    img.save(path)


def review(res, review_dir, tag):
    os.makedirs(review_dir, exist_ok=True)
    final = res["weight"] * today_approx(X, Z) + (1.0 - res["weight"]) * res["height"]
    hs = hillshade(final)
    rgb = np.stack([hs * 200 + 30, hs * 190 + 25, hs * 170 + 20], axis=-1)
    # corridors dim outlines
    edge = (np.abs(res["cmask"] - 0.5) < 0.04)
    rgb[edge] = [255, 120, 40]
    rgb = rgb[::-1]  # north (z -) at the bottom? keep z down: flip so +z is toward the viewer
    rgb = rgb[::-1]
    save_png(rgb, os.path.join(review_dir, f"shaded-{tag}.png"))
    sl = slope_deg(final)
    band = np.zeros(final.shape + (3,))
    band[sl < 24] = [60, 140, 70]
    band[(sl >= 24) & (sl < 30)] = [180, 200, 60]
    band[(sl >= 30) & (sl < 45.6)] = [230, 160, 40]
    band[(sl >= 45.6) & (sl < 63.3)] = [220, 80, 40]
    band[sl >= 63.3] = [120, 20, 120]
    save_png(band, os.path.join(review_dir, f"slope-bands-{tag}.png"))
    own = res["mask"] > 0.5
    for name, h, lbl in (("raw", res["raw_height"], "raw"), ("smoothed", res["height"], "smoothed")):
        lm = launch_mask(h)
        img = np.zeros(h.shape + (3,))
        base = hillshade(h) * 120 + 40
        img[..., 0] = base
        img[..., 1] = base
        img[..., 2] = base
        img[lm & own] = [255, 60, 40]
        img[~own] = img[~own] * 0.35
        save_png(img, os.path.join(review_dir, f"launch-cells-{lbl}-{tag}.png"))
    for name, h in (("raw", res["crater_raw"]), ("smoothed", res["crater"])):
        lm = launch_mask(h)
        base = hillshade(h) * 120 + 40
        img = np.stack([base, base, base], axis=-1)
        img[lm] = [255, 60, 40]
        save_png(img, os.path.join(review_dir, f"launch-cells-crater-{name}-{tag}.png"))
    final_c = res["crater"]
    hs2 = hillshade(final_c)
    save_png(np.stack([hs2 * 200 + 30, hs2 * 190 + 25, hs2 * 170 + 20], axis=-1), os.path.join(review_dir, f"shaded-crater-{tag}.png"))


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    ap = argparse.ArgumentParser()
    ap.add_argument("--dem", default="/home/andrew/Projects/scrapkeep/.claude/worktrees/game-completion-plan-75f776/artifacts/local/alpha/dem")
    ap.add_argument("--out", default=os.path.join(here, "..", "src", "world", "terrain"))
    ap.add_argument("--review", default=None)
    ap.add_argument("--routes", default=os.path.join(here, "traversal_lines_probe.json"))
    ap.add_argument("--smooth", default="S1", choices=["S1", "S2", "S3"])
    ap.add_argument("--s-dome", type=float, default=0.33, dest="s_dome")
    ap.add_argument("--e-dome", type=float, default=0.5, dest="e_dome")
    ap.add_argument("--dome-rmax", type=float, default=9.0, dest="dome_rmax")
    ap.add_argument("--s-horse", type=float, default=0.09, dest="s_horse")
    ap.add_argument("--s-wall", type=float, default=0.15, dest="s_wall")
    ap.add_argument("--hs-u", type=float, default=90.0, dest="hs_u")
    ap.add_argument("--hs-v", type=float, default=415.0, dest="hs_v")
    ap.add_argument("--gamma", type=float, default=0.8)
    ap.add_argument("--tag", default=None)
    ap.add_argument("--null", action="store_true", help="control: weight 1 everywhere, so the probe map equals today's Reach")
    args = ap.parse_args()
    res = build(args)
    os.makedirs(args.out, exist_ok=True)
    h = res["height"].astype("<f4")
    w = res["weight"].astype("<f4")
    if args.null:
        w = np.ones_like(w)
    blob = h.tobytes() + w.tobytes()
    crater_blob = res["crater"].astype("<f4").tobytes()
    with open(os.path.join(args.out, "reach_probe.bin"), "wb") as f:
        f.write(blob)
    with open(os.path.join(args.out, "crater_probe.bin"), "wb") as f:
        f.write(crater_blob)
    meta = {"unit": "TP", "args": {k: v for k, v in vars(args).items() if k not in ("dem", "out", "review", "routes")},
            "params": res["params"], "stats": res["stats"],
            "hash_reach": hashlib.sha256(blob).hexdigest(), "hash_crater": hashlib.sha256(crater_blob).hexdigest()}
    with open(os.path.join(args.out, "reach_probe.json"), "w") as f:
        json.dump(meta, f, indent=1)
    if args.review:
        review(res, args.review, args.tag or args.smooth)
    print(json.dumps(res["stats"], indent=1))
    print("hash", meta["hash_reach"][:16], meta["hash_crater"][:16])


if __name__ == "__main__":
    main()
