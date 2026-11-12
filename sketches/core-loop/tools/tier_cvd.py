#!/usr/bin/env python3
"""W1-26 proof: the tier still (tools/tier_still.gd) under deuteranopia.

Applies the Machado, Oliveira and Fernandes (2009) deuteranopia matrix at severity 1.0 in
linear RGB, writes normal and deuteranopia side by side, and checks that the four tiers
still differ by shape: in each row (gems, ball pieces, shop frames) it cuts each tier's
silhouette from the simulated image, drops what all four share (the bare ball), and reports the largest overlap (IoU) between any two
tiers. A row passes below 0.8, where two silhouettes are clearly different shapes.

  python3 tools/tier_cvd.py <tiers.png> <out.png>
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
COLUMNS = [800 + (i - 1.5) * 333 for i in range(4)]
HALF_W = 150
ROWS = {"gems": (130, 345), "pieces": (380, 500), "shop": (705, 790)}
TIERS = ["common", "rare", "relic", "evolved"]


def to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def main(src, out):
    rgb = np.asarray(Image.open(src).convert("RGB"), dtype=np.float64) / 255.0
    sim = to_srgb(to_linear(rgb) @ DEUTAN.T)
    side = np.concatenate([rgb, sim], axis=1)
    Image.fromarray((side * 255).round().astype(np.uint8)).save(out)
    bg = sim[5, 5]
    report = {}
    ok = True
    for row, (y0, y1) in ROWS.items():
        masks = []
        for cx in COLUMNS:
            cell = sim[y0:y1, int(cx - HALF_W):int(cx + HALF_W)]
            masks.append(np.abs(cell - bg).sum(axis=2) > 0.12)
        # What every cell shares (the bare ball under the pieces) is no tier's evidence.
        shared = np.logical_and.reduce(masks)
        masks = [m & ~shared for m in masks]
        worst = 0.0
        pair = ""
        for a in range(4):
            for b in range(a + 1, 4):
                inter = np.logical_and(masks[a], masks[b]).sum()
                union = np.logical_or(masks[a], masks[b]).sum()
                iou = inter / union if union else 1.0
                if iou > worst:
                    worst, pair = iou, f"{TIERS[a]}/{TIERS[b]}"
        report[row] = {"max_iou": round(float(worst), 3), "pair": pair, "pass": bool(worst < 0.8)}
        ok = ok and worst < 0.8
    print(json.dumps(report, indent=1))
    print("tier_cvd:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
