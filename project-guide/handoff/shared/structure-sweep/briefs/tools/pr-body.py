"""Refresh the three record-derived lines of the landing pull request's description.

Run from the root of the gate checkout:
  python3 -I <this file> <description file>
Reads project-guide/handoff/STRUCTURE-SWEEP.md and shared/structure-sweep/units.tsv,
rewrites the pool-count line, the landed-units line and the unlanded-units line in place.
Safe to rerun. Fails when a line it owns is missing or appears twice.
"""
import csv, re, sys

BODY = sys.argv[1]
PAGE = "project-guide/handoff/STRUCTURE-SWEEP.md"
UNITS = "project-guide/handoff/shared/structure-sweep/units.tsv"

page = open(PAGE).read()
found = re.findall(r"^The pool holds (\d+) items[^:]*: ([^.]+)\.", page, re.M)
assert len(found) == 1, "the page must have exactly one pool-count sentence"
count_line = "At this commit the pool holds %s items: %s. The page has the current numbers." % found[0]

rows = list(csv.DictReader(open(UNITS), delimiter="\t", quoting=csv.QUOTE_NONE))
landed = sorted({int(n) for r in rows if r["stage"] == "landed" for n in re.findall(r"\d+", r["pull request"])})
n_landed = sum(1 for r in rows if r["stage"] == "landed")
landed_line = "%d units, by pull request: %s." % (n_landed, ", ".join("#%d" % n for n in landed))

open_rows = [r for r in rows if r["stage"] != "landed"]
with_pr = sorted({int(n) for r in open_rows for n in re.findall(r"\d+", r["pull request"])})
no_pr = sum(1 for r in open_rows if not r["pull request"].strip())
parts = []
if with_pr:
    parts.append("pull request%s %s" % ("s" if len(with_pr) > 1 else "", ", ".join("#%d" % n for n in with_pr)))
if no_pr:
    parts.append("%d with a writer that %s no pull request yet" % (no_pr, "have" if no_pr > 1 else "has"))
open_line = "- Units in review or with a writer: %d (%s)." % (len(open_rows), "; ".join(parts) if parts else "none")

OWNED = [
    (r"^At this commit the pool holds .*$", count_line),
    (r"^\d+ units, by pull request: .*$", landed_line),
    (r"^- (?:\w+ units are|Units) in review or with a writer[^.]*\.", open_line),
]
text = open(BODY).read()
for pattern, line in OWNED:
    assert len(re.findall(pattern, text, re.M)) == 1, "expected one line matching %r" % pattern
    text = re.sub(pattern, lambda m, line=line: line, text, count=1, flags=re.M)
open(BODY, "w").write(text)
print(count_line[:90]); print(landed_line[:60], "…"); print(open_line)
