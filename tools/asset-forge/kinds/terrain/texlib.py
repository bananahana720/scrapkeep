"""Seamless texture toolkit for the terrain kind. Needs numpy, so it runs inside Blender's
Python (the forge's runner), never in system Python. Original code, written for Scrapkeep.

Conventions
- A "field" is a float32 array (n, n) nominally in [0, 1]. A colour image is (n, n, 3) float
  in [0, 1], sRGB-encoded (the values that end up in the PNG).
- Every generator is periodic: opposite edges of the array continue into each other, so a
  tile of any generator output, or of anything built only from this module's functions,
  repeats with no seam. `period` / `cells` are lattice cells across the whole tile.
- Everything is deterministic from `seed`.
"""
import math
import struct
import zlib

import numpy as np


# --- helpers ---------------------------------------------------------------------------
def _rng(seed):
    return np.random.default_rng(int(seed) & 0xFFFFFFFF)


def _grid(n):
    """Pixel-centre coordinates in [0, 1) as (y, x) broadcastable arrays."""
    t = (np.arange(n, dtype=np.float64) + 0.5) / n
    return t[:, None], t[None, :]


def normalize(a, lo=0.0, hi=1.0):
    """Stretch min..max of `a` to lo..hi."""
    a = np.asarray(a, dtype=np.float64)
    mn, mx = float(a.min()), float(a.max())
    if mx - mn < 1e-12:
        return np.full(a.shape, lo, dtype=np.float32)
    return (lo + (a - mn) / (mx - mn) * (hi - lo)).astype(np.float32)


def remap(a, in_lo, in_hi, out_lo=0.0, out_hi=1.0, clamp=True):
    t = (np.asarray(a, dtype=np.float64) - in_lo) / (in_hi - in_lo)
    if clamp:
        t = np.clip(t, 0.0, 1.0)
    return (out_lo + t * (out_hi - out_lo)).astype(np.float32)


def smoothstep(e0, e1, x):
    t = np.clip((np.asarray(x, dtype=np.float64) - e0) / (e1 - e0), 0.0, 1.0)
    return (t * t * (3 - 2 * t)).astype(np.float32)


def contrast(a, amount):
    """Push values away from 0.5; amount 1 = unchanged, 2 = stronger."""
    return np.clip((np.asarray(a, dtype=np.float64) - 0.5) * amount + 0.5, 0.0, 1.0).astype(np.float32)


# --- noise on a wrapped lattice -----------------------------------------------------------
def _fade(t):
    return t * t * t * (t * (t * 6 - 15) + 10)


def value_noise(n, period, seed=0):
    """Smooth value noise, `period` x `period` lattice cells wrapped over the tile. [0, 1]."""
    period = int(period)
    lat = _rng(seed).random((period, period))
    y, x = _grid(n)
    fy, fx = y * period, x * period
    y0, x0 = np.floor(fy).astype(int), np.floor(fx).astype(int)
    ty, tx = _fade(fy - y0), _fade(fx - x0)
    y0, x0 = y0 % period, x0 % period
    y1, x1 = (y0 + 1) % period, (x0 + 1) % period
    top = lat[y0, x0] * (1 - tx) + lat[y0, x1] * tx
    bot = lat[y1, x0] * (1 - tx) + lat[y1, x1] * tx
    return (top * (1 - ty) + bot * ty).astype(np.float32)


def gradient_noise(n, period, seed=0):
    """Perlin-style gradient noise with wrapped gradients. Roughly [0, 1], centred on 0.5."""
    period = int(period)
    ang = _rng(seed).random((period, period)) * (2 * math.pi)
    gx, gy = np.cos(ang), np.sin(ang)
    y, x = _grid(n)
    fy, fx = y * period, x * period
    y0, x0 = np.floor(fy).astype(int), np.floor(fx).astype(int)
    dy, dx = fy - y0, fx - x0
    ty, tx = _fade(dy), _fade(dx)
    y0, x0 = y0 % period, x0 % period
    y1, x1 = (y0 + 1) % period, (x0 + 1) % period

    def dot(yi, xi, oy, ox):
        return gx[yi, xi] * (dx - ox) + gy[yi, xi] * (dy - oy)
    top = dot(y0, x0, 0, 0) * (1 - tx) + dot(y0, x1, 0, 1) * tx
    bot = dot(y1, x0, 1, 0) * (1 - tx) + dot(y1, x1, 1, 1) * tx
    v = top * (1 - ty) + bot * ty
    return np.clip(v * 0.7 + 0.5, 0.0, 1.0).astype(np.float32)


def fbm(n, period, octaves=4, seed=0, kind="gradient", gain=0.5, lacunarity=2):
    """Fractal sum of noise octaves. The period is multiplied by `lacunarity` (an integer,
    default doubled) each octave, so every octave stays seamless. Normalised to [0, 1]."""
    fn = gradient_noise if kind == "gradient" else value_noise
    total = np.zeros((n, n), dtype=np.float64)
    amp, norm = 1.0, 0.0
    for o in range(int(octaves)):
        p = int(period) * int(lacunarity) ** o
        if p > n:
            break
        total += amp * fn(n, p, seed + 101 * o)
        norm += amp
        amp *= gain
    return normalize(total / max(norm, 1e-9))


def ridged(n, period, octaves=4, seed=0):
    """Ridged fbm (sharp crests, soft valleys), [0, 1]."""
    return normalize(1.0 - np.abs(fbm(n, period, octaves, seed).astype(np.float64) * 2 - 1))


def worley(n, cells, seed=0, mode="f1"):
    """Cellular noise on a wrapped lattice of `cells` x `cells` jittered points.
    mode: "f1" distance to nearest point, "f2" to second nearest, "edge" f2 - f1 (cell
    borders are ~0, cell middles high), "id" a flat random value per cell. Returns [0, 1]
    (distance modes are normalised by a constant, not min-max, so reseeding keeps contrast)."""
    cells = int(cells)
    pts = _rng(seed).random((cells, cells, 3))  # jitter y, jitter x, id value
    y, x = _grid(n)
    fy, fx = y * cells, x * cells
    cy, cx = np.floor(fy).astype(int), np.floor(fx).astype(int)
    f1 = np.full((n, n), 9.0)
    f2 = np.full((n, n), 9.0)
    cid = np.zeros((n, n))
    for oy in (-1, 0, 1):
        for ox in (-1, 0, 1):
            ny, nx = cy + oy, cx + ox
            wy, wx = ny % cells, nx % cells
            py = ny + pts[wy, wx, 0]
            px = nx + pts[wy, wx, 1]
            d = np.sqrt((fy - py) ** 2 + (fx - px) ** 2)
            closer = d < f1
            f2 = np.where(closer, f1, np.minimum(f2, d))
            cid = np.where(closer, pts[wy, wx, 2], cid)
            f1 = np.where(closer, d, f1)
    if mode == "f1":
        out = f1 / 1.0
    elif mode == "f2":
        out = f2 / 1.4
    elif mode == "edge":
        out = (f2 - f1) / 0.8
    elif mode == "id":
        out = cid
    else:
        raise ValueError("worley mode must be f1, f2, edge or id")
    return np.clip(out, 0.0, 1.0).astype(np.float32)


# --- filters (all wrap) ----------------------------------------------------------------
def blur(a, sigma):
    """Gaussian blur by FFT. The FFT is periodic, so a seamless input stays seamless. `sigma` in pixels."""
    a = np.asarray(a, dtype=np.float64)
    if sigma <= 0:
        return a.astype(np.float32)
    n0, n1 = a.shape[:2]
    fy = np.fft.fftfreq(n0)[:, None]
    fx = np.fft.fftfreq(n1)[None, :]
    k = np.exp(-2 * (math.pi * sigma) ** 2 * (fy ** 2 + fx ** 2))
    if a.ndim == 2:
        return np.real(np.fft.ifft2(np.fft.fft2(a) * k)).astype(np.float32)
    return np.stack([np.real(np.fft.ifft2(np.fft.fft2(a[..., c]) * k)) for c in range(a.shape[2])], axis=-1).astype(np.float32)


def _sample_wrapped(a, yy, xx):
    """Bilinear sample of `a` at float pixel coordinates (wrapping)."""
    n0, n1 = a.shape[:2]
    y0, x0 = np.floor(yy).astype(int), np.floor(xx).astype(int)
    ty, tx = yy - y0, xx - x0
    y0, x0 = y0 % n0, x0 % n1
    y1, x1 = (y0 + 1) % n0, (x0 + 1) % n1
    if a.ndim == 3:
        ty, tx = ty[..., None], tx[..., None]
    top = a[y0, x0] * (1 - tx) + a[y0, x1] * tx
    bot = a[y1, x0] * (1 - tx) + a[y1, x1] * tx
    return top * (1 - ty) + bot * ty


def warp(a, amount, period=3, seed=0):
    """Wrapped domain warp: displace `a` by two smooth periodic fields. `amount` is the
    largest shift in pixels. Works on fields and colour images."""
    a = np.asarray(a, dtype=np.float64)
    n = a.shape[0]
    dy = (gradient_noise(n, period, seed + 7).astype(np.float64) - 0.5) * 2 * amount
    dx = (gradient_noise(n, period, seed + 13).astype(np.float64) - 0.5) * 2 * amount
    yy, xx = np.mgrid[0:n, 0:a.shape[1]].astype(np.float64)
    return _sample_wrapped(a, yy + dy, xx + dx).astype(np.float32)


def shift(a, dy, dx):
    """Roll by whole pixels (wraps)."""
    return np.roll(np.asarray(a), (int(dy), int(dx)), axis=(0, 1))


# --- height derived maps ---------------------------------------------------------------
def normal_from_height(h, strength=1.0):
    """Tangent-space normal map, OpenGL convention (Y+ up, what Godot reads), as float rgb in
    [0, 1] (n * 0.5 + 0.5). Row 0 is the top of the image, so green is +d(height)/d(row).
    strength 1.0 gives a gentle relief, 3.0 a deep one. Wrapped differences keep it seamless."""
    h = np.asarray(h, dtype=np.float64)
    n = h.shape[0]
    scale = strength * n / 16.0
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5 * scale
    dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5 * scale
    nx, ny, nz = -dx, dy, np.ones_like(h)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    return (np.stack([nx / ln, ny / ln, nz / ln], axis=-1) * 0.5 + 0.5).astype(np.float32)


def ao_from_height(h, radius=None, strength=1.0):
    """Cavity ambient occlusion: pixels lower than their blurred surroundings darken.
    1 = open, lower = occluded. `radius` is the blur sigma in pixels (default n / 32)."""
    h = np.asarray(h, dtype=np.float64)
    n = h.shape[0]
    r = radius if radius is not None else n / 32.0
    cav = blur(h, r).astype(np.float64) - h
    cav = cav / max(float(np.abs(cav).max()), 1e-9)
    return np.clip(1.0 - np.clip(cav, 0.0, 1.0) * strength * 0.8, 0.0, 1.0).astype(np.float32)


# --- palette ------------------------------------------------------------------------------
def _hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def palette_rgb(palette, role):
    """sRGB float triple for a palette role name (params["palette"] maps role -> hex)."""
    if role not in palette:
        raise KeyError("no palette role %r; roles are %s" % (role, ", ".join(sorted(palette))))
    return _hex_rgb(palette[role])


def posterize(t, levels, soften=0.0):
    """Quantise a field into `levels` flat bands (painted look). `soften` 0..1 rounds the steps."""
    t = np.clip(np.asarray(t, dtype=np.float64), 0.0, 1.0)
    levels = max(int(levels), 2)
    x = t * (levels - 1)
    lo = np.floor(x)
    f = x - lo
    if soften > 0:
        w = 0.5 * min(float(soften), 1.0)
        return ((lo + smoothstep(0.5 - w, 0.5 + w, f)) / (levels - 1)).astype(np.float32)
    return (np.round(x) / (levels - 1)).astype(np.float32)


def ramp(t, stops, palette, steps=None):
    """Map a field t in [0, 1] to colours along palette roles. `stops` is a list of role
    names (evenly spaced) or of (position, role) pairs. The result lies on straight lines
    between palette colours, which the validator accepts as palette-true. `steps` posterizes
    t first for a painted, banded look. Returns (n, n, 3) float sRGB."""
    t = np.clip(np.asarray(t, dtype=np.float64), 0.0, 1.0)
    if steps:
        t = posterize(t, steps).astype(np.float64)
    if stops and not isinstance(stops[0], (tuple, list)):
        k = len(stops)
        stops = [(i / (k - 1) if k > 1 else 0.0, s) for i, s in enumerate(stops)]
    pos = np.array([p for p, _ in stops], dtype=np.float64)
    cols = np.array([palette_rgb(palette, r) for _, r in stops], dtype=np.float64)
    out = np.stack([np.interp(t, pos, cols[:, c]) for c in range(3)], axis=-1)
    return out.astype(np.float32)


# --- seam metric -------------------------------------------------------------------------
SEAM_FLOOR = 0.002   # per-pixel mean difference below which we stop calling it a step


def seam_metric(a):
    """Seam score for one map: mean wrap-pair difference / mean adjacent-pair difference,
    the larger of the x and y directions. ~1.0 is seamless (the wrap pair looks like any
    other neighbours). Differences are summed over channels, values scaled to [0, 1]. The
    denominator is floored at SEAM_FLOOR so flat areas do not divide by zero."""
    a = np.asarray(a, dtype=np.float64)
    if a.ndim == 2:
        a = a[..., None]
    worst = 0.0
    for axis in (1, 0):
        d = np.abs(np.diff(a, axis=axis)).sum(axis=-1)
        adj = float(d.mean())
        first = np.take(a, 0, axis=axis)
        last = np.take(a, -1, axis=axis)
        wrap = float(np.abs(first - last).sum(axis=-1).mean())
        worst = max(worst, wrap / max(adj, SEAM_FLOOR))
    return worst


# --- png / tres writers -----------------------------------------------------------------
def _chunk(kind, body):
    return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))


def write_png(path, arr, bits=8):
    """Write float [0, 1] data: (n, n) as greyscale, (n, n, 3) as RGB. bits 8 or 16 (the
    height map uses 16 so shallow relief keeps its steps). Filter 0, so any reader copes."""
    a = np.clip(np.nan_to_num(np.asarray(arr, dtype=np.float64)), 0.0, 1.0)
    h, w = a.shape[:2]
    ctype = 0 if a.ndim == 2 else 2
    if bits == 16:
        data = np.round(a * 65535).astype(">u2")
    else:
        data = np.round(a * 255).astype(np.uint8)
    rows = data.reshape(h, -1).view(np.uint8) if bits == 16 else data.reshape(h, -1)
    raw = np.concatenate([np.zeros((h, 1), dtype=np.uint8), rows], axis=1).tobytes()
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n"
                + _chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, bits, ctype, 0, 0, 0))
                + _chunk(b"IDAT", zlib.compress(raw, 6)) + _chunk(b"IEND", b""))


from tres import PLACEHOLDER, tres_text  # noqa: E402,F401  (stdlib, shared with promote)


# --- preview -----------------------------------------------------------------------------
def light_tile(albedo, normal, rough, ao, light=(-0.45, 0.55, 0.70)):
    """Lit albedo for the preview: lambert from `light` (tangent space, x right, y up the
    image, z out), cavity AO, a small specular that rough maps suppress. No tone mapping."""
    L = np.array(light, dtype=np.float64)
    L /= np.linalg.norm(L)
    nrm = np.asarray(normal, dtype=np.float64) * 2 - 1
    ndl = np.clip((nrm * L).sum(axis=-1), 0.0, 1.0)
    hv = L + np.array([0.0, 0.0, 1.0])
    hv /= np.linalg.norm(hv)
    ndh = np.clip((nrm * hv).sum(axis=-1), 0.0, 1.0)
    r = np.asarray(rough, dtype=np.float64)
    spec = (ndh ** (4 + 120 * (1 - r) ** 2)) * (1 - r) * 0.5
    shade = (0.30 + 0.70 * ndl) * (0.45 + 0.55 * np.asarray(ao, dtype=np.float64))
    out = np.asarray(albedo, dtype=np.float64) * shade[..., None] * 1.25 + spec[..., None]
    return np.clip(out, 0.0, 1.0).astype(np.float32)


def preview_sheet(albedo, normal, rough, ao, height):
    """2 x 2 lit tiles on top (any seam or repeat shows at the middle cross), then a strip of
    the five maps below: albedo, normal, roughness, ao, height. Returns float rgb."""
    n = albedo.shape[0]
    lit = light_tile(albedo, normal, rough, ao)
    big = np.tile(lit, (2, 2, 1))
    thumb = n * 2 // 5

    def small(m):
        m = np.asarray(m, dtype=np.float32)
        if m.ndim == 2:
            m = np.repeat(m[..., None], 3, axis=2)
        idx = (np.arange(thumb) * n // thumb)
        return m[idx][:, idx]
    strip = np.concatenate([small(m) for m in (albedo, normal, rough, ao, height)], axis=1)
    pad = np.full((thumb, big.shape[1] - strip.shape[1], 3), 0.14, dtype=np.float32)
    return np.concatenate([big, np.concatenate([strip, pad], axis=1)], axis=0)
