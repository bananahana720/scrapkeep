"""Assemble the boss concept contact sheet from a chosen list of renders.

  python contact_sheet.py --out SHEET.jpg --cols 3 ID=PATH [ID=PATH ...]

Each tile is labelled with its id at the top-left in a plain sans font. The sheet is at
most 1800 px wide. Concept references only.
"""
import argparse

from PIL import Image, ImageDraw, ImageFont


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--cols", type=int, default=3)
    ap.add_argument("--width", type=int, default=1800)
    ap.add_argument("tiles", nargs="+")
    args = ap.parse_args()

    pairs = [t.split("=", 1) for t in args.tiles]
    cols = args.cols
    gutter = 8
    tile_w = (args.width - gutter * (cols + 1)) // cols
    tile_h = round(tile_w * 768 / 1344)
    rows = (len(pairs) + cols - 1) // cols
    sheet = Image.new("RGB", (args.width, gutter + rows * (tile_h + gutter)), (36, 42, 40))
    try:
        font = ImageFont.truetype("/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", 22)
    except OSError:
        font = ImageFont.load_default()
    draw = ImageDraw.Draw(sheet)
    for i, (label, path) in enumerate(pairs):
        img = Image.open(path).convert("RGB").resize((tile_w, tile_h), Image.LANCZOS)
        x = gutter + (i % cols) * (tile_w + gutter)
        y = gutter + (i // cols) * (tile_h + gutter)
        sheet.paste(img, (x, y))
        tw = draw.textlength(label, font=font)
        draw.rectangle([x, y, x + tw + 16, y + 34], fill=(36, 42, 40))
        draw.text((x + 8, y + 5), label, fill=(210, 197, 165), font=font)
    sheet.save(args.out, quality=88)
    print(f"WROTE {args.out} {sheet.size[0]}x{sheet.size[1]}")


if __name__ == "__main__":
    main()
