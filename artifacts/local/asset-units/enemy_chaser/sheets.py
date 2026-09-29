from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import json, sys
D = Path('/home/andrew/Projects/scrapkeep/artifacts/local/visual-development/asset-c10/artifacts/local/asset-units/enemy_chaser')
font = ImageFont.truetype('/usr/share/fonts/liberation/LiberationSans-Regular.ttf', 22)
views = ['front30', 'side30', 'rear30', 'use6']
poses = ['idle', 'windup', 'lunge']
def sheet(mode, thumb):
    w, h = (480, 270) if thumb else (960, 540)
    cols = len(views)
    for pose in poses:
        img = Image.new('RGB', (cols * w, 2 * h + 60), '#171d1d')
        d = ImageDraw.Draw(img)
        for r, (tag, label) in enumerate([('before', 'base f9041a5'), ('after', 'head')]):
            for c, v in enumerate(views):
                im = Image.open(D / tag / f'{v}-{pose}-{mode}.png').convert('RGB').resize((w, h), Image.LANCZOS)
                img.paste(im, (c * w, 60 + r * h))
                d.text((c * w + 8, 6 + 0), f'{v} {pose} {mode}', font=font, fill='white')
            d.text((8, 32), '', font=font)
        d.text((8, 34), 'top row: before (base) | bottom row: after (head)', font=font, fill='#d2c5a5')
        out = D / f'sheet-{pose}-{mode}{"-thumb" if thumb else ""}.png'
        img.save(out)
for mode in ('lit', 'black'):
    sheet(mode, False)
    sheet(mode, True)
