import json, math, sys
from pathlib import Path
sys.path.insert(0,str(Path('tools/agent-player').resolve()))
from policy import Policy

class Extended(Policy):
 def _phase(self,phase,reason,duration=0):
  if phase=='relocate':duration=4.5
  super()._phase(phase,reason,duration)
  if phase=='search' and reason=='escape_complete':self.next_recovery=self.elapsed+3

def simulate(cls,initial):
 p=cls();x,z,yaw=initial;vx=vz=0;points=[]
 for i in range(12000):
  dt=.02;p.step(dt)
  p.aim(dict(id=i,width=1280,height=900,targets=[],lower_sky_fraction=0,scene_change={'changed_fraction':.3}))
  intent=p.motion;yaw+=intent.look[0]*dt*.003
  sx=('KeyD' in intent.keys)-('KeyA' in intent.keys);sz=('KeyS' in intent.keys)-('KeyW' in intent.keys)
  norm=max(1,math.hypot(sx,sz));tx=(math.cos(yaw)*sx-math.sin(yaw)*sz)/norm*7.4;tz=(math.sin(yaw)*sx+math.cos(yaw)*sz)/norm*7.4
  dx,dz=tx-vx,tz-vz;delta=math.hypot(dx,dz);s=min(1,25*dt/delta) if delta else 0
  vx+=dx*s;vz+=dz*s
  xx=x+vx*dt;zz=z+vz*dt;x=min(17,max(-17,xx));z=min(25,max(-35,zz))
  if x!=xx:vx=0
  if z!=zz:vz=0
  if i%25==0:points.append((x,z))
 grid=[(a,b) for a in range(-15,16,5) for b in range(-30,21,5)]
 distances=[min(math.hypot(x-a,z-b) for x,z in points) for a,b in grid]
 return dict(start=initial,x_span=max(x for x,z in points)-min(x for x,z in points),z_span=max(z for x,z in points)-min(z for x,z in points),largest_grid_distance=max(distances),grid_points_never_within_10=sum(d>10 for d in distances))
result={'method':'240 seconds of intended camera-relative movement, nominal speed/acceleration and rectangular bounds only; no arena objects, enemy physics, rendering or native input','variants':{}}
for name,cls in [('relocation_2_5',Policy),('relocation_4_5_minimum_scan',Extended)]:
 result['variants'][name]=[simulate(cls,start) for start in [(0,20,0),(15,-30,1),(-15,15,2),(0,-30,3)]]
Path('artifacts/local/agent-recovery-development/traversal-probe.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
