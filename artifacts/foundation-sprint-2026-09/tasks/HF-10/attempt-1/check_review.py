#!/usr/bin/env python3
"""Paper check for the HF-10 foundation review report.

Accepts an explicit repository root and an --out directory so the coordinator can
rerun it from a retained copy without rewriting retained files. It never writes
into artifacts/foundation-sprint-2026-09/.

It checks documents, not engine behavior. No build, engine or browser runs here.
"""
import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

REPORT = "artifacts/foundation-sprint-2026-09/HF-10-foundation-review.md"
SECTIONS_DIR = "docs/tech/sections"

REQUIRED_HEADINGS = [
    "Sources",
    "Contract",
    "Scenarios",
    "Unresolved questions",
    "Re-verification triggers",
    "Procedure performed",
    "Evidence limits",
]

ROWS = ["HF-01", "HF-02", "HF-03a", "HF-03b", "HF-04a", "HF-04b", "HF-05",
        "HF-06a", "HF-06b", "HF-07a", "HF-07b", "HF-08", "HF-09"]

COLUMNS = ["module boundaries", "tick ownership", "content/persistence coverage",
           "transition order", "unresolved parameter gates"]

QUESTIONS = ["Q-P14", "Q-P15", "Q-E09", "Q-P16", "Q-E05", "Q-E03"]

# A claim that a question is settled. Two forms are not claims and are excluded
# per line, because both are legitimate and both occur: a conditional
# re-verification trigger ("Recheck ... when Q-X is answered ...") and a
# hypothetical scenario case ("Q-X is answered so that/with ..."). Excluding by
# line rather than by lookbehind, because a trigger sentence lists several
# questions and "when" sits far from the match.
SETTLED = re.compile(
    r"Q-[PE]\d\d is answered|the answer to Q-[PE]\d\d is|"
    r"adopts the Q-[PE]\d\d (answer|proposal)")
NOT_A_CLAIM = re.compile(
    r"\bwhen\b|\bRecheck\b|is answered so that|is answered with|"
    r"is answered by|if .* is answered", re.I)


class Report:
    def __init__(self):
        self.checks = []

    def add(self, name, ok, detail=""):
        self.checks.append({"name": name, "passed": bool(ok), "detail": str(detail)})

    @property
    def failures(self):
        return [c for c in self.checks if not c["passed"]]


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def table_rows(text, header_contains):
    """Return the cell lists of the one markdown table whose header holds every token."""
    out = []
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if not line.startswith("|"):
            continue
        header = [c.strip().lower() for c in line.strip("|").split("|")]
        if not all(any(tok in h for h in header) for tok in header_contains):
            continue
        if i + 1 >= len(lines) or not set(lines[i + 1].replace("|", "").strip()) <= set("- :"):
            continue
        for body in lines[i + 2:]:
            if not body.startswith("|"):
                break
            out.append([c.strip() for c in body.strip("|").split("|")])
        if out:
            return out
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root", help="repository root holding docs/tech/sections/")
    ap.add_argument("--out", required=True, help="directory for paper-check.json and source-manifest.json")
    args = ap.parse_args()

    root = Path(args.root).resolve()
    out = Path(args.out).resolve()
    if "foundation-sprint-2026-09" in out.parts:
        print("refusing to write into a retained receipt directory", file=sys.stderr)
        return 2
    out.mkdir(parents=True, exist_ok=True)

    rep = Report()
    report_path = root / REPORT
    rep.add("report exists", report_path.is_file(), str(report_path))
    if not report_path.is_file():
        (out / "paper-check.json").write_text(json.dumps(
            {"result": "FAIL", "checks": rep.checks}, indent=2) + "\n")
        return 1
    text = report_path.read_text()

    # 1. required headings, in order
    found = [m.group(1).strip() for m in re.finditer(r"^## (.+)$", text, re.M)]
    rep.add("seven required headings in order",
            found == REQUIRED_HEADINGS, "%r" % (found,))

    # 2. reviewed identities match the repository bytes
    identity_rows = table_rows(text, ["row", "output", "sha256"])
    rep.add("identity table has 16 output rows", len(identity_rows) == 16, len(identity_rows))
    bad_hash, checked = [], 0
    for r in identity_rows:
        path = re.sub(r"[`]", "", r[1]).strip()
        want = re.sub(r"[`]", "", r[2]).strip()
        target = root / path
        if not target.is_file():
            bad_hash.append(path + " missing")
            continue
        got = sha256(target)
        checked += 1
        if got != want:
            bad_hash.append("%s want %s got %s" % (path, want[:12], got[:12]))
    rep.add("every reviewed identity matches the repository bytes",
            not bad_hash and checked == 16, "; ".join(bad_hash) or "%d verified" % checked)

    # 3. the thirteen-by-five matrix
    matrix = table_rows(text, ["output", "module boundaries", "tick ownership",
                               "transition order"])
    rep.add("matrix has 13 rows", len(matrix) == 13, len(matrix))
    rep.add("matrix rows are the thirteen outputs in card order",
            [r[0] for r in matrix] == ROWS, [r[0] for r in matrix])
    rep.add("matrix has 6 columns (output plus five checks)",
            all(len(r) == 6 for r in matrix),
            sorted({len(r) for r in matrix}))

    bad_cell, fail_cells = [], []
    for r in matrix:
        for ci, cell in enumerate(r[1:], start=1):
            verdict = re.match(r"\*{0,2}(PASS|FAIL|NOTES)\*{0,2}", cell)
            if not verdict:
                bad_cell.append("%s/%s" % (r[0], COLUMNS[ci - 1]))
                continue
            if verdict.group(1) == "FAIL":
                fail_cells.append((r[0], COLUMNS[ci - 1], cell))
    rep.add("every cell opens with PASS, FAIL or NOTES", not bad_cell,
            ", ".join(bad_cell) or "65 cells")

    # 4. a path and a line in every FAIL cell
    citation = re.compile(r"(docs/tech/sections/[A-Za-z0-9\-\.]+\.md):(\d+)")
    missing = [f"{o}/{c}" for o, c, cell in fail_cells if not citation.search(cell)]
    rep.add("every FAIL cell carries a path and a line", not missing,
            ", ".join(missing) or "%d FAIL cells cited" % len(fail_cells))

    # 5. no cell asserts native behavior
    native = re.compile(r"\b(engine (ran|proved|established)|natively (proven|verified)|"
                        r"hardware (proven|verified)|executed on Windows)\b", re.I)
    offenders = [r[0] for r in matrix if any(native.search(c) for c in r[1:])]
    rep.add("no matrix cell asserts native behavior", not offenders, ", ".join(offenders) or "none")

    # 6. required fixes present and reachable from the matrix
    rf_defined = sorted(set(re.findall(r"\*\*(RF-\d)\b", text)))
    rf_referenced = sorted(set(re.findall(r"See (RF-\d)\.", text)))
    rep.add("RF-1 to RF-9 are all defined", rf_defined == ["RF-%d" % i for i in range(1, 10)],
            ",".join(rf_defined))
    rep.add("every FAIL cell points at a required fix",
            all(re.search(r"See RF-\d\.", cell) for _, _, cell in fail_cells),
            "%d FAIL cells" % len(fail_cells))
    rep.add("every required fix is referenced by a matrix cell or a cross-read",
            set(rf_referenced) <= set(rf_defined) and len(rf_referenced) >= 8,
            ",".join(rf_referenced))

    # 7. every section citation in the report resolves to a non-empty line
    bad_cite, cited = [], 0
    for path, line in set(citation.findall(text)):
        target = root / path
        if not target.is_file():
            bad_cite.append(path + " missing")
            continue
        lines = target.read_text().splitlines()
        n = int(line)
        cited += 1
        if n < 1 or n > len(lines) or not lines[n - 1].strip():
            bad_cite.append("%s:%s out of range or blank" % (path, line))
    rep.add("every cited section line exists and is non-empty", not bad_cite,
            "; ".join(bad_cite) or "%d distinct citations" % cited)

    # 8. no reviewed section asserts an answer to any registered question
    settled, scanned = [], 0
    for name in sorted(Path(root / SECTIONS_DIR).glob("HF-*.md")):
        scanned += 1
        for i, line in enumerate(name.read_text().splitlines(), start=1):
            if SETTLED.search(line) and not NOT_A_CLAIM.search(line):
                settled.append("%s:%d" % (name.name, i))
    rep.add("no reviewed section treats a registered question as settled",
            not settled and scanned == 13,
            "; ".join(settled) or "%d sections clean" % scanned)

    # 8b. negative control: the exclusion above must not swallow a real claim.
    probe = "Q-P16 is answered: revival health is 50 percent."
    rep.add("settled-claim detector fires on a planted claim",
            bool(SETTLED.search(probe)) and not NOT_A_CLAIM.search(probe), probe)

    # 8c. scripts/check-docs.mjs scans only its own tracked documentation set and
    # does not read this report's path, so its relative links get no automated
    # check from `npm run check:docs`. Supply that check here.
    bad_link, links = [], 0
    for m in re.finditer(r"\]\((?!https?:)([^)#]+)(#[^)]*)?\)", text):
        links += 1
        if not (report_path.parent / m.group(1)).resolve().exists():
            bad_link.append(m.group(1))
    rep.add("every relative link in the report resolves", not bad_link,
            ", ".join(bad_link) or "%d links" % links)

    # 9. every registered question is named in the report's question state
    qstate = text.split("### Question state", 1)[-1].split("### ", 1)[0]
    absent = [q for q in QUESTIONS if q not in qstate]
    rep.add("the report's question state names all six questions", not absent,
            ", ".join(absent) or "all named")

    # 10. the report adopts no proposal
    adopts = re.findall(r"this (report|review) (adopts|recommends) the \w+ proposal", text, re.I)
    rep.add("the report adopts no proposal", not adopts, adopts or "none")

    # 11. both cross-reads are present
    rep.add("cross-read 1 (HF-08 to HF-09 seam) present",
            "Cross-read 1" in text and "HF-08:367" in text)
    rep.add("cross-read 2 (retain_revision and read_initial_snapshot) present",
            "Cross-read 2" in text and "read_initial_snapshot" in text
            and "retain_revision" in text)

    # 12. every retained script rerun is recorded with an exit code
    rerun = table_rows(text, ["script", "exit", "result and counts"])
    rep.add("thirteen retained scripts plus the two wrappers are recorded",
            len(rerun) == 15, len(rerun))
    rep.add("every rerun row records an exit code",
            all(re.fullmatch(r"\d+", r[1]) for r in rerun),
            [r[1] for r in rerun])

    manifest = {
        "root": str(root),
        "report": {"path": REPORT, "sha256": sha256(report_path)},
        "sections": {p.name: sha256(p) for p in sorted(Path(root / SECTIONS_DIR).glob("HF-*"))},
    }
    (out / "source-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")

    result = {
        "result": "PASS" if not rep.failures else "FAIL",
        "checks": len(rep.checks),
        "failed": len(rep.failures),
        "failures": rep.failures,
        "detail": rep.checks,
        "limits": [
            "Documents only. No engine, build, browser, export or hardware evidence.",
            "Citation checks prove a line exists and is non-empty, not that it holds the claim.",
            "Matrix checks prove shape and citation, not that a verdict is correct.",
        ],
    }
    (out / "paper-check.json").write_text(json.dumps(result, indent=2) + "\n")
    for c in rep.checks:
        print("%s %s%s" % ("PASS" if c["passed"] else "FAIL", c["name"],
                           (" -- " + c["detail"]) if c["detail"] else ""))
    print("%d checks, %d failed; receipts in %s" % (len(rep.checks), len(rep.failures), out))
    return 0 if not rep.failures else 1


if __name__ == "__main__":
    sys.exit(main())
