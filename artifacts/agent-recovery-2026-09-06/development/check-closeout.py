import hashlib
import json
from datetime import datetime,timezone
from pathlib import Path

root=Path(__file__).resolve().parents[3]
base=root/'artifacts/local/agent-recovery-development'
retained=root/'artifacts/agent-recovery-2026-09-06'
def read(name):return json.loads((base/name/'report.json').read_text())
def current_differences(report):
 return [name for name,digest in report['source_hashes'].items() if hashlib.sha256((root/name).read_bytes()).hexdigest()!=digest]
qualified=read('stationary-live');smoke=read('closeout-smoke');interrupt=read('stationary-interruption')
controller_root=Path.home()/'.local/share/codex-native-input/agent-desktop'
controller_diff=[name for name,digest in qualified['controller_hashes'].items() if hashlib.sha256((controller_root/name).read_bytes()).hexdigest()!=digest]
workspaces=[]
for report_path in sorted(base.glob('*/report.json')):
 report=json.loads(report_path.read_text());name=report['configuration']['workspace']
 state=Path.home()/'.local/state/codex-native-input/agent-desktop/workspaces'/name
 workspaces.append(dict(name=name,session_exists=(state/'session.json').exists(),owner_exists=(state/'owner.json').exists()))
state=Path.home()/'.local/state/codex-native-input/agent-desktop/workspaces/playtest-camera-proof'
workspaces.append(dict(name='playtest-camera-proof',session_exists=(state/'session.json').exists(),owner_exists=(state/'owner.json').exists()))
receipt=dict(checked_at=datetime.now(timezone.utc).isoformat(),qualified_outcomes=[x['outcome'] for x in qualified['trials']],qualified_passed=qualified['passed'],pause_checks=[x['pause_check'] for x in qualified['trials']],qualified_source_differences=current_differences(qualified),difference_reason='Only report.py explanatory text changed after acceptance; final smoke covers the corrected wording.',final_smoke_source_differences=current_differences(smoke),final_smoke_passed=smoke['passed'],installed_controller_differences=controller_diff,interruption=json.loads((base/'stationary-interruption/interruption-check.json').read_text()),test_workspaces=workspaces)
receipt['passed']=(receipt['qualified_passed'] and len(receipt['qualified_outcomes'])==3 and all(x in ('won','lost') for x in receipt['qualified_outcomes']) and all(x=='passed' for x in receipt['pause_checks']) and receipt['qualified_source_differences']==['tools/agent-player/report.py'] and not receipt['final_smoke_source_differences'] and receipt['final_smoke_passed'] and not controller_diff and receipt['interruption']['passed'] and all(not row['session_exists'] and not row['owner_exists'] for row in workspaces))
(retained/'closeout-check.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt,indent=2))
assert receipt['passed']
