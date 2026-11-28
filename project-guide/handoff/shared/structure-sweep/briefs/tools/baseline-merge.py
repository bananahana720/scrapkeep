"""Resolve a merge conflict in scripts/sketch-lint.baseline.json where both sides only removed entries.

Run from the root of a checkout that is in the middle of a merge with that file in conflict:

    python3 -I <this file>

The lists in that file may only shrink. When two units each remove entries, git reports a conflict
although the answer is fixed: keep an entry only if both sides kept it. This script reads the three
versions git holds for the conflict (the common ancestor, ours and theirs), refuses if either side
added an entry or raised a count, writes the intersection, formats it with the project's formatter
(`npx oxfmt -c scripts/ci/oxfmt.json`, which is how the file is kept) and stages the file. It does not
run the lint; run `npm run -s sketch:lint` afterwards, which must print 0 findings.

Safe to rerun while the conflict is still open; once the file is staged git no longer holds the three
versions and the script stops with git's error.
"""

import json
import subprocess
import sys

PATH = "scripts/sketch-lint.baseline.json"


def stage(n):
    text = subprocess.check_output(["git", "show", ":%d:%s" % (n, PATH)], text=True)
    return text, json.loads(text)


def main():
    _, base = stage(1)
    _, ours = stage(2)
    _, theirs = stage(3)
    out = {}
    for rule in ours:
        if rule not in theirs or rule not in base:
            sys.exit("baseline-merge: rule %s is not on all three sides; merge by hand" % rule)
        b, o, t = base[rule], ours[rule], theirs[rule]
        if isinstance(o, list):
            for side, name in ((o, "ours"), (t, "theirs")):
                grown = [e for e in side if e not in b]
                if grown:
                    sys.exit("baseline-merge: %s added to %s: %s" % (name, rule, grown[:3]))
            keep = set(t)
            out[rule] = [e for e in o if e in keep]
        else:
            for side, name in ((o, "ours"), (t, "theirs")):
                grown = [k for k, v in side.items() if v > b.get(k, 0)]
                if grown:
                    sys.exit("baseline-merge: %s raised %s for: %s" % (name, rule, grown[:3]))
            out[rule] = {k: min(v, t[k]) for k, v in o.items() if k in t}
        print("%s: base %d, ours %d, theirs %d, merged %d" % (rule, len(b), len(o), len(t), len(out[rule])))
    extra = [r for r in theirs if r not in ours]
    if extra:
        sys.exit("baseline-merge: theirs has rules ours lacks: %s; merge by hand" % extra)
    with open(PATH, "w") as f:
        f.write(json.dumps(out, indent=2, ensure_ascii=False) + "\n")
    subprocess.check_call(["npx", "oxfmt", "-c", "scripts/ci/oxfmt.json", PATH])
    subprocess.check_call(["git", "add", PATH])


main()
