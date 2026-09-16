#!/usr/bin/env python3
"""HF-06a paper check. Usage: check_matrix.py <repository-root> --out <receipt-directory>

Checks the HF-06a matrix (Markdown and CSV) against nouns.md, TADR-003, BIBLE.md, BACKLOG.md and the
admitted dependency sections. Writes paper-check.json and source-manifest.json under --out. Exit 0 when
every check passes, 1 on a failed check, 2 on an internal error. Documentation only; no engine behavior.
"""
import argparse
import csv
import hashlib
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

SECTION_MD = "docs/tech/sections/HF-06a-schema-inventory.md"
SECTION_CSV = "docs/tech/sections/HF-06a-schema-inventory.csv"
NOUNS_LOCAL = "artifacts/local/tasks/HF-06a/nouns.md"
NOUNS_COMMITTED = "artifacts/foundation-sprint-2026-09/tasks/HF-06a/nouns.md"
HEADINGS = ["Sources", "Contract", "Scenarios", "Unresolved questions", "Re-verification triggers",
            "Procedure performed", "Evidence limits"]
COLUMNS = ["row_id", "subject", "source", "treatment", "producing_card", "questions", "scope_and_rationale"]
MD_HEAD = ["Row", "Subject", "Source", "Treatment", "Producing card", "Questions", "Scope and rationale"]
TREATMENTS = {"schema", "embedded-record", "excluded"}
QUESTIONS = ["Q-P14", "Q-P15", "Q-E09"]
CARD_RE = re.compile(r"^(SC-0[1-8]|TH-(0[1-9]|[12][0-9]|3[01]))$")
EXPECTED = {
    "base": "08fcbcca07f4db4123a6367bd5fc252610bda398",
    "hf05_sha256": "7ef95df2fb25f05b7b544cd7dbf2239cd1106c382aab0e8bc5e76288146259a6",
    "hf03a_sha256": "95fbd03d067fd0da2d122130ae3c54284116adc92f40c7f69c91946fd941e4cc",
    "nouns_sha256": "7afacf95d00c3f865f85705953059b839228bcd71462edb5909969c4b617425e",
    "card_lines": (403, 432),
    "card_sha256": "ad4e2570f2c6b08695f1c86235e61d1f7e1ebcad4507cf13de67150000b74292",
    "family_line": 25,
    "row_count": 67,
    "noun_count": 59,
}
LINK_RE = re.compile(r"\[([^\]]+)\]\([^)]+\)")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def slugify(heading: str) -> str:
    text = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", heading).strip().lower()
    text = re.sub(r"[^\w\s-]", "", text, flags=re.UNICODE)
    return re.sub(r"\s", "-", text)


def anchors_of(lines):
    found, seen = set(), {}
    for line in lines:
        m = re.match(r"^#{1,6}\s+(.*?)\s*#*\s*$", line.replace("`", ""))
        if m:
            base = slugify(m.group(1))
            n = seen.get(base, 0)
            seen[base] = n + 1
            found.add(base if n == 0 else f"{base}-{n}")
        for a in re.finditer(r'<a\s+(?:name|id)="([^"]+)"', line):
            found.add(a.group(1))
    return found


class Report:
    def __init__(self):
        self.checks = []

    def add(self, name, ok, detail=""):
        self.checks.append({"check": name, "result": "PASS" if ok else "FAIL", "detail": detail})
        return ok

    @property
    def failed(self):
        return [c for c in self.checks if c["result"] == "FAIL"]


def parse_md_table(lines, start_marker):
    rows, in_table, header_seen = [], False, False
    for i, line in enumerate(lines):
        if line.strip() == start_marker:
            in_table = True
            continue
        if not in_table:
            continue
        if line.startswith("| " + MD_HEAD[0] + " |"):
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            header_seen = cells == MD_HEAD
            continue
        if header_seen and line.startswith("| ---"):
            continue
        if header_seen and line.startswith("| "):
            rows.append(([c.strip() for c in line.strip()[1:-1].split(" | ")], i + 1))
            continue
        if header_seen and not line.strip():
            if rows:
                break
    return rows, header_seen


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("root")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    root = Path(args.root).resolve()
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    rep = Report()

    md_path, csv_path = root / SECTION_MD, root / SECTION_CSV
    for p in (md_path, csv_path, root / "BIBLE.md", root / "BACKLOG.md", root / "adr/TADR-003-content-pipeline.md"):
        if not p.exists():
            print("missing input:", p)
            return 2
    md_lines = md_path.read_text(encoding="utf-8").split("\n")
    bible_lines = (root / "BIBLE.md").read_text(encoding="utf-8").split("\n")
    backlog_lines = (root / "BACKLOG.md").read_text(encoding="utf-8").split("\n")
    tadr_lines = (root / "adr/TADR-003-content-pipeline.md").read_text(encoding="utf-8").split("\n")

    nouns_local, nouns_committed = root / NOUNS_LOCAL, root / NOUNS_COMMITTED
    nouns_used = nouns_local if nouns_local.exists() else nouns_committed
    if not nouns_used.exists():
        print("missing nouns.md at both", nouns_local, nouns_committed)
        return 2
    if nouns_local.exists() and nouns_committed.exists():
        rep.add("nouns local copy equals committed copy", sha256(nouns_local) == sha256(nouns_committed),
                f"{sha256(nouns_local)} vs {sha256(nouns_committed)}")
    rep.add("nouns.md sha256 matches packet", sha256(nouns_used) == EXPECTED["nouns_sha256"],
            f"{nouns_used.relative_to(root)} {sha256(nouns_used)}")

    nouns = []
    for line in nouns_used.read_text(encoding="utf-8").split("\n"):
        m = re.match(r"^\| (N-\d{3}) \| (.+?) \| (.+?) \| (\d+) \| \[#([^\]]+)\]\(", line)
        if m:
            nouns.append({"id": m.group(1), "noun": m.group(2), "section": m.group(3),
                          "line": int(m.group(4)), "anchor": m.group(5)})
    rep.add("nouns.md has 59 rows", len(nouns) == EXPECTED["noun_count"], str(len(nouns)))

    present = {slugify(m.group(1)) for m in
               (re.match(r"^#{1,6}\s+(.*?)\s*#*\s*$", ln) for ln in md_lines) if m}
    for h in HEADINGS:
        rep.add(f"required heading present: {h}", slugify(h) in present)

    fam_line = tadr_lines[EXPECTED["family_line"] - 1]
    fam_m = re.search(r"\. (Character roles, .*?) must receive", fam_line)
    families = []
    if fam_m:
        families = [f.strip() for f in re.split(r", | and ", fam_m.group(1))]
    rep.add("TADR-003 line 25 enumerates eight families", len(families) == 8, "; ".join(families))

    md_rows, header_ok = parse_md_table(md_lines, "### The matrix")
    rep.add("Markdown matrix header matches column contract", header_ok, " | ".join(MD_HEAD))
    rep.add("Markdown matrix has 67 rows", len(md_rows) == EXPECTED["row_count"], str(len(md_rows)))
    norm_rows = []
    for cells, lineno in md_rows:
        if len(cells) != 7:
            rep.add(f"Markdown row at line {lineno} has 7 cells", False, str(len(cells)))
            continue
        norm_rows.append([LINK_RE.sub(r"\1", c) for c in cells])

    with csv_path.open(encoding="utf-8", newline="") as fh:
        reader = csv.reader(fh)
        csv_header = next(reader)
        csv_rows = [r for r in reader]
    rep.add("CSV header matches column contract", csv_header == COLUMNS, ",".join(csv_header))
    rep.add("CSV has 67 rows", len(csv_rows) == EXPECTED["row_count"], str(len(csv_rows)))
    parity_ok = len(csv_rows) == len(norm_rows)
    mismatches = []
    for i, (a, b) in enumerate(zip(norm_rows, csv_rows)):
        for j, (x, y) in enumerate(zip(a, b)):
            if x != y:
                mismatches.append(f"row {i + 1} col {COLUMNS[j]}: md={x[:60]!r} csv={y[:60]!r}")
        if len(a) != len(b):
            mismatches.append(f"row {i + 1} cell count {len(a)} vs {len(b)}")
    rep.add("CSV equals Markdown cell for cell after link removal and in order",
            parity_ok and not mismatches, "; ".join(mismatches[:10]) or "identical")

    ids = [r[0] for r in csv_rows]
    dupes = sorted({i for i in ids if ids.count(i) > 1})
    rep.add("row IDs are unique", not dupes, ", ".join(dupes) or "no duplicates")
    fam_ids = [f"F-{n:02d}" for n in range(1, 9)]
    rep.add("family rows F-01 to F-08 present in TADR-003 order",
            ids[:8] == fam_ids and [r[1].lower() for r in csv_rows[:8]] == [f.lower() for f in families],
            "; ".join(f"{r[0]} {r[1]}" for r in csv_rows[:8]))
    noun_ids = [n["id"] for n in nouns]
    rep.add("noun rows equal nouns.md IDs once each in order", ids[8:] == noun_ids,
            f"missing={sorted(set(noun_ids) - set(ids))} extra={sorted(set(ids[8:]) - set(noun_ids))}")

    bible_anchors = anchors_of(bible_lines)
    backlog_anchors = anchors_of(backlog_lines)
    by_id = {r[0]: r for r in csv_rows}
    noun_problems = []
    for n in nouns:
        r = by_id.get(n["id"])
        if not r:
            continue
        if r[1] != n["noun"]:
            noun_problems.append(f"{n['id']} subject {r[1]!r} != {n['noun']!r}")
        if r[2] != f"BIBLE.md#{n['anchor']} line {n['line']}":
            noun_problems.append(f"{n['id']} source {r[2]!r}")
        if n["anchor"] not in bible_anchors:
            noun_problems.append(f"{n['id']} anchor #{n['anchor']} absent from BIBLE.md")
        heading = bible_lines[n["line"] - 1] if n["line"] <= len(bible_lines) else ""
        if heading != f"### {n['noun']}":
            noun_problems.append(f"{n['id']} BIBLE.md:{n['line']} is {heading!r}")
    rep.add("every noun row keeps its supplied subject, anchor and line, and BIBLE.md agrees",
            not noun_problems, "; ".join(noun_problems[:10]) or "all 59 agree")
    fam_src_ok = all(r[2] == f"TADR-003 § Decision line {EXPECTED['family_line']}" for r in csv_rows[:8])
    rep.add("family rows cite TADR-003 § Decision line 25", fam_src_ok)

    bad_treat = [r[0] for r in csv_rows if r[3] not in TREATMENTS]
    rep.add("every row has exactly one treatment from schema, embedded-record, excluded", not bad_treat,
            ", ".join(bad_treat) or "all valid")
    bad_card = [f"{r[0]}={r[4]}" for r in csv_rows if not CARD_RE.match(r[4]) or r[4].lower() not in backlog_anchors]
    rep.add("every row names one SC-01..SC-08 or TH-01..TH-31 card with a BACKLOG anchor", not bad_card,
            ", ".join(bad_card) or "all resolve")
    bad_q = []
    tagged = {q: [] for q in QUESTIONS}
    for r in csv_rows:
        if r[5] == "none":
            continue
        parts = r[5].split("; ")
        if any(p not in QUESTIONS for p in parts) or len(set(parts)) != len(parts):
            bad_q.append(f"{r[0]}={r[5]}")
        for p in parts:
            if p in tagged:
                tagged[p].append(r[0])
    rep.add("question cells use only Q-P14, Q-P15, Q-E09", not bad_q, ", ".join(bad_q) or "valid")
    for q in QUESTIONS:
        rep.add(f"{q} shapes at least one row and each carries the ID", len(tagged[q]) > 0, ", ".join(tagged[q]))
        m = None
        for line in md_lines:
            if f"[{q}]" in line and "carry it" in line:
                m = re.search(r"Rows ((?:[FN]-\d{2,3}(?:, | and )?)+) carry it", line)
        listed = re.findall(r"[FN]-\d{2,3}", m.group(1)) if m else []
        rep.add(f"{q} invariance paragraph lists exactly the tagged rows", sorted(listed) == sorted(tagged[q]),
                f"paragraph={listed} tagged={tagged[q]}")
    thin = [r[0] for r in csv_rows if r[3] == "excluded" and len(r[6]) < 40]
    rep.add("every excluded row carries a rationale", not thin, ", ".join(thin) or "all present")

    by_card = {}
    for r in csv_rows:
        by_card.setdefault(r[4], []).append(r[0])
    card_rows, _ = parse_md_table_generic(md_lines, "### Rows by producing card")
    listed_cards = {LINK_RE.sub(r"\1", c[0]): c[1].split(", ") for c in card_rows}
    rep.add("rows-by-producing-card table equals the matrix grouping", listed_cards == by_card,
            f"{len(listed_cards)} cards listed, {len(by_card)} in matrix")

    rep.add("Markdown links to the CSV beside it", "(HF-06a-schema-inventory.csv)" in "\n".join(md_lines))
    md_link_problems = []
    for line in md_lines:
        for m in re.finditer(r"\]\(([^)]+)\)", line):
            target = m.group(1)
            if target.startswith("http"):
                continue
            path_part, _, anchor = target.partition("#")
            target_file = (md_path.parent / path_part).resolve() if path_part else md_path
            if not target_file.exists():
                md_link_problems.append(target)
            elif anchor and target_file.suffix == ".md":
                if anchor not in anchors_of(target_file.read_text(encoding="utf-8").split("\n")):
                    md_link_problems.append(target)
    rep.add("every relative link and anchor in the section resolves", not md_link_problems,
            "; ".join(md_link_problems[:10]) or "all resolve")

    hf05, hf03a = root / "docs/tech/sections/HF-05-content-admission.md", root / "docs/tech/sections/HF-03a-module-map.md"
    rep.add("HF-05 section bytes match the packet hash", hf05.exists() and sha256(hf05) == EXPECTED["hf05_sha256"])
    rep.add("HF-03a section bytes match the packet hash", hf03a.exists() and sha256(hf03a) == EXPECTED["hf03a_sha256"])
    a, b = EXPECTED["card_lines"]
    card_text = "\n".join(backlog_lines[a - 1:b]) + "\n"
    card_sha = hashlib.sha256(card_text.encode("utf-8")).hexdigest()
    rep.add("exact HF-06a card bytes at BACKLOG.md:403-432 match the pinned hash",
            card_sha == EXPECTED["card_sha256"] and backlog_lines[a - 1].startswith("### HF-06a:"), card_sha)
    consumers = sum(1 for ln in backlog_lines if "identify its HF-06 matrix rows" in ln)
    consumers += sum(1 for ln in backlog_lines if "For every HF-06a row" in ln)
    rep.add("nine downstream cards reference the matrix rows in BACKLOG", consumers == 9, str(consumers))

    manifest = {p: sha256(root / p) for p in [SECTION_MD, SECTION_CSV, "BIBLE.md", "BACKLOG.md",
                                              "adr/TADR-003-content-pipeline.md",
                                              "docs/tech/sections/HF-05-content-admission.md",
                                              "docs/tech/sections/HF-03a-module-map.md"] if (root / p).exists()}
    manifest[str(nouns_used.relative_to(root))] = sha256(nouns_used)
    (out / "source-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    result = {
        "card": "HF-06a", "revision": 1, "base": EXPECTED["base"], "repository_root": str(root),
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "treatment_counts": {t: sum(1 for r in csv_rows if r[3] == t) for t in sorted(TREATMENTS)},
        "rows": len(csv_rows), "checks": rep.checks,
        "summary": {"passed": len(rep.checks) - len(rep.failed), "failed": len(rep.failed)},
        "limits": "Paper consistency check of two documentation files against cited sources; no engine behavior.",
    }
    (out / "paper-check.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    for c in rep.checks:
        print(f"{c['result']} {c['check']}" + (f" :: {c['detail']}" if c["result"] == "FAIL" else ""))
    print(f"{result['summary']['passed']} passed, {result['summary']['failed']} failed; receipts in {out}")
    return 1 if rep.failed else 0


def parse_md_table_generic(lines, start_marker):
    rows, in_table, header_seen = [], False, False
    for i, line in enumerate(lines):
        if line.strip() == start_marker:
            in_table = True
            continue
        if not in_table:
            continue
        if line.startswith("| ") and not header_seen and not line.startswith("| ---"):
            header_seen = True
            continue
        if header_seen and line.startswith("| ---"):
            continue
        if header_seen and line.startswith("| "):
            rows.append([c.strip() for c in line.strip()[1:-1].split(" | ")])
            continue
        if header_seen and not line.strip() and rows:
            break
    return rows, header_seen


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:  # noqa: BLE001
        print("internal error:", exc)
        sys.exit(2)
