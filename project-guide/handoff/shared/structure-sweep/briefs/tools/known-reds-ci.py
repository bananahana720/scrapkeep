"""Decide whether the failed checks of a pull request may be carried into the integration branch.

Called by merge-unit.sh from the root of the integration checkout:

    python3 -I <this file> <pull request number> <full head SHA>
    python3 -I <this file> --self-test

It exits 0 only when every failed check is a Linux Godot job whose log shows that its only red tests
are listed as red on main, and prints what it excused. Anything else exits 1 with the reason.
The run itself still failed (ruling bq): this tool only tells the coordinator the red is an old one.

A failed Godot job is excused when all of these hold in its log:
  - the line "sketch:fast fail: only known reds on main (<count>): <tests>" is there, and no
    "sketch:fast fail: new reds" line;
  - the budget line reads "(FAIL)": "(FAIL+OVER_BUDGET)" means the job also ran late, and a missing
    budget line means the log is cut off;
  - every test the line names has a row of kind "red" in the checked-out
    project-guide/handoff/KNOWN-FAILING.tsv whose cause starts "red on main at " and whose review
    date is today or later;
  - if the head does not hold unit G15's merge, the log has no "warm batch hit" line (before G15 a
    batch run that was thrown away never reached the rule).
The check named "CI gate" only repeats the others, so it is excused when every other failure is.
Reads only; safe to run again.
"""
import datetime
import json
import re
import subprocess
import sys

LEDGER = "project-guide/handoff/KNOWN-FAILING.tsv"
G15_MERGE = "fa85fb21f4a4e2961885591c5ac21d916f0787c2"
ONLY = re.compile(r"sketch:fast fail: only known reds on main \((\d+)\): (.+)$")
BUDGET = re.compile(r"budget\[[^\]]+\]: [\d.]+s / [\d.]+s \(([A-Z_+]+)\)")


def main_reds(ledger_text, today):
    rows = {}
    for line in ledger_text.splitlines()[1:]:
        cells = line.split("\t")
        if len(cells) >= 6 and cells[1] == "red" and cells[2].startswith("red on main at "):
            rows[cells[0]] = cells[5] >= today
    return rows


def judge(log_text, reds, has_g15):
    lines = log_text.splitlines()
    if any("sketch:fast fail: new reds" in line for line in lines):
        return "the log has a 'new reds' line"
    found = [m for m in (ONLY.search(line) for line in lines) if m]
    if not found:
        return "the log has no 'only known reds on main' line"
    budgets = [m.group(1) for m in (BUDGET.search(line) for line in lines) if m]
    if not budgets:
        return "the log has no budget line, so it may be cut off"
    if any(status != "FAIL" for status in budgets):
        return "the budget line reads (" + ", ".join(budgets) + "), not (FAIL)"
    if not has_g15 and any("warm batch hit" in line for line in lines):
        return "a warm batch was thrown away and the head does not hold unit G15's fix"
    named = []
    for match in found:
        tests = match.group(2).split()
        if len(tests) != int(match.group(1)):
            return "the line's count and its list of tests differ"
        named += tests
    for test in named:
        name = test.rsplit("/", 1)[-1].removesuffix(".gd")
        if name not in reds:
            return name + " has no red-on-main row in the checked-out ledger"
        if not reds[name]:
            return name + "'s ledger row is past its review date"
    return None


def self_test():
    today = "2026-11-28"
    ledger = "test\tkind\tcause\towner\tadded\treview\tcheck\n" + "\n".join([
        "a_test\tred\tred on main at abc on 2026-11-28: x\tc\t2026-11-28\t2026-12-05\tcheck one",
        "old_test\tred\tred on main at abc on 2026-11-01: x\tc\t2026-11-01\t2026-11-20\tcheck",
        "flaky_test\tflake\tsometimes\tc\t2026-11-01\t2026-12-05\t-",
    ])
    reds = main_reds(ledger, today)
    good = "x sketch:fast fail: only known reds on main (1): tests/a_test.gd\nx budget[godot-affected]: 300s / 900s (FAIL)"
    cases = [
        (good, True, None),
        (good.replace("(FAIL)", "(FAIL+OVER_BUDGET)"), True, "budget"),
        (good.split("\n")[0], True, "no budget"),
        ("x budget[godot-affected]: 300s / 900s (FAIL)", True, "no 'only known"),
        (good + "\nsketch:fast fail: new reds (1): tests/b.gd; known reds on main (1): tests/a_test.gd", True, "new reds"),
        (good.replace("a_test", "b_test"), True, "no red-on-main row"),
        (good.replace("a_test", "old_test"), True, "past its review"),
        (good.replace("a_test", "flaky_test"), True, "no red-on-main row"),
        (good.replace("(1)", "(2)"), True, "count"),
        (good + "\n  warm batch hit an unexpected exit; rerunning 3 test(s) alone", False, "thrown away"),
        (good + "\n  warm batch hit an unexpected exit; rerunning 3 test(s) alone", True, None),
    ]
    for number, (log, has_g15, want) in enumerate(cases, 1):
        got = judge(log, reds, has_g15)
        ok = got is None if want is None else (got is not None and want in got)
        assert ok, "self-test case %d: wanted %r, got %r" % (number, want, got)
    print("known-reds-ci self-test: %d cases pass" % len(cases))


def run(args):
    return subprocess.run(args, capture_output=True, text=True)


def main():
    if sys.argv[1:] == ["--self-test"]:
        return self_test()
    pr, head = sys.argv[1], sys.argv[2]
    checks = json.loads(run(["gh", "pr", "checks", pr, "--json", "name,bucket,link"]).stdout or "[]")
    assert checks, "gh pr checks %s printed nothing" % pr
    waiting = [c["name"] for c in checks if c["bucket"] not in ("pass", "fail", "skipping")]
    assert not waiting, "checks still running or cancelled: " + ", ".join(waiting)
    failed = [c for c in checks if c["bucket"] == "fail" and c["name"] != "CI gate"]
    assert failed, "the only failed check is the CI gate itself, with no failed job behind it"
    reds = main_reds(open(LEDGER).read(), datetime.date.today().isoformat())
    has_g15 = run(["git", "merge-base", "--is-ancestor", G15_MERGE, head]).returncode == 0
    for check in failed:
        assert check["name"].startswith("Godot affected tests"), "a check other than the Godot jobs failed: " + check["name"]
        match = re.search(r"/actions/runs/(\d+)/job/(\d+)", check["link"])
        assert match, "no run and job in the link of " + check["name"]
        log = run(["gh", "run", "view", match.group(1), "--job", match.group(2), "--log"])
        assert log.returncode == 0 and log.stdout, "could not read the log of " + check["name"]
        why = judge(log.stdout, reds, has_g15)
        assert why is None, check["name"] + ": " + why
        line = [m.group(0) for m in (ONLY.search(l) for l in log.stdout.splitlines()) if m][-1]
        print("known-reds-ci: excused %s: %s" % (check["name"], line))


try:
    main()
except AssertionError as error:
    print("known-reds-ci: refused: %s" % error, file=sys.stderr)
    sys.exit(1)
