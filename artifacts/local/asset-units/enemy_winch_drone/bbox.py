import sys, numpy as np
from PIL import Image
base = "/home/andrew/Projects/scrapkeep/artifacts/local/visual-development/asset-c18/artifacts/local/asset-units/enemy_winch_drone"
for s in ("resting", "working"):
    print(s)
    for cam in ("asset-front30", "asset-side30", "asset-rear30", "asset-use6"):
        for rev in ("head", "base"):
            a = np.array(Image.open(f"{base}/capture-{s}/{rev}/subject-black/{cam}.png").convert("RGB"))
            vals = sorted({tuple(p) for p in a.reshape(-1, 3)[::37]} | {tuple(p) for p in np.unique(a.reshape(-1, 3), axis=0)})
            black = (a.sum(axis=2) == 0)
            ys, xs = np.where(black)
            bb = (xs.min(), ys.min(), xs.max(), ys.max()) if len(xs) else None
            print(f"  {cam} {rev} values={len(vals)} {vals} bbox_of_black={bb} w={bb[2]-bb[0]+1} h={bb[3]-bb[1]+1} area={int(black.sum())}")
