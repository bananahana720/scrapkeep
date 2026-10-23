# union_rows.py <file>: resolve each conflict block as the union of both sides' table rows, stable-sorted by the date column.
import re, sys
p = sys.argv[1]; out = []; ours = theirs = None; side = None
for line in open(p, encoding="utf-8").read().split("\n"):
    if line.startswith("<<<<<<< "): ours, theirs, side = [], [], "o"; continue
    if line == "=======" and side == "o": side = "t"; continue
    if line.startswith(">>>>>>> ") and side == "t":
        seen = set(); rows = []
        for r in ours + theirs:
            if r not in seen: seen.add(r); rows.append(r)
        key = lambda r: (re.match(r"\| (\d{4}-\d\d-\d\d)", r) or [None, "9999"])[1]
        out += sorted(rows, key=key); side = None; continue
    (ours if side == "o" else theirs if side == "t" else out).append(line)
open(p, "w", encoding="utf-8").write("\n".join(out))
