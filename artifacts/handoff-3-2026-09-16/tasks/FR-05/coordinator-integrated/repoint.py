"""Re-point stale dependency citations and hashes after an integration.

usage: repoint.py dry|apply <citer>=<old_rev> ...
Each citer's line tokens into the DEPS files are remapped from <old_rev> bytes to the working tree by
content diff; hashes stated for DEPS files are replaced; anchor-pinned script tuples are re-found by anchor.
"""
import difflib, hashlib, re, subprocess, sys, pathlib

MODE = sys.argv[1]
MAIN = pathlib.Path('/home/andrew/Projects/scrapkeep')
DEPS = {
    'HF-07a': 'docs/tech/sections/HF-07a-save-envelope.md',
    'HF-07b': 'docs/tech/sections/HF-07b-commit-boundaries.md',
    'HF-06b': 'docs/tech/sections/HF-06b-persistence-projection.md',
    'HF-04a': 'docs/tech/sections/HF-04a-runtime-lifecycle.md',
    'HF-08': 'docs/tech/sections/HF-08-save-recovery.md',
    'TH-01': 'docs/tech/sections/TH-01-complete-loop.md',
    'TH-02': 'docs/tech/sections/TH-02-movement-camera-and-active-aim.md',
    'TH-03': 'docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md',
}
HASH_FILES = list(DEPS.values()) + ['docs/tech/sections/HF-07a-save-envelope.csv', 'docs/tech/sections/HF-06b-persistence-projection.csv']
OVERRIDES = {}

def git_show(rev, rel):
    return subprocess.run(['git', '-C', str(MAIN), 'show', f'{rev}:{rel}'], capture_output=True, check=True).stdout

def build_map(old_rev, rel):
    o = git_show(old_rev, rel).decode().split('\n'); n = (MAIN / rel).read_text().split('\n')
    sm = difflib.SequenceMatcher(None, o, n, autojunk=False); m = {}
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == 'equal':
            for k in range(i2 - i1): m[i1 + k + 1] = (j1 + k + 1, 'equal')
        elif tag == 'replace':
            for k in range(i2 - i1): m[i1 + k + 1] = (j1 + min(k, j2 - j1 - 1) + 1, 'rewritten')
        elif tag == 'delete':
            for k in range(i2 - i1): m[i1 + k + 1] = (None, 'deleted')
    return m, o, n

flags = []; changed = {}
TOKEN = re.compile(r'(HF-07a|HF-07b|HF-06b|HF-04a|HF-08|TH-01|TH-02|TH-03)( rule \d,)? (line|lines|Line|Lines) (\d+)(?: (to|and) (\d+))?((?:, \d+(?: to \d+)?)*)')
ITS = re.compile(r'\b(?:its |)(line|lines|Line|Lines) (\d+)(?: (to|and) (\d+))?((?:, \d+(?: to \d+)?)*)')
PIN = re.compile(r'\("(docs/tech/sections/([A-Z]+-\d+[ab]?)[^"]+\.md)", (\d+), "([^"]+)"\)')

for spec in sys.argv[2:]:
    citer, old_rev = spec.split('=')
    maps = {k: build_map(old_rev, rel) for k, rel in DEPS.items() if rel != citer}
    hashes = {}
    for rel in HASH_FILES:
        if rel == citer: continue
        try: oh = hashlib.sha256(git_show(old_rev, rel)).hexdigest()
        except subprocess.CalledProcessError: continue
        hashes[oh] = hashlib.sha256((MAIN / rel).read_bytes()).hexdigest()
    def remap(key, num, where):
        if key not in maps: return num
        if (key, num) in OVERRIDES: return OVERRIDES[(key, num)]
        m, o, n = maps[key]; new, kind = m.get(num, (None, 'missing'))
        if kind != 'equal':
            flags.append((where, key, num, new, kind, (o[num-1] if num-1 < len(o) else '')[:60], (n[new-1][:60] if new else '')))
        return new if new else num
    p = MAIN / citer; text = p.read_text(); out = []
    if citer.endswith('.py'):
        def sub(mt):
            path, key, num, anchor = mt.groups(); n = (MAIN / path).read_text().split('\n')
            hits = [i+1 for i, l in enumerate(n) if anchor in l]
            new = hits[0] if len(hits) == 1 else remap(key, int(num), f'{citer} pin {anchor[:30]}')
            return f'("{path}", {new}, "{anchor}")'
        new = PIN.sub(sub, text)
        for oh, nh in hashes.items(): new = new.replace(oh, nh)
        out = new.split('\n')
    else:
        for ln, line in enumerate(text.split('\n'), 1):
            mb = re.match(r'- \[([A-Za-z0-9-]+)\]', line); bullet_key = mb.group(1) if mb and mb.group(1) in maps else None
            def sub_tok(mt):
                key, rule, word, a, conj, b, tail = mt.groups()
                s = f'{key}{rule or ""} {word} {remap(key, int(a), f"{citer}:{ln}")}'
                if b: s += f' {conj} {remap(key, int(b), f"{citer}:{ln}")}'
                if tail: s += re.sub(r'\d+', lambda d: str(remap(key, int(d.group(0)), f'{citer}:{ln} tail')), tail)
                return s
            line = TOKEN.sub(sub_tok, line)
            if bullet_key:
                def sub_its(mt):
                    word, a, conj, b, tail = mt.groups(); pre = mt.group(0).split(word)[0]
                    s = f'{pre}{word} {remap(bullet_key, int(a), f"{citer}:{ln}")}'
                    if b: s += f' {conj} {remap(bullet_key, int(b), f"{citer}:{ln}")}'
                    if tail: s += re.sub(r'\d+', lambda d: str(remap(bullet_key, int(d.group(0)), f'{citer}:{ln} tail')), tail)
                    return s
                line = ITS.sub(sub_its, line)
            for oh, nh in hashes.items(): line = line.replace(oh, nh)
            out.append(line)
    new_text = '\n'.join(out)
    changed[citer] = sum(1 for a, b in zip(text.split('\n'), out) if a != b)
    if MODE == 'apply': p.write_text(new_text)

print('mode', MODE, 'changed lines', changed)
print('FLAGGED', len(flags))
for f in flags: print('  ', f)
