"""Compose saved renders without altering generated reference content."""
from pathlib import Path
import argparse
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[4] / 'artifacts/anim-pilot'
FONT = ImageFont.load_default(size=18)


def compare(folder, keys, name, cell=400):
    width=cell*6
    height=(cell+36)*len(keys)
    out=Image.new('RGB',(width,height),(35,39,38))
    draw=ImageDraw.Draw(out)
    for row,n in enumerate(keys):
        y=row*(cell+36)
        ref=Image.open(ROOT/'keys'/f'key-{n:02}.png').convert('RGB')
        ref.thumbnail((cell*3,cell))
        out.paste(ref,((cell*3-ref.width)//2,y+36+(cell-ref.height)//2))
        for col,view in enumerate(('front','back','side')):
            image=Image.open(ROOT/folder/f'key-{n:02}-{view}.png').convert('RGB')
            image.thumbnail((cell,cell))
            out.paste(image,((col+3)*cell,y+36))
        draw.text((12,y+8),f'KEY {n:02}   IMAGEGEN: FRONT / BACK / RIGHT SIDE',font=FONT,fill='white')
        draw.text((cell*3+12,y+8),'BLENDER: FRONT / BACK / RIGHT SIDE',font=FONT,fill='white')
    out.save(ROOT/name)


def strips(folder):
    for view in ('front','back','side'):
        out=Image.new('RGB',(400*4,436*4),(35,39,38));d=ImageDraw.Draw(out)
        for n in range(1,17):
            x=((n-1)%4)*400;y=((n-1)//4)*436
            out.paste(Image.open(ROOT/folder/f'key-{n:02}-{view}.png'),(x,y+36))
            d.text((x+12,y+8),f'{view.upper()} / KEY {n:02}',font=FONT,fill='white')
        out.save(ROOT/f'result-{view}-strip.png')


def rig_sheet():
    for name,views in [('identity-reference.png',('front','back','side')),
                       ('rig-check.png',('front','back','side','t-pose'))]:
        out=Image.new('RGB',(480*len(views),520),(51,55,53))
        d=ImageDraw.Draw(out)
        for i,view in enumerate(views):
            out.paste(Image.open(ROOT/'references'/f'{view}.png'),(i*480,35))
            d.text((i*480+18,10),view.upper(),font=ImageFont.load_default(),fill='white')
        out.save(ROOT/name)


def keys_sheet():
    out=Image.new('RGB',(1536,1648),(35,39,38));d=ImageDraw.Draw(out)
    for n in range(1,17):
        x=((n-1)%2)*768;y=((n-1)//2)*206
        im=Image.open(ROOT/'keys'/f'key-{n:02}.png');im.thumbnail((760,180))
        out.paste(im,(x+(768-im.width)//2,y+26))
        d.text((x+12,y+3),f'KEY {n:02}',font=FONT,fill='white')
    out.save(ROOT/'keys-sheet.png')


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--pilot',choices=['rivet','sable','kest'],default='rivet')
    parser.add_argument('--folder',default='results-v4')
    parser.add_argument('--keys',nargs='+',type=int,default=list(range(1,17)))
    parser.add_argument('--out',default='result-sheet.png')
    parser.add_argument('--cell',type=int,default=400)
    parser.add_argument('--rig',action='store_true')
    parser.add_argument('--keys-sheet',action='store_true')
    args=parser.parse_args()
    if args.pilot!='rivet':
        ROOT=ROOT/args.pilot
    if args.rig:
        rig_sheet()
    elif args.keys_sheet:
        keys_sheet()
    else:
        compare(args.folder,args.keys,args.out,args.cell)
        if args.folder in ('results-v4','results') and len(args.keys)==16:
            strips(args.folder)
