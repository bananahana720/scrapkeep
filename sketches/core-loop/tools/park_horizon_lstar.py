#!/usr/bin/env python3
"""Mean CIE L* of the near box and the fitted haze box of each frame (World lane, ground over horizon).

  park_horizon_lstar.py <frames dir> <horizon_boxes.json> [--out <json>] [--overlay <dir>]

horizon_boxes.json comes from tools/park_horizon_boxes.gd. Each pose's "file" is matched to a frame by its stem, so a .png
name finds a .jpg frame. Per box: the mean over pixels of L* (sRGB decode, D65 white, CIE Lab), and the mean a* and b*.
gap = near L* - haze L*. gap_fixed uses the old fixed haze box (0, 365, 1280, 405) for comparison; gap_terrain fits the box to terrain_skyline_y.
The measure is the sky band: haze L* is the mean L* over the kept sample pixels (haze_samples, rays that hit nothing just above each
column's skyline; single pixels, no 2x2 averaging; each is [x, y] in frame pixels), gap = near L* - haze L* over valid poses (valid comes from the boxes file). The
median-box gap (haze_box_median) and the fixed-box gap are printed for comparison.
--overlay writes each frame with the near box, the haze box (green) and the per-column skyline points (red circles; blue squares for the terrain-only skyline) drawn, and the kept haze samples as small yellow-green dots.
"""
import argparse
import json
import os
import sys

from PIL import Image, ImageDraw

FIXED_HAZE = [0, 365, 1280, 405]
D65 = (0.95047, 1.0, 1.08883)
_LIN = [((i / 255.0) / 12.92 if i / 255.0 <= 0.04045 else (((i / 255.0) + 0.055) / 1.055) ** 2.4) for i in range(256)]


def _f(t):
    return t ** (1.0 / 3.0) if t > 216.0 / 24389.0 else (24389.0 / 27.0 * t + 16.0) / 116.0


def lab(r, g, b):
    lr, lg, lb = _LIN[r], _LIN[g], _LIN[b]
    x = 0.4124564 * lr + 0.3575761 * lg + 0.1804375 * lb
    y = 0.2126729 * lr + 0.7151522 * lg + 0.0721750 * lb
    z = 0.0193339 * lr + 0.1191920 * lg + 0.9503041 * lb
    fx, fy, fz = _f(x / D65[0]), _f(y / D65[1]), _f(z / D65[2])
    return 116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz)


def box_lab(img, box):
    """Mean (L*, a*, b*) of the pixels in box [x0, y0, x1, y1] (clipped), or None when empty."""
    w, h = img.size
    x0, y0, x1, y1 = max(0, box[0]), max(0, box[1]), min(w, box[2]), min(h, box[3])
    if x1 <= x0 or y1 <= y0:
        return None
    crop = img.crop((x0, y0, x1, y1))
    pixels = crop.get_flattened_data() if hasattr(crop, "get_flattened_data") else crop.getdata()
    counts = {}
    for p in pixels:
        counts[p] = counts.get(p, 0) + 1
    sl = sa = sb = 0.0
    for (r, g, b), n in counts.items():
        l, a, bb = lab(r, g, b)
        sl += l * n
        sa += a * n
        sb += bb * n
    n = (x1 - x0) * (y1 - y0)
    return sl / n, sa / n, sb / n


def self_check():
    white = lab(255, 255, 255)[0]
    grey = lab(128, 128, 128)[0]
    assert abs(white - 100.0) < 0.01, white
    assert abs(grey - 53.585) < 0.05, grey
    return white, grey


def find_frame(frames_dir, name):
    stem = os.path.splitext(name)[0]
    for f in sorted(os.listdir(frames_dir)):
        if os.path.splitext(f)[0] == stem and f.lower().endswith((".png", ".jpg", ".jpeg")):
            return os.path.join(frames_dir, f)
    return None


def samples_lab(img, samples):
    """Mean (L*, a*, b*) over single pixels at the [x, y] samples, or None when there are none."""
    if not samples:
        return None
    px = img.load()
    sl = sa = sb = 0.0
    for x, y in samples:
        l, a, b = lab(*px[x, y])
        sl += l
        sa += a
        sb += b
    n = len(samples)
    return sl / n, sa / n, sb / n


def draw_overlay(img, pose, path):
    o = img.copy()
    d = ImageDraw.Draw(o)
    d.rectangle(pose["near_box"], outline=(255, 255, 0), width=2)
    if pose.get("haze_box_median"):
        d.rectangle(pose["haze_box_median"], outline=(0, 255, 0), width=1)
    for x, y in pose.get("haze_samples") or []:
        d.rectangle([x - 1, y - 1, x + 1, y + 1], fill=(190, 255, 0))
    d.rectangle(FIXED_HAZE, outline=(0, 200, 255), width=1)
    w = img.size[0]
    cols = pose.get("skyline_cols") or []
    for i, y in enumerate(cols):
        if y is not None:
            x = (i + 0.5) * w / len(cols)
            d.ellipse([x - 4, y - 4, x + 4, y + 4], outline=(255, 0, 0), width=2)
    for i, y in enumerate(pose.get("terrain_skyline_cols") or []):
        if y is not None:
            x = (i + 0.5) * w / len(cols or [0] * 33)
            d.rectangle([x - 2, y - 2, x + 2, y + 2], outline=(0, 120, 255), width=1)
    gh = pose.get("geometric_horizon_y")
    if gh is not None and 0 <= gh < img.size[1]:
        d.line([0, gh, 30, gh], fill=(255, 0, 255), width=2)
    o.save(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("frames")
    ap.add_argument("boxes")
    ap.add_argument("--out")
    ap.add_argument("--overlay")
    args = ap.parse_args()
    self_check()
    data = json.load(open(args.boxes))
    if args.overlay:
        os.makedirs(args.overlay, exist_ok=True)
    rows = []
    print("idx  valid  n    near_L  haze_L   gap   | median_box: gap  | fixed_box: gap  | file")
    for pose in data["poses"]:
        path = find_frame(args.frames, pose["file"])
        if path is None:
            print("%3d  no frame for %s" % (pose["idx"], pose["file"]), file=sys.stderr)
            continue
        img = Image.open(path).convert("RGB")
        near = box_lab(img, pose["near_box"])
        haze = samples_lab(img, pose.get("haze_samples"))
        med = box_lab(img, pose["haze_box_median"]) if pose.get("haze_box_median") else None
        fixed = box_lab(img, FIXED_HAZE)
        valid = bool(pose.get("valid"))
        row = {
            "idx": pose["idx"], "file": os.path.basename(path), "valid": valid,
            "haze_sample_count": pose.get("haze_sample_count"), "haze_median_hit_m": pose.get("haze_median_hit_m"),
            "near": dict(zip("Lab", near)),
            "haze": dict(zip("Lab", haze)) if haze else None,
            "gap": near[0] - haze[0] if haze else None,
            "gap_median_box": near[0] - med[0] if med else None,
            "gap_fixed": near[0] - fixed[0],
        }
        rows.append(row)
        print("%3d  %-5s  %3s  %6.2f  %6s  %6s  | %6s | %6.2f | %s" % (
            row["idx"], "yes" if valid else "NO", row["haze_sample_count"], near[0], "%.2f" % haze[0] if haze else "-",
            "%.2f" % row["gap"] if haze else "-", "%.2f" % row["gap_median_box"] if med else "-", row["gap_fixed"], row["file"]))
        if args.overlay:
            draw_overlay(img, pose, os.path.join(args.overlay, os.path.splitext(row["file"])[0] + ".png"))
    vg = [r["gap"] for r in rows if r["valid"] and r["gap"] is not None]
    vm = [r["gap_median_box"] for r in rows if r["valid"] and r["gap_median_box"] is not None]
    vf = [r["gap_fixed"] for r in rows if r["valid"]]
    if vg:
        print("mean over %d valid poses: gap %.2f (median box %.2f, fixed box %.2f)" % (len(vg), sum(vg) / len(vg), sum(vm) / max(len(vm), 1), sum(vf) / len(vf)))
    if args.out:
        with open(args.out, "w") as fh:
            json.dump({"boxes": args.boxes, "frames": args.frames, "mean_gap_valid": sum(vg) / len(vg) if vg else None, "rows": rows}, fh, indent=1)


if __name__ == "__main__":
    main()
