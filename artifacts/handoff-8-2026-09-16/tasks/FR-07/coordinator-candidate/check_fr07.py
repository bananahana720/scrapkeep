#!/usr/bin/env python3
"""FR-07 paper check. Usage: check_fr07.py <repository-root> --out <receipt-directory> [--base <sha>]

Asserts the four accepted amendments AM-H8-001 to AM-H8-004 as applied to HF-06a, HF-06b, HF-07a and TH-07,
the Markdown and CSV parity of every changed row, the unchanged HF-07a field set, and that every other changed
documentation file differs from the base only in stated SHA256 tokens. Runs negative controls that mutate an
in-memory copy and must fail. Exit 0 on pass, 1 on a failed assertion or an uncaught control, 2 on an internal
error. Documentation agreement only.
"""
import argparse
import copy
import csv
import hashlib
import io
import json
import re
import subprocess
import sys
from pathlib import Path

DEFAULT_BASE = "39295c42607dbc23cbcc20d5a8465074da494ad9"
SEC = "docs/tech/sections/"
A_MD, A_CSV = SEC + "HF-06a-schema-inventory.md", SEC + "HF-06a-schema-inventory.csv"
B_MD, B_CSV = SEC + "HF-06b-persistence-projection.md", SEC + "HF-06b-persistence-projection.csv"
E_MD, E_CSV = SEC + "HF-07a-save-envelope.md", SEC + "HF-07a-save-envelope.csv"
T07 = SEC + "TH-07-four-slots-and-milestone-progression.md"
EDITED = [A_MD, A_CSV, B_MD, B_CSV, E_MD, E_CSV, T07]
HEADINGS = ["Sources", "Contract", "Scenarios", "Unresolved questions", "Re-verification triggers",
            "Procedure performed", "Evidence limits"]
KIT_ROWS = ["F-01", "N-007", "N-008", "N-009", "N-010", "N-011", "N-019"]
KIT_ABILITY = "N-021 ability definitions by ID and expected family `ability`"
LINK = re.compile(r"\[([^\]]+)\]\([^)]+\)")
HEX = re.compile(r"[0-9a-f]{64}")
SLOT_ID = "run.checkpoint.build.slots[].slot_id"


def md_rows(text, first_header):
    rows, on = {}, False
    lines = text.split("\n")
    for n, line in enumerate(lines, 1):
        if line.startswith("| " + first_header + " |") and n < len(lines) and lines[n].startswith("| ---"):
            on = True
            continue
        if on and line.startswith("| ---"):
            continue
        if on and line.startswith("| "):
            cells = [LINK.sub(r"\1", c.strip()) for c in line.strip()[1:-1].split(" | ")]
            rows[cells[0].strip("`")] = (cells, n)
            continue
        if on and rows and not line.strip():
            on = False
    return rows


def csv_rows(text, key):
    return {r[key]: r for r in csv.DictReader(io.StringIO(text))}


def headings(text):
    return [l[3:].strip() for l in text.split("\n") if l.startswith("## ")]


def not_negated_sc05_event(text):
    text = text.split("## Procedure performed")[0]
    return [m.start() for m in re.finditer(r"SC-05 event", text)
            if not text[max(0, m.start() - 7):m.start()].endswith("not an ")]


def respec_ok(cell):
    return ("F-04 objective definition (SC-04)" in cell and "Q-P18" in cell and "TH-06 UN-05" in cell
            and not not_negated_sc05_event(cell))


def run_checks(docs, base_docs, other_changed):
    res = []

    def ok(name, cond, detail=""):
        res.append({"check": name, "pass": bool(cond), "detail": detail})

    for p in EDITED:
        if p.endswith(".md"):
            ok(f"seven headings unchanged: {p}", headings(docs[p]) == HEADINGS == headings(base_docs[p]),
               ", ".join(headings(docs[p])))

    a_md, a_csv = md_rows(docs[A_MD], "Row"), csv_rows(docs[A_CSV], "row_id")
    b_md, b_csv = md_rows(docs[B_MD], "Row"), csv_rows(docs[B_CSV], "row_id")
    a_base, b_base = csv_rows(base_docs[A_CSV], "row_id"), csv_rows(base_docs[B_CSV], "row_id")
    ok("HF-06a row sets equal base in order", list(a_csv) == list(a_base) == list(a_md), f"{len(a_csv)} rows")
    ok("HF-06b row sets equal base in order", list(b_csv) == list(b_base) == list(b_md), f"{len(b_csv)} rows")

    a_changed = [k for k in a_csv if a_csv[k] != a_base.get(k)]
    b_changed = [k for k in b_csv if b_csv[k] != b_base.get(k)]
    ok("HF-06a changed rows are exactly the amended rows",
       sorted(a_changed) == sorted(KIT_ROWS + ["N-013", "N-016", "N-021", "N-024"]), ", ".join(a_changed))
    ok("HF-06b changed rows are exactly F-04, N-009 and N-024", sorted(b_changed) == ["F-04", "N-009", "N-024"],
       ", ".join(b_changed))
    for k in a_changed:
        base_cells = {c: v for c, v in a_base[k].items() if c != "scope_and_rationale"}
        now_cells = {c: v for c, v in a_csv[k].items() if c != "scope_and_rationale"}
        ok(f"HF-06a {k}: only the rationale cell changed", base_cells == now_cells)
        ok(f"HF-06a {k}: Markdown and CSV rationale identical", k in a_md and a_md[k][0][-1] == a_csv[k]["scope_and_rationale"])
    for k in b_changed:
        base_cells = {c: v for c, v in b_base[k].items() if c != "rationale"}
        now_cells = {c: v for c, v in b_csv[k].items() if c != "rationale"}
        ok(f"HF-06b {k}: only the rationale cell changed", base_cells == now_cells)
        ok(f"HF-06b {k}: Markdown and CSV rationale identical", k in b_md and b_md[k][0][-1] == b_csv[k]["rationale"])
    ok("HF-06a all rows Markdown and CSV rationale identical",
       all(a_md[k][0][-1] == a_csv[k]["scope_and_rationale"] for k in a_csv if k in a_md))
    ok("HF-06b all rows Markdown and CSV rationale identical",
       all(b_md[k][0][-1] == b_csv[k]["rationale"] for k in b_csv if k in b_md))

    ra = {k: a_csv[k]["scope_and_rationale"] for k in a_csv}
    rb = {k: b_csv[k]["rationale"] for k in b_csv}
    for k in KIT_ROWS:
        cell = ra[k]
        ok(f"{k}: kit actions reference N-021 abilities by expected family `ability`",
           "kit" in cell and KIT_ABILITY in cell, cell[:80])
        ok(f"{k}: an ability references the F-02 attacks it produces, a mobility action possibly none",
           "references the F-02 attacks it produces" in cell and "a mobility action possibly none" in cell)
        ok(f"{k}: no kit action is an F-02 reference by expected family",
           "(F-02) by ID and expected family" not in cell and "F-02 weapon" not in cell
           and "mobility actions are F-02" not in cell)
    ok("N-021 names the F-02 attack definitions it references",
       "references by ID the F-02 attack definitions" in ra["N-021"] and "attacks it produces" in ra["N-021"]
       and "expected family `ability`" in ra["N-021"])
    ok("N-013 distinguishes a slot action's visual reference from an attack's",
       "slot action's visual reference" in ra["N-013"] and "attack's visual reference" in ra["N-013"]
       and KIT_ABILITY in ra["N-013"])
    ok("N-016 distinguishes replacing a mobility action from replacing an attack",
       re.search(r"replacing a mobility action[^.;]*N-021", ra["N-016"]) is not None
       and re.search(r"replacing an attack[^.;]*F-02", ra["N-016"]) is not None
       and "movement or attacks is an effect reference to F-02" not in ra["N-016"])
    ok("HF-06b N-009: planted-limb attacks stay F-02 within an ability",
       "Planted-limb attacks stay F-02 attacks within an ability" in rb["N-009"])
    ok("HF-07a unchanged by AM-H8-003: only one CSV cell differs from base",
       sum(1 for x, y in zip(docs[E_CSV].split("\n"), base_docs[E_CSV].split("\n")) if x != y) == 1)

    slot_def = re.compile(r"\bslot definitions?\b")
    typers = [k for k, v in ra.items() if slot_def.search(v)]
    ok("exactly one HF-06a rationale types the slot definition, and it is N-024", typers == ["N-024"],
       ", ".join(typers))
    ok("N-024 types both slot and slot-tree definitions",
       ra["N-024"].startswith("Slot definitions and slot-tree definitions (F-03).")
       and "This row types the slot definition" in ra["N-024"])
    ok("HF-06b N-024 carries the matching slot-definition projection cell",
       "HF-06a row N-024 also types the slot definition" in rb["N-024"] and b_csv["N-024"]["save_column"] == "json-projection")
    e_md, e_csv = md_rows(docs[E_MD], "Field"), csv_rows(docs[E_CSV], "field")
    src_md = e_md.get(SLOT_ID, ([""] * 7, 0))[0][6]
    src_csv = e_csv.get(SLOT_ID, {}).get("source", "")
    ok("HF-07a slot_id source cell names the typing row N-024 in both copies",
       src_md == src_csv and "HF-06b row N-024" in src_csv and "F-03" not in src_csv, f"{src_md} | {src_csv}")
    ok("HF-07a slot_id Markdown row is line 127", e_md.get(SLOT_ID, (None, 0))[1] == 127)

    t07 = docs[T07]
    seam5 = [l for l in t07.split("\n") if l.startswith("**Seam 5:")]
    ok("N-024 (HF-06a) calls a respec opportunity an F-04 objective, not an SC-05 event", respec_ok(ra["N-024"]))
    ok("N-024 (HF-06b) calls a respec opportunity an F-04 objective, not an SC-05 event", respec_ok(rb["N-024"]))
    ok("TH-07 Seam 5 calls a respec opportunity an F-04 objective, not an SC-05 event",
       len(seam5) == 1 and respec_ok(seam5[0]) and "to SC-04 and Q-P18" in seam5[0])
    ok("TH-07 carries no un-negated SC-05 event anywhere", not not_negated_sc05_event(t07))
    ok("HF-06a and HF-06b carry no un-negated SC-05 event",
       not not_negated_sc05_event(docs[A_MD] + docs[A_CSV] + docs[B_MD] + docs[B_CSV]))

    f04 = b_md.get("F-04", ([""], 0))
    clause = [s for s in re.split(r"(?<=[.;])\s", rb["F-04"]) if "completed level" in s]
    ok("HF-06b F-04 is Markdown line 114", f04[1] == 114)
    ok("HF-06b line 114 clause names the route decision and next entrance and cites TH-11 line 45",
       len(clause) == 1 and "accepted route decision and a next entrance" in clause[0] and "TH-11 line 45" in clause[0],
       clause[0] if clause else "")
    ok("HF-06b line 114 clause names no level or encounter ID",
       len(clause) == 1 and re.search(r"(level|encounter)[^.;]*\bby ID\b", clause[0]) is None
       and re.search(r"\b(level|encounter)[ _-]?id\b", clause[0], re.I) is None)

    ok("HF-07a field set equal to base in both copies",
       list(csv_rows(docs[E_CSV], "field")) == list(csv_rows(base_docs[E_CSV], "field"))
       and list(e_md) == list(md_rows(base_docs[E_MD], "Field")), f"{len(e_csv)} CSV fields")

    for p, (now, base) in sorted(other_changed.items()):
        ok(f"re-pointed only by hash tokens: {p}", HEX.sub("H", now) == HEX.sub("H", base))
    return res


def git_show(root, base, path):
    return subprocess.run(["git", "show", f"{base}:{path}"], cwd=root, capture_output=True, check=True).stdout.decode("utf-8")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root")
    ap.add_argument("--out", required=True)
    ap.add_argument("--base", default=DEFAULT_BASE)
    args = ap.parse_args()
    root, out = Path(args.root).resolve(), Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    docs = {p: (root / p).read_text(encoding="utf-8") for p in EDITED}
    base_docs = {p: git_show(root, args.base, p) for p in EDITED}
    changed = subprocess.run(["git", "diff", "--name-only", args.base, "--", "docs"], cwd=root, capture_output=True,
                             text=True, check=True).stdout.split()
    other = {p: ((root / p).read_text(encoding="utf-8"), git_show(root, args.base, p)) for p in changed if p not in EDITED}

    results = run_checks(docs, base_docs, other)
    failed = [r for r in results if not r["pass"]]

    def mutate(path, old, new):
        d = copy.deepcopy(docs)
        if old not in d[path]:
            raise SystemExit(f"control setup: text not found in {path}")
        d[path] = d[path].replace(old, new, 1)
        return d

    old_n019 = git_show(root, args.base, A_CSV)
    old_n019 = csv_rows(old_n019, "row_id")["N-019"]["scope_and_rationale"]
    controls = [
        ("NC1 CSV N-019 reverted to the F-02 mobility wording",
         mutate(A_CSV, csv_rows(docs[A_CSV], "row_id")["N-019"]["scope_and_rationale"], old_n019),
         "HF-06a all rows Markdown and CSV rationale identical"),
        ("NC2 F-03 rationale also types a slot definition",
         mutate(A_CSV, "One slot-tree definition per character slot", "One slot definition and one slot-tree definition per character slot"),
         "exactly one HF-06a rationale types the slot definition, and it is N-024"),
        ("NC3 HF-06b N-024 respec back to an SC-05 event",
         mutate(B_CSV, "A respec at a respec opportunity, which is an F-04 objective definition (SC-04) under Q-P18 and not an SC-05 event definition (TH-06 UN-05 at line 119),", "A respec through an SC-05 event"),
         "N-024 (HF-06b) calls a respec opportunity an F-04 objective, not an SC-05 event"),
        ("NC4 HF-06b F-04 names the level and encounter by ID again",
         mutate(B_CSV, "because a level has no durable domain identity (TH-11 line 45)", "naming the level and encounter by ID (TH-11 line 45)"),
         "HF-06b line 114 clause names no level or encounter ID"),
        ("NC5 HF-07a CSV loses a field row",
         mutate(E_CSV, "\n" + next(l for l in docs[E_CSV].split("\n") if l.startswith("run.checkpoint.build.slots[].unlocked,")), ""),
         "HF-07a field set equal to base in both copies"),
        ("NC6 HF-07a slot_id source back to row F-03",
         mutate(E_CSV, "BIBLE line 594; HF-06b row N-024", "BIBLE line 594; HF-06b row F-03"),
         "HF-07a slot_id source cell names the typing row N-024 in both copies"),
        ("NC7 TH-07 Seam 5 back to the SC-05 event",
         mutate(T07, "is an F-04 objective definition (SC-04) under Q-P18, not an SC-05 event definition, because", "is an SC-05 event definition naming this card, because"),
         "TH-07 Seam 5 calls a respec opportunity an F-04 objective, not an SC-05 event"),
        ("NC8 N-011 kit wording dropped",
         mutate(A_MD, "Candidate pilot instance (F-01) with the same reference shape as N-007: its kit actions reference N-021 ability definitions by ID and expected family `ability`, and an ability references the F-02 attacks it produces, a mobility action possibly none. Beam", "Candidate pilot instance (F-01). Beam"),
         "HF-06a all rows Markdown and CSV rationale identical"),
    ]
    control_results = []
    for name, mutated, expected in controls:
        r = run_checks(mutated, base_docs, other)
        fails = [x["check"] for x in r if not x["pass"]]
        control_results.append({"control": name, "expected_failure": expected, "caught": expected in fails, "failed": fails})
    caught = sum(c["caught"] for c in control_results)

    manifest = {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in EDITED}
    report = {"card": "FR-07", "base": args.base, "checks_run": len(results), "checks_failed": len(failed),
              "controls_total": len(controls), "controls_caught": caught, "re_pointed_files": len(other),
              "result": "pass" if not failed and caught == len(controls) else "fail",
              "checks": results, "controls": control_results, "manifest": manifest}
    (out / "paper-check.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    for r in results:
        print(("PASS " if r["pass"] else "FAIL ") + r["check"] + (f" :: {r['detail']}" if not r["pass"] and r["detail"] else ""))
    for c in control_results:
        print(("CAUGHT " if c["caught"] else "MISSED ") + c["control"] + f" (expected {c['expected_failure']})")
    print(f"FR-07 paper check: {len(results)} checks, {len(failed)} failed; controls {caught} of {len(controls)} caught; "
          f"{len(other)} re-pointed files; result {report['result']}")
    return 0 if report["result"] == "pass" else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except SystemExit:
        raise
    except Exception as exc:
        print(f"internal error: {exc}", file=sys.stderr)
        sys.exit(2)
