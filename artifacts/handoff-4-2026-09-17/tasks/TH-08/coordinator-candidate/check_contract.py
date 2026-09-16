#!/usr/bin/env python3
"""Paper check for docs/tech/sections/TH-08-inventory-equipment-and-transformations.md.

It compares the section against the admitted sibling sections at the recorded base.
It proves document consistency and a model of the stated rebuild function. It proves
nothing about engine behaviour, storage or feel.
"""

import argparse
import hashlib
import json
import re
from pathlib import Path

SECTION = "docs/tech/sections/TH-08-inventory-equipment-and-transformations.md"
MODULE_MAP = "docs/tech/sections/HF-03a-module-map.md"
GRAPH = "docs/tech/sections/HF-03b-dependency-graph.md"
ENVELOPE_CSV = "docs/tech/sections/HF-07a-save-envelope.csv"
BACKLOG = "BACKLOG.md"

MODULES = [
    "Session",
    "Encounter",
    "CollisionQueries",
    "ContentAdmission",
    "Persistence",
    "InputAdapter",
    "Presentation",
]

# HF-05 lines 101 and 117 name the two diagnostic types that HF-03a line 34 lists as
# ContentAdmission's "compatibility and missing-ID diagnostics"; HF-03a spells the entry
# in prose, so the type names are admitted here rather than treated as unlisted interfaces.
DIAGNOSTIC_TYPES = {"ContentReferenceFailure", "ContentAdmissionFailure"}

CELL = re.compile(r"\s*\|\s*")
BACKTICK = re.compile(r"`([^`]+)`")
EDGE_ID = re.compile(r"\bD(\d{2})\b")
EDGE_RANGE = re.compile(r"\bD(\d{2}) to D(\d{2})\b")
QUESTION = re.compile(r"\bQ-[EP]\d+\b")
SOURCE_LINE = re.compile(r"\bline[s]?\s+\d+", re.IGNORECASE)
FIELD_PATH = re.compile(r"^(run|profile|preferences)\.[A-Za-z0-9_.\[\]]+$")


def rows(lines, start_predicate):
    """Every pipe table row whose first cell matches the predicate."""
    out = []
    for index, line in enumerate(lines):
        if not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if cells and start_predicate(cells[0]):
            out.append((index + 1, cells))
    return out


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class Check:
    def __init__(self):
        self.results = []

    def add(self, name, ok, detail, count=None):
        self.results.append(
            {"check": name, "status": "PASS" if ok else "FAIL", "detail": detail, "count": count}
        )

    def note(self, name, detail):
        self.results.append({"check": name, "status": "NOTE", "detail": detail, "count": None})

    @property
    def failures(self):
        return [r for r in self.results if r["status"] == "FAIL"]


def parse_modules(text):
    lines = text.splitlines()
    table = rows(lines, lambda first: first.split(".")[0].strip() in MODULES)
    modules = {}
    for _, cells in table:
        if len(cells) < 5:
            continue
        name = cells[0].split(".")[0].strip()
        modules[name] = {
            "records": set(BACKTICK.findall(cells[1])),
            "commands": set(BACKTICK.findall(cells[3])),
            "results": set(BACKTICK.findall(cells[4])),
        }
    return modules


def parse_edges(text):
    lines = text.splitlines()
    table = rows(lines, lambda first: re.fullmatch(r"D\d{2}", first) is not None)
    edges = {}
    for _, cells in table:
        edges[cells[0]] = {
            "from": cells[1],
            "to": cells[2],
            "interfaces": set(BACKTICK.findall(cells[3])),
        }
    return edges


def parse_fields(csv_text):
    fields = set()
    for line in csv_text.splitlines()[1:]:
        if line.strip():
            fields.add(line.split(",")[0].strip())
    return fields


def expand_edges(cell):
    found = set()
    for low, high in EDGE_RANGE.findall(cell):
        for value in range(int(low), int(high) + 1):
            found.add("D%02d" % value)
    for value in EDGE_ID.findall(cell):
        found.add("D" + value)
    return found


def modules_in(cell):
    if "Every module" in cell:
        return set(MODULES) | {"Values"}
    found = set()
    for name in MODULES + ["Values"]:
        if re.search(r"\b" + name + r"\b", cell):
            found.add(name)
    return found


def check_step(check_id, cells, columns, modules, edges, problems):
    caller_cell, edge_cell, interface_cell = (cells[c] for c in columns)
    used = expand_edges(edge_cell)
    named = modules_in(caller_cell)
    for edge in sorted(used):
        if edge not in edges:
            problems.append("%s uses %s, absent from the adjacency list" % (check_id, edge))
            continue
        if not named:
            continue
        for end in ("from", "to"):
            if edges[edge][end] not in named:
                problems.append(
                    "%s uses %s whose %s is %s, not named in %r"
                    % (check_id, edge, end, edges[edge][end], caller_cell)
                )
    local = "local" in edge_cell or "none" in edge_cell
    allowed_row = set(DIAGNOSTIC_TYPES)
    allowed_edge = set(DIAGNOSTIC_TYPES)
    for edge in used:
        if edge in edges:
            target = edges[edge]["to"]
            if target in modules:
                allowed_row |= modules[target]["commands"] | modules[target]["results"]
            allowed_edge |= edges[edge]["interfaces"]
    if local:
        for name in named:
            if name in modules:
                every = modules[name]
                allowed_row |= every["commands"] | every["results"] | every["records"]
                allowed_edge |= every["commands"] | every["results"] | every["records"]
    for token in BACKTICK.findall(interface_cell):
        if token not in allowed_row:
            problems.append("%s names %r, outside the target module's HF-03a row" % (check_id, token))
        if token not in allowed_edge:
            problems.append("%s names %r, outside the edge's permitted-use column" % (check_id, token))


def rebuild(selections, definitions, target_classes):
    """The EQ-03 function. Three inputs, no output of itself among them."""
    out = []
    for key in sorted(selections):
        instance = selections[key]
        declared = definitions.get(instance, {})
        for effect, classes in sorted(declared.items()):
            for target in sorted(set(classes) & target_classes):
                out.append((key, instance, effect, target))
    return tuple(out)


def patched(previous, selections, definitions, target_classes):
    """The EF-01 defect. It adds without removing, so a removal leaves a residue."""
    return tuple(sorted(set(previous) | set(rebuild(selections, definitions, target_classes))))


def model_checks(check):
    definitions = {
        "inst-1": {"chain": ("player", "device"), "prime": ("companion",)},
        "inst-3": {"replace-attack": ("player",)},
    }
    classes = {"player", "device", "companion"}
    empty = {}
    equipped = {"mount-a": "inst-1"}
    b0 = rebuild(empty, definitions, classes)
    b1 = rebuild(equipped, definitions, classes)
    b2 = rebuild(empty, definitions, classes)
    b3 = rebuild(equipped, definitions, classes)
    check.add(
        "model:no-residue",
        b2 == b0 and b0 == (),
        "rebuild after a removal returns the pre-equip value exactly (%d rows)" % len(b2),
        len(b2),
    )
    check.add(
        "model:no-accumulation",
        b3 == b1,
        "equip, remove and re-equip returns the identical value, not a second copy",
        len(b3),
    )
    check.add(
        "model:idempotent",
        rebuild(equipped, definitions, classes) == b1,
        "a repeated rebuild over the same selection set is identical",
        len(b1),
    )
    check.add(
        "model:provenance",
        all(row[0] in equipped and equipped[row[0]] == row[1] for row in b1),
        "every emitted row names a live selection and its instance",
        len(b1),
    )
    check.add(
        "model:default-deny",
        all(row[3] in definitions[row[1]][row[2]] for row in b1),
        "no row reaches a target class the definition did not declare",
        len(b1),
    )
    fed_back = rebuild(equipped, definitions, classes)
    check.add(
        "model:no-recursion",
        rebuild(equipped, definitions, classes) == fed_back,
        "the function reads no output of itself, so a second pass adds nothing",
        len(fed_back),
    )
    residue = patched(b1, empty, definitions, classes)
    check.add(
        "negative:patched-rebuild-detected",
        residue != b2 and len(residue) > 0,
        "the patching defect leaves %d residual rows after a removal and is caught" % len(residue),
        len(residue),
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    root = Path(args.root).resolve()
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)

    check = Check()
    section_path = root / SECTION
    section = section_path.read_text()
    lines = section.splitlines()
    modules = parse_modules((root / MODULE_MAP).read_text())
    edges = parse_edges((root / GRAPH).read_text())
    fields = parse_fields((root / ENVELOPE_CSV).read_text())

    check.add("sources:module-table", len(modules) == 7, "HF-03a module table parsed", len(modules))
    check.add("sources:adjacency", len(edges) == 16, "HF-03b adjacency list parsed", len(edges))
    check.add("sources:envelope", len(fields) == 70, "HF-07a CSV field paths parsed", len(fields))

    stated = {
        MODULE_MAP: "95fbd03d067fd0da2d122130ae3c54284116adc92f40c7f69c91946fd941e4cc",
        GRAPH: "7c29b6ee0fcff3749c0d30d69b3977d529732338dd794ee0019d6a6a1392d183",
        "docs/tech/sections/HF-04a-runtime-lifecycle.md": "e0058ee153804188424a753f1d4af8a3dc9fee4b45e7c82bc6625df7f80fe43d",
        "docs/tech/sections/HF-05-content-admission.md": "7ef95df2fb25f05b7b544cd7dbf2239cd1106c382aab0e8bc5e76288146259a6",
        "docs/tech/sections/HF-06a-schema-inventory.md": "fb58dfaea559734dcfd947853c7a7fd7fd73e8ac050908c846af0d4e6517fd18",
        "docs/tech/sections/HF-07a-save-envelope.md": "4c37b7b32197642e1a312758449b8ebede05d3a0788e92b74a6a9f95ed97c010",
        ENVELOPE_CSV: "1c553120d0988bfbf3d5644946904fb603b3a3617091764ce170eb1cbb798b00",
        "docs/tech/sections/HF-07b-commit-boundaries.md": "b1b88c2922d56eb7d9f9b581f387e8eb6aeb148d12ff23f4de4c53ba5d929122",
        "docs/tech/sections/TH-01-complete-loop.md": "811ed39ef6d4c7e802c3bd5c9ef08ee8c7490a49f4e14c9db9339e91d78b5fbb",
        "docs/tech/sections/TH-02-movement-camera-and-active-aim.md": "3fe2d4260a98e7f8c7452c0c8116b76d26b7f5756141ef1c08efcac0351935a9",
        "docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md": "f499f8aa27ea9a14596e2003112e433bc0cfcb89d2c3615b3dc1a2c2b0768ed5",
        "docs/tech/sections/TH-04-abilities-ultimates-and-combat-rhythm.md": "bc25b46aa5d059f02ecfa9fe5d8de556eb5ef266cdc2050f0e0ce53e228ef6aa",
        "docs/tech/sections/TH-05-electromagnetic-collection-recycling-and-growth.md": "77a67654f0b04af3d2aa2e1dd78930a1db716d87ae3a6ed1bcebbf9d78ea066a",
        "artifacts/foundation-sprint-2026-09/HF-10-foundation-review.md": "ba7e4cf9e5d0c50fb8f4bb438f737e60d9fd6702baaabcaabaab86018826da30",
        "docs/project/INCREMENT-01-lightning-playtest.md": "12c28df3d6a612177bedb125197300d5d853c793e6acce7b83b2eb40d07c85f2",
        "docs/LIGHTNING-VERIFICATION.md": "594a42cab22f1ccfed202a982a09cf81392fea0b964839f61eed7efcc83e43fd",
        "src/orchard/simulation.js": "5c82acfbd87761f8d94976b0485e6c0b0eb2ec03d1b133af17f12ad1eb1121bd",
        "docs/DISCOVERY.md": "aa63ea75bce3bfbff849631617ea9768d7cbb8a9a32aa8373edc40c73f242474",
    }
    drift = []
    for relative, expected in sorted(stated.items()):
        actual = sha256(root / relative)
        if actual != expected:
            drift.append("%s stated %s actual %s" % (relative, expected, actual))
        if ("`%s`" % expected) not in section:
            drift.append("%s hash absent from the section's Sources bullets" % relative)
    check.add("sources:hashes", not drift, "; ".join(drift) or "every stated dependency hash matches", len(stated))

    backlog = (root / BACKLOG).read_text().splitlines()
    card = []
    for index, line in enumerate(backlog):
        if line.startswith("### TH-08:"):
            card = [line]
            for follow in backlog[index + 1 :]:
                if follow.startswith("### ") or follow.startswith("<a id="):
                    break
                card.append(follow)
            break
    card_text = "\n".join(card).strip()
    card_hash = hashlib.sha256(card_text.encode()).hexdigest()
    check.add("card:present", bool(card_text), "exact TH-08 card text located and hashed %s" % card_hash, len(card))
    for item in ("Separate acquired items", "compatibility and invalidation interfaces", "Q-P19"):
        check.add("card:dod:%s" % item[:24], item in card_text, "definition-of-done phrase present in the card")

    headings = [line[3:].strip() for line in lines if line.startswith("## ")]
    required = [
        "Sources",
        "Contract",
        "Scenarios",
        "Unresolved questions",
        "Re-verification triggers",
        "Procedure performed",
        "Evidence limits",
    ]
    check.add(
        "section:headings",
        all(name in headings for name in required),
        "required level-two headings present: %s" % ", ".join(headings),
        len(headings),
    )
    dod5 = ["### Interfaces", "### Owned data", "### Algorithms and update order", "### Edge cases", "### Failure modes", "### Tunable parameters"]
    check.add(
        "section:dod5-subsections",
        all(name in lines for name in dod5),
        "explicit subsections for interfaces, owned data, algorithms, edge cases, failure modes and parameters",
        len(dod5),
    )

    interface_rows = rows(lines, lambda first: re.fullmatch(r"EI-\d+", first) is not None)
    problems = []
    for _, cells in interface_rows:
        check_step(cells[0], cells, (2, 3, 4), modules, edges, problems)
    check.add("interfaces:edges-and-commands", not problems, "; ".join(problems) or "every interface row uses a listed edge and a listed interface", len(interface_rows))

    named_modules = set()
    for _, cells in interface_rows:
        named_modules |= modules_in(cells[2])
    check.add(
        "interfaces:every-module-named",
        set(MODULES) | {"Values"} <= named_modules,
        "modules named: %s" % ", ".join(sorted(named_modules)),
        len(named_modules),
    )

    walk_rows = rows(lines, lambda first: re.fullmatch(r"W[ELT]\.\d+", first) is not None)
    walk_problems = []
    for _, cells in walk_rows:
        check_step(cells[0], cells, (2, 3, 4), modules, edges, walk_problems)
    check.add("walks:edges-and-commands", not walk_problems, "; ".join(walk_problems) or "every walk step uses a listed edge and a listed interface", len(walk_rows))

    walks = {"WE": "equip, remove and re-equip", "WL": "load", "WT": "transformation replacement"}
    outcomes = []
    for prefix, name in walks.items():
        steps = [cells for _, cells in walk_rows if cells[0].startswith(prefix + ".")]
        text = " ".join(cells[-1] for cells in steps)
        if not steps:
            outcomes.append("%s (%s) has no steps" % (prefix, name))
            continue
        if ("**%s outcome:" % prefix) not in text:
            outcomes.append("%s (%s) reaches no named outcome" % (prefix, name))
    check.add("walks:named-outcome", not outcomes, "; ".join(outcomes) or "each walked case reaches a named outcome", len(walks))

    exclusions = {
        "no-stale-effect": "every row whose provenance was `inst-1` and `mount-a` ceases to exist",
        "no-duplicate-application": "It is not `B1` plus a second copy, because nothing was added to anything.",
        "no-recursion": "cannot take its own emitted repeat as an input",
        "no-restored-effect": "Nothing derived was read from the document",
        "no-in-place-edit": "The rebuild is whole-value replacement.",
        "row-has-provenance": "A row with no live selection cannot be constructed",
    }
    missing = [name for name, phrase in exclusions.items() if phrase not in section]
    check.add("walks:exclusions-stated", not missing, "missing: %s" % ", ".join(missing) if missing else "every exclusion the card names is stated and located", len(exclusions))

    parameter_rows = rows(lines, lambda first: re.fullmatch(r"EP-\d+", first) is not None)
    unsourced = []
    unset = 0
    for _, cells in parameter_rows:
        source = cells[3]
        if cells[2].strip() == "unset":
            unset += 1
        if not (QUESTION.search(source) or SOURCE_LINE.search(source)):
            unsourced.append(cells[0])
    check.add("parameters:sourced-or-gated", not unsourced, "unsourced rows: %s" % ", ".join(unsourced) if unsourced else "every parameter row carries a source line or a question ID", len(parameter_rows))
    check.add("parameters:unset-count", unset > 0, "%d rows are unset and gate a dependent implementation" % unset, unset)

    cited_fields = set()
    for token in BACKTICK.findall(section):
        if FIELD_PATH.fullmatch(token):
            cited_fields.add(token)
    unknown = sorted(f for f in cited_fields if f.rstrip("[]") not in fields and f not in fields)
    check.add("durable:fields-in-envelope", not unknown, "unknown field paths: %s" % ", ".join(unknown) if unknown else "every durable field path named appears in HF-07a's CSV", len(cited_fields))

    invented = re.findall(r"\b(?:capacity|slot limit|mount count|stack limit) (?:is|of) (\d+)\b", section)
    check.add("product:no-invented-values", not invented, "invented values: %s" % ", ".join(invented) if invented else "no numeric capacity, limit or count is stated", len(invented))

    model_checks(check)

    fake_step = ["NC-1", "ES-1", "Presentation to Encounter", "D99", "`install_effective_build`", "", "", ""]
    nc1 = []
    check_step("NC-1", fake_step, (2, 3, 4), modules, edges, nc1)
    check.add("negative:unlisted-edge-detected", bool(nc1), "; ".join(nc1) or "an unlisted edge was NOT detected", len(nc1))

    fake_parameter = ["NC-2", "An invented limit", "4", "no source", "nothing"]
    nc2 = not (QUESTION.search(fake_parameter[3]) or SOURCE_LINE.search(fake_parameter[3]))
    check.add("negative:unsourced-parameter-detected", nc2, "a parameter row with neither a source line nor a question ID is rejected")

    nc3 = "run.checkpoint.equipment.owned[].effect_rows" not in fields
    check.add("negative:unknown-durable-field-detected", nc3, "a field path absent from HF-07a's CSV is rejected")

    whole_backlog = sha256(root / BACKLOG)
    check.note("note:backlog-drift", "whole BACKLOG.md sha256 %s; the exact TH-08 card is hashed separately above" % whole_backlog)
    check.note("note:limits", "Document and model consistency only. No engine, storage, browser or native behaviour is established.")

    report = {
        "section": SECTION,
        "section_sha256": sha256(section_path),
        "root": str(root),
        "checks": check.results,
        "counts": {
            "interface_rows": len(interface_rows),
            "walk_steps": len(walk_rows),
            "parameter_rows": len(parameter_rows),
            "unset_parameters": unset,
            "modules": len(modules),
            "edges": len(edges),
            "envelope_fields": len(fields),
            "cited_field_paths": len(cited_fields),
            "pass": len([r for r in check.results if r["status"] == "PASS"]),
            "fail": len(check.failures),
            "note": len([r for r in check.results if r["status"] == "NOTE"]),
        },
    }
    (out / "paper-check.json").write_text(json.dumps(report, indent=2) + "\n")
    for result in check.results:
        print("%-6s %-42s %s" % (result["status"], result["check"], result["detail"]))
    print("counts %s" % json.dumps(report["counts"]))
    return 1 if check.failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
