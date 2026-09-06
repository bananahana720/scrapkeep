import pathlib, re, sys, unicodedata
root = pathlib.Path('/home/andrew/Projects/scrapkeep-wt-PS-04')
files = ['BACKLOG.md', 'ORCHESTRATOR.md', 'docs/project/README.md', 'docs/project/SOURCE-DISPOSITIONS.md']

def slug(heading):
    h = unicodedata.normalize('NFKD', heading).strip().lower()
    h = re.sub(r'[^\w\- ]', '', h)
    return h.replace(' ', '-')

def anchors(path):
    text = re.sub(r'```[\s\S]*?```', '', path.read_text())
    found = set(re.findall(r'<a id="([^"]+)"', text))
    for m in re.finditer(r'^#{1,6} +(.+?)\s*$', text, re.M):
        found.add(slug(re.sub(r'\[([^\]]*)\]\([^)]*\)', r'\1', m.group(1))))
    return found

cache = {}
def anchors_of(path):
    if path not in cache:
        cache[path] = anchors(path) if path.exists() else None
    return cache[path]

failures, checked = [], 0
for rel in files:
    src = root / rel
    text = re.sub(r'```[\s\S]*?```', '', src.read_text())
    for m in re.finditer(r'!?\[[^\]]*\]\((<[^>]+>|[^)\s]+)\)', text):
        target = m.group(1).strip('<>').strip()
        if re.match(r'^[a-z][a-z0-9+.-]*:', target, re.I):
            continue
        file_part, _, frag = target.partition('#')
        dest = src if not file_part else (src.parent / file_part).resolve()
        if not dest.exists():
            failures.append(f'{rel}: missing file {target}')
            continue
        if frag:
            checked += 1
            ids = anchors_of(dest)
            if ids is None or frag not in ids:
                failures.append(f'{rel}: unresolved anchor {target}')
for f in failures:
    print('FAIL', f)
print(f'anchor links checked: {checked}; failures: {len(failures)}; files: {", ".join(files)}')
sys.exit(1 if failures else 0)
