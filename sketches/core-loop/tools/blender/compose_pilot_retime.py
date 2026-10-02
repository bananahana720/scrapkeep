"""Assemble evidence at native pixel size; the comparison uses one shared clock."""
import hashlib
import json
from pathlib import Path
import subprocess
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[4]
OUT=ROOT/'artifacts/anim-pilot/retime'
PILOTS=('rivet','sable','kest')
BG=(35,39,38)
FONT_PATH=subprocess.check_output(['fc-match','-f','%{file}','sans'],text=True).strip()
FONT=ImageFont.truetype(FONT_PATH,18)
LARGE=ImageFont.truetype(FONT_PATH,24)


def crop(pilot,version,frame):
    path=OUT/pilot/(version+'-chase')/f'{frame:04}.png'
    im=Image.open(path).convert('RGBA')
    assert im.size==(384,324),im.size
    return im


def encode(path,frames):
    p=subprocess.Popen(['ffmpeg','-hide_banner','-loglevel','error','-y','-threads','2',
        '-f','rawvideo','-pixel_format','rgb24','-video_size','1920x1080','-framerate','30',
        '-i','pipe:0','-an','-c:v','libx264','-threads','2','-crf','18','-pix_fmt','yuv420p',
        '-movflags','+faststart',str(path)],stdin=subprocess.PIPE)
    for im in frames:p.stdin.write(im.tobytes())
    p.stdin.close()
    assert p.wait()==0,path


def main():
    timings={p:json.loads((OUT/p/'timing.json').read_text()) for p in PILOTS}
    cache={(p,v):[crop(p,v,f) for f in range(34 if v=='old' else timings[p]['key_frames'][-1])]
           for p in PILOTS for v in ('old','new')}
    def sample(p,v,f):
        frames=cache[p,v]
        return frames[min(f,len(frames)-1)]
    def individual(p):
        for source in cache[p,'new']:
            im=Image.new('RGB',(1920,1080),BG)
            im.paste(source,(768,486),source)
            ImageDraw.Draw(im).text((40,40),f'{p.upper()} / drop_land / 1080p, 30 fps / idle chase: 7.5 units, 65 degrees',font=LARGE,fill='white')
            yield im
    for p in PILOTS:encode(OUT/p/'drop_land_chase_1080p.mp4',individual(p))
    def trio():
        for f in range(270):
            im=Image.new('RGB',(1920,1080),BG);draw=ImageDraw.Draw(im)
            draw.text((40,40),'DROP / LAND — retimed pilots',font=LARGE,fill='white')
            draw.text((40,80),'Native 1080p pixel size | 30 fps | idle chase camera | three repeats',font=FONT,fill='#bec7c3')
            for n,p in enumerate(PILOTS):
                source=sample(p,'new',f%90)
                im.paste(source,(n*640+128,486),source)
                draw.text((n*640+180,840),f'{p.upper()}  {timings[p]["duration_seconds"]:.3f} s',font=LARGE,fill='white')
            yield im
    encode(OUT/'trio_drop_land_v2.mp4',trio())
    def comparison():
        for f in range(270):
            im=Image.new('RGB',(1920,1080),BG);draw=ImageDraw.Draw(im)
            for row,p in enumerate(PILOTS):
                for col,v in enumerate(('old','new')):
                    source=sample(p,v,f%90)
                    im.paste(source,(col*960+288,row*360+36),source)
                    label=f'{p.upper()} / {"OLD 1.100 s" if v=="old" else "NEW %.3f s" % timings[p]["duration_seconds"]}'
                    draw.text((col*960+32,row*360+12),label,font=LARGE,fill='white')
                draw.line((960,row*360,960,(row+1)*360),fill='#5b655f',width=2)
            draw.text((1260,1048),'Same clock; old holds after finishing',font=FONT,fill='#bec7c3')
            yield im
    encode(OUT/'old-vs-new.mp4',comparison())
    sheet=Image.new('RGB',(1920,1080),BG);draw=ImageDraw.Draw(sheet)
    for row,p in enumerate(PILOTS):
        for col,(beat,frame) in enumerate(timings[p]['beat_samples'].items()):
            im=Image.open(OUT/p/'new-chase'/f'hold-{beat}.png').convert('RGBA')
            sheet.paste(im,(col*384,row*360+36),im)
            draw.text((col*384+10,row*360+10),f'{p.upper()} / {beat} / {(frame-1)/30:.3f}s',font=FONT,fill='white')
    sheet.save(OUT/'beats-sheet.png')
    report={'fps':30,'video_resolution':[1920,1080],'comparison_seconds':9,
            'comparison':'Three 3-second shared-clock repeats, no speed adjustment; finished actions hold neutral.',
            'sheet':'Rows Rivet/Sable/Kest; columns brace, squash, triumph, flourish, settled. Native 1080p pixels, no zoom.',
            'settle_sample':'Terminal driving pose; settle is an ease, not an extra authored hold.',
            'individuals':'Original 1080p camera projection reconstructed from lossless RGBA render borders.',
            'timings':timings}
    (OUT/'evidence.json').write_text(json.dumps(report,indent=2)+'\n')
    paths=[OUT/'beats-sheet.png',OUT/'trio_drop_land_v2.mp4',OUT/'old-vs-new.mp4']
    (OUT/'delivery-sha256.json').write_text(json.dumps({str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},indent=2)+'\n')


if __name__=='__main__':main()
