"""Rendered worker-face detection; no game state or browser DOM access."""

import numpy as np


def components(mask):
    """Exact four-connected components, merging horizontal spans instead of pixels."""
    h, w = mask.shape
    parents = []
    stats = []
    previous = []

    def root(label):
        while parents[label] != label:
            parents[label] = parents[parents[label]]
            label = parents[label]
        return label

    for y in range(h):
        row = mask[y]
        if not row.any():
            previous = []
            continue
        edges = np.flatnonzero(np.diff(np.concatenate(([False], row, [False]))))
        current = []
        p = 0
        for start, end in zip(edges[::2], edges[1::2]):
            start, end = int(start), int(end)
            label = len(parents)
            parents.append(label)
            stats.append([start, y, end, y + 1, end - start, y * w + start])
            while p < len(previous) and previous[p][1] <= start:
                p += 1
            q = p
            while q < len(previous) and previous[q][0] < end:
                other = root(previous[q][2])
                label = root(label)
                if label != other:
                    # Earlier component seed wins, matching the original row-major yield order.
                    if stats[label][5] > stats[other][5]:
                        label, other = other, label
                    parents[other] = label
                    a, b = stats[label], stats[other]
                    a[0] = min(a[0], b[0])
                    a[1] = min(a[1], b[1])
                    a[2] = max(a[2], b[2])
                    a[3] = max(a[3], b[3])
                    a[4] += b[4]
                q += 1
            current.append((start, end, label))
        previous = current
    for label, data in enumerate(stats):
        if parents[label] == label:
            yield tuple(data[:5])


def detect(im):
    scale = 1
    a = np.asarray(im.convert("RGB"))
    r, g, b = a.transpose(2, 0, 1)
    mask = (r < 50) & (g < 60) & (b < 45)
    mask[: int(im.height * 0.20) // scale] = False
    mask[int(im.height * 0.65) // scale :] = False
    targets = []
    for x, y, xx, yy, n in components(mask):
        w, h = xx - x, yy - y
        if not (
            5 <= w <= 100 and 3 <= h <= 50 and 1.3 <= w / h <= 5 and n / (w * h) > 0.45
        ):
            continue
        crop = a[y:yy, x:xx]
        rr, gg, bb = crop.transpose(2, 0, 1)
        eyes = (rr > 145) & (gg > 130) & (bb > 60) & (bb < 225)
        # Worker eyes glow warm; white nameplate lettering can otherwise mimic pairs.
        eyes &= (rr.astype(np.int16) - bb > 20) & (gg.astype(np.int16) - bb > 10)
        blobs = [
            c
            for c in components(eyes)
            if c[4] >= 2
            and c[4] < w * h * 0.12
            and 0.5 < (c[2] - c[0]) / (c[3] - c[1]) < 2
        ]
        for i, p in enumerate(blobs):
            for q in blobs[i + 1 :]:
                px, py = (p[0] + p[2]) / 2, (p[1] + p[3]) / 2
                qx, qy = (q[0] + q[2]) / 2, (q[1] + q[3]) / 2
                if (
                    0.15 * h < py < 0.85 * h
                    and 0.15 * h < qy < 0.85 * h
                    and 0.1 * w < px < 0.9 * w
                    and 0.1 * w < qx < 0.9 * w
                    and abs(py - qy) < max(2, h * 0.15)
                    and w * 0.2 < abs(px - qx) < w * 0.85
                ):
                    targets.append(
                        {
                            "x": (x + (px + qx) / 2) * scale,
                            "y": (y + (py + qy) / 2) * scale,
                            "box": [x * scale, y * scale, xx * scale, yy * scale],
                        }
                    )
                    break
            else:
                continue
            break
    return targets
