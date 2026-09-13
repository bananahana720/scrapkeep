#!/usr/bin/env python3
"""Render docs/tech/sections/HF-06b-persistence-projection.md and .csv from rows.py and section-template.md.
Usage: render.py <repository-root>"""
import csv
import sys
from collections import OrderedDict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from rows import PROJECTION_GROUPS, ROWS  # noqa: E402

COLUMNS = ["row_id", "subject", "treatment", "producing_card", "save_column", "rationale_case", "authoring_codec",
           "save_projection", "proof_owner", "questions", "rationale"]
MD_HEAD = ["Row", "Subject", "Treatment", "Producing card", "Save column", "Case", "Authoring codec",
           "Save projection", "Proof owner", "Questions", "Rationale"]
BACKLOG = "../../../BACKLOG.md#"


def link_card(card):
    return f"[{card}]({BACKLOG}{card.lower()})" if card != "none" else card


def md_cell(column, value):
    if column in ("producing_card", "proof_owner"):
        return link_card(value)
    return value


def main():
    root = Path(sys.argv[1]).resolve()
    here = Path(__file__).resolve().parent
    md_out = root / "docs/tech/sections/HF-06b-persistence-projection.md"
    csv_out = root / "docs/tech/sections/HF-06b-persistence-projection.csv"

    matrix = ["| " + " | ".join(MD_HEAD) + " |", "| " + " | ".join("---" for _ in MD_HEAD) + " |"]
    for r in ROWS:
        matrix.append("| " + " | ".join(md_cell(c, r[c]) for c in COLUMNS) + " |")

    counts = OrderedDict()
    for r in ROWS:
        counts.setdefault(r["save_column"], []).append(r["row_id"])
    count_lines = ["| Save column | Rows | Count |", "| --- | --- | --- |"]
    for value in ("json-projection", "transient-reconstructed", "immutable-by-id"):
        ids = counts.get(value, [])
        count_lines.append(f"| `{value}` | {', '.join(ids)} | {len(ids)} |")

    groups = OrderedDict((g[0], []) for g in PROJECTION_GROUPS)
    for r in ROWS:
        if r["save_projection"] == "none":
            continue
        for token in r["save_projection"].split("; "):
            groups[token].append(r["row_id"])
    group_lines = ["| Projection group | Aggregate part | Live record (HF-03a) | TADR-004 phrase | Rows |",
                   "| --- | --- | --- | --- | --- |"]
    for token, part, record, phrase in PROJECTION_GROUPS:
        group_lines.append(f"| `{token}` | {part} | `{record}` | {phrase} | {', '.join(groups[token])} |")

    template = (here / "section-template.md").read_text(encoding="utf-8")
    text = (template.replace("{{MATRIX}}", "\n".join(matrix))
            .replace("{{COUNTS}}", "\n".join(count_lines))
            .replace("{{GROUPS}}", "\n".join(group_lines)))
    for marker in ("{{MATRIX}}", "{{COUNTS}}", "{{GROUPS}}"):
        assert marker not in text
    md_out.write_text(text, encoding="utf-8")

    with csv_out.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.writer(fh, lineterminator="\n")
        writer.writerow(COLUMNS)
        for r in ROWS:
            writer.writerow([r[c] for c in COLUMNS])
    print(f"wrote {md_out} and {csv_out}: {len(ROWS)} rows")


if __name__ == "__main__":
    main()
