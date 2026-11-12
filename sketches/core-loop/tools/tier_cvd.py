#!/usr/bin/env python3
"""W1-26 proof: the tier still (tools/tier_still.gd) under deuteranopia.

Applies the Machado, Oliveira and Fernandes (2009) deuteranopia matrix at severity 1.0 in
linear RGB, writes normal and deuteranopia side by side, and checks that the four tiers
still differ by shape. In each row (gems, ball pieces, shop frames) it cuts each tier's
silhouette from the simulated image: a gem or a frame is every pixel off the background, and
a ball piece every pixel that differs from the bare twin still (<tiers>-bare.png, the pieces
hidden), so the ball under it does not count. Every pair of tiers is compared by the pixels
where one has shape and the other does not (XOR). A row passes when its closest pair differs
by MIN_PX or more. Each row also reports its highest IoU, for reference only.

  python3 tools/tier_cvd.py <tiers.png> <out.png>   (reads <tiers>-bare.png beside it)
"""
import json
import sys

import numpy as np
from PIL import Image

DEUTAN = np.array([[0.367322, 0.860646, -0.227968],
                   [0.280085, 0.672501, 0.047413],
                   [-0.011820, 0.042940, 0.968881]])
# Cells of the 1600x900 still: column centres, then each row's y span (the ball row is cut
# above the balls, so only the pieces and their feet count).
COLUMNS = [800 + (i - 1.5) * 334 for i in range(4)]  # tier_still.gd COLUMN_PX
HALF_W = 150
ROWS = {"gems": (130, 345), "pieces": (370, 520), "shop": (700, 800)}
TIERS = ["common", "rare", "relic", "evolved"]
# Set before the first run (12 Nov), not tuned to it: 300 px is about a 17 px square on the
# 1600x900 still, a little more than one 16 px icon (VISUAL-LANGUAGE section 5's smallest
# glyph), so the closest pair differs by at least one icon's worth of shape. The shop row
# failed it first (165 px) and passed only after the frames changed (333 px); the threshold
# stayed put.
MIN_PX = 300


def to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def closest_pair(masks):
    least, iou_max, pair = None, 0.0, ""
    for a in range(4):
        for b in range(a + 1, 4):
            xor = int(np.logical_xor(masks[a], masks[b]).sum())
            union = np.logical_or(masks[a], masks[b]).sum()
            iou_max = max(iou_max, float(np.logical_and(masks[a], masks[b]).sum() / union) if union else 1.0)
            if least is None or xor < least:
                least, pair = xor, f"{TIERS[a]}/{TIERS[b]}"
    return least, pair, iou_max


def deutan(path):
    rgb = np.asarray(Image.open(path).convert("RGB"), dtype=np.float64) / 255.0
    return rgb, to_srgb(to_linear(rgb) @ DEUTAN.T)


def main(src, out):
    rgb, sim = deutan(src)
    _, bare = deutan(src[:-4] + "-bare.png")
    side = np.concatenate([rgb, sim], axis=1)
    Image.fromarray((side * 255).round().astype(np.uint8)).save(out)
    bg = sim[5, 5]
    report = {}
    ok = True
    for row, (y0, y1) in ROWS.items():
        masks = []
        for cx in COLUMNS:
            x0, x1 = int(cx - HALF_W), int(cx + HALF_W)
            cell = sim[y0:y1, x0:x1]
            ref = bare[y0:y1, x0:x1] if row == "pieces" else bg
            masks.append(np.abs(cell - ref).sum(axis=2) > 0.12)
        least, pair, iou = closest_pair(masks)
        report[row] = {"closest_pair": pair, "differing_px": least, "max_iou": round(iou, 3), "pass": least >= MIN_PX}
        ok = ok and least >= MIN_PX
    print(json.dumps(report, indent=1))
    print("tier_cvd:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
