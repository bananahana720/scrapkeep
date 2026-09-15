#!/usr/bin/env python3
"""Paper check for docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md.

Usage:
    python3 check_attack.py <repository-root> [--out <directory>]

It reads the TH-03 section and its admitted dependencies from the given
repository root, asserts the contract properties TH-03's definition of done
and verification list name, and runs three negative controls that each remove
one gate so a passing run is not a checker that cannot fail. It reads files
only; it writes its receipt into --out (default: beside this script).

It proves paper consistency between documents. It runs no engine, no build and
no browser, and it establishes no runtime behaviour.
"""

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

SECTION = "docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md"
HF03A = "docs/tech/sections/HF-03a-module-map.md"
HF03B = "docs/tech/sections/HF-03b-dependency-graph.md"
HF04A = "docs/tech/sections/HF-04a-runtime-lifecycle.md"
TH01 = "docs/tech/sections/TH-01-complete-loop.md"
HF10 = "artifacts/foundation-sprint-2026-09/HF-10-foundation-review.md"
ADR0003 = "docs/adr/0003-authoritative-attack-geometry.md"
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

REQUIRED_SUBSECTIONS = [
    "The two attack loops",
    "The committed attack descriptor",
    "Provisional preview and its honesty rule",
    "Interfaces",
    "Owned data",
    "Algorithms and update order",
    "The four descriptor comparisons",
    "Enemy preparation, commitment, execution and recovery",
    "The chaos character's once-only outcome",
    "Edge cases",
    "Failure modes",
    "Tunable parameters",
]

# HF-04a's callback families and C-TICK phases. A class cell must be built from
# these tokens only.
CALLBACK_TOKENS = {
    "C-TICK",
    "P0",
    "P1",
    "P2",
    "P3",
    "P4",
    "P5",
    "P6",
    "F-PROCESS",
    "F-PHYSICS",
    "F-INPUT",
    "F-CONTROL",
    "F-LIFECYCLE",
    "F-SIGNAL",
    "F-ASYNC",
    "F-OTHER",
    "any",
}

MODULE_NAMES = [
    "Session",
    "Encounter",
    "CollisionQueries",
    "ContentAdmission",
    "Persistence",
    "InputAdapter",
    "Presentation",
    "Values",
]

# The descriptor-part vocabulary the section's own table defines. Only these
# tokens are compared between a comparison row's two consumer cells.
DESCRIPTOR_PARTS = {
    "origin",
    "frame",
    "shape",
    "height_band",
    "phase_window",
    "validity",
    "targets",
    "outcome",
    "identity",
}

# Phrases that would mean an open question had been answered here.
SETTLED_PHRASES = [
    "is answered",
    "the answer is",
    "adopts the answer",
    "settled by the answer",
    "we choose",
]

GATED_QUESTIONS = ["Q-P13", "Q-E10", "Q-P25", "Q-P16", "Q-E09"]


class Result:
    def __init__(self):
        self.checks = 0
        self.failures = []

    def check(self, ok, message):
        self.checks += 1
        if not ok:
            self.failures.append(message)
        return ok


def read(root: Path, relative: str) -> str:
    return (root / relative).read_text(encoding="utf-8")


def sha256(root: Path, relative: str) -> str:
    return hashlib.sha256((root / relative).read_bytes()).hexdigest()


def table_rows(text, first_cell_pattern):
    """Return the split cells of every pipe-table row whose first cell matches."""
    rows = []
    for line in text.split("\n"):
        stripped = line.strip()
        if not stripped.startswith("|"):
            continue
        cells = [cell.strip() for cell in stripped.strip("|").split("|")]
        if cells and re.fullmatch(first_cell_pattern, cells[0]):
            rows.append(cells)
    return rows


def backticked(cell):
    return re.findall(r"`([^`]+)`", cell)


def hf03a_modules(text):
    """Module name -> set of exposed commands, from HF-03a's module table."""
    modules = {}
    for cells in table_rows(text, r"(?s).*"):
        if len(cells) != 5:
            continue
        name = cells[0].split(".")[0].strip()
        if name not in MODULE_NAMES:
            continue
        commands = set(backticked(cells[3]))
        published = set(backticked(cells[4]))
        modules[name] = {"commands": commands, "published": published}
    return modules


def hf03b_edges(text):
    """Edge ID -> (from, to, permitted interface names)."""
    edges = {}
    for cells in table_rows(text, r"D\d{2}"):
        if len(cells) < 4:
            continue
        edges[cells[0]] = {
            "from": cells[1],
            "to": cells[2],
            "permitted": set(backticked(cells[3])),
        }
    return edges


def question_anchors(text):
    return set(
        match.upper() for match in re.findall(r'<a id="(q-[ep]\d{2})"></a>', text)
    )


def section_heading_names(text, level):
    prefix = "#" * level + " "
    return [
        line[len(prefix) :].strip()
        for line in text.split("\n")
        if line.startswith(prefix)
    ]


def parse_interfaces(section):
    """Rows of the Interfaces table: AT-nn."""
    rows = []
    for cells in table_rows(section, r"AT-\d{2}"):
        if len(cells) != 8:
            continue
        rows.append(
            {
                "id": cells[0],
                "operation": cells[1],
                "route": cells[2],
                "edges": re.findall(r"D\d{2}", cells[3]) or ([] if "local" in cells[3] or "none" in cells[3] else None),
                "edge_cell": cells[3],
                "interfaces": backticked(cells[4]),
                "classes": cells[5],
                "source": cells[7],
            }
        )
    return rows


def parse_parameters(section):
    rows = []
    for cells in table_rows(section, r"TP-\d{2}"):
        if len(cells) != 5:
            continue
        rows.append({"id": cells[0], "parameter": cells[1], "value": cells[2], "source": cells[3]})
    return rows


def parse_comparisons(section):
    rows = []
    for cells in table_rows(section, r"DC-\d"):
        if len(cells) != 7:
            continue
        rows.append(
            {
                "id": cells[0],
                "case": cells[1],
                "parts": set(token for token in backticked(cells[2]) if token in DESCRIPTOR_PARTS),
                "damage": cells[3],
                "visual": cells[4],
            }
        )
    return rows


def parse_scenarios(section):
    rows = []
    for cells in table_rows(section, r"A[PEC]\.\d+"):
        if len(cells) != 7:
            continue
        rows.append(
            {
                "id": cells[0],
                "route": cells[2],
                "edge_cell": cells[3],
                "interfaces": backticked(cells[4]),
                "classes": cells[5],
            }
        )
    return rows


def route_modules(route_cell):
    """Caller and target module names from a 'X to Y' route cell."""
    found = [name for name in MODULE_NAMES if re.search(r"\b" + name + r"\b", route_cell)]
    return found


def run_checks(root: Path, section_text=None):
    result = Result()
    section = section_text if section_text is not None else read(root, SECTION)
    hf03a = read(root, HF03A)
    hf03b = read(root, HF03B)
    hf04a = read(root, HF04A)
    backlog = read(root, BACKLOG)

    modules = hf03a_modules(hf03a)
    edges = hf03b_edges(hf03b)
    anchors = question_anchors(backlog)

    # 1. Required headings and the card-named subsections.
    headings = section_heading_names(section, 2)
    for required in REQUIRED_HEADINGS:
        result.check(required in headings, f"missing required heading: {required}")
    subsections = section_heading_names(section, 3)
    for required in REQUIRED_SUBSECTIONS:
        result.check(required in subsections, f"missing required subsection: {required}")

    # 2. Dependency hashes stated in Sources match the bytes.
    stated = dict(
        (name, sha256(root, path))
        for name, path in (
            ("HF-03a", HF03A),
            ("HF-03b", HF03B),
            ("HF-04a", HF04A),
            ("TH-01", TH01),
            ("HF-10", HF10),
            ("ADR 0003", ADR0003),
        )
    )
    for name, digest in stated.items():
        result.check(digest in section, f"{name} hash {digest} is not stated in the section")

    interfaces = parse_interfaces(section)
    result.check(len(interfaces) >= 30, f"interface table has only {len(interfaces)} rows")

    scenarios = parse_scenarios(section)
    result.check(len(scenarios) >= 35, f"scenario tables have only {len(scenarios)} steps")

    # 3. Every module named appears in HF-03a's module table.
    named_modules = set()
    for row in interfaces + scenarios:
        named_modules.update(route_modules(row["route"]))
    result.check(named_modules, "no module was named in any route cell")
    for name in sorted(named_modules):
        if name == "Values":
            # HF-03a line 27 defines Values as a type vocabulary, not a module
            # row with owned records, so it is checked against that definition.
            result.check(
                "`Values` means typed command/result" in hf03a,
                "HF-03a does not define Values as a type vocabulary",
            )
            continue
        result.check(name in modules, f"module {name} is absent from HF-03a's module table")

    # 4. Every command or published result belongs to the target module, and
    #    every edge used is an HF-03b allowed edge carrying that interface.
    known_interfaces = set()
    for entry in modules.values():
        known_interfaces |= entry["commands"] | entry["published"]

    for row in interfaces + scenarios:
        used_edges = re.findall(r"D\d{2}", row["edge_cell"])
        is_local = "local" in row["edge_cell"] or "none" in row["edge_cell"]
        result.check(
            bool(used_edges) or is_local,
            f"{row['id']} names neither an edge nor local",
        )
        for edge in used_edges:
            result.check(edge in edges, f"{row['id']} uses unlisted edge {edge}")
        route = route_modules(row["route"])
        if used_edges and route:
            for edge in used_edges:
                if edge not in edges:
                    continue
                if edges[edge]["to"] == "Values":
                    continue
                result.check(
                    edges[edge]["from"] in route,
                    f"{row['id']} edge {edge} From {edges[edge]['from']} is not the caller {route}",
                )
                result.check(
                    edges[edge]["to"] in route,
                    f"{row['id']} edge {edge} To {edges[edge]['to']} is not the target {route}",
                )
        for name in row["interfaces"]:
            if used_edges:
                # N-04(d): a cross-module step's every backticked interface must
                # be permitted on one of the edges the step actually uses, not
                # merely present somewhere in the target's HF-03a row.
                permitted_here = any(
                    edge in edges and name in edges[edge]["permitted"] for edge in used_edges
                )
                result.check(
                    permitted_here,
                    f"{row['id']} uses {name}, which no edge of {used_edges} permits",
                )
            if name not in known_interfaces:
                # Record names and descriptor parts are not module interfaces.
                continue
            owners = [
                module
                for module, entry in modules.items()
                if name in entry["commands"] or name in entry["published"]
            ]
            result.check(
                any(owner in route for owner in owners) or is_local or not route,
                f"{row['id']} invokes {name}, owned by {owners}, outside its route {route}",
            )
            # N-04(d): check the edge's own permitted-use column, not just the row.
            for edge in used_edges:
                if edge in edges and edges[edge]["to"] in owners:
                    result.check(
                        name in edges[edge]["permitted"],
                        f"{row['id']} uses {name} on {edge}, which does not permit it",
                    )

    # 5. No Persistence command and no D04/D09 edge: an attack is not durable.
    for row in interfaces + scenarios:
        used_edges = re.findall(r"D\d{2}", row["edge_cell"])
        result.check(
            "D04" not in used_edges and "D09" not in used_edges,
            f"{row['id']} uses a persistence edge; no attack fact is durable at this base",
        )
        for name in row["interfaces"]:
            result.check(
                name not in modules.get("Persistence", {}).get("commands", set()),
                f"{row['id']} invokes the Persistence command {name}",
            )

    # 6. Callback classes come from HF-04a.
    for row in interfaces + scenarios:
        tokens = [
            token
            for token in re.split(r"[\s,;]+", row["classes"].replace("to", " "))
            if token
        ]
        for token in tokens:
            cleaned = token.strip("().")
            if not cleaned or cleaned in {"request", "completion", "guard", "drain", "phase"}:
                continue
            result.check(
                cleaned in CALLBACK_TOKENS,
                f"{row['id']} uses callback class token {cleaned}, which HF-04a does not define",
            )
            if cleaned.startswith("F-"):
                result.check(
                    cleaned in hf04a,
                    f"{cleaned} does not appear in HF-04a",
                )

    # 7. Every parameter row is sourced or gated on a registered question ID.
    parameters = parse_parameters(section)
    result.check(len(parameters) >= 25, f"parameter table has only {len(parameters)} rows")
    for row in parameters:
        questions = re.findall(r"Q-[EP]\d{2}", row["source"])
        has_source_line = bool(re.search(r"line[s]?\s+\d+", row["source"]))
        result.check(
            bool(questions) or has_source_line,
            f"{row['id']} has neither a source line nor a question ID",
        )
        for question in questions:
            result.check(
                question in anchors,
                f"{row['id']} names {question}, which has no BACKLOG anchor",
            )
        if row["value"].strip() == "unset":
            result.check(
                bool(questions),
                f"{row['id']} is unset but names no question ID",
            )

    # Every question ID anywhere in the section resolves to a BACKLOG anchor.
    for question in sorted(set(re.findall(r"Q-[EP]\d{2}", section))):
        result.check(
            question in anchors,
            f"the section names {question}, which has no BACKLOG anchor",
        )

    # 8. The four descriptor comparisons: both consumers read the same
    #    committed descriptor.
    comparisons = parse_comparisons(section)
    result.check(len(comparisons) == 4, f"expected 4 descriptor comparisons, found {len(comparisons)}")
    required_cases = ["Blocked", "Low", "Tall", "Changed at commit"]
    for index, row in enumerate(comparisons):
        if index < len(required_cases):
            result.check(
                row["case"].startswith(required_cases[index]),
                f"{row['id']} is not the {required_cases[index]} case",
            )
        damage_parts = set(token for token in backticked(row["damage"]) if token in DESCRIPTOR_PARTS)
        visual_parts = set(token for token in backticked(row["visual"]) if token in DESCRIPTOR_PARTS)
        result.check(damage_parts, f"{row['id']} damage consumer names no descriptor part")
        result.check(
            damage_parts == visual_parts,
            f"{row['id']} consumers disagree: damage {sorted(damage_parts)} vs visual {sorted(visual_parts)}",
        )
        result.check(
            row["parts"] <= damage_parts,
            f"{row['id']} deciding parts {sorted(row['parts'])} are not all read by the damage consumer",
        )
        result.check(
            "AttackLedger" in row["damage"],
            f"{row['id']} damage consumer does not read AttackLedger",
        )
        result.check(
            "CommittedAttack" in row["visual"] and "present_committed_result" in row["visual"],
            f"{row['id']} visual consumer does not read CommittedAttack through present_committed_result",
        )
        result.check(
            "identity" in damage_parts,
            f"{row['id']} consumers do not share an identity",
        )

    # 9. No open question is treated as settled.
    lowered = section.lower()
    for question in GATED_QUESTIONS:
        for phrase in SETTLED_PHRASES:
            result.check(
                f"{question.lower()} {phrase}" not in lowered,
                f"{question} is written as {phrase}",
            )
    for question in GATED_QUESTIONS:
        result.check(question in section, f"{question} is not named in the section")

    return result


def negative_controls(root: Path):
    """Each control removes one gate; the checker must notice each removal."""
    section = read(root, SECTION)
    controls = []

    # NC-1: an unlisted command on an existing edge.
    broken = section.replace(
        "| AT-12 | Revalidate the prepared action, then resolve geometry and targets once from the weapon origin | Encounter to CollisionQueries | D07 | `query_attack`; `QueryResult` |",
        "| AT-12 | Revalidate the prepared action, then resolve geometry and targets once from the weapon origin | Encounter to CollisionQueries | D07 | `resolve_attack_here`; `QueryResult` |",
    )
    controls.append(("NC-1 unlisted command", broken, section != broken))

    # NC-2: an edge that is not in HF-03b's adjacency list.
    broken = section.replace("| AT-17 | Present effects, impact feedback, the telegraph and damage display from the same descriptor | Session to Presentation | D06 |", "| AT-17 | Present effects, impact feedback, the telegraph and damage display from the same descriptor | Session to Presentation | D99 |")
    controls.append(("NC-2 unlisted edge", broken, section != broken))

    # NC-3: a descriptor comparison whose two consumers disagree.
    broken = section.replace(
        "`present_committed_result`, `CommittedAttack`: `height_band`, `shape`, `identity`. The telegraph draws the same band, so the player can read that a jump clears it.",
        "`present_committed_result`, `CommittedAttack`: `shape`, `identity`. The telegraph draws a band the renderer picks.",
    )
    controls.append(("NC-3 consumers disagree", broken, section != broken))

    outcomes = []
    for name, text, applied in controls:
        if not applied:
            outcomes.append({"control": name, "applied": False, "detected": False})
            continue
        control_result = run_checks(root, section_text=text)
        outcomes.append(
            {
                "control": name,
                "applied": True,
                "detected": bool(control_result.failures),
                "first_failure": control_result.failures[0] if control_result.failures else None,
            }
        )
    return outcomes


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root", help="repository root to check")
    parser.add_argument("--out", default=None, help="directory for the receipt")
    arguments = parser.parse_args()

    root = Path(arguments.root).resolve()
    out = Path(arguments.out).resolve() if arguments.out else Path(__file__).resolve().parent
    out.mkdir(parents=True, exist_ok=True)

    if not (root / SECTION).is_file():
        print(f"FAIL missing {SECTION} under {root}")
        return 2

    result = run_checks(root)
    controls = negative_controls(root)

    undetected = [control for control in controls if not control["detected"]]
    for failure in result.failures:
        print("FAIL " + failure)
    for control in undetected:
        print(f"FAIL negative control not detected: {control['control']}")

    status = 0 if not result.failures and not undetected else 1
    print(
        f"{'PASS' if status == 0 else 'FAIL'} {result.checks} checks, "
        f"{len(result.failures)} failures, "
        f"{len(controls) - len(undetected)}/{len(controls)} negative controls detected"
    )

    receipt = {
        "root": str(root),
        "section": SECTION,
        "section_sha256": sha256(root, SECTION),
        "dependency_sha256": {
            HF03A: sha256(root, HF03A),
            HF03B: sha256(root, HF03B),
            HF04A: sha256(root, HF04A),
            TH01: sha256(root, TH01),
            HF10: sha256(root, HF10),
            ADR0003: sha256(root, ADR0003),
        },
        "checks": result.checks,
        "failures": result.failures,
        "negative_controls": controls,
        "exit": status,
        "limits": (
            "Paper consistency between documents only. No engine, build, browser "
            "or runtime behaviour is established, and a passing run does not make "
            "any specified ordering rule enforced."
        ),
    }
    (out / "check-attack.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(f"receipt: {out / 'check-attack.json'}")
    return status


if __name__ == "__main__":
    sys.exit(main())
