"""Pixel-art canvas, stdlib only. Recipes import it (`import pixkit as px`); the entry calls
set_palette() first. Colours are never RGB: a colour is a ramp key naming a palette role and one
of four steps, so palette-strictness holds by construction. The ramp is the sprite kind's
(spritekit.py), shared so both kinds paint with the same colours.

Colour specs (anywhere a `colour` is taken):
    "oxide"            role at the base step          ("oxide.base")
    "oxide.dark"       role at a named step           (shadow, dark, base, light)
    ("oxide", 3)       role at a step index 0..3      (3 = light)
    None               transparent (erases)
A canvas holds ramp keys or None; to_rows() maps them to RGBA at the end.
"""
import os
import sys

_KINDS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(_KINDS, "sprite"))
import spritekit as sk  # noqa: E402

RAMP = {}


def set_palette(palette):
    """palette: {role: hex} from params.json."""
    RAMP.clear()
    RAMP.update(sk.build_ramp(palette))


def key(colour):
    """Normalises a colour spec to a ramp key (or None)."""
    if colour is None:
        return None
    if isinstance(colour, tuple):
        role, step = colour
        if not isinstance(step, int) or not 0 <= step < len(sk.STEPS):
            raise ValueError("step index must be 0..%d, got %r" % (len(sk.STEPS) - 1, step))
        colour = "%s.%s" % (role, sk.STEPS[step])
    if "." not in colour:
        colour += ".base"
    if colour not in RAMP:
        roles = sorted({k.split(".")[0] for k in RAMP})
        raise ValueError("colour %r is not in the ramp; roles: %s; steps: %s" % (colour, ", ".join(roles), ", ".join(sk.STEPS)))
    return colour


def shift_step(colour, delta):
    """The same role moved `delta` steps along the ramp (clamped), e.g. shift_step('oxide', -1)."""
    role, _, step = key(colour).partition(".")
    i = max(0, min(len(sk.STEPS) - 1, sk.STEPS.index(step) + delta))
    return "%s.%s" % (role, sk.STEPS[i])


BAYER4 = ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5))


class Canvas:
    def __init__(self, w, h):
        if not (isinstance(w, int) and isinstance(h, int) and w > 0 and h > 0):
            raise ValueError("canvas size must be positive integers, got %r x %r" % (w, h))
        self.w, self.h = w, h
        self.px = [[None] * w for _ in range(h)]

    # --- reading -------------------------------------------------------------------
    def get(self, x, y):
        return self.px[y][x] if 0 <= x < self.w and 0 <= y < self.h else None

    def copy(self):
        c = Canvas(self.w, self.h)
        c.px = [list(r) for r in self.px]
        return c

    # --- drawing: every op clips silently at the canvas edge ---------------------------
    def put(self, x, y, colour):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = key(colour)
        return self

    def rect(self, x, y, w, h, colour, filled=True):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                if filled or yy in (y, y + h - 1) or xx in (x, x + w - 1):
                    self.put(xx, yy, colour)
        return self

    def line(self, x0, y0, x1, y1, colour):
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self.put(x0, y0, colour)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy
        return self

    def circle(self, cx, cy, r, colour, filled=True):
        """Pixel centres within r of (cx, cy); half-integer centres give even-sized discs
        (cx=7.5 on a 16 canvas is its true centre)."""
        for y in range(self.h):
            for x in range(self.w):
                d = (x - cx) ** 2 + (y - cy) ** 2
                if filled:
                    if d <= r * r + 0.25:
                        self.put(x, y, colour)
                elif (r - 0.75) ** 2 < d <= (r + 0.25) ** 2:
                    self.put(x, y, colour)
        return self

    def ellipse(self, cx, cy, rx, ry, colour, filled=True):
        for y in range(self.h):
            for x in range(self.w):
                d = ((x - cx) / max(rx, 0.5)) ** 2 + ((y - cy) / max(ry, 0.5)) ** 2
                if filled:
                    if d <= 1.0 + 0.5 / max(rx, ry, 1):
                        self.put(x, y, colour)
                elif 0.55 < d <= 1.0 + 0.5 / max(rx, ry, 1):
                    self.put(x, y, colour)
        return self

    def fill(self, x, y, colour):
        """Flood fill (4-neighbour) of the region containing (x, y) that shares its colour."""
        if not (0 <= x < self.w and 0 <= y < self.h):
            return self
        target, new = self.px[y][x], key(colour)
        if target == new:
            return self
        stack = [(x, y)]
        while stack:
            cx, cy = stack.pop()
            if 0 <= cx < self.w and 0 <= cy < self.h and self.px[cy][cx] == target:
                self.px[cy][cx] = new
                stack += [(cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)]
        return self

    def paste(self, other, x, y):
        for yy in range(other.h):
            for xx in range(other.w):
                if other.px[yy][xx] is not None:
                    self.put(x + xx, y + yy, other.px[yy][xx])
        return self

    # --- symmetry and transforms ---------------------------------------------------------
    def mirror_x(self):
        """Copies the left half onto the right (mirror about the vertical centre line)."""
        for row in self.px:
            for x in range(self.w // 2):
                row[self.w - 1 - x] = row[x]
        return self

    def mirror_y(self):
        for y in range(self.h // 2):
            self.px[self.h - 1 - y] = list(self.px[y])
        return self

    def flip_x(self):
        self.px = [r[::-1] for r in self.px]
        return self

    def flip_y(self):
        self.px = self.px[::-1]
        return self

    def shift(self, dx, dy, wrap=False):
        new = [[None] * self.w for _ in range(self.h)]
        for y in range(self.h):
            for x in range(self.w):
                nx, ny = x + dx, y + dy
                if wrap:
                    nx, ny = nx % self.w, ny % self.h
                if 0 <= nx < self.w and 0 <= ny < self.h:
                    new[ny][nx] = self.px[y][x]
        self.px = new
        return self

    # --- shading ---------------------------------------------------------------------------
    def outline(self, colour=None, diagonals=False):
        """A 1 px outer outline around the opaque shape. With colour=None it is selective: each
        outline pixel takes the 'shadow' step of the role it touches, so the line is a darker
        version of the edge instead of one black ring."""
        out = [list(r) for r in self.px]
        nbrs = [(1, 0), (-1, 0), (0, 1), (0, -1)] + ([(1, 1), (1, -1), (-1, 1), (-1, -1)] if diagonals else [])
        fixed = key(colour) if colour is not None else None
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] is not None:
                    continue
                for dx, dy in nbrs:
                    v = self.get(x + dx, y + dy)
                    if v is not None:
                        out[y][x] = fixed or v.split(".")[0] + ".shadow"
                        break
        self.px = out
        return self

    def dither(self, x, y, w, h, a, b, level=0.5, pattern="bayer4"):
        """Ordered dither between two ramp shades over a rectangle: `level` is the share of
        pixels that take `b` (0 = all a, 1 = all b). Existing transparency is kept."""
        ka, kb = key(a), key(b)
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                if self.get(xx, yy) is None:
                    continue
                if pattern == "checker":
                    use_b = (xx + yy) % 2 == 0  # always 50%; `level` only picks bayer4's share
                else:
                    use_b = (BAYER4[yy % 4][xx % 4] + 0.5) / 16.0 <= level
                self.px[yy][xx] = kb if use_b else ka
        return self

    def replace(self, old, new):
        ko, kn = key(old), key(new)
        self.px = [[kn if v == ko else v for v in r] for r in self.px]
        return self

    # --- output ------------------------------------------------------------------------------
    def to_rows(self):
        return [[(*RAMP[v], 255) if v is not None else (0, 0, 0, 0) for v in r] for r in self.px]

    def colours(self):
        return sorted({v for r in self.px for v in r if v is not None})


def strip_rows(frames):
    """Frames (Canvas) side by side: one row of frames."""
    h = frames[0].h
    rows = [[] for _ in range(h)]
    for f in frames:
        for y, r in enumerate(f.to_rows()):
            rows[y] += r
    return rows


def as_frames(result):
    """What a recipe's build() may return: a Canvas, or a list of Canvases of equal size."""
    frames = [result] if isinstance(result, Canvas) else list(result)
    if not frames or not all(isinstance(f, Canvas) for f in frames):
        raise ValueError("build(params) must return a pixkit Canvas or a list of Canvases, got %r" % (result,))
    if len({(f.w, f.h) for f in frames}) != 1:
        raise ValueError("every frame must be the same size, got %s" % sorted({(f.w, f.h) for f in frames}))
    return frames
