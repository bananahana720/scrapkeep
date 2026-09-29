import sys, json, numpy as np
from PIL import Image
from scipy import ndimage
# hole.py's method: subject = value 0 in the subject-black frame; hole = non-subject pixels enclosed by subject (not connected to the border).
M = sys.argv[1]
states = sys.argv[2:]
rows = []
for st in states:
    for tree in ("base", "head"):
        for cam in ("front30", "side30", "rear30"):
            a = np.array(Image.open(f"{M}/{st}/{tree}/subject-black/asset-{cam}.png").convert("L"))
            vals = np.unique(a).tolist()
            subj = a == 0
            lab, n = ndimage.label(~subj)
            border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]])).tolist())
            hole = sum(int((lab == i).sum()) for i in range(1, n + 1) if i not in border)
            ys, xs = np.nonzero(subj)
            bbox = f"x{xs.min()}..{xs.max()} y{ys.min()}..{ys.max()}" if subj.any() else "none"
            rows.append((st, tree, cam, len(vals), vals, int(subj.sum()), hole, bbox))
            print(f"{st:7s} {tree:4s} {cam:8s} values={vals} subject_px={int(subj.sum())} hole_px={hole} bbox={bbox}")
