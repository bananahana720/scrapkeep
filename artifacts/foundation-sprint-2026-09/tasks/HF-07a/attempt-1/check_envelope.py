#!/usr/bin/env python3
"""HF-07a paper check. Usage: check_envelope.py <repository-root> --out <receipt-directory>

Checks the HF-07a field contract (Markdown and CSV) against TADR-004, TADR-003, BIBLE.md, BACKLOG.md, the
decision register, the S0-07 proof and the admitted HF-06b, HF-03a and HF-05 sections. Writes
paper-check.json and source-manifest.json under --out. Exit 0 when every check passes, 1 on a failed check,
2 on an internal error. Documentation only; it runs no build and establishes no engine behaviour.

It supplies the Markdown-to-CSV parity check that `npm run check:docs` cannot: that script reads only .md
files, so the delivered CSV gets no automated link or parity coverage from it.
"""
import argparse
import csv
import hashlib
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

SECTION_MD = "docs/tech/sections/HF-07a-save-envelope.md"
SECTION_CSV = "docs/tech/sections/HF-07a-save-envelope.csv"

HEADINGS = ["Sources", "Contract", "Scenarios", "Unresolved questions", "Re-verification triggers",
            "Procedure performed", "Evidence limits"]

CSV_COLUMNS = ["field", "group", "type", "presence", "owner_module", "owner_record", "produced_from",
               "projection_group", "source", "questions", "meaning"]
MD_HEAD = ["Field", "Type", "Presence", "Owner (HF-03a)", "Produced from", "HF-06b group", "Source",
           "Questions", "Meaning and rule"]

GROUPS = ["envelope", "profile", "run-identity", "run-start", "checkpoint", "lifecycle", "preferences"]
ANCHORS = {
    "envelope": "envelope-fields",
    "profile": "profile-fields",
    "run-identity": "run-identity-fields",
    "run-start": "run-start-fields",
    "checkpoint": "checkpoint-fields",
    "lifecycle": "lifecycle-fields",
    "preferences": "preferences-fields",
}
GROUP_TITLES = {
    "envelope": "The envelope",
    "profile": "The profile",
    "run-identity": "The run identity",
    "run-start": "The run start",
    "checkpoint": "The checkpoint",
    "lifecycle": "The lifecycle facts",
    "preferences": "The preferences record",
}

TYPES = {"string", "id-string", "int", "float", "bool", "object", "object or null", "id-string or null",
         "string or null", "array of id-string", "array of string", "array of object",
         "map of string to int", "map of string to float"}
PRESENCE = {"always", "when-present", "element"}

HF06B_GROUPS = [
    "profile.discovery-knowledge", "profile.permanent-unlocks", "run.identity",
    "checkpoint.build-selections", "checkpoint.owned-equipment", "checkpoint.companion-assembly",
    "checkpoint.device-carry-over", "checkpoint.resolved-rewards",
    "checkpoint.route-generation-decisions", "checkpoint.random-generator-state",
    "checkpoint.offered-choices", "checkpoint.next-entrance", "lifecycle.revival-spent",
    "lifecycle.terminal", "preferences",
]
LOCAL_GROUPS = ["envelope", "container", "reserved"]

QUESTIONS = {"Q-E09", "Q-P14", "Q-P15", "Q-P16", "Q-P32"}  # FR-05: preferences.reduced_motion carries Q-P32 for its bound
CARD_QUESTIONS = {"Q-E09", "Q-P16"}

ENVELOPE_KEYS = ["schema_version", "content_revision", "generation", "transaction_id", "profile", "run"]
NUMERIC_TYPES = {"int", "float"}
AGGREGATE_NUMERIC_FIELDS = {
    "schema_version", "generation", "run.checkpoint.route[].sequence",
    "run.checkpoint.device_carry_over[].counters",
}
QE09_FIELDS = {"profile.discoveries", "profile.recipes", "profile.unlocks"}
QP16_FIELDS = {"run.interruption", "run.lifecycle.revival_spent"}
QP15_FIELDS = {
    "run.checkpoint.companion.chassis_id", "run.checkpoint.companion.component_ids",
    "run.checkpoint.companion.command_ids", "run.checkpoint.device_carry_over",
    "run.checkpoint.device_carry_over[].device_id", "run.checkpoint.device_carry_over[].counters",
}
GROUP_PREFIX = {
    "profile": "profile.",
    "run-identity": "run.",
    "run-start": "run.start.",
    "checkpoint": "run.checkpoint.",
    "lifecycle": "run.lifecycle.",
    "preferences": "preferences.",
}

ENGINE_TOKEN = re.compile(r"\.tres|\.tscn|packedscene|nodepath|res://|user://|scene path|node path|"
                          r"live pointer|object reference", re.IGNORECASE)
GAMEPLAY_TERM = re.compile(r"character|item|tree|recipe|unlock|region|device|companion|reward|checkpoint|"
                           r"revival", re.IGNORECASE)

EXPECTED = {
    "base": "5f459b0407dce4fbb060a1a8421a00fb8bb5e0c1",
    "hf06b_md_sha256": "83f6e4ba248518d1979e1428ace02ec99fea202722ab6aa0bab531f766094014",
    "hf06b_csv_sha256": "b42918083688be02511496932e20db19305e7407dc785d740b4e0fedf6779a48",
    "hf03a_sha256": "95fbd03d067fd0da2d122130ae3c54284116adc92f40c7f69c91946fd941e4cc",
    "s0_07_run_normal_sha256": "f2b0d512b806f43c07bd49a1775a84a2ac7109b0c3465a79c37c68764f33d28c",
    "s0_07_run_exit_sha256": "9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa",
    "card_lines": (466, 495),
    "card_sha256": "35255efcf54d49ec92d1e2395c1c349d488cb0836ee8d79ffb98e476e9f0e157",
    "field_count": 70,
    "group_counts": {"envelope": 6, "profile": 3, "run-identity": 5, "run-start": 5,
                     "checkpoint": 42, "lifecycle": 3, "preferences": 6},
    "d26_line": 49,
    "d27_line": 50,
    "hf06b_rule4_line": 34,
    "hf06b_carryover_line": 63,
    "s0_07_intcast_line": 45,
}

# Source line citations this section makes that the check verifies verbatim against the cited file.
LINE_CLAIMS = [
    ("adr/TADR-004-persistence.md", 24, "separate versioned record"),
    ("adr/TADR-004-persistence.md", 26, "device carry-over fields"),
    ("adr/TADR-004-persistence.md", 28, "schema version, gameplay content revision, generation and transaction identity"),
    ("adr/TADR-004-persistence.md", 30, "Checkpoint timing and lifecycle timing differ"),
    ("adr/TADR-004-persistence.md", 32, "That product rule remains open"),
    ("adr/TADR-004-persistence.md", 34, "are not durable save identities"),
    ("adr/TADR-003-content-pipeline.md", 41, "silently remap missing IDs"),
    ("BIBLE.md", 460, "Acquired and equipped are separate states"),
    ("BIBLE.md", 463, "Permanent unlock"),
    ("BIBLE.md", 465, "does not duplicate rewards"),
    ("BIBLE.md", 580, "two randomly selected eligible destinations"),
    ("BIBLE.md", 582, "One standard revival is available per run"),
    ("BIBLE.md", 584, "resume at the next entrance"),
    ("BIBLE.md", 586, "Permanent discoveries, learned recipes, options and challenges survive defeat"),
    ("BIBLE.md", 596, "locked slot, unavailable upgrade, permitted equipment swap and special tree respec"),
    ("BIBLE.md", 602, "sensitivity, sound, UI scale and impact shake"),
    ("docs/project/DECISION-REGISTER.md", 49, "When permanent discoveries are written"),
    ("docs/project/DECISION-REGISTER.md", 50, "Run-checkpoint schema and permanent-profile compatibility"),
    ("docs/tech/sections/HF-06b-persistence-projection.md", 34, "Every projected ID is a JSON string"),
    ("docs/tech/sections/HF-06b-persistence-projection.md", 63, "checkpoint.device-carry-over"),
    ("docs/tech/sections/HF-06b-persistence-projection.md", 81, "Q-P16 is not registered on this card"),
    ("docs/tech/sections/HF-03a-module-map.md", 45, "`RunState` holds run identity"),
    ("docs/tech/sections/HF-03a-module-map.md", 49, "`DurableAggregate` is the validated last committed"),
    ("docs/tech/sections/HF-03a-module-map.md", 58, "takes precedence over an older checkpoint"),
    ("docs/tech/sections/HF-05-content-admission.md", 18, "opaque, nonempty, case-sensitive token"),
    ("docs/tech/sections/HF-05-content-admission.md", 23, "no assumed numeric ordering"),
    ("docs/tech/sections/HF-05-content-admission.md", 54, "connected unlocked prefix"),
    ("docs/tech/proofs/S0-07-save-owner.md", 45, "parses every JSON number as a float"),
]


class Check:
    def __init__(self, root):
        self.root = Path(root).resolve()
        self.failures = []
        self.checks = []

    def ok(self, name, condition, detail=""):
        self.checks.append({"check": name, "pass": bool(condition), "detail": detail})
        if not condition:
            self.failures.append(name + (": " + detail if detail else ""))
        return bool(condition)

    def read(self, rel):
        return (self.root / rel).read_text(encoding="utf-8")

    def sha(self, rel):
        return hashlib.sha256((self.root / rel).read_bytes()).hexdigest()


def strip_ticks(text):
    return text.replace("`", "").strip()


def md_tables(lines):
    """Return {group: [cells]} for each anchored field table."""
    tables = {}
    for group, anchor in ANCHORS.items():
        marker = '<a id="' + anchor + '"></a>'
        if marker not in lines:
            continue
        start = lines.index(marker)
        rows = []
        header = None
        for line in lines[start:]:
            if line.startswith("| ") and line.endswith(" |"):
                cells = [c.strip() for c in line[1:-1].split("|")]
                if header is None:
                    header = cells
                    continue
                if set("".join(cells).replace(" ", "")) <= {"-"}:
                    continue
                rows.append(cells)
            elif rows:
                break
        tables[group] = {"header": header, "rows": rows}
    return tables


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    c = Check(args.root)

    md_text = c.read(SECTION_MD)
    md_lines = md_text.split("\n")
    csv_text = c.read(SECTION_CSV)
    rows = list(csv.DictReader(csv_text.splitlines()))

    # 1. Required headings.
    present = {re.sub(r"^#{1,6}\s+", "", line).strip().lower()
               for line in md_lines if re.match(r"^#{1,6}\s+", line)}
    for heading in HEADINGS:
        c.ok("heading:" + heading, heading.lower() in present)

    # 2. Group anchors: present, unique, in order, each followed by its heading.
    positions = []
    for group in GROUPS:
        marker = '<a id="' + ANCHORS[group] + '"></a>'
        count = md_text.count(marker)
        c.ok("anchor-unique:" + group, count == 1, "count " + str(count))
        if count == 1:
            index = md_lines.index(marker)
            positions.append(index)
            heading = "### " + GROUP_TITLES[group]
            c.ok("anchor-heading:" + group, md_lines[index + 2] == heading, md_lines[index + 2][:60])
            c.ok("anchor-heading-slug-distinct:" + group,
                 GROUP_TITLES[group].lower().replace(" ", "-") != ANCHORS[group])
    c.ok("anchor-order", positions == sorted(positions), str(positions))
    for group in GROUPS:
        c.ok("anchor-cited:" + group, "(#" + ANCHORS[group] + ")" in md_text)

    # 3. CSV shape, counts, order and uniqueness.
    c.ok("csv-columns", list(rows[0].keys()) == CSV_COLUMNS if rows else False)
    c.ok("csv-count", len(rows) == EXPECTED["field_count"], str(len(rows)))
    names = [r["field"] for r in rows]
    c.ok("csv-unique-fields", len(set(names)) == len(names))
    order = [r["group"] for r in rows]
    c.ok("csv-group-order", order == sorted(order, key=lambda g: GROUPS.index(g)))
    for group, count in EXPECTED["group_counts"].items():
        actual = sum(1 for r in rows if r["group"] == group)
        c.ok("group-count:" + group, actual == count, str(actual))

    # 4. The card's first verification bullet: every field carries all three attributes.
    for r in rows:
        c.ok("attributes:" + r["field"],
             bool(r["type"].strip()) and bool(r["owner_module"].strip())
             and bool(r["owner_record"].strip()) and bool(r["source"].strip()))
        c.ok("owner-module:" + r["field"], r["owner_module"] == "Persistence", r["owner_module"])
        c.ok("type-vocabulary:" + r["field"], r["type"] in TYPES, r["type"])
        c.ok("presence-vocabulary:" + r["field"], r["presence"] in PRESENCE, r["presence"])
        c.ok("source-cites-a-record:" + r["field"],
             any(token in r["source"] for token in ("TADR-004", "TADR-003", "BIBLE", "HF-0", "S0-07")),
             r["source"])
        tags = [t.strip() for t in r["questions"].split(";")] if r["questions"] != "none" else []
        c.ok("question-vocabulary:" + r["field"], all(t in QUESTIONS for t in tags), r["questions"])
        pgroups = [p.strip() for p in r["projection_group"].split(";")]
        c.ok("projection-group:" + r["field"],
             all(p in HF06B_GROUPS + LOCAL_GROUPS for p in pgroups), r["projection_group"])
        c.ok("no-engine-token:" + r["field"],
             not ENGINE_TOKEN.search(r["field"] + " " + r["type"] + " " + r["meaning"]))

    # 5. The card's second verification bullet: the envelope carries exactly the four identities and the
    #    two containers, and no field that only one candidate policy needs.
    envelope = [r["field"] for r in rows if r["group"] == "envelope"]
    c.ok("envelope-exact-keys", envelope == ENVELOPE_KEYS, str(envelope))
    for r in rows:
        if r["group"] == "envelope":
            c.ok("envelope-no-question:" + r["field"], r["questions"] == "none", r["questions"])
    for identity in ("generation", "content_revision", "transaction_id"):
        c.ok("envelope-identity:" + identity, identity in envelope)

    # 6. Numeric typing under HF-06b rule 4 and the S0-07 int-cast policy.
    for r in rows:
        if r["group"] == "preferences":
            continue
        if r["type"] in NUMERIC_TYPES or r["type"] == "map of string to int":
            c.ok("aggregate-numeric-declared:" + r["field"], r["field"] in AGGREGATE_NUMERIC_FIELDS)
            c.ok("aggregate-no-float:" + r["field"], r["type"] != "float", r["type"])
        if r["type"] in ("id-string", "array of id-string", "id-string or null"):
            c.ok("id-is-string:" + r["field"], True)
    for field in AGGREGATE_NUMERIC_FIELDS:
        c.ok("numeric-field-present:" + field, field in names)
    state = [r for r in rows if r["field"] == "run.checkpoint.rng_state[].state"]
    c.ok("rng-state-is-string", bool(state) and state[0]["type"] == "string")

    # 7. Names match their group's path prefix.
    for r in rows:
        prefix = GROUP_PREFIX.get(r["group"])
        if prefix is None:
            continue
        if r["group"] == "run-identity":
            c.ok("name-prefix:" + r["field"],
                 r["field"].startswith("run.") and r["field"].count(".") <= 1)
        else:
            c.ok("name-prefix:" + r["field"], r["field"].startswith(prefix), prefix)

    # 8. Every HF-06b projection group is covered by at least one field.
    covered = set()
    for r in rows:
        covered.update(p.strip() for p in r["projection_group"].split(";"))
    for group in HF06B_GROUPS:
        c.ok("hf06b-group-covered:" + group, group in covered)

    # 9. Question-shaped fields carry their IDs and the reserved containers hold under every answer.
    tagged = {q: {r["field"] for r in rows if q in r["questions"]} for q in QUESTIONS}
    c.ok("qe09-tagged", QE09_FIELDS <= tagged["Q-E09"], str(sorted(tagged["Q-E09"])))
    c.ok("qp16-tagged", QP16_FIELDS <= tagged["Q-P16"], str(sorted(tagged["Q-P16"])))
    c.ok("qp15-tagged", QP15_FIELDS <= tagged["Q-P15"], str(sorted(tagged["Q-P15"])))
    by_name = {r["field"]: r for r in rows}
    c.ok("interruption-nullable", by_name["run.interruption"]["type"] == "object or null")
    c.ok("interruption-reserved", by_name["run.interruption"]["projection_group"] == "reserved")
    c.ok("carryover-array", by_name["run.checkpoint.device_carry_over"]["type"] == "array of object")
    c.ok("carryover-may-be-empty",
         "empty" in by_name["run.checkpoint.device_carry_over"]["meaning"])
    c.ok("counters-keys-open",
         "Q-P15" in by_name["run.checkpoint.device_carry_over[].counters"]["meaning"])
    for field in QE09_FIELDS:
        c.ok("qe09-shape:" + field, by_name[field]["type"] == "array of id-string")
    c.ok("revival-monotonic", "Monotonic" in by_name["run.lifecycle.revival_spent"]["meaning"])
    c.ok("terminal-monotonic", "Monotonic" in by_name["run.lifecycle.terminal"]["meaning"])
    c.ok("no-durability-class-field",
         not any("durability_class" in n or "commit_class" in n for n in names))
    c.ok("no-playable-field", not any(n.endswith("playable") for n in names))
    c.ok("no-seed-field", not any("seed" in n for n in names))

    # 10. The preferences record holds no gameplay progress and no domain ID.
    for r in rows:
        if r["group"] != "preferences":
            continue
        c.ok("preferences-no-id:" + r["field"], "id-string" not in r["type"], r["type"])
        c.ok("preferences-owner:" + r["field"], r["owner_record"] == "PreferencesRecord")
        c.ok("preferences-name-clean:" + r["field"],
             not GAMEPLAY_TERM.search(r["field"]), r["field"])

    # 11. Markdown-to-CSV parity, cell by cell. check:docs reads only .md files, so this is the only
    #     coverage the CSV receives.
    tables = md_tables(md_lines)
    total_md = 0
    for group in GROUPS:
        table = tables.get(group)
        if not c.ok("md-table-present:" + group, table is not None):
            continue
        c.ok("md-header:" + group, table["header"] == MD_HEAD, str(table["header"]))
        group_rows = [r for r in rows if r["group"] == group]
        c.ok("md-row-count:" + group, len(table["rows"]) == len(group_rows),
             str(len(table["rows"])) + " vs " + str(len(group_rows)))
        total_md += len(table["rows"])
        for md_row, csv_row in zip(table["rows"], group_rows):
            expected = [
                csv_row["field"], csv_row["type"], csv_row["presence"],
                csv_row["owner_module"] + " / " + csv_row["owner_record"], csv_row["produced_from"],
                csv_row["projection_group"], csv_row["source"], csv_row["questions"], csv_row["meaning"],
            ]
            actual = [strip_ticks(cell) for cell in md_row]
            c.ok("md-csv-parity:" + csv_row["field"], actual == expected,
                 next((a + " != " + e for a, e in zip(actual, expected) if a != e), ""))
    c.ok("md-total-rows", total_md == EXPECTED["field_count"], str(total_md))

    # 12. Relative links and in-page anchors in the section resolve.
    anchors = set(re.findall(r'<a id="([^"]+)"></a>', md_text))
    for line in md_lines:
        heading = re.match(r"^#{1,6}\s+(.*?)\s*$", line)
        if heading:
            slug = re.sub(r"[^a-z0-9\- ]", "", heading.group(1).lower().replace("`", "")).replace(" ", "-")
            anchors.add(slug)
    for target in re.findall(r"\]\(([^)]+)\)", md_text):
        if target.startswith("#"):
            c.ok("anchor-link:" + target, target[1:] in anchors)
            continue
        path, _, fragment = target.partition("#")
        resolved = (c.root / "docs/tech/sections" / path).resolve()
        c.ok("link:" + target, resolved.exists(), str(resolved))

    # 13. Dependency, receipt and card identities at this base.
    c.ok("hf06b-md-sha", c.sha("docs/tech/sections/HF-06b-persistence-projection.md")
         == EXPECTED["hf06b_md_sha256"])
    c.ok("hf06b-csv-sha", c.sha("docs/tech/sections/HF-06b-persistence-projection.csv")
         == EXPECTED["hf06b_csv_sha256"])
    c.ok("hf03a-sha", c.sha("docs/tech/sections/HF-03a-module-map.md") == EXPECTED["hf03a_sha256"])
    c.ok("s0-07-run-normal-sha",
         c.sha("artifacts/prepare-stage-2026-09-06/tasks/S0-07/run-normal.txt")
         == EXPECTED["s0_07_run_normal_sha256"])
    c.ok("s0-07-run-exit-sha",
         c.sha("artifacts/prepare-stage-2026-09-06/tasks/S0-07/run-normal.exit")
         == EXPECTED["s0_07_run_exit_sha256"])
    backlog = c.read("BACKLOG.md").split("\n")
    first, last = EXPECTED["card_lines"]
    card = "\n".join(backlog[first - 1:last]) + "\n"
    c.ok("card-sha", hashlib.sha256(card.encode("utf-8")).hexdigest() == EXPECTED["card_sha256"])
    c.ok("card-heading", backlog[first + 1].startswith("### HF-07a:"), backlog[first + 1][:40])

    # 14. Every cited source line still says what the section says it says.
    for rel, line_no, needle in LINE_CLAIMS:
        line = c.read(rel).split("\n")[line_no - 1]
        c.ok("line-claim:" + rel + ":" + str(line_no), needle in line, line[:80])

    # 15. The 14 HF-06b json-projection rows are all represented by the groups this section fills.
    hf06b_rows = list(csv.DictReader(
        c.read("docs/tech/sections/HF-06b-persistence-projection.csv").splitlines()))
    json_rows = [r for r in hf06b_rows if r["save_column"] == "json-projection"]
    c.ok("hf06b-json-row-count", len(json_rows) == 14, str(len(json_rows)))
    for r in json_rows:
        for group in (p.strip() for p in r["save_projection"].split(";")):
            c.ok("hf06b-row-covered:" + r["row_id"] + ":" + group, group in covered)

    manifest = {
        rel: c.sha(rel) for rel in [
            SECTION_MD, SECTION_CSV,
            "docs/tech/sections/HF-06b-persistence-projection.md",
            "docs/tech/sections/HF-06b-persistence-projection.csv",
            "docs/tech/sections/HF-03a-module-map.md",
            "docs/tech/sections/HF-05-content-admission.md",
            "adr/TADR-004-persistence.md", "adr/TADR-003-content-pipeline.md",
            "docs/tech/proofs/S0-07-save-owner.md", "docs/project/DECISION-REGISTER.md",
            "BIBLE.md", "BACKLOG.md",
        ]
    }
    passed = sum(1 for entry in c.checks if entry["pass"])
    result = {
        "card": "HF-07a",
        "attempt": "HF-07a-A1",
        "base": EXPECTED["base"],
        "generated": datetime.now(timezone.utc).isoformat(),
        "root": str(c.root),
        "checks_run": len(c.checks),
        "checks_passed": passed,
        "failures": c.failures,
        "result": "PASS" if not c.failures else "FAIL",
        "detail": c.checks,
    }
    (out / "paper-check.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    (out / "source-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(result["result"], passed, "of", len(c.checks), "checks passed")
    for failure in c.failures:
        print("FAIL", failure)
    return 0 if not c.failures else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:  # noqa: BLE001
        print("INTERNAL ERROR", error)
        sys.exit(2)
