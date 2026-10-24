import json,subprocess,time,sys,os,re
LAST='?'
os.environ['MOJULO_MCP_TOOL_TIMEOUT_MS']='600000'
M=os.path.expanduser('~/.npm/_npx/944e8abfdb21a75f/node_modules/.bin/mojulo')
W=os.path.dirname(os.path.abspath(__file__))
TSV=os.path.join(W,'..','B-ladder.tsv')
def call(tool,args,timeout=600):
    f=os.path.join(W,'args%d.json'%os.getpid()); json.dump(args,open(f,'w'))
    t=time.time()
    try:
        p=subprocess.run(['nice','-n','10',M,'call',tool,'--json','@'+f],capture_output=True,text=True,timeout=timeout)
    except subprocess.TimeoutExpired:
        return None,time.time()-t,'timeout'
    dt=time.time()-t
    mm=re.search(r'tool=(\w+) ms=(\d+) (\w+)',p.stderr)
    global LAST
    LAST=(mm.group(2) if mm else '?')+('' if (mm and mm.group(3)=='ok') else '('+(mm.group(3) if mm else 'noline')+')')
    try: j=json.loads(p.stdout)
    except Exception:
        r=re.search(r'"ref": "(\w+)"',p.stdout)
        if len(p.stdout)>=65000 and '"ok": true' in p.stdout[:30] and r: j={'ok':True,'ref':r.group(1),'truncated_stdout':True}
        else: j={'ok':False,'raw':(p.stdout+p.stderr)[-1500:]}
    return j,dt,None
def ledger(tool):
    j,_,_=call('get_tool_ledger',{'tool':tool,'limit':1})
    return j
import re
def lms(tool):
    j=ledger(tool); m=re.search(r'- (\w+)\s+([\d.]+)(ms|s|m)\b',j.get('raw','') if j else '')
    if not m: return '?'
    v=float(m.group(2)); return str(int(v*{'ms':1,'s':1000,'m':60000}[m.group(3)]))+('' if m.group(1)=='ok' else '('+m.group(1)+')')
def log(row):
    new=not os.path.exists(TSV)
    with open(TSV,'a') as f:
        if new: f.write('rung\ttool\tkey_params\toutcome\tmojulo_wall_ms\town_wall_s\ttriangles\tglb_bytes\terror\n')
        f.write('\t'.join(str(x).replace('\t',' ').replace('\n',' ') for x in row)+'\n')
def rung(name,kind,spec,params,fmt='glb',tool='mint_solid'):
    j,dt,to=call(tool,spec if tool!='mint_solid' else {'kind':kind,'spec':spec,'title':name})
    if to: log([name,'mint_solid',params,'timeout','','%.1f'%dt,'','','>600s']); return 'timeout'
    mm=LAST
    if not j.get('ok'):
        log([name,tool,params,'refused/error','mint '+mm,'%.1f'%dt,'','',json.dumps(j)[:600]]);print(json.dumps(j)[:800]); return 'error'
    ref=j.get('ref'); print('minted',ref,'%.1fs'%dt, json.dumps(j.get('stats',{}))[:300])
    e,dt2,to=call('export_model',{'ref':ref,'format':fmt})
    if to: log([name,'mint+export_model',params,'timeout','','mint %.1f'%dt,'','','export >600s']); return 'timeout'
    if not e.get('ok'):
        log([name,'mint+export_model',params,'error','mint '+mm+' / export '+LAST,'mint %.1f / export %.1f'%(dt,dt2),'','',json.dumps(e)[:600]]);print(json.dumps(e)[:800]); return 'error'
    em=LAST
    out='ok' if e.get('bytes',0)<200e6 else 'error'
    log([name,tool+'+export_model',params,out,'mint %s / export %s'%(mm,em),'mint %.1f / export %.1f / total %.1f'%(dt,dt2,dt+dt2),e.get('triangles'),e.get('bytes'),'' if out=='ok' else 'glb>200MB'])
    print('exported',e.get('triangles'),e.get('bytes'),'%.1fs'%dt2); return out
