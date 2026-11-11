#!/usr/bin/env python3
"""Generate the V2 icon set from VISUAL-LANGUAGE.md section 5.

Dependency-free. Writes one standalone 64x64 SVG per id to
sketches/core-loop/assets/icons/<id>.svg and an index README next to them.

Run: python3 sketches/core-loop/tools/icons/generate_icons.py
Check, writing nothing: python3 sketches/core-loop/tools/icons/generate_icons.py --check
(exits 1 and names every icon whose committed file is not what this script draws).
The line and ultimate cards (ab_<pilot>_line, ab_<pilot>_ult) and res_mass are drawn by hand
and are not this script's.
"""
import math
import os
import sys

# --- Palette (VISUAL-LANGUAGE.md section 2) ---------------------------------
CHARCOAL = "#242a28"
BONE = "#d2c5a5"
MINT = "#8bf0d3"
AMBER = "#e5a044"
COPPER = "#b77843"
IRON_OXIDE = "#9b513a"
PETROL = "#365754"
HAZARD = "#ff5a3c"
BRASS = "#d9b44a"
ICE = "#c8f0ff"
ANCIENT = "#9dff3c"  # ancient green (Palette.ANCIENT); the old Cherenkov blue is the cobalt rung now
REDJAW_ASH = "#5e5a54"
LEDGER_CREAM = "#f7f1e3"
LEDGER = "#e6d9b8"  # Tally's own colour (Palette.LEDGER): her ability cards are drawn in it
OLD_VERDIGRIS = "#4f7f7a"

HERE = os.path.dirname(os.path.abspath(__file__))
ICON_DIR = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "icons"))
README_PATH = os.path.join(ICON_DIR, "README.md")

PRIMARY = 6
DETAIL = 4


def n(x):
    """Trim floats to at most 2 decimals for compact, readable SVG source."""
    r = round(x, 2)
    return int(r) if r == int(r) else r


# --- Geometry helpers ---------------------------------------------------------
def polygon_points(cx, cy, r, count, start_deg=-90, inner_r=None):
    pts = []
    for i in range(count * (2 if inner_r else 1)):
        ang = math.radians(start_deg + i * (360 / (count * (2 if inner_r else 1))))
        rad = r if (not inner_r or i % 2 == 0) else inner_r
        pts.append((cx + rad * math.cos(ang), cy + rad * math.sin(ang)))
    return " ".join(f"{n(x)},{n(y)}" for x, y in pts)


def chevron(cx, cy, w, h, stroke=BONE, width=PRIMARY, cap="round"):
    x0, y0 = cx - w / 2, cy - h / 2
    x1, y1 = cx + w / 2, cy
    x2, y2 = cx - w / 2, cy + h / 2
    return (
        f'<polyline points="{n(x0)},{n(y0)} {n(x1)},{n(y1)} {n(x2)},{n(y2)}" '
        f'fill="none" stroke="{stroke}" stroke-width="{width}" '
        f'stroke-linecap="{cap}" stroke-linejoin="round"/>'
    )


def ring(cx, cy, r, stroke=BONE, width=PRIMARY, dash=None):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    return f'<circle cx="{n(cx)}" cy="{n(cy)}" r="{n(r)}" fill="none" stroke="{stroke}" stroke-width="{width}"{d}/>'


def dot(cx, cy, r, fill=BONE):
    return f'<circle cx="{n(cx)}" cy="{n(cy)}" r="{n(r)}" fill="{fill}"/>'


def line(x1, y1, x2, y2, stroke=BONE, width=DETAIL, dash=None, cap="round"):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    return (
        f'<line x1="{n(x1)}" y1="{n(y1)}" x2="{n(x2)}" y2="{n(y2)}" '
        f'stroke="{stroke}" stroke-width="{width}" stroke-linecap="{cap}"{d}/>'
    )


def path(d, stroke=BONE, width=DETAIL, fill="none", cap="round", join="round", dash=None):
    dd = f' stroke-dasharray="{dash}"' if dash else ""
    return (
        f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" '
        f'stroke-linecap="{cap}" stroke-linejoin="{join}"{dd}/>'
    )


def rect(x, y, w, h, fill=BONE, rx=0, stroke=None, width=0):
    s = f' stroke="{stroke}" stroke-width="{width}"' if stroke else ""
    return f'<rect x="{n(x)}" y="{n(y)}" width="{n(w)}" height="{n(h)}" rx="{n(rx)}" fill="{fill}"{s}/>'


def cloud(cx, cy, r=9, stroke=BONE, width=DETAIL, dash="2 3"):
    """Three overlapping dashed circles reading as a puff or dust cloud silhouette."""
    els = []
    for dx, dy, rr in ((-r * 0.5, r * 0.15, r * 0.65), (r * 0.45, r * 0.05, r * 0.7), (0, -r * 0.35, r * 0.55)):
        els.append(
            f'<circle cx="{n(cx + dx)}" cy="{n(cy + dy)}" r="{n(rr)}" fill="none" '
            f'stroke="{stroke}" stroke-width="{width}" stroke-dasharray="{dash}"/>'
        )
    return els


def star(cx, cy, points, r_out, r_in, fill=AMBER, start_deg=-90):
    pts = polygon_points(cx, cy, r_out, points, start_deg=start_deg, inner_r=r_in)
    return f'<polygon points="{pts}" fill="{fill}"/>'


def poly(cx, cy, r, count, fill=CHARCOAL, stroke=None, width=0, start_deg=-90):
    pts = polygon_points(cx, cy, r, count, start_deg=start_deg)
    s = f' stroke="{stroke}" stroke-width="{width}"' if stroke else ""
    return f'<polygon points="{pts}" fill="{fill}"{s}/>'


def text(cx, cy, s, size, fill=CHARCOAL, weight=700):
    return (
        f'<text x="{n(cx)}" y="{n(cy)}" font-family="sans-serif" '
        f'font-weight="{weight}" font-size="{size}" fill="{fill}" '
        f'text-anchor="middle" dominant-baseline="central">{s}</text>'
    )


# --- Category backplates (VISUAL-LANGUAGE.md section 5, "Category backplates") --
STRIPE_DEF = (
    '<pattern id="{pid}" width="7" height="7" patternUnits="userSpaceOnUse" '
    'patternTransform="rotate(45)">'
    f'<rect width="7" height="7" fill="{CHARCOAL}"/><rect width="3.5" height="7" fill="{HAZARD}"/>'
    "</pattern>"
)


def plate_circle():
    return [f'<circle cx="32" cy="32" r="28" fill="{CHARCOAL}"/>']


def plate_rounded_square(rx=8):
    return [rect(4, 4, 56, 56, fill=CHARCOAL, rx=rx)]


def plate_square():
    return [rect(4, 4, 56, 56, fill=CHARCOAL)]


def plate_hex():
    return [poly(32, 32, 28, 6, fill=CHARCOAL, start_deg=0)]


def plate_tag():
    return [
        rect(8, 12, 48, 40, fill=CHARCOAL, rx=8),
        ring(17, 32, 5, stroke=BONE, width=3),
    ]


def plate_pentagon():
    return [poly(32, 32, 28, 5, fill=CHARCOAL, start_deg=-90)]


TRIANGLE_PTS = "32,4 61,58 3,58"


def plate_triangle(pid):
    return [
        f'<polygon points="{TRIANGLE_PTS}" fill="{CHARCOAL}" stroke="{HAZARD}" stroke-width="4" stroke-linejoin="miter"/>',
        f'<clipPath id="{pid}-clip"><rect x="3" y="46" width="58" height="12"/></clipPath>',
        f'<polygon points="{TRIANGLE_PTS}" fill="url(#{pid})" clip-path="url(#{pid}-clip)"/>',
    ]


def plate_brackets():
    # Sits on top of a solid square backplate (obj_ = square base + corner brackets).
    return [
        rect(4, 4, 56, 56, fill=CHARCOAL),
        path("M6 16 V6 H16 M48 6 H58 V16 M58 48 V58 H48 M16 58 H6 V48", stroke=BONE, width=4),
    ]


def plate_keycap(wide=False, letters_gap=False):
    x, w = (6, 52) if wide else (10, 44)
    return [
        rect(x, 8, w, 40, fill=BONE, rx=6, stroke=CHARCOAL, width=2),
        rect(x, 40, w, 10, fill=BONE, rx=3, stroke=CHARCOAL, width=2),
    ]


def plate_mouse():
    return [
        rect(20, 8, 24, 44, fill=BONE, rx=12, stroke=CHARCOAL, width=2),
        line(32, 8, 32, 24, stroke=CHARCOAL, width=3),
    ]


def plate_none():
    return []


# --- Icon registry -----------------------------------------------------------
# Each entry: id -> (meaning, drawing description, backplate fn or None, glyph fn)
ICONS = {}


def register(icon_id, meaning, drawing, backplate, glyph_fn):
    ICONS[icon_id] = {
        "meaning": meaning,
        "drawing": drawing,
        "backplate": backplate,
        "glyph": glyph_fn,
    }


# ---- Class emblems and abilities (19) ---------------------------------------
def g_cls_sable():
    return [
        ring(32, 34, 14, stroke=MINT, width=PRIMARY),
        f'<rect x="10" y="12" width="14" height="8" rx="2" fill="{BONE}" transform="rotate(-30 17 16)"/>',
        f'<rect x="40" y="12" width="14" height="8" rx="2" fill="{BONE}" transform="rotate(30 47 16)"/>',
    ]


register(
    "cls_sable", "Sable", "A ring with two bolted pylon plates at 10 and 2 o'clock",
    plate_circle, g_cls_sable,
)


def g_cls_rivet():
    return [
        f'<polyline points="28,16 46,32 28,48" fill="none" stroke="{COPPER}" '
        f'stroke-width="{PRIMARY}" stroke-linecap="round" stroke-linejoin="round"/>',
        line(22, 20, 14, 26, stroke=BONE),
        line(22, 32, 12, 32, stroke=BONE),
        line(22, 44, 14, 38, stroke=BONE),
    ]


register(
    "cls_rivet", "Rivet", "A forward chevron with three raked fins behind it",
    plate_circle, g_cls_rivet,
)


def g_cls_kest():
    return [
        star(32, 32, 8, 18, 8, fill=AMBER),
        path("M44.7 19.3 C 50 14, 54 16, 52 10", stroke=BONE, width=DETAIL),
    ]


register(
    "cls_kest", "Kest", "An eight-point starburst with a fuse wick curling off one point",
    plate_circle, g_cls_kest,
)


def g_cls_tarn():
    return [
        path("M16 16 L32 32 L48 16 L48 26 L38 36 L46 46 L36 46 L32 42 L28 46 L18 46 L26 36 L16 26 Z",
             stroke=BONE, width=DETAIL, fill=REDJAW_ASH),
        path("M26 24 L32 30 L38 24", stroke=IRON_OXIDE, width=PRIMARY),
    ]


register(
    "cls_tarn", "Tarn", "Crossed Redjaw Ash claw jaws with a rust-red tearing latch",
    plate_circle, g_cls_tarn,
)


def g_cls_tally():
    return [
        rect(16, 17, 32, 32, fill=LEDGER_CREAM, rx=2),
        rect(25, 12, 14, 10, fill=IRON_OXIDE, rx=2),
        path("M23 41 L29 41 L29 35 L35 35 L35 29 L41 29", stroke=CHARCOAL, width=DETAIL),
    ]


register(
    "cls_tally", "Tally", "A clipped Ledger Cream square with a three-step stair stamp",
    plate_circle, g_cls_tally,
)


def g_cls_cannon():
    return [
        rect(12, 25, 30, 14, fill=OLD_VERDIGRIS, rx=2, stroke=ANCIENT, width=DETAIL),
        path("M42 29 L51 22 M42 35 L51 42", stroke=BONE, width=DETAIL),
        rect(19, 42, 16, 6, fill=OLD_VERDIGRIS, rx=2),
    ]


register(
    "cls_cannon", "Remembered cannon", "An ancient-blue barrel in Old Verdigris with a split lane and a mounting plate",
    plate_circle, g_cls_cannon,
)


def g_ab_sable_weapon():
    return [
        rect(12, 28, 10, 8, fill=BONE, rx=2),
        path("M22 32 L34 24 L38 36 L48 30", stroke=MINT, width=DETAIL, cap="round", join="round"),
        ring(50, 28, 5, stroke=MINT, width=DETAIL),
    ]


register(
    "ab_sable_weapon", "Arc caster (LMB)",
    "A stubby pylon prong at left, a zigzag arc leaping right to a small ring",
    plate_rounded_square, g_ab_sable_weapon,
)


def g_ab_sable_move():
    return [
        path("M46 16 L52 12 L54 20 L46 22 Z", fill=BONE),
        path("M46 20 C 40 26, 34 32, 26 40", stroke=MINT, width=DETAIL),
        ring(20, 46, 7, stroke=BONE, width=DETAIL),
    ]


register(
    "ab_sable_move", "Grapple and winch (RMB)",
    "A hook jaw top-right, a rope curving down to a spool circle bottom-left",
    plate_rounded_square, g_ab_sable_move,
)


def g_ab_sable_special():
    return [
        ring(32, 32, 10, stroke=BONE, width=DETAIL),
        ring(32, 32, 16, stroke=BONE, width=DETAIL),
        ring(32, 32, 22, stroke=MINT, width=DETAIL, dash="4 4"),
        line(32, 12, 32, 22, stroke=BONE, width=PRIMARY),
    ]


register(
    "ab_sable_special", "Detonation gauge (F)",
    "Three concentric rings, the outer one dashed, crossed by a short bolt",
    plate_rounded_square, g_ab_sable_special,
)


def g_ab_sable_reel():
    return [
        rect(12, 14, 6, 36, fill=BONE, rx=2),
        rect(30, 14, 6, 36, fill=BONE, rx=2),
        rect(18, 22, 12, 20, fill=COPPER),
        line(30, 32, 56, 32, stroke=MINT, width=DETAIL),
        path("M 56 32 L 56 40 C 56 46 48 46 48 40", stroke=MINT, width=DETAIL),
        chevron(44, 24, 6, 8, stroke=MINT, width=DETAIL).replace("polyline", "polyline transform=\"rotate(180 44 24)\""),
    ]


register(
    "ab_sable_reel", "Reel in (shared stand-in line and ultimate)",
    "A cable spool seen from the side, its line running out to a hook, a mint arrow pointing back at the spool",
    plate_rounded_square, g_ab_sable_reel,
)


def g_ab_sable_smash():
    return [
        chevron(32, 22, 16, 12, stroke=BONE),
        line(16, 46, 48, 46, stroke=BONE, width=PRIMARY),
        ring(32, 46, 10, stroke=MINT, width=DETAIL),
        line(20, 38, 20, 44, stroke=BONE, width=DETAIL),
        line(44, 38, 44, 44, stroke=BONE, width=DETAIL),
    ]


register(
    "ab_sable_smash", "Arc slam (Ctrl)",
    "A down chevron meeting a ground line, a ring spreading, two short upright ticks",
    plate_rounded_square, g_ab_sable_smash,
)


def g_ab_sable_vault():
    return [
        rect(12, 14, 6, 36, fill=BONE),
        dot(24, 48, 5, fill=BONE),
        path("M27 45 L48 20", stroke=MINT, width=PRIMARY),
        path("M48 20 L40 22 M48 20 L46 28", stroke=MINT, width=DETAIL),
    ]


register(
    "ab_sable_vault", "Vault kick (Space at a face)",
    "A vertical wall bar at left, a ball leaving it along a sharp 60 degree arrow",
    plate_rounded_square, g_ab_sable_vault,
)


def g_ab_sable_mount():
    return [
        rect(38, 12, 6, 38, fill=BONE),
        path("M20 20 L38 30 L20 40 Z", fill=MINT),
        ring(41, 18, 5, stroke=BONE, width=DETAIL),
    ]


register(
    "ab_sable_mount", "Mount pylon (E)",
    "A pylon spike driven into a wall bar, a small ring at its head",
    plate_rounded_square, g_ab_sable_mount,
)


def g_ab_rivet_weapon():
    return [
        line(14, 26, 22, 26, stroke=BONE, width=DETAIL),
        line(14, 32, 24, 32, stroke=BONE, width=DETAIL),
        line(14, 38, 22, 38, stroke=BONE, width=DETAIL),
        f'<polyline points="30,20 48,32 30,44" fill="none" stroke="{COPPER}" '
        f'stroke-width="{PRIMARY}" stroke-linecap="round" stroke-linejoin="round"/>',
    ]


register(
    "ab_rivet_weapon", "Rapid laser (LMB)",
    "Three short parallel dashes ending in one chevron point",
    plate_rounded_square, g_ab_rivet_weapon,
)


def g_ab_rivet_move():
    return [
        f'<polygon points="14,32 26,20 26,44" fill="{COPPER}"/>',
        f'<polygon points="26,32 38,20 38,44" fill="{COPPER}"/>',
        path("M44 18 V28 M44 28 L52 28 M52 18 V28", stroke=BONE, width=DETAIL),
        path("M44 36 V46 M44 46 L52 46 M52 36 V46", stroke=BONE, width=DETAIL),
    ]


register(
    "ab_rivet_move", "Overdrive sprint (RMB)",
    "A double chevron punching through a broken bracket",
    plate_rounded_square, g_ab_rivet_move,
)


def g_ab_rivet_special():
    pts = []
    for i in range(6):
        ang = math.radians(i * 60)
        x1, y1 = 32 + 8 * math.cos(ang), 32 + 8 * math.sin(ang)
        x2, y2 = 32 + 22 * math.cos(ang), 32 + 22 * math.sin(ang)
        pts.append(line(x1, y1, x2, y2, stroke=COPPER, width=PRIMARY))
    return pts + [dot(32, 32, 4, fill=BONE)]


register(
    "ab_rivet_special", "Overdrive blast (F)",
    "Six chevrons around a centre dot, pointing outward",
    plate_rounded_square, g_ab_rivet_special,
)


def g_ab_rivet_smash():
    return [
        dot(22, 40, 6, fill=BONE),
        line(14, 46, 50, 46, stroke=BONE, width=PRIMARY),
        chevron(42, 32, 16, 14, stroke=COPPER),
        line(16, 40, 22, 44, stroke=BONE, width=DETAIL),
        line(16, 34, 24, 40, stroke=BONE, width=DETAIL),
    ]


register(
    "ab_rivet_smash", "Shockwave skid (Ctrl)",
    "A ball on a ground line, a forward wedge ahead, two skid dashes behind",
    plate_rounded_square, g_ab_rivet_smash,
)


def g_ab_kest_weapon():
    return [
        path("M14 46 Q 30 16 50 26", stroke=BONE, width=DETAIL, dash="3 4"),
        dot(50, 26, 7, fill=AMBER),
        star(50, 18, 4, 5, 2, fill=BONE, start_deg=0),
    ]


register(
    "ab_kest_weapon", "Sticky charges (LMB)",
    "A round charge with a four-point fuse spark, on a dotted lobbed arc",
    plate_rounded_square, g_ab_kest_weapon,
)


def g_ab_kest_move():
    return cloud(16, 22, r=8) + [
        ring(16, 22, 6, stroke=BONE, width=DETAIL),
        line(24, 27, 42, 40, stroke=BONE, width=DETAIL, dash="4 4"),
        dot(48, 45, 7, fill=AMBER),
    ]


register(
    "ab_kest_move", "Smoke blink (RMB)",
    "Two ball positions with a dashed gap: a puff-wrapped outline behind, a solid ball ahead",
    plate_rounded_square, g_ab_kest_move,
)


def g_ab_kest_special():
    els = [line(14, 32, 50, 32, stroke=BONE, width=PRIMARY)]
    for cx in (22, 32, 42):
        els.append(star(cx, 32, 6, 6, 3, fill=AMBER))
    return els


register(
    "ab_kest_special", "Detonation line (F)",
    "A straight line with three small starbursts along it",
    plate_rounded_square, g_ab_kest_special,
)


def g_ab_kest_smash():
    els = [chevron(32, 20, 16, 12, stroke=BONE), line(14, 46, 50, 46, stroke=BONE, width=PRIMARY)]
    for cx in (20, 32, 44):
        els.append(star(cx, 38, 6, 5, 2, fill=AMBER))
    return els


register(
    "ab_kest_smash", "Demo slam (Ctrl)",
    "A down chevron over a ground line, three small starbursts splayed along it",
    plate_rounded_square, g_ab_kest_smash,
)


def g_ab_kest_glide():
    return [
        dot(32, 40, 7, fill=BONE),
        path("M14 32 Q 32 18 50 32", stroke=AMBER, width=DETAIL),
        star(32, 50, 5, 5, 2, fill=AMBER),
    ]


register(
    "ab_kest_glide", "Glide and rocket jump (Space)",
    "A ball under a shallow wing arc, a small starburst beneath it",
    plate_rounded_square, g_ab_kest_glide,
)


def g_ab_kest_cloak():
    return [dot(27, 37, 10, fill=BONE)] + cloud(38, 26, r=10) + [
        line(46, 16, 50, 12, stroke=AMBER, width=3),
        line(50, 16, 46, 12, stroke=AMBER, width=3),
    ]


register(
    "ab_kest_cloak", "Dust cloak (passive)",
    "A ball half hidden by a dotted cloud outline, one spark at its edge",
    plate_rounded_square, g_ab_kest_cloak,
)


def g_ab_tarn_weapon():
    return [
        path("M16 46 Q 20 26 40 16", stroke=IRON_OXIDE, width=DETAIL),
        path("M16 46 Q 28 32 48 24", stroke=IRON_OXIDE, width=PRIMARY),
        path("M16 46 Q 34 40 50 34", stroke=IRON_OXIDE, width=DETAIL),
        dot(16, 46, 4, fill=BONE),
    ]


register(
    "ab_tarn_weapon", "Claw sweep (LMB)",
    "Three talon arcs raking from lower left to upper right, a pivot pin at their root",
    plate_rounded_square, g_ab_tarn_weapon,
)


def g_ab_tarn_move():
    return [
        dot(18, 46, 7, fill=BONE),
        line(24, 40, 40, 24, stroke=BONE, width=DETAIL, dash="4 4"),
        f'<polyline points="27,31 33,31 33,37" fill="none" stroke="{IRON_OXIDE}" '
        f'stroke-width="{DETAIL}" stroke-linecap="round" stroke-linejoin="round"/>',
        line(40, 24, 50, 14, stroke=IRON_OXIDE, width=PRIMARY),
        line(40, 24, 40, 12, stroke=IRON_OXIDE, width=DETAIL),
        line(40, 24, 52, 24, stroke=IRON_OXIDE, width=DETAIL),
    ]


register(
    "ab_tarn_move", "Claw pull (Shift)",
    "A ball on a dashed cable to a three-prong claw planted upper right, a chevron pointing at the claw",
    plate_rounded_square, g_ab_tarn_move,
)


def g_ab_tarn_special():
    return [
        path("M24 14 Q 8 32 24 50", stroke=IRON_OXIDE, width=PRIMARY),
        path("M40 14 Q 56 32 40 50", stroke=IRON_OXIDE, width=PRIMARY),
        line(18, 24, 24, 26, stroke=BONE, width=DETAIL),
        line(18, 40, 24, 38, stroke=BONE, width=DETAIL),
        line(46, 24, 40, 26, stroke=BONE, width=DETAIL),
        line(46, 40, 40, 38, stroke=BONE, width=DETAIL),
        dot(32, 32, 5, fill=BONE),
    ]


register(
    "ab_tarn_special", "Claw clamp (F)",
    "Two opposed jaws with inward teeth closing on a centre dot",
    plate_rounded_square, g_ab_tarn_special,
)


def g_ab_tarn_smash():
    return [
        line(10, 46, 54, 46, stroke=BONE, width=PRIMARY),
        chevron(18, 34, 10, 16, stroke=IRON_OXIDE),
        f'<polyline points="51,26 41,34 51,42" fill="none" stroke="{IRON_OXIDE}" '
        f'stroke-width="{PRIMARY}" stroke-linecap="round" stroke-linejoin="round"/>',
        dot(32, 36, 6, fill=BONE),
    ]


register(
    "ab_tarn_smash", "Rend slam (Ctrl)",
    "A ground line with two chevrons pointing inward at an impact dot",
    plate_rounded_square, g_ab_tarn_smash,
)

# ---- Tally's ability and program cards (7) ------------------------------------


def g_ab_tally_weapon():
    return [
        path("M22 12 H38 L46 20 V42 H22 Z", stroke=LEDGER, width=PRIMARY),
        *[dot(x, y, 1.8, fill=BONE) for y in (24, 32) for x in (29, 38)],
        line(12, 44, 52, 44, stroke=BONE, width=DETAIL),
    ]


register(
    "ab_tally_weapon", "Ledger reader (LMB)",
    "A clipped-corner ledger program card with two rows of punch holes, half in a reader slot",
    plate_rounded_square, g_ab_tally_weapon,
)


def g_ab_tally_move():
    return [
        ring(42, 32, 12, stroke=BONE, width=DETAIL),
        *[line(42, 32, 42 + 12 * math.cos(a), 32 + 12 * math.sin(a), stroke=BONE, width=DETAIL)
          for a in (-math.pi / 2, math.pi / 6, 5 * math.pi / 6)],
        path("M23 20 Q10 16 12 28", stroke=LEDGER, width=PRIMARY, dash="3 6"),
        path("M23 40 Q8 38 12 49", stroke=LEDGER, width=PRIMARY, dash="3 6"),
    ]


register(
    "ab_tally_move", "Flywheel surge (Shift)",
    "A three-spoke flywheel at right with two dashed ledger steam puffs trailing left",
    plate_rounded_square, g_ab_tally_move,
)


def g_ab_tally_special():
    return [
        rect(12, 12, 18, 12, fill="none", rx=3, stroke=LEDGER, width=PRIMARY),
        path("M20 30 Q16 50 38 46", stroke=BONE, width=DETAIL),
        path("M32 39 L39 46 L31 51", stroke=BONE, width=DETAIL),
        dot(48, 42, 6, fill=BONE),
    ]


register(
    "ab_tally_special", "Plate return (F)",
    "A ledger plate upper left with a curved return arrow to a ball lower right",
    plate_rounded_square, g_ab_tally_special,
)


def g_ab_tally_smash():
    return [
        ring(32, 14, 4, stroke=LEDGER, width=PRIMARY),
        line(32, 20, 32, 27, stroke=LEDGER, width=PRIMARY),
        path("M20 28 H44 V35 H20 Z", stroke=LEDGER, width=PRIMARY),
        line(10, 42, 54, 42, stroke=BONE, width=DETAIL),
        *[line(x, 49, x, 55, stroke=BONE, width=DETAIL) for x in (23, 29, 35, 41)],
        line(19, 55, 45, 48, stroke=BONE, width=DETAIL),
    ]


register(
    "ab_tally_smash", "Stamp slam (Ctrl)",
    "A ledger stamp over a ground line with four tally strokes and a slash printed beneath",
    plate_rounded_square, g_ab_tally_smash,
)


def g_ab_tally_gather():
    return [
        ring(32, 32, 9, stroke=LEDGER, width=PRIMARY),
        path("M13 21 L21 21 L21 13", stroke=BONE, width=DETAIL),
        path("M43 13 L43 21 L51 21", stroke=BONE, width=DETAIL),
        path("M13 43 L21 43 L21 51", stroke=BONE, width=DETAIL),
        path("M43 51 L43 43 L51 43", stroke=BONE, width=DETAIL),
    ]


register(
    "ab_tally_gather", "Gather (1)",
    "A ledger plate disc with four bone corner chevrons pointing inward",
    plate_rounded_square, g_ab_tally_gather,
)


def g_ab_tally_link():
    points = [(32, 15), (15, 46), (49, 46)]
    return [
        path("M32 15 L15 46 H49 Z", stroke=LEDGER, width=PRIMARY, dash="4 6"),
        *[dot(x, y, 5, fill=BONE) for x, y in points],
        *[path(f"M{x + 3} {y - 6} H{x + 7} V{y + 1}",
               stroke=LEDGER, width=PRIMARY) for x, y in points],
    ]


register(
    "ab_tally_link", "Link (2)",
    "Three bone dots joined by a dashed ledger triangle, each dot held by a ledger clip",
    plate_rounded_square, g_ab_tally_link,
)


def g_ab_tally_balance():
    return [
        ring(32, 32, 14, stroke=LEDGER, width=PRIMARY),
        line(26, 28, 38, 28, stroke=BONE, width=DETAIL),
        line(26, 36, 38, 36, stroke=BONE, width=DETAIL),
        line(32, 7, 32, 11, stroke=BONE, width=DETAIL),
        line(32, 53, 32, 57, stroke=BONE, width=DETAIL),
        line(7, 32, 11, 32, stroke=BONE, width=DETAIL),
        line(53, 32, 57, 32, stroke=BONE, width=DETAIL),
    ]


register(
    "ab_tally_balance", "Balance Due (3)",
    "A ledger capacitor ring with a bone equals sign and four discharge rays",
    plate_rounded_square, g_ab_tally_balance,
)

# ---- Remembered cannon abilities (4) -----------------------------------------


def g_ab_cannon_weapon():
    return [
        line(24, 25, 47, 25, stroke=ANCIENT, width=PRIMARY),
        line(24, 39, 47, 39, stroke=ANCIENT, width=PRIMARY),
        chevron(48, 32, 10, 24, stroke=ANCIENT, width=PRIMARY),
        ring(17, 32, 7, stroke=BONE, width=DETAIL),
    ]


register(
    "ab_cannon_weapon", "Cannon lane (LMB)",
    "A bone ball calling two ancient-blue rails toward a right-pointing chevron",
    plate_rounded_square, g_ab_cannon_weapon,
)


def g_ab_cannon_move():
    return [
        line(36, 30, 14, 38, stroke=ANCIENT, width=PRIMARY),
        line(34, 32, 25, 52, stroke=ANCIENT, width=PRIMARY),
        ring(40, 23, 7, stroke=BONE, width=DETAIL),
        path("M44 11 L53 11 L53 20", stroke=BONE, width=DETAIL),
    ]


register(
    "ab_cannon_move", "Recoil split (Shift)",
    "A bone ball moving up-right with two ancient-blue rails splitting behind it",
    plate_rounded_square, g_ab_cannon_move,
)


def g_ab_cannon_special():
    return [
        path("M16 48 L24 13 A36 36 0 0 1 51 39 Z", stroke=ANCIENT, width=PRIMARY),
        path("M26 29 A22 22 0 0 1 37 39", stroke=BONE, width=DETAIL),
        dot(16, 48, 4, fill=BONE),
    ]


register(
    "ab_cannon_special", "Cannon plate (F)",
    "An ancient-blue wedge with a bone apex and an inner wave-front arc",
    plate_rounded_square, g_ab_cannon_special,
)


def g_ab_cannon_smash():
    return [
        line(10, 49, 54, 49, stroke=BONE, width=DETAIL),
        ring(32, 34, 15, stroke=ANCIENT, width=PRIMARY),
        dot(32, 34, 4, fill=BONE),
    ]


register(
    "ab_cannon_smash", "Rush ring (Ctrl)",
    "An ancient-blue ring resting on a bone ground line around its impact dot",
    plate_rounded_square, g_ab_cannon_smash,
)


# ---- Key glyphs (10) ---------------------------------------------------------


def g_key_lmb():
    return [
        rect(18, 8, 28, 46, fill=CHARCOAL, rx=13, stroke=BONE, width=3),
        rect(19, 9, 12, 17, fill=BONE, rx=8),
        line(32, 9, 32, 26, stroke=BONE, width=3),
    ]


register(
    "key_lmb", "Weapon", "A mouse body, the left button a solid bone fill, a clear divider",
    plate_none, g_key_lmb,
)


def g_key_rmb():
    return [
        rect(18, 8, 28, 46, fill=CHARCOAL, rx=13, stroke=BONE, width=3),
        rect(33, 9, 12, 17, fill=BONE, rx=8),
        line(32, 9, 32, 26, stroke=BONE, width=3),
    ]


register(
    "key_rmb", "Movement", "A mouse body, the right button a solid bone fill, a clear divider",
    plate_none, g_key_rmb,
)


def g_key_f():
    return [text(32, 30, "F", 26)]


register("key_f", "Special", 'Keycap "F"', lambda: plate_keycap(), g_key_f)


def g_key_ctrl():
    return [text(32, 30, "CT", 22)]


register("key_ctrl", "Smash", 'A wide keycap "CT"', lambda: plate_keycap(wide=True), g_key_ctrl)


def g_key_space():
    return [rect(16, 26, 32, 8, fill=CHARCOAL, rx=3)]


register(
    "key_space", "Jump, vault, glide",
    "A long flat keycap with an empty face",
    lambda: plate_keycap(wide=True), g_key_space,
)


def g_key_shift():
    return [path("M32 16 L42 28 L36 28 L36 38 L28 38 L28 28 L22 28 Z", stroke=CHARCOAL, width=3, fill="none")]


register(
    "key_shift", "Boost",
    "A wide keycap with an outlined up arrow",
    lambda: plate_keycap(wide=True), g_key_shift,
)


def g_key_e():
    return [text(32, 30, "E", 26)]


register("key_e", "Mount", 'Keycap "E"', lambda: plate_keycap(), g_key_e)


def g_key_q():
    return [text(32, 30, "Q", 26)]


register("key_q", "Winch", 'Keycap "Q"', lambda: plate_keycap(), g_key_q)


def g_key_r():
    return [
        text(23, 24, "R", 18),
        path("M46 34 A 7.5 7.5 0 1 1 41 28.3", stroke=CHARCOAL, width=3),
        f'<polygon points="41,24.5 41,30 46.5,28.5" fill="{CHARCOAL}"/>',
    ]


register(
    "key_r", "Hold to restart",
    'Keycap "R" with a circular arrow',
    lambda: plate_keycap(), g_key_r,
)


def g_key_tab():
    return [
        line(16, 32, 40, 32, stroke=CHARCOAL, width=3),
        path("M36 26 L44 32 L36 38 Z", fill=CHARCOAL),
        rect(44, 24, 4, 16, fill=CHARCOAL),
    ]


register(
    "key_tab", "Hold for field notes",
    "A wide keycap with an arrow into a bar",
    lambda: plate_keycap(wide=True), g_key_tab,
)


def g_key_1():
    return [text(32, 30, "1", 26)]


register("key_1", "Menu choice 1", 'Keycap "1"', lambda: plate_keycap(), g_key_1)


def g_key_2():
    return [text(32, 30, "2", 26)]


register("key_2", "Menu choice 2", 'Keycap "2"', lambda: plate_keycap(), g_key_2)


def g_key_3():
    return [text(32, 30, "3", 26)]


register("key_3", "Menu choice 3", 'Keycap "3"', lambda: plate_keycap(), g_key_3)


def g_key_n():
    return [text(32, 30, "N", 26)]


register("key_n", "New run", 'Keycap "N"', lambda: plate_keycap(), g_key_n)


def g_key_c():
    return [text(32, 30, "C", 26)]


register("key_c", "Choose class", 'Keycap "C"', lambda: plate_keycap(), g_key_c)


def g_key_t():
    return [text(32, 30, "T", 26)]


register("key_t", "Replay stage", 'Keycap "T"', lambda: plate_keycap(), g_key_t)

# ---- Item categories (6) ------------------------------------------------------


def g_cat_damage():
    return [path("M32 12 L40 34 L32 52 L24 34 Z", fill=BONE)]


register("cat_damage", "Weapon damage", "A single sharp claw tooth, point up", plate_hex, g_cat_damage)


def g_cat_mobility():
    return [chevron(32, 24, 18, 12, stroke=BONE), chevron(32, 40, 18, 12, stroke=BONE)]


register(
    "cat_mobility", "Movement", "Two stacked chevrons, pointing right", plate_hex, g_cat_mobility,
)


def g_cat_defense():
    return [
        rect(16, 20, 32, 24, fill=BONE, rx=6),
        dot(22, 26, 2, fill=CHARCOAL), dot(42, 26, 2, fill=CHARCOAL),
        dot(22, 38, 2, fill=CHARCOAL), dot(42, 38, 2, fill=CHARCOAL),
    ]


register(
    "cat_defense", "Plating and resistance",
    "A thick rounded plate with four rivets", plate_hex, g_cat_defense,
)


def g_cat_utility():
    return [
        path("M18 46 L34 30", stroke=BONE, width=PRIMARY),
        path("M34 30 L34 22 L42 14 L46 18 L38 26 L46 26 L38 34 Z", fill=BONE),
    ]


register(
    "cat_utility", "Non-combat effects", "An open-ended wrench, diagonal", plate_hex, g_cat_utility,
)


def g_cat_charge():
    return [
        rect(22, 16, 20, 34, fill="none", stroke=BONE, width=PRIMARY, rx=4),
        rect(28, 11, 8, 5, fill=BONE),
        rect(27, 22, 10, 5, fill=MINT),
        rect(27, 30, 10, 5, fill=MINT),
        rect(27, 38, 10, 5, fill=MINT),
    ]


register(
    "cat_charge", "Extra charges", "A cell with three stacked pips", plate_hex, g_cat_charge,
)


def g_cat_transform():
    return [
        rect(12, 26, 12, 12, fill=BONE),
        f'<circle cx="46" cy="32" r="7" fill="none" stroke="{BONE}" stroke-width="{PRIMARY}"/>',
        path("M26 26 Q 34 14 42 24", stroke=BONE, width=DETAIL),
        path("M42 24 L38 22 M42 24 L40 29", stroke=BONE, width=DETAIL),
    ]


register(
    "cat_transform", "Pattern transformers",
    "A square at left and a circle at right, joined by a curved arrow",
    plate_hex, g_cat_transform,
)

# ---- Elements (3) --------------------------------------------------------------


def g_el_frost():
    els = []
    for i in range(6):
        ang = math.radians(i * 60)
        x2, y2 = 32 + 18 * math.cos(ang), 32 + 18 * math.sin(ang)
        els.append(line(32, 32, x2, y2, stroke=ICE, width=DETAIL))
        bx, by = 32 + 11 * math.cos(ang), 32 + 11 * math.sin(ang)
        pa = ang + math.radians(35)
        pb = ang - math.radians(35)
        els.append(line(bx, by, bx + 5 * math.cos(pa), by + 5 * math.sin(pa), stroke=ICE, width=3))
        els.append(line(bx, by, bx + 5 * math.cos(pb), by + 5 * math.sin(pb), stroke=ICE, width=3))
    return els


register(
    "el_frost", "Frost (ICE)", "A six-arm snowflake with short barbs", plate_circle, g_el_frost,
)


def g_el_arc():
    return [
        path("M26 14 L34 28 L26 30 L38 50", stroke=MINT, width=PRIMARY, join="round"),
        dot(26, 14, 3, fill=BONE), dot(38, 50, 3, fill=BONE),
    ]


register(
    "el_arc", "Arc (mint)", "A zigzag bolt between two small nodes", plate_circle, g_el_arc,
)


def g_el_kinetic():
    return [
        dot(30, 28, 11, fill=BONE),
        line(44, 40, 50, 46, stroke=BONE, width=DETAIL),
        line(46, 34, 53, 37, stroke=BONE, width=DETAIL),
        line(46, 44, 53, 44, stroke=BONE, width=DETAIL),
    ]


register(
    "el_kinetic", "Kinetic (bone)",
    "A heavy ball with three impact lines at one side", plate_circle, g_el_kinetic,
)

# ---- Triggers (12) --------------------------------------------------------------


def g_trg_on_hit():
    return [
        path("M12 18 V10 H20 M44 10 H52 V18 M52 42 V50 H44 M20 50 H12 V42", stroke=BONE, width=DETAIL),
        dot(32, 30, 4, fill=AMBER),
    ]


register(
    "trg_on_hit", "On hit", "A four-bracket reticle with a centre dot", plate_tag, g_trg_on_hit,
)


def g_trg_on_kill():
    return [
        path("M12 18 V10 H20 M44 10 H52 V18 M52 42 V50 H44 M20 50 H12 V42", stroke=BONE, width=DETAIL),
        line(26, 24, 38, 36, stroke=BONE, width=PRIMARY),
        line(38, 24, 26, 36, stroke=BONE, width=PRIMARY),
    ]


register(
    "trg_on_kill", "On kill", "A four-bracket reticle with an X", plate_tag, g_trg_on_kill,
)


def g_trg_on_smash():
    return [chevron(32, 20, 14, 12, stroke=BONE), line(20, 38, 48, 38, stroke=BONE, width=PRIMARY)]


register(
    "trg_on_smash", "On smash", "A down chevron striking a ground line", plate_tag, g_trg_on_smash,
)


# A hop off a floor, never a bare V: three blind readers of three took the V for a tick, and a first-timer
# took a gate that wore it for a gate already taken (play finding 22).
def g_trg_on_rebound():
    return [
        line(26, 46, 52, 46, stroke=BONE, width=DETAIL),
        path("M27 41 Q34 4 41 41", stroke=BONE, width=DETAIL),
        path("M41 41 Q44 27 49 27", stroke=BONE, width=DETAIL),
        dot(49, 26, 4.5, fill=BONE),
    ]


register(
    "trg_on_rebound", "On rebound", "A ball hopping up off a floor line", plate_tag, g_trg_on_rebound,
)


def g_trg_on_vault():
    return [
        rect(20, 14, 5, 26, fill=BONE),
        path("M25 28 L48 16", stroke=BONE, width=DETAIL),
        path("M48 16 L41 17 M48 16 L45 22", stroke=BONE, width=3),
    ]


register(
    "trg_on_vault", "On vault kick", "A wall bar with a sharp exit arrow", plate_tag, g_trg_on_vault,
)


def g_trg_on_charge_release():
    return [
        f'<path d="M 32 16 A 16 16 0 1 1 17.5 24" fill="none" stroke="{BONE}" stroke-width="{DETAIL}"/>',
        path("M17.5 24 L12 18 M17.5 24 L23 22", stroke=BONE, width=3),
    ]


register(
    "trg_on_charge_release", "On charge release",
    "A three-quarter gauge ring with an arrow leaving its gap", plate_tag, g_trg_on_charge_release,
)


def g_trg_on_cloak_break():
    return cloud(32, 30, r=11) + [
        line(23, 21, 41, 39, stroke=AMBER, width=PRIMARY),
    ]


register(
    "trg_on_cloak_break", "On cloak break",
    "A dotted cloud split by a spark", plate_tag, g_trg_on_cloak_break,
)


def g_trg_on_land():
    return [
        dot(32, 22, 8, fill=BONE),
        line(16, 38, 48, 38, stroke=BONE, width=PRIMARY),
        path("M20 38 Q 24 32 28 38", stroke=BONE, width=3),
        path("M36 38 Q 40 32 44 38", stroke=BONE, width=3),
    ]


register(
    "trg_on_land", "On land",
    "A ball above a ground line, two small puff arcs", plate_tag, g_trg_on_land,
)


def g_trg_on_speed_tier_up():
    return [
        f'<path d="M16 38 A 16 16 0 0 1 48 38" fill="none" stroke="{BONE}" stroke-width="{DETAIL}"/>',
        line(32, 38, 42, 24, stroke=BONE, width=3),
        chevron(32, 16, 8, 6, stroke=BONE, width=3),
    ]


register(
    "trg_on_speed_tier_up", "On speed tier up",
    "A speedometer arc, the needle past a tick, a small up chevron", plate_tag, g_trg_on_speed_tier_up,
)


def g_trg_on_pickup():
    return [
        path("M20 14 V26 A 12 12 0 0 0 44 26 V14", stroke=BONE, width=PRIMARY, fill="none"),
        rect(29, 34, 6, 6, fill=MINT),
        line(24, 32, 29, 36, stroke=BONE, width=3, dash="2 2"),
        line(40, 32, 35, 36, stroke=BONE, width=3, dash="2 2"),
    ]


register(
    "trg_on_pickup", "On pickup",
    "A U-magnet with a scrap square and two pull lines", plate_tag, g_trg_on_pickup,
)


def g_trg_on_damage_taken():
    return [
        rect(20, 16, 24, 32, fill="none", stroke=BONE, width=PRIMARY, rx=3),
        path("M28 16 L32 28 L27 30 L36 48", stroke=IRON_OXIDE, width=3),
    ]


register(
    "trg_on_damage_taken", "On damage taken",
    "A plate with a jagged crack", plate_tag, g_trg_on_damage_taken,
)


def g_trg_timed():
    return [
        ring(32, 32, 14, stroke=BONE, width=DETAIL),
        line(32, 32, 32, 21, stroke=BONE, width=3),
        line(32, 32, 40, 32, stroke=BONE, width=3),
        path("M42 20 A 6 6 0 1 1 40 16", stroke=BONE, width=2.5),
    ]


register(
    "trg_timed", "Timed",
    "A clock face with one hand and a small repeat arrow", plate_tag, g_trg_timed,
)

# ---- Threat types (4) -----------------------------------------------------------


def g_thr_instant():
    els = [dot(32, 40, 11, fill=CHARCOAL)]
    for i in range(8):
        ang = math.radians(i * 45)
        x1, y1 = 32 + 11 * math.cos(ang), 40 + 11 * math.sin(ang)
        x2, y2 = 32 + 15 * math.cos(ang), 40 + 15 * math.sin(ang)
        els.append(line(x1, y1, x2, y2, stroke=HAZARD, width=3))
    els.append(ring(32, 40, 11, stroke=HAZARD, width=3))
    return els


register(
    "thr_instant", "Instant AOE", "A solid disc with a spiked rim",
    lambda: plate_triangle("thr-instant-stripes"), g_thr_instant,
)


def g_thr_wave():
    return [
        path("M20 44 Q 32 28 44 44", stroke=HAZARD, width=5),
        chevron(32, 24, 8, 6, stroke=BONE, width=3),
        chevron(20, 34, 8, 6, stroke=BONE, width=3),
        chevron(44, 34, 8, 6, stroke=BONE, width=3),
    ]


register(
    "thr_wave", "Travelling wave", "One arc front with three chevrons pointing outward",
    lambda: plate_triangle("thr-wave-stripes"), g_thr_wave,
)


def g_thr_projectile():
    return [
        path("M14 46 Q 24 24 34 30", stroke=BONE, width=3, dash="3 4"),
        path("M40 38 V30 H48 V38 M38 44 H50 M40 38 L38 44 M48 38 L50 44", stroke=HAZARD, width=3),
    ]


register(
    "thr_projectile", "Projectile", "A dotted arc ending in four closing brackets",
    lambda: plate_triangle("thr-proj-stripes"), g_thr_projectile,
)


def g_thr_lane():
    return [
        dot(14, 40, 4, fill=BONE),
        rect(18, 36, 34, 8, fill="none", stroke=HAZARD, width=3),
        rect(18, 36, 17, 8, fill=HAZARD),
    ]


register(
    "thr_lane", "Lane or beam", "A long bar half filled from its left end, a source dot at left",
    lambda: plate_triangle("thr-lane-stripes"), g_thr_lane,
)

# ---- Objectives (6) ----------------------------------------------------------


def g_obj_beacon():
    return [
        line(32, 18, 32, 50, stroke=BONE, width=PRIMARY),
        f'<path d="M24 24 A 10 10 0 0 1 40 24" fill="none" stroke="{MINT}" stroke-width="{DETAIL}"/>',
        f'<path d="M20 30 A 16 16 0 0 1 44 30" fill="none" stroke="{MINT}" stroke-width="3" opacity="0.7"/>',
    ]


register(
    "obj_beacon", "Beacon", "A mast with two ring waves at its top", plate_brackets, g_obj_beacon,
)


def g_obj_warden():
    return [
        path("M22 18 Q 12 32 22 46", stroke=BONE, width=PRIMARY),
        path("M42 18 Q 52 32 42 46", stroke=BONE, width=PRIMARY),
        line(22, 24, 30, 24, stroke=HAZARD, width=3),
        line(22, 32, 30, 32, stroke=HAZARD, width=3),
        line(22, 40, 30, 40, stroke=HAZARD, width=3),
    ]


register(
    "obj_warden", "The Warden", "A C-clamp jaw with three teeth, closing", plate_brackets, g_obj_warden,
)


def g_obj_gate():
    return [
        rect(18, 24, 7, 26, fill=BONE),
        rect(39, 24, 7, 26, fill=BONE),
        rect(15, 20, 34, 6, fill=BONE),
        poly(32, 18, 8, 4, fill=AMBER, start_deg=-90),
    ]


register(
    "obj_gate", "Reward gate", "A square arch with a diamond keystone", plate_brackets, g_obj_gate,
)


def g_obj_fabricator():
    return [
        f'<circle cx="32" cy="32" r="16" fill="none" stroke="{BONE}" stroke-width="{PRIMARY}"/>',
        poly(32, 32, 8, 6, fill=CHARCOAL, stroke=BONE, width=3, start_deg=0),
    ]


register(
    "obj_fabricator", "Drive-through fabricator",
    "An upright hoop with a hex nut inside", plate_brackets, g_obj_fabricator,
)


def g_obj_vault():
    return [
        rect(16, 26, 32, 22, fill="none", stroke=BONE, width=PRIMARY, rx=3),
        rect(16, 32, 32, 6, fill=AMBER),
        dot(22, 35, 2, fill=CHARCOAL), dot(42, 35, 2, fill=CHARCOAL),
        dot(22, 29, 2, fill=CHARCOAL), dot(42, 29, 2, fill=CHARCOAL),
    ]


register(
    "obj_vault", "Plated vault", "A squat box with a heavy band and four rivets", plate_brackets, g_obj_vault,
)


def g_obj_event():
    return [
        path("M24 40 L24 28 A 8 8 0 0 1 40 28 L40 40 Z", fill=BONE),
        rect(22, 40, 20, 5, fill=BONE),
        path("M44 22 Q 50 26 44 30", stroke=AMBER, width=3),
        path("M48 18 Q 56 26 48 34", stroke=AMBER, width=3),
    ]


register(
    "obj_event", "World event", "A klaxon lamp with two sound arcs", plate_brackets, g_obj_event,
)


def g_obj_launch():
    return [
        ring(32, 46, 9, stroke=BONE, width=DETAIL),
        path("M20 32 L32 16 L44 32", stroke=AMBER, width=PRIMARY),
        line(32, 20, 32, 42, stroke=AMBER, width=DETAIL),
    ]


register(
    "obj_launch", "Launch",
    "A launch rail or upward chevron over a ring, amber reward accent",
    plate_brackets, g_obj_launch,
)


def g_obj_stage():
    return [
        f'<polygon points="10,48 21,24 29,36 37,16 50,48" fill="{BONE}"/>',
    ]


register(
    "obj_stage", "Stage marker", "A canyon silhouette in a bracket frame",
    plate_brackets, g_obj_stage,
)

# ---- Resources (6) -------------------------------------------------------------


def g_res_scrap():
    return [
        poly(32, 32, 18, 4, fill=BONE, start_deg=20),
        ring(32, 32, 3.5, stroke=CHARCOAL, width=2.5),
    ]


register(
    "res_scrap", "Scrap", "An irregular four-facet chunk with a bolt hole", plate_none, g_res_scrap,
)


def g_res_heft():
    return [
        dot(32, 20, 9, fill=BONE),
        rect(14, 34, 36, 6, fill=BONE, rx=2),
        rect(17, 42, 30, 6, fill=BONE, rx=2),
        rect(20, 50, 24, 6, fill=BONE, rx=2),
    ]


register(
    "res_heft", "Heft class", "A ball resting on three stacked plates", plate_none, g_res_heft,
)


def g_res_health():
    return [
        f'<path d="M18 30 A 14 14 0 0 1 46 30 L46 34 A 14 12 0 0 1 32 50 A 14 12 0 0 1 18 34 Z" '
        f'fill="none" stroke="{BONE}" stroke-width="{PRIMARY}"/>',
        line(32, 24, 32, 36, stroke=BONE, width=4),
        line(26, 30, 38, 30, stroke=BONE, width=4),
    ]


register(
    "res_health", "Health", "The cockpit dome with a plus on its glass", plate_none, g_res_health,
)


def g_res_core():
    return [poly(32, 32, 18, 4, fill=BONE, start_deg=0), dot(32, 32, 4, fill=MINT)]


register(
    "res_core", "Bonus core", "A diamond with a mint dot at its heart", plate_none, g_res_core,
)


def g_res_timer():
    return [
        ring(32, 32, 18, stroke=BONE, width=PRIMARY),
        line(32, 32, 32, 18, stroke=BONE, width=3),
        line(32, 32, 42, 32, stroke=BONE, width=3),
    ]


register(
    "res_timer", "Run clock", "A clock face with two hands", plate_none, g_res_timer,
)


def g_res_difficulty():
    els = [line(12, 46, 52, 46, stroke=BONE, width=3)]
    heights = [6, 12, 18, 26]
    xs = [16, 27, 38, 48]
    for x, h in zip(xs, heights):
        els.append(rect(x, 46 - h, 8, h, fill=BONE))
    return els


register(
    "res_difficulty", "Difficulty", "A bar with rising sawtooth notches", plate_none, g_res_difficulty,
)

# ---- Factions (4) ---------------------------------------------------------------


def g_fac_fleet():
    return [
        rect(16, 22, 32, 20, fill=BRASS, rx=2),
        line(24, 22, 24, 42, stroke=CHARCOAL, width=2, dash="3 3"),
        ring(38, 32, 3, stroke=CHARCOAL, width=2.5),
    ]


register(
    "fac_fleet", "Furnace Fleet crews",
    "A brass requisition tag with a stencilled notch and one bolt hole", plate_pentagon, g_fac_fleet,
)


def g_fac_reactor():
    return [
        f'<path d="M16 40 A 16 16 0 0 1 48 40 Z" fill="{BONE}"/>',
        rect(20, 40, 5, 12, fill=ANCIENT),
        rect(29.5, 40, 5, 12, fill=ANCIENT),
        rect(39, 40, 5, 12, fill=ANCIENT),
    ]


register(
    "fac_reactor", "Reactor relics",
    "A low dome over three thick vent bars", plate_pentagon, g_fac_reactor,
)


def g_fac_swarm():
    pts = [(32, 14), (22, 26), (42, 26), (14, 40), (32, 40), (50, 40)]
    els = []
    for cx, cy in pts:
        els.append(f'<polygon points="{cx-6},{cy+6} {cx},{cy-6} {cx+6},{cy+6}" fill="{BONE}"/>')
    els.append(dot(32, 14, 2, fill=ANCIENT))
    return els


register(
    "fac_swarm", "Swarm remnants", "Five small triangles in an arrowhead", plate_pentagon, g_fac_swarm,
)


def g_fac_mind():
    return [
        f'<circle cx="32" cy="30" r="10" fill="none" stroke="{BONE}" stroke-width="{PRIMARY}"/>',
        dot(32, 30, 3, fill=ANCIENT),
        path("M20 24 Q 12 20 14 12", stroke=BONE, width=3),
        path("M44 24 Q 52 20 50 12", stroke=BONE, width=3),
    ]


register(
    "fac_mind", "The Mind's hands", "A round lens held by a two-joint arm", plate_pentagon, g_fac_mind,
)


def g_fac_brindle():
    return [
        poly(32, 30, 13, 5, fill=BRASS, start_deg=-90),
        dot(32, 30, 3, fill=CHARCOAL),
        line(22, 44, 42, 44, stroke=BRASS, width=3),
    ]


register(
    "fac_brindle", "Admiral Brindle (Fleet boss)",
    "Brindle's requisition mark, brass accent, for the boss objective",
    plate_pentagon, g_fac_brindle,
)


# ---- Companion pieces (6): one backplate per family, so "one of each kind" reads from the marks ----
# Conductive primer wears the circle, ram brace the rounded square, escape corridor the hex nut.
# Purpose note: docs/art/reference/fx_ui/companion-piece-icons.md.
# The family frame is a verdigris rim on the plate so the shape shows on a charcoal panel too.
def plate_cmp_circle():
    return [f'<circle cx="32" cy="32" r="28" fill="{CHARCOAL}" stroke="{OLD_VERDIGRIS}" stroke-width="3"/>']


def plate_cmp_square():
    return [rect(4, 4, 56, 56, fill=CHARCOAL, rx=8, stroke=OLD_VERDIGRIS, width=3)]


def plate_cmp_hex():
    return [poly(32, 32, 28, 6, fill=CHARCOAL, stroke=OLD_VERDIGRIS, width=3, start_deg=0)]


def g_cmp_primer_coil():
    return [
        path("M10 40 C10 22 22 22 22 40 C22 22 34 22 34 40 C34 22 46 22 46 40", stroke=MINT, width=PRIMARY),
        ring(47, 20, 6, stroke=BONE, width=DETAIL),
        dot(47, 20, 2.5, fill=AMBER),
    ]


register(
    "cmp_primer_coil", "Primer Coil",
    "A three-loop coil beside a ringed target dot", plate_cmp_circle, g_cmp_primer_coil,
)


def g_cmp_primer_mesh():
    els = [
        line(14, 22, 42, 50, stroke=BONE, width=DETAIL), line(26, 14, 50, 38, stroke=BONE, width=DETAIL),
        line(50, 26, 26, 50, stroke=BONE, width=DETAIL), line(38, 14, 14, 38, stroke=BONE, width=DETAIL),
    ]
    return els + [dot(32, 32, 5, fill=MINT), dot(20, 20, 4, fill=MINT), dot(44, 44, 4, fill=MINT)]


register(
    "cmp_primer_mesh", "Conductive Mesh",
    "A diamond lattice with three lit nodes", plate_cmp_circle, g_cmp_primer_mesh,
)


def g_cmp_ram_prow():
    return [
        f'<polygon points="12,20 36,32 12,44" fill="{COPPER}"/>',
        rect(44, 16, 6, 32, fill=BONE),
        line(38, 24, 40, 24, stroke=BONE, width=DETAIL),
        line(38, 40, 40, 40, stroke=BONE, width=DETAIL),
    ]


register(
    "cmp_ram_prow", "Ram Prow",
    "A solid wedge nose driving a standing bar, with shove ticks", plate_cmp_square, g_cmp_ram_prow,
)


def g_cmp_ram_spring():
    return [
        rect(10, 16, 6, 32, fill=BONE),
        path("M16 32 H20 L24 22 L30 42 L36 22 L40 32", stroke=COPPER, width=PRIMARY),
        rect(44, 20, 6, 24, fill=BONE),
    ]


register(
    "cmp_ram_spring", "Brace Spring",
    "A wall bar, a compressed zigzag spring and a pressed plate", plate_cmp_square, g_cmp_ram_spring,
)


def g_cmp_escape_vent():
    return [
        rect(15, 20, 16, 24, fill="none", stroke=BONE, width=DETAIL),
        line(20, 28, 26, 28, stroke=BONE, width=DETAIL),
        line(20, 36, 26, 36, stroke=BONE, width=DETAIL),
        chevron(38, 32, 8, 14, stroke=ICE),
        chevron(48, 32, 8, 14, stroke=ICE),
    ]


register(
    "cmp_escape_vent", "Escape Vent",
    "A slotted vent box with two chevrons pushing out", plate_cmp_hex, g_cmp_escape_vent,
)


def g_cmp_escape_rail():
    return [
        line(15, 25, 40, 25, stroke=BONE, width=DETAIL),
        line(15, 39, 40, 39, stroke=BONE, width=DETAIL),
        line(21, 21, 21, 43, stroke=BONE, width=3),
        line(32, 21, 32, 43, stroke=BONE, width=3),
        chevron(46, 32, 8, 16, stroke=ICE),
    ]


register(
    "cmp_escape_rail", "Corridor Rail",
    "Two rails with ties and one chevron at the far end", plate_cmp_hex, g_cmp_escape_rail,
)


# ---- The radio take (1): the radio chip's knob, a ring with its needle -----------------------------
# Purpose note: docs/art/reference/fx_ui/radio-take-icon.md. No backplate and a near-white glyph, so
# the card tints it (the HUD modulates the texture) the way it tints the drawn shapes.
def g_radio_take():
    return [
        ring(32, 32, 24, stroke=LEDGER_CREAM, width=PRIMARY),
        dot(32, 32, 5, fill=LEDGER_CREAM),
        line(32, 32, 46, 12, stroke=LEDGER_CREAM, width=PRIMARY),
    ]


register(
    "radio_take", "A radio take",
    "The radio chip's knob: a ring with its needle pointing up and right", plate_none, g_radio_take,
)


# --- Compose and write --------------------------------------------------------
def compose(icon_id):
    spec = ICONS[icon_id]
    backplate_els = spec["backplate"]()
    glyph_els = spec["glyph"]()
    defs = []
    body = []
    for el in backplate_els:
        if el.startswith("<pattern") or el.startswith("<clipPath"):
            defs.append(el)
        else:
            body.append(el)
    defs_block = f"<defs>{''.join(defs)}</defs>" if defs else ""
    body_block = "".join(body) + "".join(glyph_els)
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">'
        f"{defs_block}{body_block}</svg>\n"
    )


def write_readme(ids):
    lines = [
        "# Core-loop V2 icons",
        "",
        f"Generated by `sketches/core-loop/tools/icons/generate_icons.py`, {len(ids)} ids: the list in "
        "`VISUAL-LANGUAGE.md` section 5 plus later pilot portraits and ability icons. SVGs in this folder that the "
        "table does not list are not drawn by the script. Regenerate after any script edit; do not "
        "hand-edit the SVGs.",
        "",
        "| id | file | meaning |",
        "| --- | --- | --- |",
    ]
    for icon_id in ids:
        meaning = ICONS[icon_id]["meaning"]
        lines.append(f"| `{icon_id}` | `{icon_id}.svg` | {meaning} |")
    lines.append("")
    with open(README_PATH, "w") as f:
        f.write("\n".join(lines))


def main():
    os.makedirs(ICON_DIR, exist_ok=True)
    written = []
    for icon_id in ICONS:
        svg = compose(icon_id)
        out_path = os.path.join(ICON_DIR, f"{icon_id}.svg")
        with open(out_path, "w") as f:
            f.write(svg)
        written.append(icon_id)
    write_readme(written)
    print(f"Wrote {len(written)} icons and README.md to {ICON_DIR}")
    return written


def check():
    stale = []
    for icon_id in ICONS:
        path_ = os.path.join(ICON_DIR, f"{icon_id}.svg")
        if not os.path.exists(path_) or open(path_, "rb").read() != compose(icon_id).encode():
            stale.append(icon_id)
    for icon_id in stale:
        print(f"{icon_id}.svg is not what this script draws")
    print(f"{len(ICONS) - len(stale)} of {len(ICONS)} icons match")
    return 1 if stale else 0


if __name__ == "__main__":
    if "--check" in sys.argv[1:]:
        sys.exit(check())
    main()
