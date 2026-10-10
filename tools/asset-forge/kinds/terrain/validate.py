"""Terrain validator (runs outside Blender, stdlib only, reads the PNGs itself).

validate(vdir, params, result, pack) -> list of checks {id, state, value, detail}.
Thresholds are in the constants below; kinds/terrain/README.md says how they were set.
"""
import array
import struct
import sys
import zlib
from operator import sub
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import forgecore as fc  # noqa: E402
import pngio  # noqa: E402

MAPS = ("albedo", "normal", "roughness", "ao", "height")
SEAM_WARN = 2.0          # wrap-pair / adjacent-pair difference; texlib fbm and worley measure 0.9 to 1.2
SEAM_FAIL = 3.0          # a cropped noise, a ramp, a framed tile measure 12 to 500
SEAM_FLOOR = 0.002       # same floor as texlib.SEAM_FLOOR
OFF_PALETTE_TOL = 0.04   # sRGB euclidean distance to a palette colour or palette mix
OFF_PALETTE_FAIL = 0.01  # share of sampled pixels
NORMAL_LEN_TOL = 0.03    # mean |length - 1| of decoded normals (8-bit rounding gives about 0.004)
NORMAL_Z_MIN = 0.999     # share of pixels with z > 0
NORMAL_CORR_MIN = 0.6    # Pearson of green with +dh/drow and red with -dh/dx proves OpenGL Y+
HEIGHT_STD_FAIL = 0.02   # flat tile
HEIGHT_AUTOCORR_FAIL = 0.6   # lag-1 neighbour correlation: white noise is ~0, smooth relief > 0.9
HEIGHT_AUTOCORR_WARN = 0.8


def read_png(path):
    """(width, height, channels, depth, rows) where rows[y] is a list of ints at full bit depth."""
    data = Path(path).read_bytes()
    if data[:8] != pngio.SIG:
        raise ValueError("not a PNG")
    idat = bytearray()
    for kind, body in pngio._chunks(data):
        if kind == b"IHDR":
            w, h, depth, ctype, _, _, interlace = struct.unpack(">IIBBBBB", body)
        elif kind == b"IDAT":
            idat += body
    if interlace or depth not in (8, 16) or ctype not in (0, 2, 6):
        raise ValueError("unsupported PNG (depth %d, type %d)" % (depth, ctype))
    ch = pngio.CHANNELS[ctype]
    size = depth // 8
    lines = pngio._unfilter(zlib.decompress(bytes(idat)), h, w * ch * size, ch * size)
    rows = []
    for line in lines:
        if size == 2:
            a = array.array("H", bytes(line))
            if sys.byteorder == "little":
                a.byteswap()
            rows.append(list(a))
        else:
            rows.append(list(line))
    return w, h, ch, depth, rows


def seam_metric(rows, ch, maxval):
    """Same definition as texlib.seam_metric, in pure Python. Returns the larger of x and y."""
    h, w = len(rows), len(rows[0]) // ch
    worst = 0.0
    # x direction
    adj = sum(sum(map(abs, map(sub, r[ch:], r[:-ch]))) for r in rows)
    wrap = sum(sum(abs(r[c] - r[-ch + c]) for c in range(ch)) for r in rows)
    adj_m = adj / (h * (w - 1)) / maxval
    wrap_m = wrap / h / maxval
    worst = max(worst, wrap_m / max(adj_m, SEAM_FLOOR))
    # y direction
    adj = sum(sum(map(abs, map(sub, rows[y + 1], rows[y]))) for y in range(h - 1))
    wrap = sum(map(abs, map(sub, rows[0], rows[-1])))
    adj_m = adj / ((h - 1) * w) / maxval
    wrap_m = wrap / w / maxval
    worst = max(worst, wrap_m / max(adj_m, SEAM_FLOOR))
    return worst


def pearson(xs, ys):
    n = len(xs)
    mx, my = sum(xs) / n, sum(ys) / n
    sxx = sum((x - mx) ** 2 for x in xs)
    syy = sum((y - my) ** 2 for y in ys)
    if sxx < 1e-12 or syy < 1e-12:
        return None
    return sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / (sxx * syy) ** 0.5


def validate(vdir, params, result, pack):
    vdir = Path(vdir)
    asset = params["asset"]
    checks = []
    add = lambda *a: checks.append(fc.check(*a))  # noqa: E731
    status = result.get("status")
    if status != "ok":
        add("build", "fail", status, (result.get("error") or "the recipe did not build")[-1500:])
        return checks
    add("build", "pass", "ok", "recipe built and wrote its maps")
    for w in result.get("warnings", []):
        add("harness_warning", "warn", None, w)

    paths = {m: vdir / "out" / ("%s_%s.png" % (asset, m)) for m in MAPS}
    missing = [m for m, p in paths.items() if not p.is_file()]
    if missing:
        add("maps_present", "fail", missing, "missing map files: %s" % ", ".join(missing))
    else:
        add("maps_present", "pass", len(MAPS), "all five maps exist")

    imgs = {}
    for m, p in paths.items():
        if p.is_file():
            try:
                imgs[m] = read_png(p)
            except Exception as exc:  # noqa: BLE001
                add("png_%s" % m, "fail", None, "cannot read %s: %r" % (p.name, exc))
    expect_ch = {"albedo": 3, "normal": 3, "roughness": 1, "ao": 1, "height": 1}
    for m in [k for k, v in imgs.items() if v[2] != expect_ch[k]]:
        add("png_%s" % m, "fail", imgs[m][2], "%s has %d channels, expected %d" % (m, imgs[m][2], expect_ch[m]))
        imgs.pop(m)

    sizes = {m: (v[0], v[1]) for m, v in imgs.items()}
    if sizes:
        distinct = sorted(set(sizes.values()))
        w0, h0 = distinct[0]
        lo, hi = params["band"]
        if len(distinct) > 1:
            add("size_equal", "fail", [list(s) for s in distinct], "maps differ in size: %s" % ", ".join("%s %dx%d" % (m, *s) for m, s in sizes.items()))
        elif w0 != h0:
            add("size_square", "fail", [w0, h0], "tile is %dx%d, not square" % (w0, h0))
        elif w0 & (w0 - 1):
            add("size_pot", "fail", w0, "%d is not a power of two (mipmaps and tiling want 256, 512, 1024)" % w0)
        elif not lo <= w0 <= hi:
            add("size_band", "fail", w0, "%d px outside the allowed %d to %d" % (w0, lo, hi))
        else:
            add("size", "pass", w0, "%d x %d, square, power of two, inside %d to %d" % (w0, h0, lo, hi))

    # seams: the point of the kind
    seams = {}
    for m, (w, h, ch, depth, rows) in imgs.items():
        if w >= 8 and h >= 8:
            seams[m] = seam_metric(rows, ch, 65535 if depth == 16 else 255)
    if seams:
        worst_map = max(seams, key=seams.get)
        worst = seams[worst_map]
        detail = "worst %s %.2f (warn above %.1f, fail above %.1f; 1.0 is seamless); %s" % (
            worst_map, worst, SEAM_WARN, SEAM_FAIL, ", ".join("%s %.2f" % (m, v) for m, v in seams.items()))
        state = "fail" if worst > SEAM_FAIL else "warn" if worst > SEAM_WARN else "pass"
        add("seam", state, round(worst, 3), detail)

    # albedo palette
    if "albedo" in imgs:
        w, h, ch, depth, rows = imgs["albedo"]
        step = max(1, w // 128)
        counts = {}
        for y in range(0, h, step):
            r = rows[y]
            for x in range(0, w, step):
                key = (r[3 * x], r[3 * x + 1], r[3 * x + 2])
                counts[key] = counts.get(key, 0) + 1
        total = sum(counts.values())
        pal = list(params["palette"].values())
        off, off_n, worst_hex = 0, 0, None
        cache = {}
        for key, c in counts.items():
            hx = "%02x%02x%02x" % key
            d = fc.palette_distance(hx, pal)
            cache[key] = d
            if d > OFF_PALETTE_TOL:
                off += c
                off_n += 1
                if worst_hex is None or d > cache[worst_hex[0]]:
                    worst_hex = (key, hx)
        share = off / total
        if share > OFF_PALETTE_FAIL:
            add("palette", "fail", round(share, 3), "%.0f%% of albedo is off palette (e.g. #%s is %.2f from the nearest palette colour or mix)" % (
                100 * share, worst_hex[1], cache[worst_hex[0]]))
        elif off:
            add("palette", "warn", round(share, 4), "%.2f%% of albedo is slightly off palette (e.g. #%s)" % (100 * share, worst_hex[1]))
        else:
            add("palette", "pass", len(counts), "%d sampled colours, every one a palette colour or mix" % len(counts))

    # height relief and white noise
    if "height" in imgs:
        w, h, ch, depth, rows = imgs["height"]
        mx = 65535 if depth == 16 else 255
        flat = [v for r in rows[::max(1, h // 128)] for v in r[::max(1, w // 128)]]
        mean = sum(flat) / len(flat)
        std = (sum((v - mean) ** 2 for v in flat) / len(flat)) ** 0.5 / mx
        if std < HEIGHT_STD_FAIL:
            add("relief", "fail", round(std, 4), "height std %.3f is flat (need at least %.2f)" % (std, HEIGHT_STD_FAIL))
        else:
            add("relief", "pass", round(std, 4), "height std %.3f" % std)
        xs, ys = [], []
        for r in rows[::4]:
            xs += r[:-1]
            ys += r[1:]
        ac = pearson(xs, ys)
        if ac is None:
            add("smoothness", "info", None, "height has no variance to correlate")
        elif ac < HEIGHT_AUTOCORR_FAIL:
            add("smoothness", "fail", round(ac, 3), "neighbouring height pixels correlate only %.2f: per-pixel noise (need above %.1f)" % (ac, HEIGHT_AUTOCORR_FAIL))
        elif ac < HEIGHT_AUTOCORR_WARN:
            add("smoothness", "warn", round(ac, 3), "neighbouring height pixels correlate %.2f: grainy (want above %.1f)" % (ac, HEIGHT_AUTOCORR_WARN))
        else:
            add("smoothness", "pass", round(ac, 3), "neighbouring height pixels correlate %.2f" % ac)

    # normal map: unit length, z up, Y+ against the height map
    if "normal" in imgs:
        w, h, ch, depth, rows = imgs["normal"]
        step = max(1, w // 128)
        errs, zpos, cnt = 0.0, 0, 0
        for y in range(0, h, step):
            r = rows[y]
            for x in range(0, w, step):
                nx, ny, nz = r[3 * x] / 127.5 - 1, r[3 * x + 1] / 127.5 - 1, r[3 * x + 2] / 127.5 - 1
                errs += abs((nx * nx + ny * ny + nz * nz) ** 0.5 - 1)
                zpos += nz > 0
                cnt += 1
        mean_err, zshare = errs / cnt, zpos / cnt
        if mean_err > NORMAL_LEN_TOL:
            add("normal_unit", "fail", round(mean_err, 4), "normals are not unit length (mean error %.3f)" % mean_err)
        else:
            add("normal_unit", "pass", round(mean_err, 4), "mean length error %.4f" % mean_err)
        if zshare < NORMAL_Z_MIN:
            add("normal_z", "fail", round(zshare, 4), "only %.1f%% of normals face up (z > 0)" % (100 * zshare))
        else:
            add("normal_z", "pass", round(zshare, 4), "%.2f%% of normals have z > 0" % (100 * zshare))
        if "height" in imgs and imgs["height"][:2] == (w, h):
            hr = imgs["height"][4]
            gy, dy, rx, dx = [], [], [], []
            for y in range(0, h, step):
                for x in range(0, w, step):
                    gy.append(rows[y][3 * x + 1] / 127.5 - 1)
                    dy.append(hr[(y + 1) % h][x] - hr[(y - 1) % h][x])
                    rx.append(rows[y][3 * x] / 127.5 - 1)
                    dx.append(-(hr[y][(x + 1) % w] - hr[y][(x - 1) % w]))
            cg, cr = pearson(gy, dy), pearson(rx, dx)
            if cg is None or cr is None:
                add("normal_y_plus", "info", None, "no relief to correlate")
            elif cg >= NORMAL_CORR_MIN and cr >= NORMAL_CORR_MIN:
                add("normal_y_plus", "pass", [round(cr, 3), round(cg, 3)], "green follows +d(height)/d(row) (%.2f) and red follows -d(height)/dx (%.2f): OpenGL Y+" % (cg, cr))
            else:
                add("normal_y_plus", "fail", [round(cr, 3), round(cg, 3)],
                    "normal does not match the height map (red %.2f, green %.2f, need above %.1f); a Y-down (DirectX) normal gives a negative green" % (cr, cg, NORMAL_CORR_MIN))

    # material and preview
    tres = vdir / "out" / (asset + ".tres")
    if not tres.is_file():
        add("tres", "fail", None, "out/%s.tres is missing" % asset)
    else:
        text = tres.read_text()
        absent = [m for m in MAPS if "%s_%s.png" % (asset, m) not in text]
        if absent:
            add("tres", "fail", absent, ".tres does not reference: %s" % ", ".join(absent))
        elif "StandardMaterial3D" not in text:
            add("tres", "fail", None, ".tres is not a StandardMaterial3D")
        else:
            add("tres", "pass", None, "StandardMaterial3D references all five maps")
    if params.get("preview", True):
        sheet = vdir / "preview" / "sheet.png"
        add("preview", "pass" if sheet.is_file() else "warn", sheet.name, "2x2 lit sheet " + ("present" if sheet.is_file() else "missing"))
    return checks
