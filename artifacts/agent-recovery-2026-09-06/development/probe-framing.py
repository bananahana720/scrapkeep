from pathlib import Path
import sys,json
sys.path.insert(0,str(Path('tools/agent-player').resolve()))
import numpy as np
from PIL import Image
from policy import Policy

def ground(im):
 a=np.asarray(im.convert('RGB')).astype(np.int16)
 h,w=a.shape[:2];band=a[int(h*.12):int(h*.32),int(w*.30):int(w*.72)]
 r,g,b=band.transpose(2,0,1)
 return float(((r>150)&(g>145)&(b>90)&(r-b>25)&(g-b>25)&(np.abs(r-g)<35)).mean())
rows=[]
for base in ['artifacts/agent-player-2026-09-06/default-visual','artifacts/local/agent-recovery-development/candidate-b','artifacts/local/agent-recovery-development/baseline']:
 images=list(Path(base).glob('trial-*/timeout.jpg'))
 if not images:images=sorted(Path(base).glob('trial-*/frame-*.jpg'))[::8]
 for p in images:rows.append({'path':str(p),'upper_ground_fraction':ground(Image.open(p))})
policy=Policy();yields=[]
for i in range(160):
 policy.step(.1);seen=i%20==0
 policy.aim(dict(id=i,width=1280,height=900,targets=[dict(x=800,y=450,box=[794,446,806,454])] if seen else [],lower_sky_fraction=0))
 if policy.recovery.phase=='search':yields.append(policy.motion.look[1])
print(json.dumps({'views':rows,'search_pitch_ticks':{'positive':sum(y>0 for y in yields),'negative':sum(y<0 for y in yields),'sum':sum(yields)}},indent=2))
