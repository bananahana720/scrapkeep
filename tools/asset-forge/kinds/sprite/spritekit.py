"""Sprite pipeline maths, stdlib only: the shade ramp, quantizing, box downsampling, outline
and sheet assembly. The entry (inside Blender), the validator and the tests all import this
one module, so the ramp the harness paints with is the ramp the validator checks against."""

# The shade ramp: every palette role at four fixed value steps.
#   shadow  role * 0.42        dark   role * 0.68
#   base    the role itself    light  role moved 28% of the way to white
STEPS = ("shadow", "dark", "base", "light")
SHADOW_MUL = 0.42
DARK_MUL = 0.68
LIGHT_TOWARD_WHITE = 0.28


def hex_rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def shade(rgb, step):
    if step == "shadow":
        return tuple(round(c * SHADOW_MUL) for c in rgb)
    if step == "dark":
        return tuple(round(c * DARK_MUL) for c in rgb)
    if step == "base":
        return tuple(rgb)
    if step == "light":
        return tuple(round(c + (255 - c) * LIGHT_TOWARD_WHITE) for c in rgb)
    raise ValueError("unknown shade step %r (steps: %s)" % (step, ", ".join(STEPS)))


def build_ramp(palette):
    """{role: hex} -> {"role.step": (r, g, b)} in a fixed order."""
    ramp = {}
    for role in sorted(palette):
        base = hex_rgb(palette[role])
        for step in STEPS:
            ramp["%s.%s" % (role, step)] = shade(base, step)
    return ramp


def luma(rgb):
    return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]


def darkest(ramp):
    """(key, rgb) of the darkest ramp colour; this is the outline colour."""
    key = min(sorted(ramp), key=lambda k: luma(ramp[k]))
    return key, ramp[key]


def colour_distance(a, b):
    """'Redmean' weighted RGB distance squared; cheap and close to what the eye sees."""
    rm = (a[0] + b[0]) / 2
    dr, dg, db = a[0] - b[0], a[1] - b[1], a[2] - b[2]
    return (2 + rm / 256) * dr * dr + 4 * dg * dg + (2 + (255 - rm) / 256) * db * db


class Quantizer:
    def __init__(self, ramp):
        self.entries = [(k, ramp[k]) for k in sorted(ramp)]
        self.cache = {}

    def nearest(self, rgb):
        hit = self.cache.get(rgb)
        if hit is None:
            hit = min(self.entries, key=lambda e: colour_distance(rgb, e[1]))[1]
            self.cache[rgb] = hit
        return hit


def downsample(rows, ss, cut=0.5):
    """Box-downsamples RGBA rows by an integer factor. A cell is opaque when its mean alpha is at
    least `cut`; its colour is the alpha-weighted mean of the cell's samples. Returns rows of
    (r, g, b, a) with a in {0, 255}; transparent cells are (0, 0, 0, 0)."""
    h, w = len(rows), len(rows[0])
    out = []
    for cy in range(h // ss):
        line = []
        for cx in range(w // ss):
            sa = sr = sg = sb = 0.0
            for y in range(cy * ss, cy * ss + ss):
                row = rows[y]
                for x in range(cx * ss, cx * ss + ss):
                    r, g, b, a = row[x]
                    sa += a
                    sr += r * a
                    sg += g * a
                    sb += b * a
            if sa / (ss * ss * 255.0) >= cut and sa > 0:
                line.append((round(sr / sa), round(sg / sa), round(sb / sa), 255))
            else:
                line.append((0, 0, 0, 0))
        out.append(line)
    return out


def quantize_rows(rows, ramp):
    q = Quantizer(ramp)
    out = []
    for row in rows:
        out.append([(*q.nearest(p[:3]), 255) if p[3] else (0, 0, 0, 0) for p in row])
    return out


def add_outline(rows, rgb):
    """A 1 px outer outline (4-neighbour) in `rgb` around every opaque pixel."""
    h, w = len(rows), len(rows[0])
    out = [list(r) for r in rows]
    for y in range(h):
        for x in range(w):
            if rows[y][x][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and rows[ny][nx][3]:
                    out[y][x] = (*rgb, 255)
                    break
    return out


def stack_rows(frames):
    """Frames (each a list of rows) stacked top to bottom: row k is direction k."""
    out = []
    for f in frames:
        out += f
    return out


def upscale(rows, k):
    out = []
    for row in rows:
        wide = [p for p in row for _ in range(k)]
        out += [wide] * k
    return out


def preview_rows(frames, scale, bg=(36, 42, 40, 255), gap=4):
    """Frames side by side on a charcoal ground: one row nearest-upscaled by `scale`, and
    below it the same frames at 1x (the size the game shows them)."""
    fh, fw = len(frames[0]), len(frames[0][0])
    width = gap + len(frames) * (fw * scale + gap)
    big_h = fh * scale
    height = gap + big_h + gap + fh + gap
    canvas = [[bg] * width for _ in range(height)]

    def blit(rows, ox, oy):
        for y, row in enumerate(rows):
            for x, p in enumerate(row):
                if p[3]:
                    canvas[oy + y][ox + x] = p

    for i, f in enumerate(frames):
        blit(upscale(f, scale), gap + i * (fw * scale + gap), gap)
        blit(f, gap + i * (fw * scale + gap), gap + big_h + gap)
    return width, height, canvas


def opaque_count(rows):
    return sum(1 for row in rows for p in row if p[3])
