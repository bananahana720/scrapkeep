"""Deterministic particle preview for a vfx spec. Stdlib only.

Particle state is a pure function of (spec, emitter, slot, time). Randomness comes from a
portable 32-bit integer hash (see README: "The hash"), so a GDScript port can match bit for bit
(GDScript ints are 64-bit; mask with 0xFFFFFFFF after every multiply). The motion model is
analytic and approximates CPUParticles3D; it is a preview, not the engine.

Motion: p(a) = offset + emit_point + dir * dist(a) + 0.5 * gravity * a^2, with
dist(a) = v*a - 0.5*damp*a^2, held at v^2/(2*damp) once the speed hits zero (a >= v/damp).
"""
import math

M32 = 0xFFFFFFFF

# channels: which random number a particle draws
CH_AZIMUTH, CH_POLAR, CH_SPEED, CH_PX, CH_PY, CH_PZ, CH_SCALE, CH_DAMP, CH_BIRTH = range(9)


def mix32(x):
    """lowbias32 (Chris Wellons): xor-shift-multiply, 32-bit."""
    x &= M32
    x ^= x >> 16
    x = (x * 0x7FEB352D) & M32
    x ^= x >> 15
    x = (x * 0x846CA68B) & M32
    x ^= x >> 16
    return x


def rand(seed, emitter, slot, channel):
    """Uniform [0, 1) from (seed, emitter, slot, channel)."""
    x = mix32((seed + 0x9E3779B9) & M32)
    for v in (emitter, slot, channel):
        x = mix32(x ^ (((v + 1) * 0x85EBCA6B) & M32))
    return x / 4294967296.0


def _unit(v):
    n = math.sqrt(sum(c * c for c in v))
    return [c / n for c in v]


def _basis(d):
    """Two unit vectors perpendicular to unit d."""
    ref = [1.0, 0.0, 0.0] if abs(d[0]) < 0.9 else [0.0, 0.0, 1.0]
    u = _unit([d[1] * ref[2] - d[2] * ref[1], d[2] * ref[0] - d[0] * ref[2], d[0] * ref[1] - d[1] * ref[0]])
    w = [d[1] * u[2] - d[2] * u[1], d[2] * u[0] - d[0] * u[2], d[0] * u[1] - d[1] * u[0]]
    return u, w


def lerp(a, b, t):
    return a + (b - a) * t


def sample_curve(pts, t):
    if t <= pts[0][0]:
        return pts[0][1]
    for (t0, v0), (t1, v1) in zip(pts, pts[1:]):
        if t <= t1:
            return lerp(v0, v1, (t - t0) / (t1 - t0))
    return pts[-1][1]


def ramp_hexes(e, palette):
    return [(s["t"], palette[s["role"]], s.get("alpha", 1.0)) for s in e["color_ramp"]]


def hex_rgb(h):
    return [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]


def sample_ramp(stops, t):
    """stops: [(t, hex, alpha)]; linear in sRGB floats like Godot's Gradient. -> (r, g, b, a)."""
    cols = [(s[0], hex_rgb(s[1]) + [s[2]]) for s in stops]
    if t <= cols[0][0]:
        return tuple(cols[0][1])
    for (t0, c0), (t1, c1) in zip(cols, cols[1:]):
        if t <= t1:
            k = (t - t0) / (t1 - t0)
            return tuple(lerp(a, b, k) for a, b in zip(c0, c1))
    return tuple(cols[-1][1])


def emit_point(e, seed, ei, slot):
    shape = e["shape"]
    if shape == "point":
        return [0.0, 0.0, 0.0]
    if shape == "box":
        return [(rand(seed, ei, slot, ch) * 2 - 1) * e["extents"][i] for i, ch in enumerate((CH_PX, CH_PY, CH_PZ))]
    # sphere: a direction from two draws, radius cube-root of a third (uniform in volume)
    cz = rand(seed, ei, slot, CH_PX) * 2 - 1
    az = rand(seed, ei, slot, CH_PY) * 2 * math.pi
    r = e["extents"][0] * rand(seed, ei, slot, CH_PZ) ** (1.0 / 3.0)
    s = math.sqrt(max(0.0, 1 - cz * cz))
    return [r * s * math.cos(az), r * cz, r * s * math.sin(az)]


def birth_time(e, seed, ei, slot):
    base = (1.0 - e["explosiveness"]) * e["lifetime"] * (slot / e["amount"])
    jitter = e["randomness"] * e["lifetime"] * 0.25 * (rand(seed, ei, slot, CH_BIRTH) - 0.5)
    return max(0.0, base + jitter)


def particle(spec, palette, ei, slot, t):
    """State of one particle at time t, or None when unborn or dead.
    -> {"pos": [x, y, z], "age": 0..1, "size": metres, "rgba": (r, g, b, a) floats 0..1}"""
    e = spec["emitters"][ei]
    seed = spec["seed"]
    life = e["lifetime"]
    since = t - birth_time(e, seed, ei, slot)
    if since < 0:
        return None
    cycle = 0
    if e["one_shot"]:
        if since >= life:
            return None
    else:
        cycle = int(since // life)
        since -= cycle * life
    key = slot + e["amount"] * cycle
    d = _unit(e["direction"])
    u, w = _basis(d)
    polar = math.radians(e["spread"]) * rand(seed, ei, key, CH_POLAR)
    az = 2 * math.pi * rand(seed, ei, key, CH_AZIMUTH)
    sp, cp = math.sin(polar), math.cos(polar)
    dirv = [d[i] * cp + (u[i] * math.cos(az) + w[i] * math.sin(az)) * sp for i in range(3)]
    v = lerp(e["velocity"][0], e["velocity"][1], rand(seed, ei, key, CH_SPEED))
    damp = lerp(e["damping"][0], e["damping"][1], rand(seed, ei, key, CH_DAMP))
    if damp > 0:
        a_eff = min(since, v / damp)
        dist = v * a_eff - 0.5 * damp * a_eff * a_eff
    else:
        dist = v * since
    p0 = emit_point(e, seed, ei, key)
    pos = [e["offset"][i] + p0[i] + dirv[i] * dist + 0.5 * e["gravity"][i] * since * since for i in range(3)]
    age = since / life
    scale = lerp(e["scale"][0], e["scale"][1], rand(seed, ei, key, CH_SCALE)) * sample_curve(e["scale_curve"], age)
    if e["mesh"] == "sphere":
        base = e["mesh_size"][0]
    elif e["mesh"] == "quad":
        base = (e["mesh_size"][0] + e["mesh_size"][1]) / 2
    else:
        base = max(e["mesh_size"])
    rgba = sample_ramp(ramp_hexes(e, palette), age)
    return {"pos": pos, "age": age, "size": base * scale, "rgba": rgba}


def duration(spec):
    """Seconds until every one-shot emitter is dead; two lifetimes for a looping one."""
    end = 0.0
    for e in spec["emitters"]:
        if e["one_shot"]:
            span = e["lifetime"] * (2.0 - e["explosiveness"]) + e["randomness"] * e["lifetime"] * 0.125
        else:
            span = 2 * e["lifetime"]
        end = max(end, span)
    return end


def frame(spec, palette, t):
    out = []
    for ei, e in enumerate(spec["emitters"]):
        for slot in range(e["amount"]):
            p = particle(spec, palette, ei, slot, t)
            if p:
                p["emitter"] = ei
                out.append(p)
    return out


def cloud_radius(spec, palette, step=0.02):
    """Largest distance from the effect origin any particle reaches, over the whole effect."""
    best = 0.0
    for k in range(int(duration(spec) / step) + 2):
        for p in frame(spec, palette, k * step):
            best = max(best, math.sqrt(sum(c * c for c in p["pos"])))
    return best


def peak_size(spec, palette):
    """Smallest per-emitter peak particle size in metres (an emitter whose biggest visible particle is
    tiny is fine sparkle). None when nothing is ever visible."""
    peaks = {}
    step = 0.04
    for k in range(int(duration(spec) / step) + 1):
        for p in frame(spec, palette, k * step):
            if p["rgba"][3] > 0.05:
                peaks[p["emitter"]] = max(peaks.get(p["emitter"], 0.0), p["size"])
    return min(peaks.values()) if peaks else None


# --- strip render -----------------------------------------------------------------------
FRAMES = 6
CELL = 160
YAW = math.radians(35.0)
PITCH = math.radians(28.0)
BG = (36, 42, 40)


def project(pos):
    """World (x, y up, z) -> (screen x, screen y up, depth); orthographic 3/4 view."""
    cy, sy = math.cos(YAW), math.sin(YAW)
    cp, sp = math.cos(PITCH), math.sin(PITCH)
    x1 = pos[0] * cy + pos[2] * sy
    z1 = -pos[0] * sy + pos[2] * cy
    return x1, pos[1] * cp - z1 * sp, pos[1] * sp + z1 * cp


def frame_times(spec):
    end = min(duration(spec), max(e["lifetime"] for e in spec["emitters"])) * 0.95   # t = 0.05 .. ~lifetime
    return [0.05 + (end - 0.05) * k / (FRAMES - 1) for k in range(FRAMES)]


def pixels_per_metre(spec, palette, times):
    left = right = up = down = 0.25
    for t in times:
        for p in frame(spec, palette, t):
            sx, sy, _ = project(p["pos"])
            left, right = max(left, -sx), max(right, sx)
            up, down = max(up, sy), max(down, -sy)
    half = max(left, right) + 0.2
    return max(8.0, min(80.0, 0.45 * CELL / half, 0.62 * CELL / (up + 0.2), 0.5 * CELL / (down + 0.1)))


def render_strip(spec, palette):
    """-> (width, height, rows) with rows of (r, g, b, 255); pure function of (spec, palette)."""
    times = frame_times(spec)
    ppm = pixels_per_metre(spec, palette, times)
    width, height = CELL * FRAMES, CELL
    grid = [[list(BG) for _ in range(width)] for _ in range(height)]
    ox, oy = CELL // 2, int(CELL * 0.72)
    petrol = [c * 255 for c in hex_rgb(palette.get("petrol", "365754"))]
    bone = [int(c * 255) for c in hex_rgb(palette.get("bone", "d2c5a5"))]
    for f, t in enumerate(times):
        x0 = f * CELL
        for k in range(48):
            a = k / 48 * 2 * math.pi
            sx, sy, _ = project([0.5 * math.cos(a), 0.0, 0.5 * math.sin(a)])
            _put(grid, x0 + ox + int(round(sx * ppm)), oy - int(round(sy * ppm)), petrol, 1.0, False)
        for y in range(height):
            grid[y][x0] = [20, 24, 23]
        for y in range(height - 4 - int(ppm), height - 4):   # a one-metre bar for scale
            grid[y][x0 + 8] = list(bone)
        drawn = frame(spec, palette, t)
        drawn.sort(key=lambda p: project(p["pos"])[2])
        for p in drawn:
            e = spec["emitters"][p["emitter"]]
            sx, sy, _ = project(p["pos"])
            r = max(1.5, 0.5 * p["size"] * ppm)
            rgb = [c * 255 * (e["emissive"] if e["blend"] == "add" else 1.0) for c in p["rgba"][:3]]
            _splat(grid, x0 + ox + sx * ppm, oy - sy * ppm, r, e["mesh"], rgb, p["rgba"][3], e["blend"] == "add")
    rows = [[(c[0], c[1], c[2], 255) for c in row] for row in grid]
    return width, height, rows


def _put(grid, x, y, rgb, alpha, add):
    if 0 <= y < len(grid) and 0 <= x < len(grid[0]):
        px = grid[y][x]
        for i in range(3):
            px[i] = int(min(255, px[i] + rgb[i] * alpha)) if add else int(px[i] * (1 - alpha) + min(255, rgb[i]) * alpha)


def _splat(grid, cx, cy, r, mesh, rgb, alpha, add):
    for y in range(int(math.floor(cy - r)), int(math.ceil(cy + r)) + 1):
        for x in range(int(math.floor(cx - r)), int(math.ceil(cx + r)) + 1):
            dx, dy = x - cx, y - cy
            if mesh in ("sphere", "quad"):
                inside = dx * dx + dy * dy <= r * r
            elif mesh == "box":
                inside = abs(dx) <= r and abs(dy) <= r
            else:  # prism: upright triangle
                inside = -r <= dy <= r and abs(dx) <= (dy + r) / 2
            if inside:
                _put(grid, x, y, rgb, alpha, add)


def write_strip(path, spec, palette):
    import pngio
    w, h, rows = render_strip(spec, palette)
    pngio.write(path, w, h, rows)
