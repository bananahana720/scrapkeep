import os, subprocess
from pathlib import Path
d=Path('artifacts/local/W1-144').resolve()
g=Path.home()/'Applications/Godot_4.7.2.app/Contents/MacOS/Godot'
for label,delay in [('control',0),('planted',1)]:
    h=d/('control-home-'+label)
    h.mkdir(exist_ok=True)
    env=dict(os.environ,HOME=str(h),XDG_DATA_HOME=str(h),XDG_CONFIG_HOME=str(h),W144_DELAY=str(delay))
    with (d/('transition-'+label+'.log')).open('w') as out:
        r=subprocess.run([g,'--headless','--fixed-fps','90','--path','sketches/core-loop','--script',d/'transition-control.gd','--','--profile=sitting'],env=env,stdout=out,stderr=subprocess.STDOUT,timeout=125)
    print(label,r.returncode)
