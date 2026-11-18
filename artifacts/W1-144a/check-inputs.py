from pathlib import Path
import subprocess, json
d=Path('artifacts/local/W1-144/fixture')
d.mkdir(parents=True,exist_ok=True)
def run(label,code,*,mode='frames',spike=None,length=2500,beat=35.1,film=False,skip=False,victory=True,cold=False,exit_line='GODOT_EXIT 0',errors=(),marker=True,bowl=24):
    frames=[10.0]*length
    if spike:
        frames[spike[0]]=spike[1]
    title='scrapkeep_frame_log,engine,driver,adapter,vsync\nscrapkeep_frame_log,4.7,metal,Apple M5 Max,0\nframetime\n'
    (d/'frames.csv').write_text(title+''.join(f'{m:.3f}\n' for m in frames))
    lines=['self-play: stage 1 entered at 2.00 s']
    if not skip: lines.append('self-play: stage 1 exit taken at 11.99 s')
    lines.extend(['self-play: stage 2 entered at 12.00 s','self-play: stage 2 exit taken at 23.99 s',f'self-play: boss arena entered at {bowl:.2f} s'])
    raw=['Metal 4 - Apple M5 Max','ERROR: old in-play error',*lines]
    if marker: raw.append(f'SCRAPKEEP_FRAME_LOG {length} frames {d}/frames.csv')
    if beat: raw.append(f'self-play: beat {beat:.1f} s stage 2 boss')
    if victory: raw.append('self-play: run won at 49.00 s')
    if film: raw.append('self-play: film 2 frames (2 drawn) in scratch')
    raw.extend(errors)
    if exit_line: raw.append(exit_line)
    (d/'ride.log').write_text('\n'.join(raw)+'\n')
    (d/'summary.json').write_text(json.dumps({'log':str(d/'frames.csv'),'target':'debug-editor','cache':'cold' if cold else 'reused (--home)','frames':length,'self_play':{'exit':0,'stalled':None,'stages':[{'stage':1,'retry':False},{'stage':2,'retry':False,'log_s':2}],'lines':[x for x in raw if x.startswith('self-play:')]}}))
    args=['node','scripts/handover-frame-probe.mjs',mode]
    if mode=='frames':args.append(d)
    r=subprocess.run([*args,d/'ride.log'],text=True,capture_output=True)
    assert r.returncode==code,(label,r.returncode,r.stdout,r.stderr)
    print(label,code,(r.stdout or r.stderr).strip())
run('clear',0)
run('flume 50 ms',1,spike=(200,50))
run('bowl 50 ms',1,spike=(1400,50))
run('outside',0,spike=(1000,50))
run('precision',1,spike=(1400,33.301))
run('uncertain boundary',2,spike=(90,50))
run('truncated bowl window',2,bowl=34)
run('skipped exit',2,skip=True)
run('film clock',2,film=True)
run('cold pass',2,cold=True)
run('missing CSV marker',2,marker=False)
run('missing beat',2,beat=0)
run('no victory',2,victory=False)
run('clean exit',0,mode='shutdown')
run('dummy RID',0,mode='shutdown',errors=["ERROR: 2 RID allocations of type 'N13RendererDummy15MaterialStorage11DummyShaderE' were leaked at exit."])
run('Metal error',1,mode='shutdown',errors=['ERROR: renderer fault'])
run('victory log cut short',2,mode='shutdown',exit_line=None)
run('abnormal exit',2,mode='shutdown',exit_line='GODOT_EXIT 1')
