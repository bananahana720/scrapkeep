import hashlib, json, pathlib, re, subprocess
root = pathlib.Path.cwd()
path = pathlib.Path('docs/tech/sections/HF-01-production-conventions.md')
body = path.read_text()
base = '3ab3477bc8731f157e9cdff31598251e20acef98'
amendment = '2bb86d3eaebd80a2afae62b49b8742f06bc6d113'
rows = []
for line in body.splitlines():
    if not line.startswith('| `'): continue
    columns = [x.strip() for x in line.strip('|').split('|')]
    assert len(columns) == 5, columns
    globs = re.findall(r'`([^`]+)`', columns[0])
    assert globs
    rows.append({'globs':globs, 'owner':columns[1], 'adr':columns[4]})
assert len(rows) == 13

def matches(pattern, value):
    rx = re.escape(pattern).replace(r'\*\*', '.*').replace(r'\*', '[^/]*')
    return re.fullmatch(rx, value) is not None

def owners(value):
    return [i + 1 for i, row in enumerate(rows) if any(matches(g, value) for g in row['globs'])]

def git(*args): return subprocess.check_output(['git', *args], text=True).splitlines()

native = git('ls-files', 'native')
native_coverage = {p: owners(p) for p in native}
assert all(len(v) == 1 for v in native_coverage.values()), native_coverage
s0 = git('diff', '7aaea69^1', '7aaea69', '--name-only')
assert len(s0) == 9
s0_native = {p:owners(p) for p in s0 if p.startswith('native/')}
assert len(s0_native) == 4 and all(len(v) == 1 for v in s0_native.values())
support = [p for p in s0 if not p.startswith('native/')]
assert all('`' + p + '`' in body for p in support)
evidence = ['artifacts/local/tasks/S0-01/', 'artifacts/local/native-smoke/report.json']
assert all('`' + p + '`' in body and not owners(p) for p in evidence)
protected = ['/', '/orchard.html', 'index.html', 'orchard.html', 'src/', 'server/', 'tests/', 'tools/', 'artifacts/', 'public/']
for row in rows:
    for glob in row['globs']:
        assert glob.startswith(('native/', 'source-assets/', 'docs/tech/')), glob
for p in protected:
    assert not owners(p)
    if p.endswith('/'):
        assert not owners(p + 'example.gd')
representatives = {
    'native/runtime/combat/encounter.gd':2,
    'native/presentation/hud/hud.gd':3,
    'native/content/example/definitions/attack.tres':4,
    'native/content/example/scenes/actor.tscn':5,
    'native/content/example/assets/mesh.glb':6,
    'native/content/example/assets/mesh.glb.import':6,
    'source-assets/example/master.blend':7,
    'native/.godot/imported/mesh.scn':8,
    'native/editor_tools/validate_catalogue.gd':12,
    'docs/tech/sections/example.md':13,
}
for p, expected in representatives.items(): assert owners(p) == [expected], (p, owners(p))
required = ['Sources','Contract','Scenarios','Unresolved questions','Re-verification triggers','Procedure performed','Evidence limits']
assert re.findall(r'^## (.+)$',body,re.M) == required
assert body.count('unverified until a scaffold proof exists') == 2
report = {
 'result':'pass', 'method':'static contract enumeration and representative path scenarios; no engine execution',
 'base':base, 'amendmentDependency':amendment, 'cardRevision':3,
 'sectionSha256':hashlib.sha256(path.read_bytes()).hexdigest(), 'tableColumnCount':5, 'rowCount':len(rows),
 's0AcceptedMerge':'7aaea699582c188eb2b1e3723bbb946e4b2c8f37', 's0Native':s0_native,
 's0SupportAccounting':support,'s0RequiredEvidenceAccounting':evidence,
 'currentNativeFileCount':len(native), 'currentNativeCoverage':native_coverage,
 'protectedPaths':protected, 'representatives':representatives, 'requiredHeadings':required,
 'sourceScenarioReview': [
   'TADR-00123-29 engine pin and typed boundaries preserved; no extra language or renderer selected',
   'TADR-00323-35 Resources/scenes, stable IDs, immutable admission and provenance preserved',
   'Import-sidecar mismatch disclosed with TH-19 prerequisite; no ignore/harness mutation',
   'Browser preservation and no publication authority checked against CONTRIBUTING and browser ADR',
   'S0-01 root proof separated from later S0 export receipt and unverified production import operation',
   'Documentation-only scope and source-version/evidence limits preserved in reviewer checklist'
 ]
}
output = root/'artifacts/local/tasks/HF-01/coverage.json'
output.write_text(json.dumps(report,indent=2)+'\n')
print(f'PASS: {len(rows)} five-column rows, {len(s0_native)} S0-01 native files, {len(support)} support files, {len(native)} current native files, {len(representatives)} representative paths; protected paths excluded.')
