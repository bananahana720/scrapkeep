import os,subprocess,time,socket
from pathlib import Path
d=Path('artifacts/local/W1-144').resolve()
g=Path.home()/'Applications/Godot_4.7.2.app/Contents/MacOS/Godot'
h=d/'profile-home'
h.mkdir(exist_ok=True)
with socket.socket() as port:
    port.bind(('127.0.0.1',0))
    n=port.getsockname()[1]
env=dict(os.environ,HOME=str(h),XDG_DATA_HOME=str(h),XDG_CONFIG_HOME=str(h),PROF_PORT=str(n),PROF_OUT=str(d/'profile.jsonl'))
base=[g,'--headless','--path','sketches/core-loop']
with (d/'profile-server.log').open('w') as log, (d/'profile-control.log').open('w') as client:
    p=subprocess.Popen(base+['--script','res://tools/script_profile.gd'],env=env,stdout=log,stderr=subprocess.STDOUT)
    try:
        for _ in range(300):
            if Path(env['PROF_OUT']).exists():break
            time.sleep(.05)
        result=subprocess.run(base+['--remote-debug',f'tcp://127.0.0.1:{n}','--fixed-fps','90','--script',d/'prepared-entry.gd','--','--profile=sitting'],env=env,stdout=client,stderr=subprocess.STDOUT,timeout=150)
        print('client',result.returncode)
        print('profiler',p.wait(timeout=8))
    finally:
        if p.poll() is None: p.terminate();p.wait(timeout=4)
