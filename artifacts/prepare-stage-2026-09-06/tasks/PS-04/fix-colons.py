import pathlib
root = pathlib.Path('/home/andrew/Projects/scrapkeep-wt-PS-04')

def edit(path, pairs):
    p = root / path
    t = p.read_text()
    for old, new in pairs:
        assert t.count(old) == 1, (path, old[:60], t.count(old))
        t = t.replace(old, new)
    p.write_text(t)
    print(path, len(pairs), 'edits')

edit('BACKLOG.md', [
    ('- [TRACKING.md](TRACKING.md) event EV-0024, the install record: editor at `/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64`, version `4.7.2.stable.official.ed1daf0bf`, official 4.7.2-stable release, SHA512 verified against the release sums',
     '- [TRACKING.md](TRACKING.md) event EV-0024, the install record (editor at `/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64`, version `4.7.2.stable.official.ed1daf0bf`, official 4.7.2-stable release, SHA512 verified against the release sums)'),
    ('- Browser precedent to differ from, not port: `src/orchard/simulation.js:140`, `:347-374`, `:417-421` and `tests/orchard.test.js:12-15`, `:327-337`',
     '- `src/orchard/simulation.js:140`, `:347-374`, `:417-421` and `tests/orchard.test.js:12-15`, `:327-337`, the browser precedent to differ from and not port'),
    ('- The reviewer confirms the defect is structural: the rule rejected it, not typing, per TADR-003 § Decision.',
     '- The reviewer confirms the defect is structural, so the rule rejected it and typing did not, per TADR-003 § Decision.'),
    ('- Prior art only, not reuse: `server/store.js:103-124` and `tests/progress-store.test.js:72-133`',
     '- `server/store.js:103-124` and `tests/progress-store.test.js:72-133` as prior art only, not reuse'),
])
edit('ORCHESTRATOR.md', [
    ('These definitions no longer self-isolate: the coordinator creates each writer\'s worktree',
     'These definitions no longer self-isolate. The coordinator creates each writer\'s worktree'),
])
