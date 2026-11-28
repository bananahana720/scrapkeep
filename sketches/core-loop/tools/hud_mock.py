#!/usr/bin/env python3
"""Draw the Feel document's 1080p layout over the supplied v2 still using Pillow."""

import argparse
import hashlib
import json
from pathlib import Path
import re

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
DOC = ROOT / "sketches/core-loop/design-v3/FEEL-READABILITY.md"
DEFAULT_STILL = (
    Path.home()
    / "Projects/scrapkeep-worktrees/core-loop-v2/"
    "artifacts/local/alpha-capture/19fc173-seed1/25-warden3.png"
)
SIZE = (1920, 1080)
SAFE = (96, 54, 1728, 972)
MINT = (125, 240, 215, 255)
AMBER = (255, 196, 102, 255)
BONE = (238, 228, 200, 255)
RED = (255, 103, 86, 255)
INK = (22, 30, 31, 255)


def font(size):
    for path in (
        "/usr/share/fonts/liberation/LiberationSans-Regular.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ):
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default(size=size)


def bounds(box):
    x, y, w, h = box
    return x, y, x + w, y + h


def overlaps(a, b):
    ax, ay, ar, ab = bounds(a)
    bx, by, br, bb = bounds(b)
    return ax < br and ar > bx and ay < bb and ab > by


def load_layout():
    section = DOC.read_text().split("### 2.5", 1)[1].split("### 2.6", 1)[0]
    boxes = {}
    for line in section.splitlines():
        match = re.match(r"\| (.*?) \| (\d+), (\d+), (\d+), (\d+) \|", line)
        if match:
            boxes[match[1]] = tuple(map(int, match.groups()[1:]))
    if len(boxes) != 13:
        raise ValueError(f"Expected 13 layout rectangles in §2.5, got {len(boxes)}")
    return boxes


def validate(boxes):
    exclusion = boxes["Reticle exclusion"]
    corridor = boxes["Prompt corridor, forbidden to prompts"]
    occupied = {k: v for k, v in boxes.items() if k not in (
        "Reticle exclusion", "Prompt corridor, forbidden to prompts"
    )}
    sx, sy, sr, sb = bounds(SAFE)
    for name, box in occupied.items():
        x, y, right, bottom = bounds(box)
        assert sx <= x < right <= sr and sy <= y < bottom <= sb, name
        assert not overlaps(box, exclusion), f"Reticle collision: {name}"
        if name.startswith("Prompt slot"):
            assert not overlaps(box, corridor), f"Corridor collision: {name}"
    for i, (name, box) in enumerate(occupied.items()):
        for other, target in list(occupied.items())[i + 1:]:
            assert not overlaps(box, target), f"Overlap: {name} / {other}"


def dashed(draw, box, colour, step=18):
    x, y, right, bottom = bounds(box)
    for xx in range(x, right, step * 2):
        for yy in (y, bottom):
            draw.line((xx, yy, min(xx + step, right), yy), fill=colour, width=2)
    for yy in range(y, bottom, step * 2):
        for xx in (x, right):
            draw.line((xx, yy, xx, min(yy + step, bottom)), fill=colour, width=2)


def label(draw, at, text, colour=BONE, size=22):
    face = font(size)
    rect = draw.textbbox(at, text, font=face)
    draw.rectangle((rect[0] - 5, rect[1] - 3, rect[2] + 5, rect[3] + 3), fill=INK)
    draw.text(at, text, fill=colour, font=face)


def panel(still, boxes, proposed):
    canvas = still.convert("RGBA")
    overlay = Image.new("RGBA", SIZE)
    draw = ImageDraw.Draw(overlay)
    if proposed:
        mask = ImageDraw.Draw(canvas)
        for rect in [(10, 4, 180, 82), (760, 4, 1160, 82), (0, 950, 1320, 1080)]:
            mask.rectangle(rect, fill=INK)
        for number, (name, box) in enumerate(boxes.items(), 1):
            if name in ("Reticle exclusion", "Prompt corridor, forbidden to prompts"):
                continue
            draw.rectangle(bounds(box), fill=(22, 30, 31, 185), outline=MINT, width=3)
            x, y, w, h = box
            if name.startswith("Ability bar"):
                for i, key in enumerate(["LMB", "RMB", "F", "Ctrl"]):
                    left = x + i * 94
                    draw.rectangle((left, y, left + 80, y + 80), outline=AMBER, width=2)
                    draw.text((left + 4, y + 80), key, font=font(22), fill=BONE)
                label(draw, (x, y - 32), "10  ABILITIES  /  362 x 110", MINT)
            elif name == "Chain counter":
                draw.text((x + 17, y + 9), "8", font=font(42), fill=AMBER)
                label(draw, (x + w + 15, y + 20), "6  CHAIN", MINT)
            elif name.startswith("Health tank"):
                draw.rectangle((x + 4, y + 16, x + 314, y + 32), outline=BONE, width=2)
                draw.rectangle((x + 5, y + 17, x + 237, y + 31), fill=MINT)
                label(draw, (x, y - 31), "9  HULL + SPEED", MINT)
            elif name.startswith("Heft dial"):
                draw.ellipse((x + 8, y + 8, x + 87, y + 87), outline=AMBER, width=4)
                draw.text((x + 95, y + 33), "138", font=font(27), fill=MINT)
                label(draw, (x, y - 31), "11  HEFT + SCRAP", MINT)
            else:
                short = {
                    "Status: stage pips, clock, difficulty": "1  STATUS",
                    "Objective: icon, ≤ 5 words, core pips, integrity chunks": "2  OBJECTIVE + INTEGRITY",
                    "Toast, one": "3  ONE TOAST",
                    "Callout or hold-R meter, mutually exclusive": "4  CALLOUT / HOLD R",
                    "Prompt slot 1": "7  PROMPT 1",
                    "Prompt slot 2": "7  PROMPT 2",
                    "Prompt slot 3": "7  PROMPT 3",
                }[name]
                draw.text((x + 9, y + 6), short, font=font(min(24, h - 10)), fill=BONE)
        dashed(draw, boxes["Reticle exclusion"], RED)
        label(draw, (764, 302), "5  NO SECONDARY HUD  /  400 x 400", RED)
        dashed(draw, boxes["Prompt corridor, forbidden to prompts"], AMBER)
        label(draw, (676, 847), "8  FLOOR CORRIDOR: NO PROMPTS", AMBER)
    else:
        for box, title in [
            ((12, 6, 164, 73), "CURRENT STATUS"),
            ((764, 6, 392, 72), "CURRENT OBJECTIVE"),
            ((584, 958, 730, 83), "CURRENT LOWER STRIP"),
        ]:
            draw.rectangle(bounds(box), outline=AMBER, width=3)
            label(draw, (box[0], box[1] + box[3] + 8 if box[1] < 500 else box[1] - 35), title, AMBER)
    dashed(draw, SAFE, BONE, step=12)
    label(draw, (105, 885), "5% SAFE: x 96..1824  /  y 54..1026", BONE)
    return Image.alpha_composite(canvas, overlay).convert("RGB")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--still", type=Path, default=DEFAULT_STILL)
    parser.add_argument("--out", type=Path, default=ROOT / "artifacts/local/hud-mock")
    args = parser.parse_args()
    with Image.open(args.still) as original:
        if original.size != SIZE:
            raise ValueError(f"Expected native {SIZE} source, got {original.size}")
        still = original.convert("RGB")
    boxes = load_layout()
    validate(boxes)
    output = Image.new("RGB", (3880, 1410), INK[:3])
    draw = ImageDraw.Draw(output)
    for x, heading, proposed in [(10, "TODAY / v2 captured HUD", False),
                                  (1950, "v3 / proposed layout boxes", True)]:
        draw.text((x + 20, 20), heading, font=font(36), fill=BONE)
        output.paste(panel(still, boxes, proposed), (x, 80))
    notes = [
        "PLACEMENT STUDY  |  Each panel is native 1920 x 1080. Labels and guides are annotations, not fight text.",
        "Same 25-warden3.png under both panels. Right masks the old HUD; world geometry is unchanged. No v3 rendering or feel claim.",
        "Mint = allocated HUD boxes. Bone dashed = title-safe. Red dashed = reticle exclusion. Amber dashed = prompt-free floor corridor.",
        "§2.5 fixes: abilities 4 x 80 + 3 x 14 = 362 px; chain outside exclusion; all proposed boxes above the 54 px bottom margin.",
        "Runtime gate: ≤25 fight words, ≥26 px key glyphs, collision-free reflow, and moving dense footage with music + threat SFX.",
    ]
    for i, note in enumerate(notes):
        draw.text((30, 1180 + i * 42), note, font=font(27), fill=BONE)
    args.out.mkdir(parents=True, exist_ok=True)
    target = args.out / "side-by-side.png"
    output.save(target)
    manifest = {
        "source": str(args.still), "source_sha256": hashlib.sha256(args.still.read_bytes()).hexdigest(),
        "document": str(DOC), "layout": boxes, "safe": SAFE, "validated": True,
        "output": str(target), "output_sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
        "limitations": "PIL placement study. Annotation words are not game HUD. Moving/native evidence pending.",
    }
    (args.out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(target)
    print("13 document rectangles parsed; safe bounds, exclusions and occupied-box intersections pass.")


if __name__ == "__main__":
    main()
