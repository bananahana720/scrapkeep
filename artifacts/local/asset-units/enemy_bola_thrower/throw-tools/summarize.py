import re, json, sys, numpy as np
from PIL import Image
from scipy import ndimage
M = "capture-throw"
S = ["wind25", "wind60", "wind95", "rel30", "rel70", "rel95", "land"]
def vec(s): return np.array([float(x) for x in s.split(",")])
def rb(st, tree):
    lines = open(f"{M}/{st}/readback-{tree}.txt").read().splitlines()
    line = [l for l in lines if l.startswith("STATE frozen")][0]
    d = dict(re.findall(r"(\w+)=(\([^)]*\)|\S+)", line))
    return d
def hole(path):
    a = np.array(Image.open(path).convert("L")); subj = a == 0
    lab, n = ndimage.label(~subj)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]])).tolist())
    return sorted(np.unique(a).tolist()), int(subj.sum()), sum(int((lab == i).sum()) for i in range(1, n + 1) if i not in border)
out = []
for st in S:
    h, b = rb(st, "head"), rb(st, "base")
    fr = json.load(open(f"{M}/{st}/head/lit/frames.json"))
    eyes = {f["id"]: np.array(f["eye"]) for f in fr["frames"]}
    pos = vec(h["bola_pos"].strip("()")); ax = vec(h["axis"].strip("()"))
    row = f"| {st} | {h['phase']} | {h['_t']} | {h['bola_top']} | {h['held']} | {h['bola_pos']} |"
    los = []
    holes = {}
    for cam in ("front30", "side30", "rear30"):
        e = eyes["asset-" + cam]; u = (e - pos) / np.linalg.norm(e - pos)
        los.append(f"{abs(float(ax @ u)):.3f}")
        vh, sh, hh = hole(f"{M}/{st}/head/subject-black/asset-{cam}.png")
        vb, sb, hb = hole(f"{M}/{st}/base/subject-black/asset-{cam}.png")
        assert vh == [0, 127] and vb == [0, 127], (st, cam, vh, vb)
        holes[cam] = f"{hb} / {hh}"
    row += " " + " / ".join(los) + " | " + " | ".join(holes[c] for c in ("front30", "side30", "rear30")) + " |"
    out.append(row)
    print(row, "| base phase", b["phase"], b["_t"], "base_bola_pos", b["bola_pos"])
open("/home/andrew/Projects/scrapkeep/artifacts/local/visual-development/asset-c13b/scratchpad/c13d/table.md", "w").write("\n".join(out))
