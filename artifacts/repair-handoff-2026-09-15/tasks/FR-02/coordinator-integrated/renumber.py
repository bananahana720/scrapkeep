import difflib, hashlib, re, subprocess, sys, pathlib

MODE = sys.argv[1]          # dry | apply
NEW_ROOT = pathlib.Path(sys.argv[2])   # tree holding the new HF-07a/HF-07b/HF-06b bytes
MAIN = pathlib.Path('/home/andrew/Projects/scrapkeep')
OLD_REV = '395bc3ff5583a460bba21095fffcda7faf514555'
DEPS = {
    'HF-07a': 'docs/tech/sections/HF-07a-save-envelope.md',
    'HF-07b': 'docs/tech/sections/HF-07b-commit-boundaries.md',
    'HF-06b': 'docs/tech/sections/HF-06b-persistence-projection.md',
}
HASH_FILES = [DEPS['HF-07a'], 'docs/tech/sections/HF-07a-save-envelope.csv', DEPS['HF-07b'], DEPS['HF-06b'],
              'docs/tech/sections/HF-06b-persistence-projection.csv']

def old_lines(rel):
    return subprocess.run(['git', '-C', str(MAIN), 'show', f'{OLD_REV}:{rel}'], capture_output=True, text=True, check=True).stdout.split('\n')

def new_lines(rel):
    return (NEW_ROOT / rel).read_text().split('\n')

maps = {}
for key, rel in DEPS.items():
    o, n = old_lines(rel), new_lines(rel)
    sm = difflib.SequenceMatcher(None, o, n, autojunk=False)
    m = {}
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == 'equal':
            for k in range(i2 - i1):
                m[i1 + k + 1] = (j1 + k + 1, 'equal')
        elif tag == 'replace':
            for k in range(i2 - i1):
                m[i1 + k + 1] = (j1 + min(k, j2 - j1 - 1) + 1, 'rewritten')
        elif tag == 'delete':
            for k in range(i2 - i1):
                m[i1 + k + 1] = (None, 'deleted')
    maps[key] = (m, o, n)

flags = []
OVERRIDES = {('HF-07a', 99): 103, ('HF-07a', 148): 104, ('HF-07b', 261): 296}
def remap(key, num, where):
    m, o, n = maps[key]
    if (key, num) in OVERRIDES: return OVERRIDES[(key, num)]
    new, kind = m.get(num, (None, 'missing'))
    if kind != 'equal':
        flags.append((where, key, num, new, kind, (o[num-1] if num-1 < len(o) else '')[:70], (n[new-1][:70] if new else '')))
    return new if new else num

def oldsha(rel): return hashlib.sha256(subprocess.run(['git','-C',str(MAIN),'show',f'{OLD_REV}:{rel}'],capture_output=True,check=True).stdout).hexdigest()
def newsha(rel): return hashlib.sha256((NEW_ROOT/rel).read_bytes()).hexdigest()
HASHES = {oldsha(r): newsha(r) for r in HASH_FILES}

TOKEN = re.compile(r'(HF-07a|HF-07b|HF-06b)( rule \d,)? (line|lines) (\d+)(?: (to|and) (\d+))?((?:, \d+(?: to \d+)?)*)')
ITS = re.compile(r'\b(?:its |[Ll]ine(?=s? \d)|)(line|lines|Line|Lines) (\d+)(?: (to|and) (\d+))?')

def rewrite_prose(rel):
    p = MAIN / rel; text = p.read_text(); out = []
    for ln, line in enumerate(text.split('\n'), 1):
        bullet_key = None
        mb = re.match(r'- \[(HF-07a|HF-07b|HF-06b)\]', line)
        if mb: bullet_key = mb.group(1)
        def sub_tok(mt):
            key, rule, word, a, conj, b, tail = mt.groups()
            na = remap(key, int(a), f'{rel}:{ln}')
            s = f'{key}{rule or ""} {word} {na}'
            if b: s += f' {conj} {remap(key, int(b), f"{rel}:{ln}")}'
            if tail: s += re.sub(r'\d+', lambda d: str(remap(key, int(d.group(0)), f'{rel}:{ln} tail')), tail)
            return s
        line = TOKEN.sub(sub_tok, line)
        if bullet_key:
            def sub_its(mt):
                word, a, conj, b = mt.groups()
                s = f'{mt.group(0).split(word)[0]}{word} {remap(bullet_key, int(a), f"{rel}:{ln}")}'
                if b: s += f' {conj} {remap(bullet_key, int(b), f"{rel}:{ln}")}'
                return s
            line = ITS.sub(sub_its, line)
        for oh, nh in HASHES.items(): line = line.replace(oh, nh)
        out.append(line)
    new = '\n'.join(out)
    if MODE == 'apply': p.write_text(new)
    return sum(1 for a, b in zip(text.split('\n'), out) if a != b)

PIN = re.compile(r'\("(docs/tech/sections/(HF-07a|HF-07b|HF-06b)[^"]+\.md)", (\d+), "([^"]+)"\)')
def rewrite_pins(rel):
    p = MAIN / rel; text = p.read_text()
    def sub(mt):
        path, key, num, anchor = mt.groups()
        n = new_lines(path)
        hits = [i+1 for i, l in enumerate(n) if anchor in l]
        if len(hits) == 1: new = hits[0]
        else:
            new = remap(key, int(num), f'{rel} pin'); flags.append((f'{rel} pin', key, int(num), new, f'anchor hits={len(hits)}', anchor, ''))
        return f'("{path}", {new}, "{anchor}")'
    new = PIN.sub(sub, text)
    for oh, nh in HASHES.items(): new = new.replace(oh, nh)
    if MODE == 'apply': p.write_text(new)
    return sum(1 for a, b in zip(text.split('\n'), new.split('\n')) if a != b)

changed = {}
for rel in ['docs/tech/sections/TH-01-complete-loop.md']:
    changed[rel] = rewrite_prose(rel)
print('mode', MODE, 'changed lines per file', changed)
print('hash replacements', {k[:8]: v[:8] for k, v in HASHES.items()})
print('FLAGGED (non-equal mappings) count', len(flags))
for f in flags: print('  ', f)
