"""Pixel validator (runs outside Blender, stdlib only).

validate(vdir, params, result, pack) -> list of checks {id, state, value, detail}.
"""
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1]))
sys.path.insert(0, str(HERE.parent / "sprite"))
import forgecore as fc  # noqa: E402
import pngio  # noqa: E402
import spritekit as sk  # noqa: E402


def requested(prompt):
    """'16x16' (WxH) and 'N-frame(s)' stated in the prompt."""
    out = {}
    m = re.search(r"(\d+)\s*[x×]\s*(\d+)", prompt, re.I)
    if m:
        out["size"] = (int(m.group(1)), int(m.group(2)))
    m = re.search(r"(\d+)\s*-?\s*frames?\b", prompt, re.I)
    if m:
        out["frames"] = int(m.group(1))
    return out


def block_upscale(rows, k):
    """True when every aligned k x k block of the frame holds one value (a k-times upscale)."""
    h, w = len(rows), len(rows[0])
    if h % k or w % k:
        return False
    for by in range(0, h, k):
        for bx in range(0, w, k):
            v = rows[by][bx]
            for y in range(by, by + k):
                for x in range(bx, bx + k):
                    if rows[y][x] != v:
                        return False
    return True


def upscale_factor(rows):
    """Largest k >= 2 for which the frame is a pure k-times upscale, else 1."""
    h, w = len(rows), len(rows[0])
    for k in range(min(h, w) // 4, 1, -1):  # at least a 4 x 4 cell grid, so a lone big rect is not flagged
        if h % k == 0 and w % k == 0 and block_upscale(rows, k):
            return k
    return 1


def frame_rows(rows, i, fw):
    return [row[i * fw:(i + 1) * fw] for row in rows]


def validate(vdir, params, result, pack):
    vdir = Path(vdir)
    checks = []
    add = lambda *a: checks.append(fc.check(*a))  # noqa: E731
    status = result.get("status")
    if status != "ok":
        add("build", "fail", status, (result.get("error") or "the recipe did not build")[-1500:])
        return checks
    add("build", "pass", "ok", "recipe built and the image was written")
    for w in result.get("warnings", []):
        add("harness_warning", "warn", None, w)

    asset = params["asset"]
    png_path = vdir / "out" / (asset + ".png")
    meta_path = vdir / "out" / (asset + ".json")
    if not png_path.is_file() or not meta_path.is_file():
        add("outputs", "fail", None, "out/%s.png or out/%s.json is missing" % (asset, asset))
        return checks
    try:
        meta = json.loads(meta_path.read_text())
        width, height, rows = pngio.read(png_path)
    except Exception as exc:  # noqa: BLE001
        add("outputs", "fail", None, "cannot read the image or its json: %r" % exc)
        return checks

    fw, fh, n = meta.get("frame_width"), meta.get("frame_height"), meta.get("frames")
    if not all(isinstance(v, int) and v > 0 for v in (fw, fh, n)):
        add("frames", "fail", None, "json lacks integer frame_width, frame_height and frames")
        return checks
    if width == fw * n and height == fh:
        add("frames", "pass", "%dx%d x %d" % (fw, fh, n), "%dx%d strip is %d equal frames of %dx%d" % (width, height, n, fw, fh))
    else:
        add("frames", "fail", [width, height], "%dx%d image is not %d frames of %dx%d side by side" % (width, height, n, fw, fh))
        return checks

    lo, hi = params["band"]
    if lo <= fw <= hi and lo <= fh <= hi:
        add("canvas_band", "pass", fw, "canvas %dx%d inside %d to %d" % (fw, fh, lo, hi))
    else:
        add("canvas_band", "fail", fw, "canvas %dx%d outside the %s band %d to %d px" % (fw, fh, params["category"], lo, hi))
    flo, fhi = params["size_range"]
    if flo <= n <= fhi:
        add("frame_count", "pass", n, "%d frames inside %d to %d" % (n, flo, fhi))
    else:
        add("frame_count", "fail", n, "%d frames outside %d to %d" % (n, flo, fhi))

    want = requested((vdir / "prompt.md").read_text()) if (vdir / "prompt.md").is_file() else {}
    if want.get("size"):
        add("requested_size", "pass" if (fw, fh) == want["size"] else "fail", [fw, fh],
            "the prompt asks for %dx%d, the canvas is %dx%d" % (*want["size"], fw, fh))
    if want.get("frames"):
        add("requested_frames", "pass" if n == want["frames"] else "fail", n,
            "the prompt asks for %d frames, the strip has %d" % (want["frames"], n))

    translucent = sum(1 for row in rows for p in row if p[3] not in (0, 255))
    if translucent:
        add("alpha", "fail", translucent, "%d pixels are partly transparent; pixel art uses binary alpha" % translucent)
    else:
        add("alpha", "pass", 0, "alpha is 0 or 255 everywhere")

    allowed = set(sk.build_ramp(params["palette"]).values())
    seen = {}
    off = []
    for y, row in enumerate(rows):
        for x, p in enumerate(row):
            if p[3] == 0:
                continue
            seen[p[:3]] = seen.get(p[:3], 0) + 1
            if p[:3] not in allowed:
                off.append((x, y, p))
    if off:
        add("ramp", "fail", len(off), "%d opaque pixels are not in the shade ramp, e.g. #%02x%02x%02x at (%d, %d)" % (
            len(off), *off[0][2][:3], off[0][0], off[0][1]))
    else:
        add("ramp", "pass", len(seen), "every opaque pixel is one of the %d ramp colours (%d used)" % (len(allowed), len(seen)))

    empty, scaled = [], []
    for i in range(n):
        f = frame_rows(rows, i, fw)
        if not any(p[3] for r in f for p in r):
            empty.append(i)
        else:
            k = upscale_factor(f)
            if k > 1:
                scaled.append((i, k))
    if empty:
        add("content", "fail", empty, "frame(s) %s are empty" % empty)
    else:
        add("content", "pass", n, "every frame has opaque pixels")
    if scaled:
        add("native_grid", "fail", scaled, "frame %d is a uniform %dx upscale (every %dx%d block is one colour); author at 1 px per cell" % (
            scaled[0][0], scaled[0][1], scaled[0][1], scaled[0][1]))
    else:
        add("native_grid", "pass", 1, "no frame is a uniform k x k upscale")

    budget = params["max_draw_calls"]
    add("colour_budget", "pass" if len(seen) <= budget else "warn", len(seen),
        "%d distinct colours; the %s budget is %d" % (len(seen), params["category"], budget))

    if params.get("preview", True):
        sheet = vdir / "preview" / "sheet.png"
        add("preview", "pass" if sheet.is_file() else "warn", sheet.name, "preview " + ("present" if sheet.is_file() else "missing"))
    return checks
