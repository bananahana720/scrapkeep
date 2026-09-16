#!/usr/bin/env python3
"""Executable paper check for docs/tech/sections/TH-04-abilities-ultimates-and-combat-rhythm.md.

Usage: python3 check_abilities.py <repository-root> [--out <directory>]

It checks documents, not engine behaviour. A pass means the section's own
tables agree with the admitted HF-03a module table, the HF-03b adjacency list
and its per-edge permitted-use column, HF-04a's callback families, HF-07a's
machine-readable field list and the question register. It proves nothing about
runtime behaviour.
"""

import argparse
import csv
import hashlib
import json
import os
import re
import sys

SECTION = "docs/tech/sections/TH-04-abilities-ultimates-and-combat-rhythm.md"
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

# The card names these six subsections explicitly.
REQUIRED_SUBSECTIONS = [
    "Interfaces",
    "Owned data",
    "Algorithms and update order",
    "Edge cases",
    "Failure modes",
    "Tunable parameters",
]

# CD-07, CC-08 and EL-08 all rest on the envelope carrying no ability value.
FORBIDDEN_DURABLE_TOKENS = ("cooldown", "charge", "window", "activation", "ultimate")

# Persistence writes nothing for an ability, so neither it nor its two edges may
# appear in an interface or scenario row.
FORBIDDEN_IN_ROUTES = ("Persistence", "D04", "D09")

# Q-P11, Q-P13 and Q-P20 must stay open. A conditional re-verification trigger
# ("when Q-P20 is answered") is not an adoption, so the assertion forms below
# exclude a preceding conditional word rather than matching "answered" alone.
OPEN_QUESTIONS = ("Q-P11", "Q-P13", "Q-P20")
ADOPTION = re.compile(
    r"(?P<lead>[^.|\n]{0,70})(?P<id>Q-P11|Q-P13|Q-P20)(?P<gap>[^.|\n]{0,60}?)"
    r"(?P<claim>is resolved|is settled|is answered by|the answer is|adopts the answer|"
    r"adopted as|settled by the answer)",
    re.I,
)
CONDITIONAL = re.compile(
    r"\b(when|until|unless|if|once|after|would|should|at which point|recheck)\b", re.I
)

TICK_PHASE = re.compile(r"^C-TICK P[0-6]$")
FAMILY = re.compile(r"^F-[A-Z]+$")
QUESTION = re.compile(r"Q-[EP]\d{2}")
BACKTICK = re.compile(r"`([^`]+)`")
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
    """HF-03b's adjacency list: D-id -> (from, to, permitted backticked names)."""
    edges = {}
    for line in text.splitlines():
        if not line.startswith("| D"):
            continue
        column = cells(line)
        if len(column) < 4 or not re.fullmatch(r"D\d{2}", column[0]):
            continue
        edges[column[0]] = (column[1], column[2], set(BACKTICK.findall(column[3])))
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


def check_route_row(row_id, number, callers, edge_cell, interface, klass, context,
                    modules, edges, families, known, fail):
    """One interface or scenario step: modules, edges, endpoints, interfaces, class."""
    known_commands, known_results, known_records = known
    module_names = set(modules) | {"Values"}
    pairs = []
    for step in split_steps(callers):
        if " to " in step:
            source, target = [part.strip() for part in step.split(" to ", 1)]
            pairs.append((source, target))
        else:
            pairs.append((step, step))
    for source, target in pairs:
        for module in (source, target):
            if module != "Every module" and module not in module_names:
                fail("modules", "%s line %d: %s is not an HF-03a module" % (row_id, number, module))

    edge_steps = split_steps(edge_cell)
    aligned = len(edge_steps) == len(pairs)
    for index, token in enumerate(edge_steps):
        if token in ("local", "none"):
            if aligned:
                source, target = pairs[index]
                if source != target:
                    fail("edges", "%s line %d: %s step crosses %s to %s"
                         % (row_id, number, token, source, target))
            continue
        if token not in edges:
            fail("edges", "%s line %d: %s is not an HF-03b allowed edge" % (row_id, number, token))
            continue
        if aligned:
            source, target = pairs[index]
            if edges[token][0] != source or edges[token][1] != target:
                fail("edges", "%s line %d: %s is %s to %s, used for %s to %s"
                     % (row_id, number, token, edges[token][0], edges[token][1], source, target))

    targets = {target for _, target in pairs}
    cross_edges = [token for token in edge_steps if token in edges]
    for token in BACKTICK.findall(interface):
        owners, kind = known_commands.get(token), "command"
        if owners is None:
            owners, kind = known_results.get(token), "result"
        if owners is None:
            owners, kind = known_records.get(token), "record"
        if owners is None:
            fail("interfaces", "%s line %d: %s is not an HF-03a command, published result or owned record"
                 % (row_id, number, token))
            continue
        if not (owners & targets):
            fail("interfaces", "%s line %d: %s %s belongs to %s, attributed to %s"
                 % (row_id, number, kind, token, ", ".join(sorted(owners)), ", ".join(sorted(targets))))
            continue
        # HF-10 note N-04(d): the edge's own permitted-use column, not the whole
        # row. Only a single cross-module step binds one command to one edge; a
        # row that chains a cross step and a local step does not.
        if kind == "command" and len(pairs) == 1 and len(cross_edges) == 1:
            permitted = edges[cross_edges[0]][2]
            if permitted and token not in permitted:
                fail("interfaces", "%s line %d: %s is not in %s's permitted-use column"
                     % (row_id, number, token, cross_edges[0]))

    for part in re.split(r",| or |;", klass):
        part = part.strip()
        part = re.sub(r"\s+(request|completion)$", "", part)
        if not part or part in ("any", "all", "Held"):
            continue
        if TICK_PHASE.match(part) or FAMILY.match(part):
            continue
        fail("classes", "%s line %d: %r is not an HF-04a callback family or C-TICK phase"
             % (row_id, number, part))

    joined = " ".join([callers, edge_cell, context])
    for forbidden in FORBIDDEN_IN_ROUTES:
        if re.search(r"\b" + forbidden + r"\b", joined):
            fail("persistence", "%s line %d: names %s, which this contract states is unused"
                 % (row_id, number, forbidden))


def analyse(root, text, modules, edges, families, anchors, fields):
    failures = []
    counts = {}

    def fail(kind, detail):
        failures.append({"check": kind, "detail": detail})

    lines = text.splitlines()

    # 1. Required headings and the card's six named subsections.
    present = {
        match.group(1).strip().lower()
        for match in (re.match(r"^#{1,6}\s+(.*?)\s*#*\s*$", line) for line in lines)
        if match
    }
    for heading in REQUIRED_HEADINGS + REQUIRED_SUBSECTIONS:
        if heading.lower() not in present:
            fail("headings", "missing required heading: " + heading)
    counts["headings"] = len(REQUIRED_HEADINGS) + len(REQUIRED_SUBSECTIONS)

    known_commands, known_results, known_records = {}, {}, {}
    for module, (commands, results, records) in modules.items():
        for command in commands:
            known_commands.setdefault(command, set()).add(module)
        for result in results:
            known_results.setdefault(result, set()).add(module)
        for record in records:
            known_records.setdefault(record, set()).add(module)
    known = (known_commands, known_results, known_records)

    # 2. Interface rows.
    interface_rows = section_rows(text, r"AI-\d+", 8)
    counts["interface_rows"] = len(interface_rows)
    if len(interface_rows) < 30:
        fail("interfaces", "expected the full interface table, found %d rows" % len(interface_rows))
    for number, column in interface_rows:
        row_id, _, callers, edge_cell, interface, klass, _, source = column
        check_route_row(row_id, number, callers, edge_cell, interface, klass, source,
                        modules, edges, families, known, fail)

    for family in ("F-PROCESS", "F-CONTROL", "F-LIFECYCLE", "F-INPUT", "F-SIGNAL"):
        if family not in families:
            fail("classes", family + " is not defined in HF-04a")

    # 3. Scenario steps, same gates plus the case column.
    step_rows = section_rows(text, r"(?:UC|UA|UE)\.\d+", 8)
    counts["scenario_steps"] = len(step_rows)
    if len(step_rows) < 24:
        fail("scenarios", "expected the three walked routes, found %d steps" % len(step_rows))
    for number, column in step_rows:
        row_id, _, callers, edge_cell, interface, klass, case, result = column
        check_route_row(row_id, number, callers, edge_cell, interface, klass, result,
                        modules, edges, families, known, fail)
        if not re.fullmatch(r"TA-[1-4]", case):
            fail("cases", "%s line %d: %r is not one of the four named cases" % (row_id, number, case))

    # 4. Each named case is walked and reaches a bolded named outcome.
    required_words = {
        "TA-1": ("once per applied contribution", "by passing"),
        "TA-2": ("nothing was consumed", "costs nothing"),
        "TA-3": ("one activation, one resolution, one spend",),
        "TA-4": ("opened once and closed once", "nothing durable"),
    }
    for case in ("TA-1", "TA-2", "TA-3", "TA-4"):
        walked = [number for number, column in step_rows if column[6] == case]
        counts["steps_" + case] = len(walked)
        if not walked:
            fail("cases", case + " appears in no walked route step")
        outcome = re.search(r"\*\*" + case + r" outcome: (.+?)\*\*", text, re.S)
        if not outcome:
            fail("cases", case + " reaches no bolded named outcome")
        elif not any(word in outcome.group(1).lower() for word in required_words[case]):
            fail("cases", case + " outcome does not state its once-only or no-idle-progression result")

    # 5. Parameter rows: sourced or gated on a registered question.
    parameter_rows = section_rows(text, r"AP-\d+", 5)
    counts["parameter_rows"] = len(parameter_rows)
    if len(parameter_rows) < 30:
        fail("parameters", "expected the full parameter table, found %d rows" % len(parameter_rows))
    unset = 0
    for number, column in parameter_rows:
        source_cell = column[3]
        has_line = re.search(r"\blines?\s+\d+", source_cell) is not None
        has_event = re.search(r"\bEV-\d{4}\b", source_cell) is not None
        has_question = QUESTION.search(source_cell) is not None
        if not (has_line or has_question or has_event):
            fail("parameters", "%s line %d: neither a source line nor a question ID" % (column[0], number))
        if column[2].strip().lower() == "unset":
            unset += 1
            if not has_question:
                fail("parameters", "%s line %d: unset without a question ID" % (column[0], number))
    counts["unset_parameters"] = unset

    # 6. Every question ID named resolves to a BACKLOG anchor, and none of the
    #    three product questions this card must not decide is treated as answered.
    questions = sorted(set(QUESTION.findall(text)))
    counts["questions"] = len(questions)
    for question in questions:
        if question.lower() not in anchors:
            fail("questions", question + " has no BACKLOG.md anchor")
    for match in ADOPTION.finditer(text):
        if CONDITIONAL.search(match.group("lead") + match.group("gap")):
            continue
        fail("questions", "an open product question reads as adopted: %s %s"
             % (match.group("id"), match.group("claim")))
    unresolved = text.split("## Unresolved questions", 1)
    for question in OPEN_QUESTIONS:
        if len(unresolved) < 2 or question not in unresolved[1]:
            fail("questions", question + " is not carried in the Unresolved questions section")
    for number, column in parameter_rows:
        if any(question in column[3] for question in OPEN_QUESTIONS):
            if column[2].strip().lower() != "unset":
                fail("questions", "%s line %d: a row gated on an open product question states a value"
                     % (column[0], number))

    # 7. Durable field paths exist in HF-07a's CSV, and the CSV carries no
    #    ability value, which is the premise CD-07, CC-08 and EL-08 rest on.
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
                fail("durable", "HF-07a carries %s, so the no-durable-value premise is stale" % field)

    # 8. Stated dependency hashes match the bytes, bound to the nearest preceding
    #    link in the same Sources bullet, as scripts/check-drift.mjs binds them.
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
                    fail("hashes", "%s: stated %s, actual %s"
                         % (path, match.group(1)[:12], actual[:12]))
            else:
                candidate = match.group(2)
                base = os.path.basename(candidate.split("#")[0])
                if "#" in candidate and base in ("BACKLOG.md", "TRACKING.md"):
                    continue
                target = candidate
    counts["stated_hashes"] = stated
    if stated < 11:
        fail("hashes", "expected at least eleven stated dependency hashes, found %d" % stated)

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
    baseline = len(failures)
    mutations = [
        (
            "unlisted-command",
            lambda body: body.replace(
                "| AI-28 | Cancel uncommitted action preparation, O2 | Session to Encounter | D01 | `cancel_prepared` |",
                "| AI-28 | Cancel uncommitted action preparation, O2 | Session to Encounter | D01 | `read_initial_snapshot` |",
                1,
            ),
        ),
        (
            "mismatched-edge",
            lambda body: body.replace(
                "| AI-11 | Query the prepared action's provisional obstruction and height from the weapon origin | Encounter to CollisionQueries | D07 |",
                "| AI-11 | Query the prepared action's provisional obstruction and height from the weapon origin | Encounter to CollisionQueries | D05 |",
                1,
            ),
        ),
        (
            "unsourced-parameter",
            lambda body: body.replace(
                "| AP-21 | Whether an active ultimate may be re-activated | unset | Q-P20 |",
                "| AP-21 | Whether an active ultimate may be re-activated | unset | none |",
                1,
            ),
        ),
    ]
    controls = []
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
    print(json.dumps({"result": report["result"], "counts": counts, "failures": failures},
                     indent=2, sort_keys=True))
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
