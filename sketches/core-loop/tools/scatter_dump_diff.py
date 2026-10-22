#!/usr/bin/env python3
"""Diff two SCATTER_DUMP files (scatter_rows_test.gd) from two machines.

  SCATTER_DUMP=/path/a.txt godot --headless --path sketches/core-loop --script tests/scatter_rows_test.gd
  python3 sketches/core-loop/tools/scatter_dump_diff.py a.txt b.txt

Per row: the instance counts, the mesh aabb, how many instances differ and the largest position delta (metres) and
largest basis delta. Exit 0 when the dumps are identical, 1 otherwise.
"""
import sys


def load(path):
    rows, cur = {}, None
    with open(path) as f:
        for line in f:
            line = line.rstrip("\n")
            if line.startswith("row "):
                parts = line.split()
                cur = (parts[1], parts[2])
                rows[cur] = {"head": line, "inst": []}
            elif line and cur is not None:
                rows[cur]["inst"].append([float(x) for x in line.split()])
    return rows


def main(a_path, b_path):
    a, b = load(a_path), load(b_path)
    differ = 0
    for key in sorted(set(a) | set(b)):
        ra, rb = a.get(key), b.get(key)
        if ra is None or rb is None:
            print("%s/%s: only in %s" % (key[0], key[1], "b" if ra is None else "a"))
            differ += 1
            continue
        ha = ra["head"].split("aabb=")[1]
        hb = rb["head"].split("aabb=")[1]
        na, nb = len(ra["inst"]), len(rb["inst"])
        n = min(na, nb)
        bad = 0
        pos = 0.0
        basis = 0.0
        for i in range(n):
            x, y = ra["inst"][i], rb["inst"][i]
            if x != y:
                bad += 1
                pos = max(pos, max(abs(x[k] - y[k]) for k in (3, 7, 11)))
                basis = max(basis, max(abs(x[k] - y[k]) for k in (0, 1, 2, 4, 5, 6, 8, 9, 10)))
        same = na == nb and bad == 0 and ha.split(" count")[0] == hb.split(" count")[0]
        print("%s/%s: count %d vs %d, aabb %s, %d instances differ, max position delta %.9f m, max basis delta %.9f"
              % (key[0], key[1], na, nb, "equal" if ha.split(" count")[0] == hb.split(" count")[0] else "DIFFERS (%s | %s)" % (ha.split(" count")[0], hb.split(" count")[0]), bad, pos, basis))
        if not same:
            differ += 1
    print("rows differing: %d of %d" % (differ, len(set(a) | set(b))))
    return 0 if differ == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
