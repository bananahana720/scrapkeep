import pathlib, re
root = pathlib.Path('/home/andrew/Projects/scrapkeep-wt-PS-04')
backlog = root / 'BACKLOG.md'
text = backlog.read_text()
cards = (root / 'artifacts/local/tasks/PS-04/hf-cards.md').read_text()

def replace_once(old, new, where=None):
    global text
    assert text.count(old) == 1, (old[:60], text.count(old))
    text = text.replace(old, new)

start = text.index('<a id="hf-01"></a>')
end = text.index('<a id="pd-01"></a>')
text = text[:start] + cards + text[end:]

replace_once(
    'Edition 2 · Updated 6 September 2026 · Existing cards remain revision 1; PUB-01 revision 2 includes the completed repository-local workflow package',
    'Edition 3 · Updated 6 September 2026 · HF cards amended and split per the accepted AI-first audit under PS-04; PUB-01 revision 2 includes the completed repository-local workflow package')

replace_once(
    'The original cards retain revision 1 from preparation handoff. PUB-01 is a separate revision-2 publication card.',
    'Cards retain revision 1 from preparation handoff unless a recorded definition change raised them. After the accepted 6 September audit, HF-01, HF-02, HF-05, HF-08, HF-09 and HF-10 are revision 2, and HF-03a/b, HF-04a/b, HF-06a/b and HF-07a/b are the revision-1 replacements of four split cards. PUB-01 is a separate revision-2 publication card.')

replace_once(
    'All workers read BIBLE.md, accepted ADRs, this card, ORCHESTRATOR.md, TRACKING.md and CONTRIBUTING.md. Sources below give the exact additional sections and prerequisites.',
    'All workers read the Bible sections and accepted ADR sections their card names, this card, ORCHESTRATOR.md, TRACKING.md and CONTRIBUTING.md. Sources below give the exact additional sections and prerequisites.')
replace_once(
    'A listed output path is permitted scope, not an existing file or a live lease.',
    'A listed output path is permitted scope, not an existing file or a live lease. Every `docs/tech/sections/` output uses the headings Sources, Contract, Scenarios, Unresolved questions, Re-verification triggers, Procedure performed and Evidence limits. The coordinator checks those headings and every local `#anchor` on admission with `npm run check:docs`; `npm run check:project` validates file links only.')

replace_once(
    'Store verification receipts under the card\'s explicit artifacts/local/tasks/ID/ directory. Workers return disjoint section drafts; the coordinator admits shared documents serially. An independent reviewer report is itself reviewed for coverage by a different reviewer before it is accepted.',
    'Work under `artifacts/local/tasks/ID/` (ignored). At handoff copy every receipt the coordinator will cite into `artifacts/foundation-sprint-2026-09/tasks/ID/` and list each file in the candidate manifest, because `artifacts/local/` is not committed. Workers return disjoint section drafts; the coordinator admits shared documents serially.')

sprint_start = text.index('## Proposed first sprint')
sprint_end = text.index('## Task catalogue')
sprint = '''## Proposed first sprint

Fourteen foundation-contract cards form one closed dependency set. HF-01 and HF-02 have no predecessors; every other predecessor is inside this sprint. Open questions that shape a card are registered on it as non-blocking; each such contract must hold under every candidate answer, and HF-07b may submit a proposed Q-E09 protocol. Unknown values remain named and gate later implementation. The S0 prepare-stage proofs are a separate family scheduled into the writer slots these waves leave idle.

| ID | Outcome | Dependencies | Owner / size |
| --- | --- | --- | --- |
| [HF-01](#hf-01) | Specify production paths and contribution conventions | None | Conventions / M |
| [HF-02](#hf-02) | Create constraints and evidence register | None | Verification / S |
| [HF-03a](#hf-03a) | Specify module ownership and owned records | [HF-01](#hf-01) | Runtime / M |
| [HF-03b](#hf-03b) | Specify dependency edges and interface walkthroughs | [HF-03a](#hf-03a) | Runtime / M |
| [HF-04a](#hf-04a) | Specify tick, pause and scene lifecycle | [HF-03a](#hf-03a) | Runtime / M |
| [HF-04b](#hf-04b) | Specify runtime patterns and typed sketches | [HF-04a](#hf-04a) | Runtime / M |
| [HF-05](#hf-05) | Specify stable content identity and admission | [HF-03a](#hf-03a) | Content / M |
| [HF-06a](#hf-06a) | Inventory authored content and its treatment | [HF-05](#hf-05) | Content / M |
| [HF-06b](#hf-06b) | Map matrix rows to persistence projections | [HF-06a](#hf-06a) | Persistence / M |
| [HF-07a](#hf-07a) | Specify the save envelope and preferences record | [HF-06b](#hf-06b) | Persistence / S |
| [HF-07b](#hf-07b) | Specify durable commit boundaries | [HF-04a](#hf-04a), [HF-07a](#hf-07a) | Persistence / M |
| [HF-08](#hf-08) | Specify save failure and conservative recovery | [HF-07b](#hf-07b) | Persistence / M |
| [HF-09](#hf-09) | Specify schema and gameplay-content migration | [HF-06b](#hf-06b), [HF-07b](#hf-07b) | Persistence / M |
| [HF-10](#hf-10) | Review the complete foundation contract | [HF-01](#hf-01), [HF-02](#hf-02), [HF-03a](#hf-03a), [HF-03b](#hf-03b), [HF-04a](#hf-04a), [HF-04b](#hf-04b), [HF-05](#hf-05), [HF-06a](#hf-06a), [HF-06b](#hf-06b), [HF-07a](#hf-07a), [HF-07b](#hf-07b), [HF-08](#hf-08), [HF-09](#hf-09) | Independent review / M |

Schedule in dependency waves under the two-writer ceiling. W1 HF-01 and HF-02. W2 HF-03a beside S0-01. W3 HF-04a and HF-05. W4 HF-03b and HF-04b. W5 HF-06a beside S0-05. W6 HF-06b beside S0-07. W7 HF-07a beside S0-04. W8 HF-07b beside S0-08. W9 HF-08 and HF-09. W10 HF-10, whose reviewer slot leaves a writer slot for S0-06. S0-02 and S0-03 precede W1; they need no engine and make the integration checks executable. These are dependency waves, not promises of duration. A reviewer uses one of the three delegate slots, and one fresh reviewer may read a wave's two candidates together. After HF-01, HF-02, HF-03a, HF-03b, HF-04a, HF-04b and HF-05 are admitted, the coordinator runs one integrated read of them before assigning HF-06a; findings return through changes_requested. Early completed work may proceed through review while the other writer runs if ownership is disjoint. The audit's seven-wave order placed S0-01 beside HF-03, S0-05 and S0-07 beside HF-06, and S0-04, S0-06 and S0-08 beside HF-07 with spill into the next idle slot; the four splits add three waves under the same ceiling, and each proof lands before or beside the card whose "re-verify when S0-0x lands" trigger names it, or that trigger fires on the admitted card.

HF-10 produces a scoped foundation review. It does not stand in for all per-system designs, the assembled TECH_BIBLE.md or TH-31's final architecture audit. That later audit must separate paper schema consistency from unperformed native roundtrip qualification.

'''
text = text[:sprint_start] + sprint + text[sprint_end:]

old_rows = '''| [HF-03](#hf-03) | Specify module ownership and dependency interfaces | Runtime | M |
| [HF-04](#hf-04) | Specify tick, pause and scene lifecycle | Runtime | M |
| [HF-05](#hf-05) | Specify stable content identity and admission | Content | M |
| [HF-06](#hf-06) | Map content schemas to persistence coverage | Content | M |
| [HF-07](#hf-07) | Specify save envelope and durable commit boundaries | Persistence | M |
'''
new_rows = '''| [HF-03a](#hf-03a) | Specify module ownership and owned records | Runtime | M |
| [HF-03b](#hf-03b) | Specify dependency edges and interface walkthroughs | Runtime | M |
| [HF-04a](#hf-04a) | Specify tick, pause and scene lifecycle | Runtime | M |
| [HF-04b](#hf-04b) | Specify runtime patterns and typed sketches | Runtime | M |
| [HF-05](#hf-05) | Specify stable content identity and admission | Content | M |
| [HF-06a](#hf-06a) | Inventory authored content and its treatment | Content | M |
| [HF-06b](#hf-06b) | Map matrix rows to persistence projections | Persistence | M |
| [HF-07a](#hf-07a) | Specify the save envelope and preferences record | Persistence | S |
| [HF-07b](#hf-07b) | Specify durable commit boundaries | Persistence | M |
'''
replace_once(old_rows, new_rows)

# Source-path rewiring for consumers outside the HF family.
src = {
    'HF-03-module-map.md` from [HF-03](#hf-03)': 'HF-03a-module-map.md` from [HF-03a](#hf-03a)',
    'HF-04-runtime-lifecycle.md` from [HF-04](#hf-04)': 'HF-04a-runtime-lifecycle.md` from [HF-04a](#hf-04a)',
    'HF-06-schema-coverage.md` from [HF-06](#hf-06)': 'HF-06a-schema-inventory.md` from [HF-06a](#hf-06a)',
    'HF-07-save-envelope.md` from [HF-07](#hf-07)': 'HF-07a-save-envelope.md` from [HF-07a](#hf-07a)',
    '`docs/tech/sections/HF-10-foundation-review.md` from [HF-10](#hf-10)': '`artifacts/foundation-sprint-2026-09/HF-10-foundation-review.md` from [HF-10](#hf-10)',
}
counts = {}
for old, new in src.items():
    counts[old] = text.count(old)
    text = text.replace(old, new)

# TH-30 assembles every output, so it also lists the b halves.
th30_start = text.index('### TH-30:')
th30_end = text.index('**Boundary:**', th30_start)
th30 = text[th30_start:th30_end]
second = {
    '- `docs/tech/sections/HF-03a-module-map.md` from [HF-03a](#hf-03a) (must be admitted before assignment)\n':
        '- `docs/tech/sections/HF-03b-dependency-graph.md` from [HF-03b](#hf-03b) (must be admitted before assignment)\n',
    '- `docs/tech/sections/HF-04a-runtime-lifecycle.md` from [HF-04a](#hf-04a) (must be admitted before assignment)\n':
        '- `docs/tech/sections/HF-04b-runtime-patterns.md` from [HF-04b](#hf-04b) (must be admitted before assignment)\n',
    '- `docs/tech/sections/HF-06a-schema-inventory.md` from [HF-06a](#hf-06a) (must be admitted before assignment)\n':
        '- `docs/tech/sections/HF-06b-persistence-projection.md` from [HF-06b](#hf-06b) (must be admitted before assignment)\n',
    '- `docs/tech/sections/HF-07a-save-envelope.md` from [HF-07a](#hf-07a) (must be admitted before assignment)\n':
        '- `docs/tech/sections/HF-07b-commit-boundaries.md` from [HF-07b](#hf-07b) (must be admitted before assignment)\n',
}
for a, b in second.items():
    assert th30.count(a) == 1, a
    th30 = th30.replace(a, a + b)
text = text[:th30_start] + th30 + text[th30_end:]

# Dependency rewiring. Full-family lists (TH-30, TH-31) name both halves; single consumers name the producing half.
both = {
    '[HF-03](#hf-03)': '[HF-03a](#hf-03a), [HF-03b](#hf-03b)',
    '[HF-04](#hf-04)': '[HF-04a](#hf-04a), [HF-04b](#hf-04b)',
    '[HF-06](#hf-06)': '[HF-06a](#hf-06a), [HF-06b](#hf-06b)',
    '[HF-07](#hf-07)': '[HF-07a](#hf-07a), [HF-07b](#hf-07b)',
}
half = {k: v.split(', ')[0] for k, v in both.items()}
out = []
for line in text.split('\n'):
    if line.startswith('**Dependencies:**') and '[HF-10](#hf-10), [TH-01](#th-01)' in line:
        for k, v in both.items():
            line = line.replace(k, v)
    elif line.startswith('**Dependencies:**'):
        for k, v in half.items():
            line = line.replace(k, v)
    out.append(line)
text = '\n'.join(out)

for k in both:
    assert k not in text, (k, [l[:80] for l in text.split('\n') if k in l])
assert 'docs/tech/sections/HF-10-foundation-review.md' not in text
backlog.write_text(text)
print('source rewires', counts)

disp = root / 'docs/project/SOURCE-DISPOSITIONS.md'
d = disp.read_text()
n = 0
for k, v in both.items():
    old = k.replace('(#', '(../../BACKLOG.md#')
    new = v.replace('(#', '(../../BACKLOG.md#')
    n += d.count(old)
    d = d.replace(old, new)
disp.write_text(d)
print('disposition rewires', n)
print('HF headings', len(re.findall(r'^### HF-', text, re.M)))
