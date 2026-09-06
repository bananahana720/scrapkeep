import pathlib, re
root = pathlib.Path('/home/andrew/Projects/scrapkeep-wt-PS-04')
backlog = root / 'BACKLOG.md'
text = backlog.read_text()
cards = (root / 'artifacts/local/tasks/PS-04/s0-cards.md').read_text()

marker = '<a id="pd-01"></a>'
assert text.count(marker) == 1 and '<a id="s0-01"></a>' not in text
text = text.replace(marker, cards + marker)

intro_old = 'HF covers foundation contracts; PD covers production-facing briefs;'
intro_new = 'HF covers foundation contracts; S0 covers prepare-stage tooling and executable ADR proofs; PD covers production-facing briefs;'
assert text.count(intro_old) == 1
text = text.replace(intro_old, intro_new)

hf10_row = '| [HF-10](#hf-10) | Review the complete foundation contract | Independent review | M |\n'
s0_rows = '''| [S0-01](#s0-01) | Pin the Godot 4.7.2 toolchain and prove a typed offline headless boot | Verification | M |
| [S0-02](#s0-02) | Add the documentation-only check command | Tooling | S |
| [S0-03](#s0-03) | Add the verification-scope selector and reserve the native check command | Verification | S |
| [S0-04](#s0-04) | Prove runtime ownership under TADR-002 and TADR-005 | Runtime | M |
| [S0-05](#s0-05) | Prove typed Resource identity, admission and immutability headlessly | Content | S |
| [S0-06](#s0-06) | Prove binary-tree admission rejection and failed-reload retention | Content | S |
| [S0-07](#s0-07) | Author the TADR-004 save-owner proof and fixtures | Persistence | S |
| [S0-08](#s0-08) | Execute the TADR-004 proof and record evidence | Verification | S |
| [S0-09](#s0-09) | Export presets and CI smoke workflow (parked) | Verification | M |
'''
assert text.count(hf10_row) == 1
text = text.replace(hf10_row, hf10_row + s0_rows)
backlog.write_text(text)
print('S0 headings', len(re.findall(r'^### S0-', text, re.M)), 'lines', text.count('\n') + 1)
