import re, pathlib
root = pathlib.Path('/home/andrew/Projects/scrapkeep-wt-PS-04')
backlog = root / 'BACKLOG.md'
lines = backlog.read_text().split('\n')
start = lines.index('## Source dispositions')
assert start == 2713, start
region = lines[start:]
assert region[-1] == '' and '## Source inventory' in region

def relink(m):
    target = m.group(1)
    if target.startswith('#'):
        return '](../../BACKLOG.md' + target + ')'
    if re.match(r'^[a-z][a-z0-9+.-]*:', target, re.I):
        return m.group(0)
    return '](../../' + target + ')'

moved = [re.sub(r'\]\(([^)]+)\)', relink, line) for line in region]
header = [
    '# Source dispositions and inventory',
    'Moved verbatim from BACKLOG.md on 6 September 2026 under PS-04; the coordinator owns this file, every task and question link points back to [BACKLOG.md](../../BACKLOG.md), and nothing here grants task completion, a native support claim or implementation authorization.',
    '',
]
(root / 'docs/project/SOURCE-DISPOSITIONS.md').write_text('\n'.join(header + moved))

pointer = [
    '## Source records',
    '',
    'Source dispositions and the source inventory live in [docs/project/SOURCE-DISPOSITIONS.md](docs/project/SOURCE-DISPOSITIONS.md), moved there verbatim on 6 September 2026. The coordinator owns that file. It preserves every P/T/R/D/BD identifier, the unnumbered planning obligations, core-system headings, selected concept-art receipts and requested engineering sections, and its task and question links point back to the cards and questions in this file. A disposition row grants no task completion, native support claim or implementation authorization.',
    '',
]
new = lines[:start] + pointer
text = '\n'.join(new)
old_nav = '- [Source dispositions](#source-dispositions)\n- [Source inventory](#source-inventory)'
assert old_nav in text
text = text.replace(old_nav, '- [Source dispositions and inventory](docs/project/SOURCE-DISPOSITIONS.md)')
backlog.write_text(text)
print('moved', len(region), 'lines; backlog now', text.count('\n') + 1, 'lines')
