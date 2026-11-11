"""Pass C census: joins census-<seed>.json files from tools/sysaudit/clip_census.gd runs.

Usage: python3 -I census.py <runs dir> <clips dir>
Prints a markdown table of the feel facts per run and writes feel-timeline.png (one run per row:
carves, near misses, hits taken, slams and harpoon bites over run time) into <clips dir>.
"""
import glob
import json
import os
import sys

from PIL import Image, ImageDraw

FACTS = ["carved", "near_miss", "player_hit", "slammed", "landed", "harpoon_bit", "harpoon_smashed",
         "enemy_struck", "strike_deflected", "boosted", "jumped", "boss_weak_point_hit", "heft_class_changed",
         "maker_set_completed", "escape_window", "ultimate_ready", "enemy_killed"]
COLOURS = {"carved": (240, 170, 40), "near_miss": (80, 200, 255), "player_hit": (230, 60, 50),
           "slammed": (180, 120, 255), "harpoon_bit": (120, 230, 120)}


def load(root):
    runs = []
    for path in sorted(glob.glob(os.path.join(root, "*", "census-*.json"))):
        with open(path) as f:
            d = json.load(f)
        d["name"] = os.path.basename(os.path.dirname(path))
        runs.append(d)
    return runs


def total(d, k):
    return sum(d["events"].get(k, {}).values())


def table(runs):
    head = "| Fact | " + " | ".join(r["name"] for r in runs) + " |"
    rows = [head, "| --- |" + " --- |" * len(runs)]
    rows.append("| run time (s) | " + " | ".join(str(round(r["run_time"])) for r in runs) + " |")
    rows.append("| seconds carving | " + " | ".join(str(r["carve_seconds"]) for r in runs) + " |")
    rows.append("| carves started | " + " | ".join(str(r["carves_started"]) for r in runs) + " |")
    for k in FACTS:
        rows.append("| `%s` | " % k + " | ".join(str(total(r, k)) for r in runs) + " |")
    sent = lambda r: sum(v for k, v in r["rumbles"].items() if k.endswith(" sent"))
    held = lambda r: sum(v for k, v in r["rumbles"].items() if k.endswith(" held"))
    rows.append("| rumbles sent / held | " + " | ".join("%d / %d" % (sent(r), held(r)) for r in runs) + " |")
    return "\n".join(rows)


def timeline(runs, out):
    w, lane, pad, left = 1200, 46, 24, 170
    h = pad * 2 + lane * len(runs) + 40
    img = Image.new("RGB", (w, h), (24, 22, 28))
    d = ImageDraw.Draw(img)
    span = max((r["run_time"] for r in runs), default=1.0) or 1.0
    x_of = lambda t: left + (w - left - pad) * t / span
    for i, r in enumerate(runs):
        y = pad + i * lane
        d.text((8, y + 14), r["name"], fill=(220, 220, 220))
        d.line([(left, y + lane - 8), (w - pad, y + lane - 8)], fill=(70, 70, 80))
        for row in r["timeline"]:
            t, kind = row[0], row[1]
            c = COLOURS.get(kind)
            if c is None:
                continue
            x = x_of(t)
            band = list(COLOURS).index(kind)
            yy = y + 4 + band * 7
            if kind == "carved" and len(row) > 3:
                length = max(2.0, (w - left - pad) * row[3]["seconds"] / span)
                d.rectangle([x - length, yy, x, yy + 5], fill=c)
            else:
                d.rectangle([x - 1, yy, x + 1, yy + 5], fill=c)
    for t in range(0, int(span) + 1, 60):
        x = x_of(t)
        d.text((x - 8, h - 34), "%dm" % (t // 60), fill=(160, 160, 170))
    x = left
    for kind, c in COLOURS.items():
        d.rectangle([x, h - 16, x + 10, h - 8], fill=c)
        d.text((x + 14, h - 18), kind, fill=(200, 200, 200))
        x += 130
    img.save(out)


if __name__ == "__main__":
    runs = load(sys.argv[1])
    print(table(runs))
    os.makedirs(sys.argv[2], exist_ok=True)
    timeline(runs, os.path.join(sys.argv[2], "feel-timeline.png"))
