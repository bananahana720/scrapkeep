"""Compose native chase pixels into the existing 3-row, 5-beat sheet format."""
import json
from pathlib import Path
import subprocess
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / 'artifacts/anim-reactions'
PILOTS = ('rivet', 'sable', 'kest')
BEATS = {
    'big_cheer': [('anticipate',6),('rise',15),('triumph',34),('accent',57),('seated',84)],
    'wince': [('impact',2),('compress',4),('release',7),('recover',11),('seated',15)],
    'slump': [('deflate',6),('droop',14),('dejected',22),('hold',30),('seated',45)],
    'phew': [('inhale',4),('release',9),('relief',13),('exhale',18),('seated',24)],
    'brace': [('bite',2),('brace',5),('hold',9),('release',13),('seated',18)],
    'heave': [('impact',2),('heave',6),('hold',9),('release',14),('seated',24)],
}
BG = (35,39,38)
FONT_PATH = subprocess.check_output(['fc-match','-f','%{file}','sans'],text=True).strip()
FONT = ImageFont.truetype(FONT_PATH,18)
LARGE = ImageFont.truetype(FONT_PATH,24)


def source(pilot, clip, frame):
    image = Image.open(OUT / pilot / (clip+'-chase') / f'{frame:04}.png').convert('RGBA')
    assert image.size == (384,324), image.size
    return image


def encode(path, frames):
    process = subprocess.Popen(['ffmpeg','-hide_banner','-loglevel','error','-y','-threads','2',
        '-f','rawvideo','-pixel_format','rgb24','-video_size','1920x1080','-framerate','30',
        '-i','pipe:0','-an','-c:v','libx264','-threads','2','-crf','18','-pix_fmt','yuv420p',
        '-movflags','+faststart',str(path)], stdin=subprocess.PIPE)
    for image in frames:
        process.stdin.write(image.tobytes())
    process.stdin.close()
    assert process.wait() == 0


def main():
    for clip, beats in BEATS.items():
        folder = OUT / clip
        folder.mkdir(exist_ok=True)
        sheet = Image.new('RGB',(1920,1080),BG)
        draw = ImageDraw.Draw(sheet)
        for row,pilot in enumerate(PILOTS):
            for col,(beat,frame) in enumerate(beats):
                image = source(pilot,clip,frame)
                sheet.paste(image,(col*384,row*360+36),image)
                draw.text((col*384+10,row*360+10),f'{pilot.upper()} / {beat} / {frame/30:.3f}s',font=FONT,fill='white')
        sheet.save(folder/'beats-sheet.png')
        end = beats[-1][1]
        cache = {p: [source(p,clip,f) for f in range(end+1)] for p in PILOTS}
        cycle = end + 1 + 30
        def trio():
            for f in range(cycle*3):
                image = Image.new('RGB',(1920,1080),BG)
                draw = ImageDraw.Draw(image)
                draw.text((40,40),f'{clip.upper()} / native 1080p chase pixels / three repeats',font=LARGE,fill='white')
                draw.text((40,80),f'Clip {end/30:.3f}s; one second seated between repeats. CPU Cycles studio, no game background.',font=FONT,fill='#bec7c3')
                for i,pilot in enumerate(PILOTS):
                    crop = cache[pilot][min(f%cycle,end)]
                    image.paste(crop,(i*640+128,486),crop)
                    draw.text((i*640+180,840),pilot.upper(),font=LARGE,fill='white')
                yield image
        encode(folder/f'trio_{clip}.mp4',trio())
    old = [source('sable','drop_land-old',f) for f in range(66)]
    new = [source('sable','drop_land',f) for f in range(66)]
    def comparison():
        for f in range(270):
            image = Image.new('RGB',(1920,1080),BG)
            draw = ImageDraw.Draw(image)
            for i,(label,frames) in enumerate([('OLD hidden point',old),('NEW side-on point',new)]):
                crop = frames[min(f%90,65)]
                image.paste(crop,(i*960+288,486),crop)
                draw.text((i*960+80,80),f'SABLE / {label} / 2.166667s, same clock',font=LARGE,fill='white')
            yield image
    encode(OUT/'sable-drop-old-vs-new.mp4',comparison())
    image = Image.new('RGB',(1920,720),BG)
    draw = ImageDraw.Draw(image)
    for row,(label,frames) in enumerate([('OLD',old),('NEW',new)]):
        for col,frame in enumerate([23,26,31,38,65]):
            crop = frames[frame]
            image.paste(crop,(col*384,row*360+36),crop)
            draw.text((col*384+10,row*360+10),f'{label} / SABLE / {frame/30:.3f}s',font=FONT,fill='white')
    image.save(OUT/'sable-drop-old-vs-new.png')


if __name__ == '__main__':
    main()
