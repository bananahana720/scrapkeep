#!/usr/bin/env python3
"""Executable paper check for docs/tech/sections/TH-05-electromagnetic-collection-recycling-and-growth.md.

Usage: python3 check_collection.py <repository-root> [--out <directory>]

It checks documents, not engine behaviour. A pass means the section's own
tables agree with the admitted HF-03a module table, the HF-03b adjacency list,
HF-04a's callback families, HF-07a's machine-readable field list and the
question register. It proves nothing about runtime behaviour.
"""

import argparse
import csv
import hashlib
import json
import os
import re
import sys

SECTION = "docs/tech/sections/TH-05-electromagnetic-collection-recycling-and-growth.md"
HF03A = "docs/tech/sections/HF-03a-module-map.md"
HF03B = "docs/tech/sections/HF-03b-dependency-graph.md"
HF04A = "docs/tech/sections/HF-04a-runtime-lifecycle.md"
HF07A_CSV = "docs/tech/sections/HF-07a-save-envelope.csv"
BACKLOG = "BACKLOG.md"

REQUIRED_HEADINGS = [
    "Sources",
    "Contract",
    "Scenarios",
    "Unresolved questions",
    "Re-verification triggers",
    "Procedure performed",
    "Evidence limits",
]

# Field-name substrings that must never appear in the durable envelope while
# CO-07 claims recovered material has no durable projection.
FORBIDDEN_DURABLE_TOKENS = ("material", "scrap", "metal", "collect", "extent", "silhouette")

TICK_PHASE = re.compile(r"^C-TICK P[0-6]$")
FAMILY = re.compile(r"^F-[A-Z]+$")
QUESTION = re.compile(r"Q-[EP]\d{2}")
BACKTICK = re.compile(r"`([^`]+)`")
DPATH = re.compile(r"\bD\d{2}\b")
FIELDPATH = re.compile(r"\b(?:run|profile|preferences)(?:\.[a-z_]+(?:\[\])?)+")
HASH_TOKEN = re.compile(r"SHA256\s+`([0-9a-fA-F]{64})`")
LINK_TOKEN = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
TOKEN = re.compile(HASH_TOKEN.pattern + "|" + LINK_TOKEN.pattern)


def read(root, relative):
    with open(os.path.join(root, relative), encoding="utf-8") as handle:
        return handle.read()


def cells(line):
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def parse_modules(text):
    """HF-03a's module table: module -> (exposed commands, published results, owned records)."""
    modules = {}
    for line in text.splitlines():
        if not line.startswith("| "):
            continue
        column = cells(line)
        if len(column) != 5:
            continue
        name = column[0].split(".")[0].strip()
        if name == "Module" or not re.fullmatch(r"[A-Z][A-Za-z]+", name):
            continue
        modules[name] = (
            set(BACKTICK.findall(column[3])),
            set(BACKTICK.findall(column[4])),
            set(BACKTICK.findall(column[1])),
        )
    return modules


def parse_edges(text):
    """HF-03b's adjacency list: D-id -> (from, to)."""
    edges = {}
    for line in text.splitlines():
        if not line.startswith("| D"):
            continue
        column = cells(line)
        if len(column) < 3 or not re.fullmatch(r"D\d{2}", column[0]):
            continue
        edges[column[0]] = (column[1], column[2])
    return edges


def parse_families(text):
    families = set()
    for line in text.splitlines():
        if line.startswith("| F-") or line.startswith("| C-TICK"):
            families.add(cells(line)[0])
    return families


def parse_question_anchors(text):
    return {anchor.lower() for anchor in re.findall(r'<a id="(q-[ep]\d{2})">', text)}


def section_rows(text, pattern, width):
    """Table rows whose first cell matches <pattern> and which have <width> cells."""
    rows = []
    compiled = re.compile(pattern)
    for number, line in enumerate(text.splitlines(), start=1):
        if not line.startswith("| "):
            continue
        column = cells(line)
        if len(column) != width:
            continue
        if not compiled.fullmatch(column[0]):
            continue
        rows.append((number, column))
    return rows


def split_steps(cell):
    """`A to B, then C` and `A, B` both become an ordered list of segments."""
    parts = re.split(r",\s*then\s+|\s+then\s+|,\s*", cell)
    return [part.strip() for part in parts if part.strip()]


def analyse(root, text, modules, edges, families, anchors, fields):
    failures = []
    counts = {}

    def fail(kind, detail):
        failures.append({"check": kind, "detail": detail})

    lines = text.splitlines()

    # 1. Required headings.
    present = {
        match.group(1).strip().lower()
        for match in (re.match(r"^#{1,6}\s+(.*?)\s*#*\s*$", line) for line in lines)
        if match
    }
    for heading in REQUIRED_HEADINGS:
        if heading.lower() not in present:
            fail("headings", "missing required heading: " + heading)
    counts["headings"] = len(REQUIRED_HEADINGS)

    known_commands = {}
    known_results = {}
    known_records = {}
    for module, (commands, results, records) in modules.items():
        for command in commands:
            known_commands.setdefault(command, set()).add(module)
        for result in results:
            known_results.setdefault(result, set()).add(module)
        for record in records:
            known_records.setdefault(record, set()).add(module)
    # HF-05 line 101 publishes this diagnostic value from ContentAdmission; it
    # is the one named value that is not in an HF-03a cell.
    known_results.setdefault("ContentReferenceFailure", set()).add("ContentAdmission")

    # 2. Interface rows: modules, edges, endpoints, commands, callback classes.
    interface_rows = section_rows(text, r"CI-\d+", 8)
    counts["interface_rows"] = len(interface_rows)
    if len(interface_rows) < 20:
        fail("interfaces", "expected the full interface table, found %d rows" % len(interface_rows))
    module_names = set(modules) | {"Values"}
    seen_modules = set()
    strict_rows = 0
    for number, column in interface_rows:
        row_id, _, callers, edge_cell, interface, klass, _, _ = column
        caller_steps = split_steps(callers)
        edge_steps = split_steps(edge_cell)
        pairs = []
        for step in caller_steps:
            if " to " in step:
                source, target = [part.strip() for part in step.split(" to ", 1)]
                pairs.append((source, target))
                seen_modules.update({source, target})
            else:
                pairs.append((step, step))
                seen_modules.add(step)
        for source, target in pairs:
            for module in (source, target):
                if module != "Every module" and module not in module_names:
                    fail("modules", "%s line %d: %s is not an HF-03a module" % (row_id, number, module))

        # Edge agreement. `D10 to D16` is the Values range and is expanded.
        if edge_steps == ["D10 to D16"]:
            for index in range(10, 17):
                name = "D%02d" % index
                if name not in edges:
                    fail("edges", "%s: %s is not an HF-03b edge" % (row_id, name))
                elif edges[name][1] != "Values":
                    fail("edges", "%s: %s does not target Values" % (row_id, name))
        elif len(edge_steps) == len(pairs):
            for (source, target), token in zip(pairs, edge_steps):
                if token in ("local", "none"):
                    if source != target:
                        fail("edges", "%s line %d: %s step crosses %s to %s" % (row_id, number, token, source, target))
                    continue
                if token not in edges:
                    fail("edges", "%s line %d: %s is not an HF-03b allowed edge" % (row_id, number, token))
                    continue
                if edges[token] != (source, target):
                    fail(
                        "edges",
                        "%s line %d: %s is %s to %s, used for %s to %s"
                        % (row_id, number, token, edges[token][0], edges[token][1], source, target),
                    )
        else:
            for token in edge_steps:
                if token not in ("local", "none") and token not in edges:
                    fail("edges", "%s line %d: %s is not an HF-03b allowed edge" % (row_id, number, token))

        # Command attribution.
        targets = {target for _, target in pairs}
        tokens = BACKTICK.findall(interface)
        single = len(pairs) == 1 and pairs[0][0] != pairs[0][1]
        if single:
            strict_rows += 1
        for token in tokens:
            owners, kind = known_commands.get(token), "command"
            if owners is None:
                owners, kind = known_results.get(token), "result"
            if owners is None:
                owners, kind = known_records.get(token), "record"
            if owners is None:
                fail(
                    "commands",
                    "%s line %d: %s is not an HF-03a command, published result or owned record"
                    % (row_id, number, token),
                )
                continue
            if not (owners & targets):
                fail(
                    "commands",
                    "%s line %d: %s %s belongs to %s, attributed to %s"
                    % (row_id, number, kind, token, ", ".join(sorted(owners)), ", ".join(sorted(targets))),
                )

        # Callback classes.
        for part in re.split(r",| or |;", klass):
            part = part.strip()
            part = re.sub(r"\s+(request|completion|release|held)$", "", part)
            if not part or part in ("any", "all"):
                continue
            if TICK_PHASE.match(part) or FAMILY.match(part):
                continue
            fail("classes", "%s line %d: %r is not an HF-04a callback family or C-TICK phase" % (row_id, number, part))
    counts["strict_interface_rows"] = strict_rows

    missing_modules = set(modules) - seen_modules
    if missing_modules:
        fail("modules", "HF-03a modules never named in the interface table: " + ", ".join(sorted(missing_modules)))

    for family in ("F-PROCESS", "F-CONTROL", "F-LIFECYCLE"):
        if family not in families:
            fail("classes", family + " is not defined in HF-04a")

    # 3. Parameter rows: every row sourced or gated on a registered question.
    parameter_rows = section_rows(text, r"CP-\d+", 5)
    counts["parameter_rows"] = len(parameter_rows)
    if len(parameter_rows) < 20:
        fail("parameters", "expected the full parameter table, found %d rows" % len(parameter_rows))
    for number, column in parameter_rows:
        source_cell = column[3]
        has_line = re.search(r"\blines?\s+\d+", source_cell) is not None
        has_question = QUESTION.search(source_cell) is not None
        if not (has_line or has_question):
            fail("parameters", "%s line %d: neither a source line nor a question ID" % (column[0], number))
        if column[2].strip().lower() == "unset" and not has_question:
            fail("parameters", "%s line %d: unset without a question ID" % (column[0], number))

    # 4. Every question ID named resolves to a BACKLOG anchor.
    questions = sorted(set(QUESTION.findall(text)))
    counts["questions"] = len(questions)
    for question in questions:
        if question.lower() not in anchors:
            fail("questions", question + " has no BACKLOG.md anchor")

    # 5. Durable field paths exist in HF-07a's CSV, and the CSV holds no
    #    material field, which is the premise CO-07 rests on.
    named_fields = sorted(set(FIELDPATH.findall(text)))
    counts["durable_field_paths"] = len(named_fields)
    for path in named_fields:
        candidate = path[:-2] if path.endswith("[]") else path
        if candidate not in fields:
            fail("durable", "%s is not a field path in HF-07a's CSV" % path)
    counts["envelope_fields"] = len(fields)
    for field in fields:
        lowered = field.lower()
        for token in FORBIDDEN_DURABLE_TOKENS:
            if token in lowered:
                fail("durable", "HF-07a carries %s, so CO-07's premise is stale" % field)

    # 6. The three walked cases reach a bolded named outcome, with the
    #    duplicate-progress language the card requires.
    required_words = {
        "TC-1": ("once", "collected twice", "grants nothing"),
        "TC-2": ("once", "duplicates nothing", "not unlocked a second time", "converge"),
        "TC-3": ("no mass sacrifice", "no handling penalty", "no shrink"),
    }
    for case in ("TC-1", "TC-2", "TC-3"):
        in_steps = [
            number
            for number, column in section_rows(text, r"(?:CX|CM)\.\d+", 8)
            if case in column[6]
        ]
        if not in_steps:
            fail("cases", case + " appears in no walked route step")
        outcome = re.search(r"\*\*" + case + r" outcome: (.+?)\*\*", text, re.S)
        if not outcome:
            fail("cases", case + " reaches no bolded named outcome")
        elif not any(word in outcome.group(1).lower() for word in required_words[case]):
            fail("cases", case + " outcome states neither its once-only nor its no-sacrifice result")
        counts["steps_" + case] = len(in_steps)

    # 7. Stated dependency hashes match the bytes, bound to the nearest
    #    preceding link in the same Sources bullet, as check-drift binds them.
    stated = 0
    for line in lines:
        if not line.startswith("- "):
            continue
        target = None
        for match in TOKEN.finditer(line):
            if match.group(1):
                if target is None:
                    fail("hashes", "a stated hash has no preceding link: " + match.group(1)[:12])
                    continue
                path = target.split("#")[0]
                if not path or re.match(r"^[a-z][a-z0-9+.-]*:", path):
                    continue
                resolved = os.path.normpath(os.path.join(root, "docs/tech/sections", path))
                if not os.path.exists(resolved):
                    fail("hashes", "cited path does not exist: " + path)
                    continue
                with open(resolved, "rb") as handle:
                    actual = hashlib.sha256(handle.read()).hexdigest()
                stated += 1
                if actual != match.group(1).lower():
                    fail("hashes", "%s: stated %s, actual %s" % (path, match.group(1)[:12], actual[:12]))
            else:
                candidate = match.group(2)
                base = os.path.basename(candidate.split("#")[0])
                if "#" in candidate and base in ("BACKLOG.md", "TRACKING.md"):
                    continue
                target = candidate
    counts["stated_hashes"] = stated
    if stated < 8:
        fail("hashes", "expected at least eight stated dependency hashes, found %d" % stated)

    return failures, counts


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root")
    parser.add_argument("--out", default=None)
    arguments = parser.parse_args()
    root = os.path.abspath(arguments.root)
    out = os.path.abspath(arguments.out) if arguments.out else os.path.dirname(os.path.abspath(__file__))
    os.makedirs(out, exist_ok=True)

    text = read(root, SECTION)
    modules = parse_modules(read(root, HF03A))
    edges = parse_edges(read(root, HF03B))
    families = parse_families(read(root, HF04A))
    anchors = parse_question_anchors(read(root, BACKLOG))
    with open(os.path.join(root, HF07A_CSV), encoding="utf-8") as handle:
        fields = {row["field"] for row in csv.DictReader(handle)}

    failures, counts = analyse(root, text, modules, edges, families, anchors, fields)

    # Negative controls: each removes one gate and must be noticed.
    controls = []
    baseline = len(failures)
    mutations = [
        (
            "unlisted-command",
            lambda body: body.replace(
                "| CI-16 | Read the encounter's identified committed results | Session to Encounter | D01 | `read_committed_results`;",
                "| CI-16 | Read the encounter's identified committed results | Session to Encounter | D01 | `read_initial_snapshot`;",
                1,
            ),
        ),
        (
            "mismatched-edge",
            lambda body: body.replace(
                "| CI-12 | Interpret the contacts the resolution produced, including the intake contact | Encounter to CollisionQueries | D07 |",
                "| CI-12 | Interpret the contacts the resolution produced, including the intake contact | Encounter to CollisionQueries | D05 |",
                1,
            ),
        ),
        (
            "unsourced-parameter",
            lambda body: body.replace(
                "| CP-32 | Attraction radius, travel rate and capture distance | unset | Q-P10; BIBLE line 509 |",
                "| CP-32 | Attraction radius, travel rate and capture distance | unset | none |",
                1,
            ),
        ),
    ]
    for name, mutate in mutations:
        mutated = mutate(text)
        applied = mutated != text
        found, _ = analyse(root, mutated, modules, edges, families, anchors, fields)
        detected = len(found) > baseline
        controls.append({"control": name, "applied": applied, "detected": detected})
        if not (applied and detected):
            failures.append({"check": "negative-control", "detail": name + " was not detected"})

    counts["controls_detected"] = sum(1 for control in controls if control["detected"])
    report = {
        "section": SECTION,
        "root": root,
        "result": "pass" if not failures else "fail",
        "counts": counts,
        "controls": controls,
        "failures": failures,
        "limits": "Document agreement only. No engine, browser or build ran; a checked ordering rule is not an enforced one.",
    }
    with open(os.path.join(out, "paper-check.json"), "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")
    print(json.dumps({"result": report["result"], "counts": counts, "failures": failures}, indent=2, sort_keys=True))
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
