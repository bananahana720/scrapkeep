import hashlib,json,pathlib,re,subprocess
root=pathlib.Path.cwd(); output=root/'artifacts/local/tasks/HF-02'; document=root/'docs/tech/sections/HF-02-constraints-evidence.md'
text=document.read_text(); classes={'approved constraints','proposed budgets','historical browser measurements','unmeasured native requirements'}
def inspect(text):
 errors=[]; rows=[]
 for line in text.splitlines():
  if not re.match(r'\| [CHBN]-',line): continue
  cells=[c.strip() for c in line.strip('|').split('|')]; rows.append(cells)
  if cells[1] not in classes: errors.append('classification')
  if cells[0].startswith('H-') and re.search(r'\d',cells[2]):
   if not re.search(r'\d+(?:\.\d+)? ms\b',cells[2]): errors.append('unit')
   tag=re.search(r'measured:([^`\s]+)',cells[2])
   if not tag or not (root/tag.group(1)).is_file(): errors.append('measurement source')
  if cells[0].startswith('B-'):
   if len(cells)!=7 or any(not c for c in cells): errors.append('admission fields')
   if 'proposed:Q-E03' not in cells[-1]: errors.append('proposal tag')
 if {r[1] for r in rows}!=classes: errors.append('four classes')
 return errors,rows
errors,rows=inspect(text)
assert not errors,errors
assert len(rows)==25,len(rows)
assert len({r[0] for r in rows})==len(rows)
for heading in ['Sources','Contract','Scenarios','Unresolved questions','Re-verification triggers','Procedure performed','Evidence limits']:
 assert f'## {heading}' in text
mutations={
 'mixed classification':text.replace('| approved constraints |','| approved constraints; historical browser measurements |',1),
 'missing measured tag':text.replace('measured:artifacts/performance-stress.json','observation:artifacts/performance-stress.json',1),
 'missing units':text.replace('Frame median 16.7 ms and p95 16.8 ms; CPU submission median 1.7 ms and p95 2.1 ms.','Frame median 16.7 and p95 16.8; CPU submission median 1.7 and p95 2.1.',1),
 'missing proposal tag':text.replace('Value unset, `proposed:Q-E03`.','Value unset.',1),
 'missing artifact':text.replace('measured:artifacts/performance-stress.json','measured:artifacts/missing-hf02.json',1)
}
negative={name:inspect(value)[0] for name,value in mutations.items()}
assert all(negative.values()),negative
sources=['artifacts/performance-stress.json','artifacts/performance-stress-final.json','artifacts/lightning-playtest/stress-1920x1080.json','artifacts/lightning-playtest/manifest.json','artifacts/prepare-stage-2026-09-06/tasks/S0-01/native-smoke-report.json','docs/project/sprint-0/closure.json']
hashes={p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in sources}
manifest=json.loads((root/sources[3]).read_text()); record=next(r for r in manifest['records'] if r['path']=='stress-1920x1080.json')
assert record['sha256']==hashes[sources[2]]
assert record['sourceHead']=='49175ac4e8967071ea6203e2e416c382a48d9278'
assert record['sha256'] in text and record['sourceHead'] in text
p=json.loads((root/sources[2]).read_text())['performance']; values=p['frameSummaryMs']
assert [round(values[k],2) for k in ['mean','p95','p99','max']]==[16.69,16.8,16.9,34.1]
assert len(p['frameTimesMs'])==p['frameCount']==3601
assert abs(sum(p['frameTimesMs'])/3601-values['mean'])<1e-8
for path,expected in [(sources[0],[16.7,16.8,1.7,2.1]),(sources[1],[16.7,16.8,1.8,2.3])]:
 data=json.loads((root/path).read_text()); q=data['performance']; assert [round(q[k],1) for k in ['medianFrameMs','p95FrameMs','medianRenderMs','p95RenderMs']]==expected
 assert not {'sourceCommit','sourceHead','timestamp','generatedAt'}&data.keys()
assert json.loads((root/sources[5]).read_text())['integratedCommit']=='e54e429c76f3d83641c0127b4e44fe7eb8b2098f'
result={'result':'pass','method':'document classification/tag checks and in-memory negative mutations; retained JSON/hash inspection; not a runtime check','head':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'documentSha256':hashlib.sha256(document.read_bytes()).hexdigest(),'rowCount':len(rows),'negativeProbes':negative,'sourceSha256':hashes,'limits':['Numeric scan targets register observation cells; prose was separately read for stray budget claims.','Legacy capture source identity remains absent.','No native/browser benchmark or human play.']}
(output/'focused-check.json').write_text(json.dumps(result,indent=2)+'\n'); print(json.dumps(result,indent=2))
