import hashlib
import json
from collections import Counter
from pathlib import Path

root = Path(__file__).resolve().parents[3]
source = root / 'artifacts/local/agent-recovery-development'
names = ('baseline','baseline-batch','candidate-a','candidate-b','synthesis-live','final-live','relocation-live','extended-live','stationary-live')
rows=[]

def digest(value):
    return hashlib.sha256(json.dumps(value,sort_keys=True).encode()).hexdigest()

for name in names:
    path=source/name/'report.json'
    if not path.exists():
        continue
    report=json.loads(path.read_text())
    game={k:v for k,v in report['source_hashes'].items() if k.startswith('src/') or k in ('package.json','package-lock.json','orchard.html')}
    for result in report['trials']:
        trial=source/name/f"trial-{result['trial']:03}"
        labels=result.get('result_labels',[])
        details={}
        for label in ('Time','Scrap collected'):
            indices=[i for i,x in enumerate(labels) if x==label and i+1<len(labels)]
            if indices:
                details[label]=labels[indices[-1]+1]
        frames=[];gaps=[]
        for line in (trial/'events.ndjson').read_text().splitlines():
            event=json.loads(line)
            if event['kind']=='combat_segment':
                frames+=event['frames'];gaps+=event['tick_gaps_ms']
        phases=Counter(f.get('policy',{}).get('recovery',{}).get('phase','unrecorded') for f in frames)
        def stats(values):
            values=sorted(values)
            import math
            return dict(samples=len(values),p50=values[max(0,math.ceil(len(values)*.5)-1)],p95=values[max(0,math.ceil(len(values)*.95)-1)],max=max(values)) if values else None
        rows.append(dict(variant=name,trial=result['trial'],outcome=result['outcome'],active_seconds=result['active_seconds'],visible_result=details,pause_check=result.get('pause_check'),game_identity=digest(game),controller_identity=digest(report['controller_hashes']),build_identity=digest(report['build_hashes']),source_unchanged=report['source_unchanged'],controller_unchanged=report['controller_unchanged'],cleanup_errors=report['cleanup_errors'],phase_frame_counts=phases,input_tick_ms=stats(gaps),fresh_frame_age_ms=stats([f['frame_age_ms'] for f in frames]),observe_ms=stats([f['observe_ms'] for f in frames])))
result=dict(runs=rows,same_game_across_runs=len({r['game_identity'] for r in rows})==1,same_controller_across_runs=len({r['controller_identity'] for r in rows})==1,same_served_build_across_runs=len({r['build_identity'] for r in rows})==1,limits=['The ordinary game defaults to seed 42; the runner does not set or read a live seed. Input and capture timing varies, so these are not deterministic replays or a controlled win-rate estimate.','Command and image diagnostics do not provide world-position or damage measurements.'])
(source/'qualification-comparison.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='runs'},indent=2))
for row in rows:
 print(row['variant'],row['trial'],row['outcome'],row['visible_result'])
