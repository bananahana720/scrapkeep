"""Apply one batch of changes to the structure sweep's records, then regenerate the page.

Usage, from the root of the checkout that holds the records (the gate checkout):
  python3 -I <path>/records.py <changes file>

The changes file is Python that may define any of:
  UNITS      {unit: {"stage": ..., "pr": ..., "writer": ..., "note": text appended to the notes}}
  NEW_UNITS  [(unit, what, writer, pull request, stage, notes)]
  POOL       {id: {"status": ..., "unit": ..., "note": text appended to the finding}}
  NEW_LEADS  [(kind, risk, status, unit, finding)]   ids continue from the last LEAD row
  PAGE       [(old text, new text, how many times old must occur)]

Every named unit and id must exist exactly once, every new unit must not, and every
page replacement must find its old text the stated number of times; otherwise nothing
is written. It then runs `node scripts/structure-sweep.mjs --write`, which must report
0 findings. Not safe to rerun with the same file: appended notes would repeat.
"""
import pathlib
import re
import subprocess
import sys

ns = {}
exec(pathlib.Path(sys.argv[1]).read_text(), ns)
D = pathlib.Path("project-guide/handoff/shared/structure-sweep")
PAGE_FILE = pathlib.Path("project-guide/handoff/STRUCTURE-SWEEP.md")


def rows(path):
    lines = path.read_text().split("\n")
    assert lines[-1] == "", f"{path} must end with a newline"
    return [line.split("\t") for line in lines[:-1]]


def clean(text):
    assert "\t" not in text and "\n" not in text, f"tab or newline in: {text[:60]}"
    return text.strip()


units = rows(D / "units.tsv")
assert units[0] == ["unit", "what", "writer", "pull request", "stage", "notes"], units[0]
col = {"writer": 2, "pr": 3, "stage": 4}
for unit, change in ns.get("UNITS", {}).items():
    hit = [r for r in units if r[0] == unit]
    assert len(hit) == 1, f"unit {unit}: {len(hit)} rows"
    for key, value in change.items():
        if key == "note":
            hit[0][5] = (hit[0][5] + " " + clean(value)).strip()
        else:
            hit[0][col[key]] = clean(value)
for row in ns.get("NEW_UNITS", []):
    assert len(row) == 6 and not any(r[0] == row[0] for r in units), f"new unit {row[0]}"
    units.append([clean(c) for c in row])

pool = rows(D / "pool.tsv")
assert pool[0] == ["id", "survey file", "kind", "risk", "status", "unit", "finding"], pool[0]
for item, change in ns.get("POOL", {}).items():
    hit = [r for r in pool if r[0] == item]
    assert len(hit) == 1, f"pool {item}: {len(hit)} rows"
    for key, value in change.items():
        if key == "note":
            hit[0][6] = (hit[0][6] + " " + clean(value)).strip()
        else:
            hit[0][{"status": 4, "unit": 5}[key]] = clean(value)
last = max(int(r[0][5:]) for r in pool if re.fullmatch(r"LEAD-\d+", r[0]))
for kind, risk, status, unit, finding in ns.get("NEW_LEADS", []):
    last += 1
    pool.append([f"LEAD-{last:02d}", "leads", kind, risk, status, unit, clean(finding)])

page = PAGE_FILE.read_text()
for old, new, count in ns.get("PAGE", []):
    assert page.count(old) == count, f"page has {page.count(old)} of: {old[:70]}"
    page = page.replace(old, new)

(D / "units.tsv").write_text("".join("\t".join(r) + "\n" for r in units))
(D / "pool.tsv").write_text("".join("\t".join(r) + "\n" for r in pool))
PAGE_FILE.write_text(page)
done = subprocess.run(["node", "scripts/structure-sweep.mjs", "--write"], capture_output=True, text=True)
print((done.stdout + done.stderr).strip()[-600:])
print(f"last lead LEAD-{last:02d}")
sys.exit(done.returncode)
