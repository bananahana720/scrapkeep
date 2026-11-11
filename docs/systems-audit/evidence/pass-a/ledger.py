import json,collections,sys,glob,os
base=sys.argv[1]
out=[]
for d in sorted(glob.glob(base+'/*-28*/')):
    name=os.path.basename(d.rstrip('/'))
    rows=[]
    for f in glob.glob(d+"econ-*.ndjson"):
        for l in open(f):
            try: rows.append(json.loads(l))
            except: pass
    if not rows: continue
    bots=[]
    for l in open(d+'bots.ndjson') if os.path.exists(d+'bots.ndjson') else []:
        try: bots.append(json.loads(l))
        except: pass
    last=rows[-1]
    c=collections.Counter(r['kind'] for r in rows)
    cin=collections.Counter(); 
    for r in rows:
        if r['kind']=='cogs+': cin[r['stage']]+=r.get('amount',0)
    cout=sum(r.get('amount',0) for r in rows if r['kind']=='cogs-')
    parts=collections.Counter(r.get('source') for r in rows if r['kind']=='part+')
    cores=collections.Counter(r.get('source') for r in rows if r['kind']=='core+')
    lost=collections.Counter()
    for r in rows:
        if r['kind']=='scrap-': lost[r.get('cause')]+=r.get('amount',0)
    stage_snap=[{k:r[k] for k in ('t','stage','cogs','scrap','mass','cores','parts','panels','tree')} for r in rows if r['kind']=='stage']
    b=bots[0] if bots else {}
    out.append(dict(run=name, outcome=last.get('outcome') or b.get('outcome'), game_s=last['t'], end={k:last[k] for k in ('stage','cogs','scrap','mass','hp','cores','parts','panels','tree','relics')},
        cogs_in_by_stage=dict(cin), cogs_spent=cout, part_sources=dict(parts), core_sources=dict(cores), panels=c['panel+'], scrap_lost=dict(lost), stage_entries=stage_snap,
        bot={k:b.get(k) for k in ('outcome','stage_reached','game_seconds','class','min_hp')}, stage_notes=[{k:s.get(k) for k in ('stage','warden_broken_s','exit_s','hp_lost','hits','rib_caches_taken','rogues_beaten','secrets_found')} for s in b.get('stages',[])]))
print(json.dumps(out,indent=1))
