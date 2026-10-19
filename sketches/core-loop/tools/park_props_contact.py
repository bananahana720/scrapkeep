#!/usr/bin/env python3
"""Contact sheet for a park_props_audit run: python3 tools/park_props_contact.py <out/map dir>.

Reads stills.json beside the PNGs and writes contact.png: one tile per still, labelled with the sample index,
metres along its line, dressing in view within 120 m and the BARE flag. PIL only.
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

TILE_W, TILE_H, CAPTION_H, COLS = 480, 270, 34, 4


def font(size):
    for path in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf"):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def main(directory):
    with open(os.path.join(directory, "stills.json")) as handle:
        data = json.load(handle)
    stills = sorted(data["stills"], key=lambda s: s["idx"])
    if not stills:
        print("no stills")
        return 1
    rows = (len(stills) + COLS - 1) // COLS
    sheet = Image.new("RGB", (COLS * TILE_W, rows * (TILE_H + CAPTION_H)), (24, 24, 24))
    draw = ImageDraw.Draw(sheet)
    small = font(13)
    for i, still in enumerate(stills):
        x = (i % COLS) * TILE_W
        y = (i // COLS) * (TILE_H + CAPTION_H)
        image = Image.open(os.path.join(directory, still["file"])).convert("RGB").resize((TILE_W, TILE_H), Image.LANCZOS)
        sheet.paste(image, (x, y + CAPTION_H))
        bare = bool(still["bare"])
        draw.rectangle((x, y, x + TILE_W - 1, y + CAPTION_H - 1), fill=(120, 20, 20) if bare else (30, 60, 40))
        text = "#%d %dm %s | in view %d | core60 %d | kinds %d | %s" % (
            still["idx"], round(still["along_m"]), still["line"], still["props_120"], still["core_60"], still["kinds_120"], "BARE" if bare else "ok")
        draw.text((x + 6, y + 8), text, fill=(255, 255, 255), font=small)
    out = os.path.join(directory, "contact.png")
    sheet.save(out)
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]) if len(sys.argv) == 2 else 2)
