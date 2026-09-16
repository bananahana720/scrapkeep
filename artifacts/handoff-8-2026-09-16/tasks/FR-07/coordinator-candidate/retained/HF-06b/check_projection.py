#!/usr/bin/env python3
"""HF-06b paper check. Usage: check_projection.py <repository-root> --out <receipt-directory>

Checks the HF-06b projection matrix (Markdown and CSV) against the HF-06a CSV, TADR-003, TADR-004, BACKLOG.md and
the admitted dependency sections. Writes paper-check.json and source-manifest.json under --out. Exit 0 when every
check passes, 1 on a failed check, 2 on an internal error. Documentation only; no engine behavior.
"""
import argparse
import csv
import hashlib
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

SECTION_MD = "docs/tech/sections/HF-06b-persistence-projection.md"
SECTION_CSV = "docs/tech/sections/HF-06b-persistence-projection.csv"
HF06A_CSV = "docs/tech/sections/HF-06a-schema-inventory.csv"
HEADINGS = ["Sources", "Contract", "Scenarios", "Unresolved questions", "Re-verification triggers",
            "Procedure performed", "Evidence limits"]
COLUMNS = ["row_id", "subject", "treatment", "producing_card", "save_column", "rationale_case", "authoring_codec",
           "save_projection", "proof_owner", "questions", "rationale"]
MD_HEAD = ["Row", "Subject", "Treatment", "Producing card", "Save column", "Case", "Authoring codec",
           "Save projection", "Proof owner", "Questions", "Rationale"]
SAVE_VALUES = {"json-projection", "transient-reconstructed", "immutable-by-id"}
CASE_FOR_SAVE = {
    "json-projection": {"projection"},
    "transient-reconstructed": {"runtime-rebuilt"},
    "immutable-by-id": {"definition-by-id", "no-definition-no-state"},
}
TREATMENT_FOR_CASE = {
    "projection": {"schema", "embedded-record"},
    "definition-by-id": {"schema", "embedded-record"},
    "runtime-rebuilt": {"excluded"},
    "no-definition-no-state": {"excluded"},
}
CODEC_FOR_TREATMENT = {"schema": "tres", "embedded-record": "tres-embedded", "excluded": "none"}
PROJECTION_GROUPS = [
    "profile.discovery-knowledge", "profile.permanent-unlocks", "run.identity", "checkpoint.build-selections",
    "checkpoint.owned-equipment", "checkpoint.companion-assembly", "checkpoint.device-carry-over",
    "checkpoint.resolved-rewards", "checkpoint.route-generation-decisions", "checkpoint.random-generator-state",
    "checkpoint.offered-choices", "checkpoint.next-entrance", "lifecycle.revival-spent", "lifecycle.terminal",
    "preferences",
]
ENGINE_OBJECT_RE = re.compile(r"resource|\.tres|\.tscn|\bnode\b|\bscene\b|pointer|packedscene", re.IGNORECASE)
QUESTIONS = ["Q-P14", "Q-P15", "Q-E09"]
REQUIRED_TAGS = {"Q-P15": ["F-06", "F-07", "N-027"], "Q-E09": ["F-08", "N-017", "N-026", "N-028"]}
EXPECTED = {
    "base": "2d33632136918703a2d64d9ca8f05bf03d45fcd4",
    "hf06a_md_sha256": "fb58dfaea559734dcfd947853c7a7fd7fd73e8ac050908c846af0d4e6517fd18",
    "hf06a_csv_sha256": "eb8148de5f80018084a550fb7f29295e28da68ae664f0221697d476e70480d4f",
    "hf05_sha256": "7ef95df2fb25f05b7b544cd7dbf2239cd1106c382aab0e8bc5e76288146259a6",
    "hf03a_sha256": "95fbd03d067fd0da2d122130ae3c54284116adc92f40c7f69c91946fd941e4cc",
    "s0_07_run_normal_sha256": "f2b0d512b806f43c07bd49a1775a84a2ac7109b0c3465a79c37c68764f33d28c",
    "s0_07_run_exit_sha256": "9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa",
    "card_lines": (436, 464),
    "card_sha256": "69d5f98725c4a3583500f3ece2ccbf3209b63453aca6ca2941106c433e45932f",
    "th22_anchor_line": 1811,
    "row_count": 67,
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


def parse_md_table(lines, start_marker, head=None):
    rows, in_table, header_seen = [], False, False
    for i, line in enumerate(lines):
        if line.strip() == start_marker:
            in_table = True
            continue
        if not in_table:
            continue
        if line.startswith("| ") and not header_seen and not line.startswith("| ---"):
            cells = [c.strip() for c in line.strip()[1:-1].split(" | ")]
            header_seen = cells == head if head else True
            continue
        if header_seen and line.startswith("| ---"):
            continue
        if header_seen and line.startswith("| "):
            rows.append(([c.strip() for c in line.strip()[1:-1].split(" | ")], i + 1))
            continue
        if header_seen and not line.strip() and rows:
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

    md_path, csv_path, hf06a_path = root / SECTION_MD, root / SECTION_CSV, root / HF06A_CSV
    for p in (md_path, csv_path, hf06a_path, root / "BACKLOG.md", root / "adr/TADR-004-persistence.md"):
        if not p.exists():
            print("missing input:", p)
            return 2
    md_lines = md_path.read_text(encoding="utf-8").split("\n")
    backlog_lines = root / "BACKLOG.md"
    backlog_lines = backlog_lines.read_text(encoding="utf-8").split("\n")

    present = {slugify(m.group(1)) for m in
               (re.match(r"^#{1,6}\s+(.*?)\s*#*\s*$", ln) for ln in md_lines) if m}
    for h in HEADINGS:
        rep.add(f"required heading present: {h}", slugify(h) in present)

    md_rows, header_ok = parse_md_table(md_lines, "### The projection matrix", MD_HEAD)
    rep.add("Markdown matrix header matches column contract", header_ok, " | ".join(MD_HEAD))
    rep.add("Markdown matrix has 67 rows", len(md_rows) == EXPECTED["row_count"], str(len(md_rows)))
    norm_rows = []
    for cells, lineno in md_rows:
        if len(cells) != len(COLUMNS):
            rep.add(f"Markdown row at line {lineno} has {len(COLUMNS)} cells", False, str(len(cells)))
            continue
        norm_rows.append([LINK_RE.sub(r"\1", c) for c in cells])

    with csv_path.open(encoding="utf-8", newline="") as fh:
        reader = csv.reader(fh)
        csv_header = next(reader)
        csv_rows = [r for r in reader]
    rep.add("CSV header matches column contract", csv_header == COLUMNS, ",".join(csv_header))
    rep.add("CSV has 67 rows", len(csv_rows) == EXPECTED["row_count"], str(len(csv_rows)))
    mismatches = []
    for i, (a, b) in enumerate(zip(norm_rows, csv_rows)):
        for j, (x, y) in enumerate(zip(a, b)):
            if x != y:
                mismatches.append(f"row {i + 1} col {COLUMNS[j]}: md={x[:60]!r} csv={y[:60]!r}")
        if len(a) != len(b):
            mismatches.append(f"row {i + 1} cell count {len(a)} vs {len(b)}")
    rep.add("CSV equals Markdown cell for cell after link removal and in order",
            len(csv_rows) == len(norm_rows) and not mismatches, "; ".join(mismatches[:10]) or "identical")

    with hf06a_path.open(encoding="utf-8", newline="") as fh:
        reader = csv.reader(fh)
        next(reader)
        hf06a = [r for r in reader]
    rep.add("HF-06a CSV has 67 rows", len(hf06a) == EXPECTED["row_count"], str(len(hf06a)))
    key_problems = []
    for i, (a, b) in enumerate(zip(csv_rows, hf06a)):
        if a[0] != b[0]:
            key_problems.append(f"row {i + 1} id {a[0]} != {b[0]}")
            continue
        if a[1] != b[1]:
            key_problems.append(f"{a[0]} subject differs")
        if a[2] != b[3]:
            key_problems.append(f"{a[0]} treatment {a[2]} != {b[3]}")
        if a[3] != b[4]:
            key_problems.append(f"{a[0]} producing card {a[3]} != {b[4]}")
    rep.add("row IDs, subjects, treatments and producing cards equal the HF-06a CSV in order",
            len(csv_rows) == len(hf06a) and not key_problems, "; ".join(key_problems[:10]) or "all 67 agree")
    ids = [r[0] for r in csv_rows]
    rep.add("row IDs are unique", len(set(ids)) == len(ids))

    rows = [dict(zip(COLUMNS, r)) for r in csv_rows]
    bad = [r["row_id"] for r in rows if r["save_column"] not in SAVE_VALUES]
    rep.add("every row has exactly one save column value from the closed set", not bad, ", ".join(bad) or "all valid")
    bad = [f"{r['row_id']} {r['save_column']}/{r['rationale_case']}" for r in rows
           if r["rationale_case"] not in CASE_FOR_SAVE.get(r["save_column"], set())]
    rep.add("rationale case matches the save column", not bad, ", ".join(bad) or "all match")
    bad = [f"{r['row_id']} {r['rationale_case']}/{r['treatment']}" for r in rows
           if r["treatment"] not in TREATMENT_FOR_CASE.get(r["rationale_case"], set())]
    rep.add("rationale case matches the HF-06a treatment (rule 2)", not bad, ", ".join(bad) or "all match")
    bad = [f"{r['row_id']} {r['authoring_codec']}/{r['treatment']}" for r in rows
           if CODEC_FOR_TREATMENT.get(r["treatment"]) != r["authoring_codec"]]
    rep.add("authoring codec matches the treatment", not bad, ", ".join(bad) or "all match")

    json_rows = [r for r in rows if r["save_column"] == "json-projection"]
    other_rows = [r for r in rows if r["save_column"] != "json-projection"]
    bad = []
    used = {g: [] for g in PROJECTION_GROUPS}
    for r in json_rows:
        tokens = r["save_projection"].split("; ")
        if r["save_projection"] == "none" or any(t not in PROJECTION_GROUPS for t in tokens) \
                or len(set(tokens)) != len(tokens):
            bad.append(f"{r['row_id']} projection {r['save_projection']!r}")
        for t in tokens:
            if t in used:
                used[t].append(r["row_id"])
        if r["proof_owner"] != "TH-22":
            bad.append(f"{r['row_id']} proof owner {r['proof_owner']!r}")
        if r["authoring_codec"] not in ("tres", "tres-embedded"):
            bad.append(f"{r['row_id']} codec {r['authoring_codec']!r}")
    rep.add("every json-projection row names a codec, a vocabulary projection and TH-22 as proof owner",
            not bad, "; ".join(bad) or f"{len(json_rows)} rows")
    bad = [r["row_id"] for r in other_rows
           if r["save_projection"] != "none" or r["proof_owner"] != "none" or len(r["rationale"]) < 60]
    rep.add("every other row has no projection, no proof owner and a rationale", not bad, ", ".join(bad) or "all")
    unused = [g for g, ids_ in used.items() if not ids_]
    rep.add("every projection group is used by at least one row", not unused, ", ".join(unused) or "all used")
    bad = [r["row_id"] for r in rows if ENGINE_OBJECT_RE.search(r["save_projection"])]
    rep.add("no row projects a Resource, node, scene or live object", not bad, ", ".join(bad) or "none")

    bad = []
    tagged = {q: [] for q in QUESTIONS}
    for r in rows:
        if r["questions"] == "none":
            continue
        parts = r["questions"].split("; ")
        if any(p not in QUESTIONS for p in parts) or len(set(parts)) != len(parts):
            bad.append(f"{r['row_id']}={r['questions']}")
        for p in parts:
            if p in tagged:
                tagged[p].append(r["row_id"])
            if p not in r["rationale"]:
                bad.append(f"{r['row_id']} rationale does not name {p}")
    rep.add("question cells use only Q-P14, Q-P15, Q-E09 and each rationale names its tags", not bad,
            ", ".join(bad) or "valid")
    for q, required in REQUIRED_TAGS.items():
        missing = [i for i in required if i not in tagged[q]]
        rep.add(f"{q} device/companion/discovery rows carry the tag", not missing, ", ".join(tagged[q]))
    for q in QUESTIONS:
        m = None
        for line in md_lines:
            if f"[{q}]" in line and "carry it" in line:
                m = re.search(r"Rows ((?:[FN]-\d{2,3}(?:, | and )?)+) carry it", line)
        listed = re.findall(r"[FN]-\d{2,3}", m.group(1)) if m else []
        rep.add(f"{q} invariance paragraph lists exactly the tagged rows", sorted(listed) == sorted(tagged[q]),
                f"paragraph={listed} tagged={tagged[q]}")

    counts, _ = parse_md_table(md_lines, "### Rows by save column")
    listed = {re.sub(r"`", "", c[0]): (c[1].split(", "), int(c[2])) for c, _ in counts}
    actual = {}
    for r in rows:
        actual.setdefault(r["save_column"], []).append(r["row_id"])
    rep.add("rows-by-save-column table equals the matrix grouping",
            all(listed.get(v) == (ids_, len(ids_)) for v, ids_ in actual.items()) and len(listed) == 3,
            "; ".join(f"{v}={len(i)}" for v, i in actual.items()))
    groups, _ = parse_md_table(md_lines, "### Projection groups")
    listed_groups = {re.sub(r"`", "", c[0]): c[4].split(", ") for c, _ in groups}
    rep.add("projection-group table equals the matrix grouping", listed_groups == used,
            f"{len(listed_groups)} listed, {len(PROJECTION_GROUPS)} expected")

    rep.add("Markdown links to the CSV beside it", "(HF-06b-persistence-projection.csv)" in "\n".join(md_lines))
    link_problems = []
    for line in md_lines:
        for m in re.finditer(r"\]\(([^)]+)\)", line):
            target = m.group(1)
            if target.startswith("http"):
                continue
            path_part, _, anchor = target.partition("#")
            target_file = (md_path.parent / path_part).resolve() if path_part else md_path
            if not target_file.exists():
                link_problems.append(target)
            elif anchor and target_file.suffix == ".md":
                if anchor not in anchors_of(target_file.read_text(encoding="utf-8").split("\n")):
                    link_problems.append(target)
    rep.add("every relative link and anchor in the section resolves", not link_problems,
            "; ".join(link_problems[:10]) or "all resolve")

    deps = {
        "HF-06a section": ("docs/tech/sections/HF-06a-schema-inventory.md", EXPECTED["hf06a_md_sha256"]),
        "HF-06a CSV": (HF06A_CSV, EXPECTED["hf06a_csv_sha256"]),
        "HF-05 section": ("docs/tech/sections/HF-05-content-admission.md", EXPECTED["hf05_sha256"]),
        "HF-03a section": ("docs/tech/sections/HF-03a-module-map.md", EXPECTED["hf03a_sha256"]),
        "S0-07 run-normal.txt receipt": ("artifacts/prepare-stage-2026-09-06/tasks/S0-07/run-normal.txt",
                                         EXPECTED["s0_07_run_normal_sha256"]),
        "S0-07 run-normal.exit receipt": ("artifacts/prepare-stage-2026-09-06/tasks/S0-07/run-normal.exit",
                                          EXPECTED["s0_07_run_exit_sha256"]),
    }
    for name, (rel, expected) in deps.items():
        p = root / rel
        rep.add(f"{name} bytes match the packet hash", p.exists() and sha256(p) == expected,
                sha256(p) if p.exists() else "missing")
    a, b = EXPECTED["card_lines"]
    card_text = "\n".join(backlog_lines[a - 1:b]) + "\n"
    card_sha = hashlib.sha256(card_text.encode("utf-8")).hexdigest()
    rep.add("exact HF-06b card bytes at BACKLOG.md:436-464 match the pinned hash",
            card_sha == EXPECTED["card_sha256"] and backlog_lines[a - 1].startswith("### HF-06b:"), card_sha)
    rep.add("TH-22 anchor is at BACKLOG.md:1811",
            backlog_lines[EXPECTED["th22_anchor_line"] - 1].strip() == '<a id="th-22"></a>'
            and backlog_lines[EXPECTED["th22_anchor_line"] + 1].startswith("### TH-22:"))

    manifest = {rel: sha256(root / rel) for rel in [SECTION_MD, SECTION_CSV, HF06A_CSV, "BACKLOG.md", "BIBLE.md",
                                                     "adr/TADR-003-content-pipeline.md",
                                                     "adr/TADR-004-persistence.md",
                                                     "docs/tech/proofs/S0-07-save-owner.md",
                                                     "docs/tech/proofs/S0-08-save-evidence.md"]
                + [rel for rel, _ in deps.values()] if (root / rel).exists()}
    (out / "source-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    result = {
        "card": "HF-06b", "revision": 1, "base": EXPECTED["base"], "repository_root": str(root),
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "save_column_counts": {v: len(i) for v, i in actual.items()},
        "rows": len(rows), "checks": rep.checks,
        "summary": {"passed": len(rep.checks) - len(rep.failed), "failed": len(rep.failed)},
        "limits": "Paper consistency check of two documentation files against cited sources; no engine behavior.",
    }
    (out / "paper-check.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    for c in rep.checks:
        print(f"{c['result']} {c['check']}" + (f" :: {c['detail']}" if c["result"] == "FAIL" else ""))
    print(f"{result['summary']['passed']} passed, {result['summary']['failed']} failed; receipts in {out}")
    return 1 if rep.failed else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:  # noqa: BLE001
        print("internal error:", exc)
        sys.exit(2)
