"""Sprite validator (runs outside Blender, stdlib only).

validate(vdir, params, result, pack) -> list of checks {id, state, value, detail}.
The sheet is judged against the shade ramp the harness paints with (spritekit.py), so the two
cannot drift.
"""
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1]))
sys.path.insert(0, str(HERE))
import forgecore as fc  # noqa: E402
import pngio  # noqa: E402
import spritekit as sk  # noqa: E402


def requested(prompt):
    """Numbers the prompt states outright: '64px' or '64 px' / '64x64', 'N-direction(s)'."""
    out = {}
    m = re.search(r"(\d+)\s*[x×]\s*(\d+)\s*(?:px)?", prompt, re.I) or re.search(r"(\d+)\s*-?\s*px\b", prompt, re.I)
    if m:
        out["size"] = int(m.group(1))
        if m.lastindex == 2 and int(m.group(2)) != int(m.group(1)):
            out["size"] = None  # non-square ask: only the band applies
    m = re.search(r"(\d+)\s*-?\s*(?:direction|dir|angle|view)", prompt, re.I)
    if m:
        out["directions"] = int(m.group(1))
    return out


def validate(vdir, params, result, pack):
    vdir = Path(vdir)
    checks = []
    add = lambda *a: checks.append(fc.check(*a))  # noqa: E731
    status = result.get("status")
    if status != "ok":
        add("build", "fail", status, (result.get("error") or "the recipe did not build")[-1500:])
        return checks
    add("build", "pass", "ok", "recipe built and the sheet rendered")
    for w in result.get("warnings", []):
        add("harness_warning", "warn", None, w)

    asset = params["asset"]
    sheet_path = vdir / "out" / (asset + "_sheet.png")
    meta_path = vdir / "out" / (asset + ".json")
    if not sheet_path.is_file() or not meta_path.is_file():
        add("outputs", "fail", None, "out/%s_sheet.png or out/%s.json is missing" % (asset, asset))
        return checks
    try:
        meta = json.loads(meta_path.read_text())
        width, height, rows = pngio.read(sheet_path)
    except Exception as exc:  # noqa: BLE001
        add("outputs", "fail", None, "cannot read the sheet or its json: %r" % exc)
        return checks

    fw, fh, n = meta.get("frame_width"), meta.get("frame_height"), meta.get("directions")
    if not all(isinstance(v, int) and v > 0 for v in (fw, fh, n)):
        add("frames", "fail", None, "json lacks integer frame_width, frame_height and directions")
        return checks
    if width % fw == 0 and height % fh == 0 and (width // fw) * (height // fh) == n:
        add("frames", "pass", "%dx%d x %d" % (fw, fh, n), "%dx%d sheet divides into %d whole %dx%d frames" % (width, height, n, fw, fh))
    else:
        add("frames", "fail", [width, height], "%dx%d sheet does not divide into %d frames of %dx%d" % (width, height, n, fw, fh))
        return checks
    cols = width // fw

    lo, hi = params["band"]
    if lo <= fw <= hi and lo <= fh <= hi:
        add("frame_band", "pass", fw, "frame edge %d inside %d to %d" % (fw, lo, hi))
    else:
        add("frame_band", "fail", fw, "frame %dx%d outside the %s band %d to %d px" % (fw, fh, params["category"], lo, hi))

    want = requested((vdir / "prompt.md").read_text()) if (vdir / "prompt.md").is_file() else {}
    if want.get("size"):
        add("requested_size", "pass" if fw == fh == want["size"] else "fail", fw,
            "the prompt asks for %d px, the frame is %dx%d" % (want["size"], fw, fh))
    if want.get("directions"):
        add("requested_directions", "pass" if n == want["directions"] else "fail", n,
            "the prompt asks for %d directions, the sheet has %d" % (want["directions"], n))
    if n not in (1, 4, 8):
        add("directions", "fail", n, "directions must be 1, 4 or 8")

    translucent = sum(1 for row in rows for p in row if p[3] not in (0, 255))
    if translucent:
        add("alpha", "fail", translucent, "%d pixels are partly transparent; sprites use binary alpha" % translucent)
    else:
        add("alpha", "pass", 0, "alpha is 0 or 255 everywhere")

    ramp = sk.build_ramp(params["palette"])
    allowed = set(ramp.values())
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
        add("ramp", "fail", len(off), "%d opaque pixels are not in the shade ramp, e.g. %s at (%d, %d)" % (
            len(off), "#%02x%02x%02x" % off[0][2][:3], off[0][0], off[0][1]))
    else:
        add("ramp", "pass", len(seen), "every opaque pixel is one of the %d ramp colours (%d used)" % (len(allowed), len(seen)))

    empty = []
    for k in range(n):
        cx, cy = k % cols, k // cols
        if not any(rows[y][x][3] for y in range(cy * fh, cy * fh + fh) for x in range(cx * fw, cx * fw + fw)):
            empty.append(k)
    if empty:
        add("content", "fail", empty, "frame(s) %s are empty" % empty)
    else:
        add("content", "pass", n, "every frame has opaque pixels")

    pivot = meta.get("pivot")
    if isinstance(pivot, list) and len(pivot) == 2 and all(isinstance(v, (int, float)) for v in pivot) \
            and -fw <= pivot[0] <= 2 * fw and -fh <= pivot[1] <= 2 * fh:
        add("pivot", "pass", pivot, "pivot (%.1f, %.1f) recorded in the json" % tuple(pivot))
    else:
        add("pivot", "fail", pivot, "json has no usable pivot [x, y]")

    budget = params["max_draw_calls"]
    add("colour_budget", "pass" if len(seen) <= budget else "warn", len(seen),
        "%d distinct colours; the %s budget is %d" % (len(seen), params["category"], budget))

    m = result.get("measure") or {}
    if m.get("size"):
        longest = max(m["size"])
        slo, shi = params["size_range"]
        if slo <= longest <= shi:
            add("model_size", "pass", round(longest, 3), "model longest edge %.2f m inside %.2f to %.2f" % (longest, slo, shi))
        else:
            add("model_size", "warn", round(longest, 3), "model longest edge %.2f m outside %.2f to %.2f" % (longest, slo, shi))

    if params.get("preview", True):
        sheet = vdir / "preview" / "sheet.png"
        add("preview", "pass" if sheet.is_file() else "warn", sheet.name, "preview " + ("present" if sheet.is_file() else "missing"))
    return checks
