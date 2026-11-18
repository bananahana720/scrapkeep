from pathlib import Path
import json
r=Path('artifacts/local/W1-144/ride')
rows=[json.loads(x) for x in (r/'frames-1.ndjson').read_text().splitlines()]
for key in ['stage','state']:
 for a,b in zip(rows,rows[1:]):
  if a[key]!=b[key] and (key=='stage' or b[key]==8):
   print(key,a[key],b[key],{k:b[k] for k in ('f','ms','net_ms','bot_ms','phys_ms','post_proc_ms','pre_proc_ms','proc_ms','nodes','draw_ms')})
for e in map(json.loads,(r/'entry-1.ndjson').read_text().splitlines()):
 if e['f'] in (20382,35760):
  print(e['signal'],e['args'],e['total_ms'],e['handlers'][:3])
