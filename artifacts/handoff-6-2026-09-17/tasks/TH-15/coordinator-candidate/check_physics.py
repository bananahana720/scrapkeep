#!/usr/bin/env python3
"""Paper checks for docs/tech/sections/TH-15-physics-query-contract.md.

Usage: python check_physics.py <repository-root> [--out <directory>]

Checks documents and their stated source identities. It runs no engine, no
build and no browser, and it establishes no runtime behaviour.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import re
import sys

SECTION = "docs/tech/sections/TH-15-physics-query-contract.md"
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

QUERY_COMMANDS = {
    "attach_world",
    "resolve_movement",
    "query_attack",
    "interpret_contacts",
    "detach_world",
}
GATED_QUESTIONS = {"Q-E03", "Q-P21", "Q-P22"}
CALLBACK_FAMILIES = {
    "F-PROCESS",
    "F-PHYSICS",
    "F-INPUT",
    "F-CONTROL",
    "F-LIFECYCLE",
    "F-SIGNAL",
    "F-ASYNC",
    "F-OTHER",
    "C-TICK",
}

BACKTICK = re.compile(r"`([^`]+)`")
HASH_TOKEN = re.compile(r"SHA256\s+`([0-9a-fA-F]{64})`")
LINK_TOKEN = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
SOURCE_OR_QUESTION = re.compile(r"\bline[s]?\s+\d+|\bQ-[EP]\d+\b|TRACKING EV-\d+")
QUESTION_ID = re.compile(r"\bQ-[EP]\d+\b")
# Rule identifiers the two dependency pages use, so a review row must name one.
TH02_RULE = re.compile(r"\b(?:MA|MO|ME|MF|MP|MI)-\d\d\b")
TH03_RULE = re.compile(r"\b(?:AT|AO|DC|EC|EP|FM|TP|PL|EN|CH)-\d+\b")
# `E1 T2 P3 command`, `T0 attach_world`, `Tn P3 resolve_movement`.
SEQ_TOKEN = re.compile(
    r"^(?:(E\d+)\s+)?(?:(T(?:\d+|n|m))\s+)?(?:(P\d)\s+)?([a-z_]+)$"
)


class Report:
    def __init__(self) -> None:
        self.findings: list[dict] = []
        self.counts: dict[str, int] = {}

    def fail(self, check: str, detail: str) -> None:
        self.findings.append({"check": check, "detail": detail})

    def count(self, key: str, value: int) -> None:
        self.counts[key] = value

    @property
    def failed(self) -> bool:
        return bool(self.findings)


def read(root: str, relative: str) -> str:
    with open(os.path.join(root, relative), encoding="utf-8") as handle:
        return handle.read()


def visible_lines(text: str) -> list[str]:
    """Blank fenced blocks so findings keep their line numbers."""
    fenced = False
    out = []
    for line in text.split("\n"):
        if re.match(r"^\s*(```|~~~)", line):
            fenced = not fenced
            out.append("")
            continue
        out.append("" if fenced else line)
    return out


def table_rows(lines: list[str]) -> list[tuple[int, list[str]]]:
    rows = []
    for index, line in enumerate(lines, start=1):
        stripped = line.strip()
        if not stripped.startswith("|") or not stripped.endswith("|"):
            continue
        cells = [cell.strip() for cell in stripped[1:-1].split("|")]
        if all(re.fullmatch(r":?-{2,}:?", cell) for cell in cells if cell):
            continue
        rows.append((index, cells))
    return rows


def rows_with_id(lines: list[str], pattern: str) -> list[tuple[int, list[str]]]:
    return [
        (line_no, cells)
        for line_no, cells in table_rows(lines)
        if cells and re.fullmatch(pattern, cells[0])
    ]


# --- dependency vocabularies -------------------------------------------------


def hf03a_modules(text: str) -> dict[str, dict[str, set[str]]]:
    """Module name -> {records, commands, results} from HF-03a's module table."""
    modules: dict[str, dict[str, set[str]]] = {}
    for _, cells in table_rows(visible_lines(text)):
        if len(cells) != 5:
            continue
        name = cells[0].split(".")[0].strip()
        if not re.fullmatch(r"[A-Z][A-Za-z]+", name):
            continue
        modules[name] = {
            "records": set(BACKTICK.findall(cells[1])),
            "commands": set(BACKTICK.findall(cells[3])),
            "results": set(BACKTICK.findall(cells[4])),
        }
    modules.setdefault("Values", {"records": set(), "commands": set(), "results": set()})
    return modules


def hf03b_edges(text: str) -> dict[str, tuple[str, str]]:
    edges = {}
    for _, cells in table_rows(visible_lines(text)):
        if len(cells) >= 3 and re.fullmatch(r"D\d\d", cells[0]):
            edges[cells[0]] = (cells[1], cells[2])
    return edges


def hf07a_fields(root: str) -> set[str]:
    fields = set()
    with open(os.path.join(root, HF07A_CSV), encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            value = (row.get("field") or "").strip()
            if value:
                fields.add(value)
    return fields


def backlog_anchors(text: str) -> set[str]:
    return {match.upper() for match in re.findall(r'<a id="(q-[ep]\d+)"></a>', text)}


# --- section parsing ---------------------------------------------------------


def split_chain(cell: str) -> list[str]:
    return [part.strip() for part in re.split(r",\s*then\s+", cell) if part.strip()]


def interface_rows(lines: list[str]) -> list[tuple[int, list[str]]]:
    return rows_with_id(lines, r"PI-\d\d")


def walk_rows(lines: list[str]) -> list[tuple[str, list[tuple[int, list[str]]]]]:
    routes: dict[str, list[tuple[int, list[str]]]] = {}
    for line_no, cells in table_rows(lines):
        match = re.fullmatch(r"(QW|QG)\.\d+", cells[0]) if cells else None
        if match:
            routes.setdefault(match.group(1), []).append((line_no, cells))
    return sorted(routes.items())


def fixture_rows(lines: list[str]) -> list[tuple[int, list[str]]]:
    return [
        (line_no, cells)
        for line_no, cells in rows_with_id(lines, r"PX-\d\d")
        if len(cells) == 7
    ]


def review_rows(lines: list[str]) -> dict[str, list[str]]:
    return {
        cells[0]: cells
        for _, cells in rows_with_id(lines, r"PX-\d\d")
        if len(cells) == 4
    }


def parameter_rows(lines: list[str]) -> list[tuple[int, list[str]]]:
    return [
        (line_no, cells)
        for line_no, cells in rows_with_id(lines, r"PP-\d\d")
        if len(cells) == 5
    ]


# --- checks ------------------------------------------------------------------


def check_headings(lines: list[str], report: Report) -> None:
    present = {
        match.group(1).strip().lower()
        for match in (re.match(r"^#{1,6}\s+(.*?)\s*#*\s*$", line) for line in lines)
        if match
    }
    for heading in REQUIRED_HEADINGS:
        if heading.lower() not in present:
            report.fail("headings", f"missing required heading: {heading}")
    report.count("required_headings", len(REQUIRED_HEADINGS))


def check_modules_and_commands(
    lines: list[str], modules: dict, report: Report
) -> None:
    owner_of_command: dict[str, str] = {}
    for name, sets in modules.items():
        for command in sets["commands"]:
            owner_of_command.setdefault(command, name)
    owner_of_value: dict[str, set[str]] = {}
    for name, sets in modules.items():
        for token in sets["records"] | sets["results"]:
            owner_of_value.setdefault(token, set()).add(name)

    named_modules: set[str] = set()
    commands_checked = 0
    for line_no, cells in interface_rows(lines):
        if len(cells) != 8:
            report.fail("interfaces", f"line {line_no}: expected 8 columns")
            continue
        chain = split_chain(cells[2])
        row_modules: set[str] = set()
        for segment in chain:
            for part in re.split(r"\s+to\s+", segment):
                part = part.strip()
                if part in ("every module",):
                    row_modules |= set(modules)
                    continue
                if part not in modules:
                    report.fail(
                        "modules",
                        f"line {line_no}: '{part}' is not a module in HF-03a's table",
                    )
                    continue
                row_modules.add(part)
                named_modules.add(part)
        for token in BACKTICK.findall(cells[4]):
            if token in owner_of_command:
                commands_checked += 1
                owner = owner_of_command[token]
                if owner not in row_modules:
                    report.fail(
                        "commands",
                        f"line {line_no}: `{token}` belongs to {owner}, which this "
                        "row's caller chain does not name",
                    )
            elif token in owner_of_value:
                if not (owner_of_value[token] & row_modules):
                    report.fail(
                        "commands",
                        f"line {line_no}: `{token}` is owned by "
                        f"{sorted(owner_of_value[token])}, not named by this row",
                    )
            else:
                report.fail(
                    "commands",
                    f"line {line_no}: `{token}` is in no HF-03a command, result or "
                    "record list",
                )
    report.count("modules_named", len(named_modules))
    report.count("commands_checked", commands_checked)


def check_edges(lines: list[str], edges: dict, modules: dict, report: Report) -> None:
    checked = 0
    for line_no, cells in interface_rows(lines):
        if len(cells) != 8:
            continue
        callers = split_chain(cells[2])
        edge_parts = split_chain(cells[3])
        if len(callers) != len(edge_parts):
            report.fail(
                "edges",
                f"line {line_no}: {len(callers)} caller segments and "
                f"{len(edge_parts)} edge segments",
            )
            continue
        for caller, edge in zip(callers, edge_parts):
            endpoints = [part.strip() for part in re.split(r"\s+to\s+", caller)]
            range_match = re.fullmatch(r"D(\d\d) to D(\d\d)", edge)
            if edge == "none":
                continue
            if edge == "local":
                if len(endpoints) != 1:
                    report.fail(
                        "edges",
                        f"line {line_no}: a `local` step makes no cross-module call",
                    )
                continue
            if range_match:
                first, last = int(range_match.group(1)), int(range_match.group(2))
                for number in range(first, last + 1):
                    identifier = f"D{number:02d}"
                    checked += 1
                    if identifier not in edges:
                        report.fail(
                            "edges", f"line {line_no}: {identifier} is not an HF-03b edge"
                        )
                    elif edges[identifier][1] != "Values":
                        report.fail(
                            "edges",
                            f"line {line_no}: {identifier} does not target Values",
                        )
                continue
            for identifier in [part.strip() for part in edge.split(",")]:
                if not re.fullmatch(r"D\d\d", identifier):
                    report.fail("edges", f"line {line_no}: '{identifier}' is not an edge")
                    continue
                checked += 1
                if identifier not in edges:
                    report.fail(
                        "edges", f"line {line_no}: {identifier} is not an HF-03b edge"
                    )
                    continue
                source, target = edges[identifier]
                if len(endpoints) != 2:
                    report.fail(
                        "edges",
                        f"line {line_no}: {identifier} used without two endpoints",
                    )
                    continue
                if endpoints[0] != "every module" and endpoints[0] != source:
                    report.fail(
                        "edges",
                        f"line {line_no}: {identifier} is From {source}, row says "
                        f"{endpoints[0]}",
                    )
                if endpoints[1] != target:
                    report.fail(
                        "edges",
                        f"line {line_no}: {identifier} is To {target}, row says "
                        f"{endpoints[1]}",
                    )
    report.count("edge_uses_checked", checked)


def check_query_and_diagnostic_edges(lines: list[str], report: Report) -> None:
    """Gameplay queries travel on D07 only; D02 rows name no query command.

    The D02 assertion is made directly rather than derived from the backticks
    inside HF-03b's negative clause, which HF-10 note N-04(e) records as a
    sensitivity limit of the retained HF-03b checker.
    """
    d02_rows = 0
    d07_rows = 0
    candidates = list(interface_rows(lines))
    for _, cells in walk_rows(lines):
        candidates.extend(cells)
    for line_no, cells in candidates:
        joined = " | ".join(cells)
        edge_cell = next(
            (cell for cell in cells if re.search(r"\bD\d\d\b|\blocal\b|\bnone\b", cell)),
            "",
        )
        named = {token for token in BACKTICK.findall(joined) if token in QUERY_COMMANDS}
        if "D02" in edge_cell:
            d02_rows += 1
            if named:
                report.fail(
                    "d02",
                    f"line {line_no}: D02 row names gameplay query {sorted(named)}",
                )
        if named:
            d07_rows += 1
            if "D07" not in edge_cell:
                report.fail(
                    "d07",
                    f"line {line_no}: gameplay query {sorted(named)} without D07",
                )
    report.count("d02_rows", d02_rows)
    report.count("query_rows", d07_rows)


def check_callback_classes(lines: list[str], report: Report) -> None:
    checked = 0
    rows = list(interface_rows(lines))
    class_index = 5
    for line_no, cells in rows:
        if len(cells) != 8:
            continue
        checked += 1
        for token in re.split(r",\s*then\s+|,\s*", cells[class_index]):
            token = token.strip()
            if not token:
                continue
            head = token.split()[0]
            if head in CALLBACK_FAMILIES:
                continue
            if re.fullmatch(r"P\d", head):
                continue
            if head in ("all", "any", "between"):
                continue
            report.fail(
                "classes",
                f"line {line_no}: '{token}' is not an HF-04a family or a C-TICK phase",
            )
    report.count("class_rows", checked)


def check_parameters(lines: list[str], anchors: set[str], report: Report) -> None:
    rows = parameter_rows(lines)
    for line_no, cells in rows:
        source = cells[3]
        if not SOURCE_OR_QUESTION.search(source):
            report.fail(
                "parameters",
                f"line {line_no}: {cells[0]} has neither a source line nor a question",
            )
        questions = set(QUESTION_ID.findall(source))
        for question in questions:
            if question not in anchors:
                report.fail(
                    "parameters",
                    f"line {line_no}: {question} has no BACKLOG.md anchor",
                )
        if questions & GATED_QUESTIONS and not cells[2].startswith("unset"):
            report.fail(
                "parameters",
                f"line {line_no}: {cells[0]} is gated on "
                f"{sorted(questions & GATED_QUESTIONS)} but states "
                f"'{cells[2]}'",
            )
    report.count("parameter_rows", len(rows))
    if len(rows) < 20:
        report.fail("parameters", f"only {len(rows)} parameter rows found")


def check_no_durable_field(text: str, fields: set[str], report: Report) -> None:
    """No field of HF-07a's closed surface is named here.

    A dotted path is matched as plain text. The six bare envelope keys are
    ordinary English words, so they are matched only as backticked tokens,
    which is how a section would name a field rather than use the word.
    """
    backticked = set(BACKTICK.findall(text))
    for field in sorted(fields):
        if "." in field:
            if field in text:
                report.fail("durable", f"names durable field path '{field}'")
        elif field in backticked:
            report.fail("durable", f"names durable envelope key `{field}`")
    report.count("durable_fields_scanned", len(fields))


def parse_sequence(cell: str) -> list[tuple[str, str, str]]:
    """Return [(tick key, phase, command)] in listed order."""
    steps = []
    for raw in re.split(r"→|->", cell):
        token = raw.strip().strip("`").strip()
        if not token:
            continue
        token = token.replace("`", "")
        match = SEQ_TOKEN.fullmatch(token)
        if not match:
            steps.append(("?", "?", token))
            continue
        encounter, tick, phase, command = match.groups()
        steps.append(((encounter or "") + "/" + (tick or ""), phase or "", command))
    return steps


def check_fixtures(lines: list[str], report: Report) -> None:
    fixtures = fixture_rows(lines)
    reviews = review_rows(lines)
    order_checks = 0
    for line_no, cells in fixtures:
        identifier, _family, setup, inputs, sequence, expected, status = cells
        for label, value in (
            ("setup", setup),
            ("inputs", inputs),
            ("query sequence", sequence),
            ("expected observation", expected),
        ):
            if len(value) < 20:
                report.fail(
                    "fixtures", f"line {line_no}: {identifier} has no {label}"
                )
        if status.strip() != "unexecuted":
            report.fail(
                "fixtures",
                f"line {line_no}: {identifier} status is '{status}', not 'unexecuted'",
            )
        review = reviews.get(identifier)
        if not review:
            report.fail("fixtures", f"{identifier} has no row in the review table")
        else:
            for column, page, pattern in (
                (1, "TH-02", TH02_RULE),
                (2, "TH-03", TH03_RULE),
            ):
                if not pattern.search(review[column]):
                    report.fail(
                        "fixtures",
                        f"{identifier} names no {page} rule in the review table",
                    )
                if "line" not in review[column]:
                    report.fail(
                        "fixtures",
                        f"{identifier} cites no {page} line in the review table",
                    )
        steps = parse_sequence(sequence)
        if not steps:
            report.fail("fixtures", f"{identifier} has an unparsable query sequence")
            continue
        for tick, phase, command in steps:
            if command in ("resolve_movement", "interpret_contacts") and phase != "P3":
                report.fail(
                    "order",
                    f"{identifier}: {command} labelled '{phase or 'no phase'}', not P3",
                )
            if command == "query_attack" and phase != "P4":
                report.fail(
                    "order",
                    f"{identifier}: query_attack labelled '{phase or 'no phase'}', "
                    "not P4",
                )
            if command in ("attach_world", "detach_world") and phase:
                report.fail(
                    "order",
                    f"{identifier}: {command} carries phase {phase}; it is a "
                    "lifecycle boundary",
                )
            if command not in QUERY_COMMANDS:
                report.fail(
                    "order", f"{identifier}: '{command}' is not a collision interface"
                )
        ticks: dict[str, list[tuple[int, str]]] = {}
        for index, (tick, _phase, command) in enumerate(steps):
            ticks.setdefault(tick, []).append((index, command))
        for tick, entries in ticks.items():
            attacks = [i for i, command in entries if command == "query_attack"]
            movements = [i for i, command in entries if command == "resolve_movement"]
            if not attacks:
                continue
            order_checks += 1
            if not movements:
                report.fail(
                    "order",
                    f"{identifier} tick {tick}: query_attack with no resolve_movement "
                    "in the same tick",
                )
                continue
            if min(attacks) < max(movements):
                report.fail(
                    "order",
                    f"{identifier} tick {tick}: query_attack at step {min(attacks)} "
                    f"precedes resolve_movement at step {max(movements)}",
                )
    report.count("fixtures", len(fixtures))
    report.count("fixture_tick_order_checks", order_checks)
    if len(fixtures) < 4:
        report.fail("fixtures", f"only {len(fixtures)} fixtures found")


def check_walks(lines: list[str], report: Report) -> None:
    routes = walk_rows(lines)
    outcomes: set[str] = set()
    steps_checked = 0
    for name, rows in routes:
        first_movement = None
        first_attack = None
        for position, (line_no, cells) in enumerate(rows):
            if len(cells) != 8:
                report.fail("walks", f"line {line_no}: expected 8 columns")
                continue
            steps_checked += 1
            joined = " | ".join(cells)
            classes = cells[5]
            gate = cells[7]
            if "line" not in gate:
                report.fail(
                    "walks",
                    f"line {line_no}: step {cells[0]} cites no source line in its gate",
                )
            if not re.search(r"[Gg]ate", gate):
                report.fail(
                    "walks", f"line {line_no}: step {cells[0]} states no gate"
                )
            named = {t for t in BACKTICK.findall(joined) if t in QUERY_COMMANDS}
            if {"resolve_movement", "interpret_contacts"} & named and "P3" not in classes:
                report.fail(
                    "walks",
                    f"line {line_no}: {sorted(named)} outside a P3 class '{classes}'",
                )
            if "query_attack" in named and "P4" not in classes:
                report.fail(
                    "walks",
                    f"line {line_no}: query_attack outside a P4 class '{classes}'",
                )
            if {"attach_world", "detach_world"} & named and "F-LIFECYCLE" not in classes:
                report.fail(
                    "walks",
                    f"line {line_no}: world binding outside F-LIFECYCLE '{classes}'",
                )
            interface_cell = cells[4]
            if "resolve_movement" in interface_cell and "query_attack" in interface_cell:
                if interface_cell.index("query_attack") < interface_cell.index(
                    "resolve_movement"
                ):
                    report.fail(
                        "walks",
                        f"line {line_no}: query_attack precedes resolve_movement in "
                        "one step",
                    )
            if "resolve_movement" in named and first_movement is None:
                first_movement = position
            if "query_attack" in named and first_attack is None:
                first_attack = position
            for match in re.finditer(r"\*\*(QC-\d) outcome", joined):
                outcomes.add(match.group(1))
        if first_attack is not None:
            if first_movement is None or first_movement > first_attack:
                report.fail(
                    "walks",
                    f"route {name}: an attack query is walked before any movement "
                    "resolution",
                )
    report.count("walk_steps", steps_checked)
    expected_cases = {"QC-1", "QC-2", "QC-3", "QC-4"}
    missing = expected_cases - outcomes
    if missing:
        report.fail("walks", f"traced cases without a bolded outcome: {sorted(missing)}")
    report.count("traced_case_outcomes", len(outcomes))


def check_stated_hashes(root: str, lines: list[str], report: Report) -> None:
    section_dir = os.path.dirname(os.path.join(root, SECTION))
    in_sources = False
    checked = 0
    for line_no, line in enumerate(lines, start=1):
        if line.startswith("## "):
            in_sources = line.strip() == "## Sources"
            continue
        if not in_sources or not line.strip().startswith("-"):
            continue
        link = None
        for token in re.finditer(
            HASH_TOKEN.pattern + "|" + LINK_TOKEN.pattern, line
        ):
            stated, target = token.group(1), token.group(2)
            if target is not None:
                path = target.split("#")[0].strip()
                if (
                    path
                    and not re.match(r"^[a-z][a-z0-9+.-]*:", path)
                    and not (
                        "#" in target
                        and os.path.basename(path) in ("BACKLOG.md", "TRACKING.md")
                    )
                ):
                    link = path
                continue
            checked += 1
            if not link:
                report.fail("hashes", f"line {line_no}: stated hash with no path link")
                continue
            resolved = os.path.normpath(os.path.join(section_dir, link))
            try:
                with open(resolved, "rb") as handle:
                    actual = hashlib.sha256(handle.read()).hexdigest()
            except OSError:
                report.fail("hashes", f"line {line_no}: {link} is missing")
                continue
            if actual != stated.lower():
                report.fail(
                    "hashes",
                    f"line {line_no}: {link} stated {stated.lower()} actual {actual}",
                )
    report.count("stated_hashes", checked)


def run_suite(root: str, text: str, deps: dict) -> Report:
    report = Report()
    lines = visible_lines(text)
    check_headings(lines, report)
    check_modules_and_commands(lines, deps["modules"], report)
    check_edges(lines, deps["edges"], deps["modules"], report)
    check_query_and_diagnostic_edges(lines, report)
    check_callback_classes(lines, report)
    check_parameters(lines, deps["anchors"], report)
    check_no_durable_field(text, deps["fields"], report)
    check_fixtures(lines, report)
    check_walks(lines, report)
    check_stated_hashes(root, lines, report)
    return report


NEGATIVE_CONTROLS = [
    (
        "unlisted command",
        "commands",
        lambda text: text.replace(
            "| PI-12 | Query obstruction and height from the weapon origin against the "
            "post-movement world, provisionally | Encounter to CollisionQueries | D07 | "
            "`query_attack`;",
            "| PI-12 | Query obstruction and height from the weapon origin against the "
            "post-movement world, provisionally | Encounter to CollisionQueries | D07 | "
            "`query_world`;",
            1,
        ),
    ),
    (
        "edge endpoints that do not match",
        "edges",
        lambda text: text.replace(
            "| PI-10 | Resolve movement against the physical world in stable "
            "entity-ID order | Encounter to CollisionQueries | D07 |",
            "| PI-10 | Resolve movement against the physical world in stable "
            "entity-ID order | Encounter to CollisionQueries | D03 |",
            1,
        ),
    ),
    (
        "attack query before movement resolution in a fixture",
        "order",
        lambda text: text.replace(
            "`T1 P3 resolve_movement` → `T1 P3 interpret_contacts` → "
            "`T1 P4 query_attack` → `T2 P3 resolve_movement`",
            "`T1 P4 query_attack` → `T1 P3 resolve_movement` → "
            "`T1 P3 interpret_contacts` → `T2 P3 resolve_movement`",
            1,
        ),
    ),
]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", help="repository root to check")
    parser.add_argument("--out", default=None, help="directory for the receipts")
    arguments = parser.parse_args()

    root = os.path.abspath(arguments.root)
    out = os.path.abspath(arguments.out or os.path.dirname(os.path.abspath(__file__)))
    os.makedirs(out, exist_ok=True)

    text = read(root, SECTION)
    deps = {
        "modules": hf03a_modules(read(root, HF03A)),
        "edges": hf03b_edges(read(root, HF03B)),
        "anchors": backlog_anchors(read(root, BACKLOG)),
        "fields": hf07a_fields(root),
    }
    read(root, HF04A)  # presence of the ordering source is part of the premise

    report = run_suite(root, text, deps)

    controls = []
    for label, expected_check, mutate in NEGATIVE_CONTROLS:
        mutated = mutate(text)
        if mutated == text:
            controls.append(
                {"control": label, "noticed": False, "detail": "mutation did not apply"}
            )
            report.fail("negative-controls", f"{label}: mutation did not apply")
            continue
        mutated_report = run_suite(root, mutated, deps)
        noticed = any(
            finding["check"] == expected_check for finding in mutated_report.findings
        )
        controls.append(
            {
                "control": label,
                "expected_check": expected_check,
                "noticed": noticed,
                "findings": len(mutated_report.findings),
            }
        )
        if not noticed:
            report.fail(
                "negative-controls",
                f"{label}: the {expected_check} gate did not notice the removal",
            )

    result = {
        "section": SECTION,
        "root": root,
        "result": "fail" if report.failed else "pass",
        "counts": report.counts,
        "findings": report.findings,
        "negative_controls": controls,
        "limits": (
            "Paper and source checks only. No engine, build or browser ran; no "
            "fixture was instantiated and no runtime behaviour is established."
        ),
    }
    with open(os.path.join(out, "physics-check.json"), "w", encoding="utf-8") as handle:
        json.dump(result, handle, indent=2, sort_keys=False)
        handle.write("\n")
    with open(os.path.join(out, "physics-check.log"), "w", encoding="utf-8") as handle:
        handle.write(f"check_physics {result['result']}\n")
        for key, value in report.counts.items():
            handle.write(f"  {key}: {value}\n")
        for control in controls:
            handle.write(
                f"  control {control['control']}: "
                f"{'noticed' if control['noticed'] else 'MISSED'}\n"
            )
        for finding in report.findings:
            handle.write(f"  FAIL [{finding['check']}] {finding['detail']}\n")

    print(f"check_physics {result['result']}: {json.dumps(report.counts)}")
    for control in controls:
        print(
            f"  control '{control['control']}': "
            f"{'noticed' if control['noticed'] else 'MISSED'}"
        )
    for finding in report.findings:
        print(f"  FAIL [{finding['check']}] {finding['detail']}")
    return 1 if report.failed else 0


if __name__ == "__main__":
    sys.exit(main())
