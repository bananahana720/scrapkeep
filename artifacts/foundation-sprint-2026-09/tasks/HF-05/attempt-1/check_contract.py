#!/usr/bin/env python3
"""Paper consistency and historical source checks. Never launches an engine."""
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path.cwd().resolve()
receipts = Path(__file__).resolve().parent
manifest = json.loads((receipts / 'source-manifest.json').read_text())
output = root / 'docs/tech/sections/HF-05-content-admission.md'
text = output.read_text()
checks = []
notes = []

def digest(data):
    return hashlib.sha256(data).hexdigest()

def check(name, condition, detail):
    checks.append({'name': name, 'passed': bool(condition), 'detail': detail})

def card(data):
    return data.split('### HF-05:', 1)[1].split('<a id="hf-06a">', 1)[0].strip()

for name, expected in manifest['sources'].items():
    path = root / name
    check('source:' + name, path.exists() and digest(path.read_bytes()) == expected, 'Required source bytes match assigned baseline')
for name, expected in manifest.get('informational_sources', {}).items():
    path = root / name
    check('informational source exists:' + name, path.exists(), 'Navigation index is not a semantic contract input')
    if path.exists() and digest(path.read_bytes()) != expected:
        notes.append('Navigation index changed: ' + name + '. Section schema headings are independently checked.')
backlog = (root / 'BACKLOG.md').read_bytes()
check('card revision and exact definition', digest(card(backlog.decode()).encode()) == manifest['card_sha256'], 'HF-05 extracted independently of unrelated cards')
if digest(backlog) != manifest['backlog_sha256']:
    notes.append('Whole BACKLOG changed; exact HF-05 card is checked separately. Unrelated drift does not fail this check.')
required_headings = ['Sources', 'Contract', 'Scenarios', 'Unresolved questions', 'Re-verification triggers', 'Procedure performed', 'Evidence limits']
check('section headings', all('## ' + h + '\n' in text for h in required_headings), required_headings)
edges = {}
traces = {}
for line in text.splitlines():
    cells = [c.strip() for c in line.strip().strip('|').split('|')]
    if re.fullmatch(r'E\d{2}', cells[0]):
        check('unique edge:' + cells[0], cells[0] not in edges, cells)
        edges[cells[0]] = cells[1:3]
    if re.fullmatch(r'T[1-4]\.\d+', cells[0]):
        check('unique step:' + cells[0], cells[0] not in traces, cells)
        traces[cells[0]] = cells[1:]
states = {'draft', 'imported', 'structurally valid', 'semantically valid', 'admitted', 'rejected-reload', 'pinned'}
check('exact seven states', {v for pair in edges.values() for v in pair} == states, sorted(states))
state_rows = {}
for line in text.splitlines():
    cells = [c.strip() for c in line.strip().strip('|').split('|')]
    if cells[0] in states and len(cells) == 3:
        state_rows[cells[0]] = set(re.findall(r'E\d{2}', cells[2]))
check('seven state rows', set(state_rows) == states, sorted(state_rows))
for state, outgoing in state_rows.items():
    check('state outgoing edges:' + state, outgoing == {key for key,pair in edges.items() if pair[0] == state}, sorted(outgoing))
check('edge identities', set(edges) == {f'E{i:02d}' for i in range(1,17)}, 'E01 through E16')
expected_counts = {'T1': 3, 'T2': 6, 'T3': 5, 'T4': 5}
initial = {'T1': {'candidate A': 'draft'}, 'T2': {'candidate A': 'draft'}, 'T3': {'candidate B':'draft', 'run A binding':'pinned'}, 'T4': {'candidate B':'semantically valid', 'run A binding':'pinned'}}
for name, count in expected_counts.items():
    subset = {key: val for key, val in traces.items() if key.startswith(name + '.')}
    check(name + ': numbered steps', set(subset) == {f'{name}.{i}' for i in range(1,count+1)}, list(subset))
    current = dict(initial[name])
    for i in range(1,count+1):
        row = subset.get(f'{name}.{i}')
        if row is None:
            continue
        subject, edge, before, after, action = row
        check(f'{name}.{i}: listed edge', edge in edges and edges[edge] == [before,after], row)
        check(f'{name}.{i}: subject continuity', current.get(subject) == before, {'subject':subject, 'expected':current.get(subject), 'from':before})
        current[subject] = after
    check(name + ': no draft/rejection changes live pin', current.get('run A binding', 'pinned') == 'pinned', current)
check('admission has validation predecessor', all(pair[0] == 'semantically valid' for pair in edges.values() if pair[1] == 'admitted'), edges)
check('pin has no destructive outgoing edge', all(pair[1] == 'pinned' for pair in edges.values() if pair[0] == 'pinned'), edges)
check('no draft directly admitted or pinned', all(pair[1] not in {'admitted','pinned'} for pair in edges.values() if pair[0] in {'draft','imported','structurally valid','rejected-reload'}), edges)
proof_manifest = root / 'artifacts/prepare-stage-2026-09-06/tasks/S0-05/sha256-manifest.txt'
for row in proof_manifest.read_text().splitlines():
    expected, relative = row.split(maxsplit=1)
    check('historical proof SHA256:' + relative, digest((root/'native'/relative).read_bytes()) == expected, expected)
normal = (root/'artifacts/prepare-stage-2026-09-06/tasks/S0-05/run-normal.txt').read_text()
fault = (root/'artifacts/prepare-stage-2026-09-06/tasks/S0-05/run-inject-fault.txt').read_text()
normal_summary = json.loads(normal.splitlines()[-1])
fault_summary = json.loads(fault.splitlines()[-1])
check('retained normal receipt', normal_summary['passed'] == 8 and normal_summary['failed'] == 0 and normal_summary['exit'] == 0, normal_summary)
check('retained fault detects bypass', fault_summary['failed'] == 1 and fault_summary['exit'] == 1 and 'S0-06 rule_rejects FAIL' in fault, fault_summary)
check('retained deep-copy observation', 'cached_definition_unchanged=true' in normal and 'shallow_duplicate_shares_packed_arrays=true' in normal, 'One placeholder graph on recorded engine only')
check('retained failed reload leaves active catalogue', 'active_kept=true' in normal and 'swapped=true' in normal, 'Headless dictionary swap, no live safe-boundary claim')
report = {'result': 'PASS' if all(c['passed'] for c in checks) else 'FAIL', 'method':'source and tabletop checks only', 'root':str(root), 'head':subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],text=True).strip(), 'base':manifest['base'], 'output_sha256':digest(output.read_bytes()), 'checks':checks, 'notes':notes, 'limits':'No engine execution. Trace predicates are documentary constraints; identity/source checks do not prove production behavior.'}
(receipts/'paper-check.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'result':report['result'], 'checks':len(checks), 'failures':[c for c in checks if not c['passed']], 'notes':notes, 'receipt':str(receipts/'paper-check.json')},indent=2))
sys.exit(0 if report['result']=='PASS' else 1)
