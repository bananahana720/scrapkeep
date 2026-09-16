#!/usr/bin/env python3
"""Executable paper check for docs/tech/sections/TH-10-devices-and-one-main-companion.md.

It checks this document against the admitted sibling sections, the HF-03a module
table, the HF-03b adjacency list and its permitted-use column, the HF-07a CSV
field list and TH-08's compatibility and invalidation rows. It proves
cross-document consistency at one base and nothing about runtime behaviour.

Usage: python check_contract.py --root <repository-root> [--out <directory>]
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

SECTION = "docs/tech/sections/TH-10-devices-and-one-main-companion.md"
HF03A = "docs/tech/sections/HF-03a-module-map.md"
HF03B = "docs/tech/sections/HF-03b-dependency-graph.md"
HF07A_CSV = "docs/tech/sections/HF-07a-save-envelope.csv"
TH08 = "docs/tech/sections/TH-08-inventory-equipment-and-transformations.md"
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

MODULES = [
    "Session",
    "Encounter",
    "CollisionQueries",
    "ContentAdmission",
    "Persistence",
    "InputAdapter",
    "Presentation",
]

# Records each module owns, read from HF-03a's table so a `local` step can name
# one without it being mistaken for a command.
OWNED_RECORD_COLUMN = 1
COMMAND_COLUMN = 3
RESULT_COLUMN = 4

WALKS = ["WP", "WR", "WS", "WC"]

# Words that would mean this section chose a product value the card forbids.
FORBIDDEN_VALUE_PATTERNS = [
    (r"\bat most (one|two|three|four|five|\d+) (device|conductor|companion)", "a device cap"),
    (r"\bdevice cap of\b", "a device cap"),
    (r"\b(device|conductor)s? (last|expire) (for )?\d", "a device lifetime"),
    (r"\bcomponent slots? (is|are) \d", "a component model"),
]


def visible_lines(text: str) -> list[str]:
    """Blank fenced blocks so a documented example is not read as a claim."""
    out, fenced = [], False
    for line in text.split("\n"):
        if re.match(r"^\s*(```|~~~)", line):
            fenced = not fenced
            out.append("")
            continue
        out.append("" if fenced else line)
    return out


def table_cells(line: str) -> list[str]:
    if not line.strip().startswith("|"):
        return []
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def backticked(text: str) -> list[str]:
    return re.findall(r"`([^`]+)`", text)


class Check:
    def __init__(self) -> None:
        self.passes = 0
        self.failures: list[str] = []
        self.notes: list[str] = []
        self.counts: dict[str, int] = {}

    def assert_(self, ok: bool, message: str) -> bool:
        if ok:
            self.passes += 1
        else:
            self.failures.append(message)
        return ok

    def note(self, message: str) -> None:
        self.notes.append(message)


def parse_hf03a(root: Path) -> dict[str, dict[str, set[str]]]:
    """Module name -> {records, commands, results} from HF-03a's module table."""
    modules: dict[str, dict[str, set[str]]] = {}
    for line in visible_lines((root / HF03A).read_text(encoding="utf8")):
        cells = table_cells(line)
        if len(cells) < 5:
            continue
        name = cells[0].split(".")[0].strip()
        if name not in MODULES:
            continue
        modules[name] = {
            "records": set(backticked(cells[OWNED_RECORD_COLUMN])),
            "commands": set(backticked(cells[COMMAND_COLUMN])),
            "results": set(backticked(cells[RESULT_COLUMN])),
        }
    return modules


def parse_hf03b(root: Path) -> dict[str, dict[str, object]]:
    """Edge id -> {from, to, permitted} from HF-03b's adjacency rows."""
    edges: dict[str, dict[str, object]] = {}
    for line in visible_lines((root / HF03B).read_text(encoding="utf8")):
        cells = table_cells(line)
        if len(cells) < 5 or not re.fullmatch(r"D\d{2}", cells[0]):
            continue
        edges[cells[0]] = {
            "from": cells[1],
            "to": cells[2],
            "permitted": set(backticked(cells[3])),
        }
    return edges


def parse_csv_fields(root: Path) -> set[str]:
    fields = set()
    for index, line in enumerate((root / HF07A_CSV).read_text(encoding="utf8").split("\n")):
        if index == 0 or not line.strip():
            continue
        fields.add(line.split(",")[0].strip())
    return fields


def parse_th08_rows(root: Path) -> dict[str, str]:
    """TH-08 row id -> the row's full text, for EC and EN rows."""
    rows = {}
    for line in visible_lines((root / TH08).read_text(encoding="utf8")):
        cells = table_cells(line)
        if len(cells) < 2 or not re.fullmatch(r"E[CN]-\d{2}", cells[0]):
            continue
        rows[cells[0]] = " | ".join(cells)
    return rows


def card_text(root: Path) -> str:
    lines = (root / BACKLOG).read_text(encoding="utf8").split("\n")
    start = None
    for index, line in enumerate(lines):
        if line.startswith("### TH-10:"):
            start = index
        elif start is not None and line.startswith("### ") and index > start:
            return "\n".join(lines[start:index])
    return "" if start is None else "\n".join(lines[start:])


def run(root: Path, out: Path) -> Check:
    check = Check()
    section_path = root / SECTION
    text = section_path.read_text(encoding="utf8")
    lines = visible_lines(text)
    body = "\n".join(lines)

    modules = parse_hf03a(root)
    edges = parse_hf03b(root)
    csv_fields = parse_csv_fields(root)
    th08_rows = parse_th08_rows(root)

    check.counts["hf03a_modules"] = len(modules)
    check.counts["hf03b_edges"] = len(edges)
    check.counts["hf07a_csv_fields"] = len(csv_fields)
    check.counts["th08_ec_en_rows"] = len(th08_rows)

    check.assert_(len(modules) == 7, f"HF-03a must yield 7 modules, got {len(modules)}")
    check.assert_(len(edges) == 16, f"HF-03b must yield 16 edges, got {len(edges)}")
    check.assert_(len(csv_fields) == 70, f"HF-07a CSV must have 70 field rows, got {len(csv_fields)}")

    # 1. Required headings.
    present = {
        match.group(1).strip().lower()
        for match in (re.match(r"^#{1,6}\s+(.*?)\s*#*$", line) for line in lines)
        if match
    }
    for heading in REQUIRED_HEADINGS:
        check.assert_(heading.lower() in present, f"missing required heading: {heading}")

    # 2. Every module HF-03a names appears in the section.
    for module in MODULES:
        check.assert_(
            re.search(rf"\b{module}\b", body) is not None,
            f"module not named anywhere in the section: {module}",
        )
    check.assert_("`Values`" in body or "Values" in body, "the Values sink is not named")

    # 3. Interface rows: edge exists, caller/target match, every backticked
    #    interface belongs to the target's HF-03a row AND to the edge's
    #    permitted-use column (HF-10 note N-04 records that HF-03b's own checker
    #    only does the first).
    interface_rows = 0
    edges_used: set[str] = set()
    commands_seen: set[str] = set()
    for line in lines:
        cells = table_cells(line)
        if len(cells) < 8 or not re.fullmatch(r"DI-\d{2}", cells[0]):
            continue
        interface_rows += 1
        route, edge_cell, interface_cell = cells[2], cells[3], cells[4]
        pairs = [part.strip() for part in re.split(r",|\bthen\b", route) if part.strip()]
        edge_ids = re.findall(r"D\d{2}", edge_cell)
        local = "local" in edge_cell
        none = re.search(r"\bnone\b", edge_cell) is not None
        names = backticked(interface_cell)

        if re.search(r"D10 to D16", edge_cell):
            edge_ids = [f"D{index:02d}" for index in range(10, 17)]
        for edge_id in edge_ids:
            if not check.assert_(edge_id in edges, f"{cells[0]}: unlisted edge {edge_id}"):
                continue
            edges_used.add(edge_id)

        # Caller/target agreement for single-edge rows.
        if len(edge_ids) == 1 and edge_ids[0] in edges and not local and not none and len(pairs) == 1:
            edge = edges[edge_ids[0]]
            caller_target = pairs[0]
            if " to " in caller_target:
                caller, target = (part.strip() for part in caller_target.split(" to ", 1))
                check.assert_(
                    edge["from"] == caller and edge["to"] == target,
                    f"{cells[0]}: {edge_ids[0]} is {edge['from']}->{edge['to']}, row says {caller}->{target}",
                )
                for name in names:
                    if name in modules.get(target, {}).get("commands", set()):
                        commands_seen.add(name)
                        check.assert_(
                            name in edge["permitted"],
                            f"{cells[0]}: `{name}` is not in {edge_ids[0]}'s permitted-use column",
                        )
                    elif name in modules.get(target, {}).get("results", set()):
                        pass
                    elif name in modules.get(target, {}).get("records", set()):
                        check.assert_(
                            False,
                            f"{cells[0]}: `{name}` is {target}'s owned record and cannot travel on {edge_ids[0]}",
                        )
        # A local row may only name its own caller's records or commands.
        if local and len(pairs) == 1 and " to " not in pairs[0]:
            owner = pairs[0]
            for name in names:
                if name in modules.get(owner, {}).get("commands", set()):
                    commands_seen.add(name)
                    continue
                if name in modules.get(owner, {}).get("records", set()):
                    continue
                if name in modules.get(owner, {}).get("results", set()):
                    continue
                known = any(
                    name in group
                    for module in modules.values()
                    for group in module.values()
                )
                check.assert_(
                    not known,
                    f"{cells[0]}: local step of {owner} names `{name}`, which belongs to another module",
                )
        # Every backticked name that resembles a command must exist somewhere.
        for name in names:
            if re.fullmatch(r"[a-z_]+", name):
                owner_found = any(
                    name in module["commands"] for module in modules.values()
                )
                check.assert_(
                    owner_found,
                    f"{cells[0]}: `{name}` is not an exposed command of any HF-03a module",
                )
                commands_seen.add(name)
    check.counts["interface_rows"] = interface_rows
    check.counts["edges_used"] = len(edges_used)
    check.counts["commands_invoked"] = len(commands_seen)
    check.assert_(interface_rows >= 20, f"too few interface rows: {interface_rows}")

    # 4. Every edge named anywhere in the document is an HF-03b edge.
    for edge_id in set(re.findall(r"\bD\d{2}\b", body)):
        check.assert_(edge_id in edges, f"document names unlisted edge {edge_id}")

    # 5. Every parameter row carries a source line or a question ID.
    parameter_rows = 0
    sourced = 0
    unset = 0
    for line in lines:
        cells = table_cells(line)
        if len(cells) < 5 or not re.fullmatch(r"DP-\d{2}", cells[0]):
            continue
        parameter_rows += 1
        source = cells[3]
        has_question = re.search(r"Q-[EP]-?\d+|Q-[EP]\d+", source) is not None
        has_line = re.search(r"\bline[s]? \d+", source) is not None
        check.assert_(
            has_question or has_line,
            f"{cells[0]}: neither a source line nor a question ID in {source!r}",
        )
        if cells[2].strip() == "unset":
            unset += 1
            check.assert_(has_question, f"{cells[0]}: unset without a question ID")
        else:
            sourced += 1
            check.assert_(has_line, f"{cells[0]}: a stated value without a source line")
            # DoD 2: caps, recall, lifetime, parts and cross-level persistence are
            # Q-P15 inputs and the naming rule is Q-P29's, so a row gated on either
            # may not also state a value.
            gated = re.search(r"Q-P15|Q-P29", source)
            check.assert_(
                gated is None,
                f"{cells[0]}: states {cells[2]!r} while naming {gated.group(0) if gated else ''}, "
                "which would answer an open product question",
            )
    check.counts["parameter_rows"] = parameter_rows
    check.counts["parameter_rows_sourced"] = sourced
    check.counts["parameter_rows_unset"] = unset
    check.assert_(parameter_rows >= 30, f"too few parameter rows: {parameter_rows}")

    # 6. Every durable field path named appears in HF-07a's CSV.
    field_paths = set(
        name
        for name in re.findall(r"`([a-z_]+(?:\.[a-z_]+|\[\])+)`", body)
        if name.startswith(("run.", "profile.", "preferences."))
    )
    check.counts["durable_fields_named"] = len(field_paths)
    for path in sorted(field_paths):
        # A bare trailing `[]` denotes the elements of the array field row that
        # HF-07a keys without it; both forms resolve to one CSV row.
        candidate = path[:-2] if path.endswith("[]") else path
        check.assert_(
            candidate in csv_fields,
            f"durable field path not in HF-07a's CSV: {path}",
        )

    # 7. Every TH-08 compatibility or invalidation interface named exists there.
    # TH-01, TH-03 and TH-06 also number rows `EC-nn`. An occurrence whose line
    # attributes it to one of those sections is theirs; every other occurrence
    # must be a TH-08 row that exists verbatim there.
    referenced: set[str] = set()
    foreign: set[str] = set()
    for line in lines:
        ids = re.findall(r"\bE[CN]-\d{2}\b", line)
        if not ids:
            continue
        attributed_elsewhere = (
            re.search(r"\bTH-(01|03|06)\b", line) is not None
            and re.search(r"\bTH-08\b", line) is None
        )
        (foreign if attributed_elsewhere else referenced).update(ids)
    check.counts["th08_rows_referenced"] = len(referenced)
    check.counts["foreign_ec_rows_attributed"] = len(foreign)
    for row in sorted(referenced):
        check.assert_(
            row in th08_rows,
            f"names TH-08 row {row}, which does not exist in TH-08",
        )
    # The three target classes and the default-deny outcome must be quoted from
    # TH-08's own rows rather than restated loosely.
    ec01 = th08_rows.get("EC-01", "")
    for token in ("`player`", "`device`", "`companion`"):
        check.assert_(token in ec01, f"TH-08 EC-01 no longer names {token}")
        check.assert_(token in body, f"this section no longer names {token}")
    check.assert_(
        "not eligible" in th08_rows.get("EC-03", "") and "not eligible" in body,
        "the default-deny outcome is not carried from TH-08 EC-03",
    )
    check.assert_(
        "EN-06" in referenced,
        "TH-08 EN-06, the rule that stops a support effect by the same rebuild, is not consumed",
    )

    # 8. The four walked cases each reach a named outcome.
    for walk in WALKS:
        marker = f"**{walk} outcome:"
        check.assert_(marker in text, f"walk {walk} has no named outcome")
        steps = [line for line in lines if re.match(rf"^\|\s*{walk}\.\d+\s*\|", line)]
        check.counts[f"walk_{walk}_steps"] = len(steps)
        check.assert_(len(steps) >= 10, f"walk {walk} has only {len(steps)} steps")
        for step in steps:
            cells = table_cells(step)
            if len(cells) < 6:
                continue
            edge_cell = cells[3]
            ok = (
                "local" in edge_cell
                or re.search(r"\bnone\b", edge_cell)
                or re.findall(r"D\d{2}", edge_cell)
            )
            check.assert_(bool(ok), f"{cells[0]}: no listed edge and not local")
            for edge_id in re.findall(r"D\d{2}", edge_cell):
                check.assert_(edge_id in edges, f"{cells[0]}: unlisted edge {edge_id}")

    # 9. No walk grants a standard revival at a rescue.
    walk_text = "\n".join(
        line for line in lines if re.match(r"^\|\s*W[PRSC]\.\d+\s*\|", line)
    )
    grant = re.search(
        r"(grants?|award(s|ed)?|restor(es|ed)?|refill(s|ed)?|add(s|ed)?)\s+(a\s+|another\s+|the\s+)?"
        r"(second\s+)?(standard\s+)?revival",
        walk_text,
        re.IGNORECASE,
    )
    if grant:
        fragment = walk_text[max(0, grant.start() - 80) : grant.end() + 20]
        negated = re.search(
            r"(never|no branch|cannot|not|nothing here|neither)\b[^.]{0,120}$",
            fragment[: grant.start() - max(0, grant.start() - 80)],
            re.IGNORECASE,
        )
        check.assert_(bool(negated), f"a walk step appears to grant a revival: {fragment!r}")
    else:
        check.passes += 1
    check.assert_(
        "never a second standard revival" in body,
        "the rescue rule is not stated in the section",
    )
    check.assert_(
        "run.lifecycle.revival_spent" in body,
        "the durable revival fact is not named, so the rescue rule is unanchored",
    )

    # 10. No walk states a cap, a lifetime or a component.
    for pattern, what in [
        (r"\bcapacity of \d", "a capacity"),
        (r"\bat most \d", "a cap"),
        (r"\bmaximum of \d", "a cap"),
        (r"\blasts? \d+(\.\d+)? (second|tick)", "a lifetime"),
        (r"\b\d+ components?\b", "a component count"),
    ]:
        hit = re.search(pattern, walk_text, re.IGNORECASE)
        check.assert_(hit is None, f"a walk states {what}: {hit.group(0) if hit else ''!r}")

    # 11. No invented product value anywhere in the contract body.
    for pattern, what in FORBIDDEN_VALUE_PATTERNS:
        hit = re.search(pattern, body, re.IGNORECASE)
        check.assert_(hit is None, f"the section states {what}: {hit.group(0) if hit else ''!r}")

    # 12. Q-P15 and Q-P29 are carried as gates, not answered.
    for question in ("Q-P15", "Q-P29"):
        check.assert_(question in body, f"{question} is not named")
        answered = re.search(
            rf"{question}[^.]{{0,80}}\b(is answered|is settled|the answer is|adopts)\b",
            body,
            re.IGNORECASE,
        )
        check.assert_(answered is None, f"{question} is treated as answered")

    # 13. Stated dependency hashes agree with the bytes at this root.
    stated = 0
    for line in lines:
        if not re.match(r"^\s*[-*]\s+", line):
            continue
        for match in re.finditer(r"\[[^\]]*\]\(([^)#]+)[^)]*\)[^`]{0,400}?SHA256 `([0-9a-f]{64})`", line):
            target, digest = match.group(1), match.group(2)
            if target.endswith(("BACKLOG.md", "TRACKING.md")):
                continue
            path = (section_path.parent / target).resolve()
            if not path.exists():
                check.assert_(False, f"stated hash for a missing path: {target}")
                continue
            actual = hashlib.sha256(path.read_bytes()).hexdigest()
            stated += 1
            check.assert_(
                actual == digest,
                f"stated hash for {target} is {digest}, actual {actual}",
            )
    check.counts["stated_hashes"] = stated
    check.assert_(stated >= 15, f"too few stated dependency hashes: {stated}")

    # 14. The exact card text, separate from whole-register drift (HF-10 N-03).
    card = card_text(root)
    check.assert_(card.strip() != "", "the TH-10 card was not found in BACKLOG.md")
    card_digest = hashlib.sha256(card.encode("utf8")).hexdigest()
    for item in [
        "Define autonomous action ownership, compatible effects and one main assembled companion.",
        "Identify caps, recall, lifetime, parts and cross-level persistence as Q-P15 inputs; rescue cannot add a standard revival.",
        "Name every accessed module and tie all commands, records and events to HF-03 permissions.",
        "Keep chassis-type epithets separate from assembled-instance identity; Q-P29 supplies the selected naming rule.",
    ]:
        check.assert_(item in card, f"the card no longer contains: {item[:48]}...")
    check.note(f"exact TH-10 card sha256 {card_digest}; whole-register drift is not a failure here")

    # 15. Forbidden write scope: the section must not claim to edit shared files.
    for forbidden in ["TRACKING.md", "ORCHESTRATOR.md"]:
        check.assert_(
            f"edited {forbidden}" not in body,
            f"the section claims to have edited {forbidden}",
        )

    return check


def negative_controls(root: Path) -> list[dict[str, object]]:
    """Three controls: each mutation must make a named check fail."""
    controls = []
    section_path = root / SECTION
    original = section_path.read_text(encoding="utf8")

    def trial(name: str, mutate) -> None:
        mutated = mutate(original)
        if mutated == original:
            controls.append({"control": name, "applied": False, "detected": False})
            return
        section_path.write_text(mutated, encoding="utf8")
        try:
            result = run(root, root)
            detected = len(result.failures) > 0
            first = result.failures[0] if result.failures else None
        finally:
            section_path.write_text(original, encoding="utf8")
        controls.append(
            {"control": name, "applied": True, "detected": detected, "first_failure": first}
        )

    trial(
        "unlisted-edge",
        lambda text: text.replace(
            "| DI-08 | Install the rebuilt set as values at the Session-authorized boundary | Session to Encounter | D01 |",
            "| DI-08 | Install the rebuilt set as values at the Session-authorized boundary | Session to Encounter | D99 |",
            1,
        ),
    )
    trial(
        "invented-cap",
        lambda text: text.replace(
            "| DP-18 | Device capacity: how many devices may be present at once | unset |",
            "| DP-18 | Device capacity: how many devices may be present at once | at most 2 |",
            1,
        ),
    )
    trial(
        "unknown-durable-field",
        lambda text: text.replace(
            "`run.checkpoint.companion.chassis_id`, an id-string or null;",
            "`run.checkpoint.companion.instance_name`, an id-string or null;",
            1,
        ),
    )
    return controls


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--out", default=None)
    parser.add_argument("--skip-controls", action="store_true")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    out = Path(args.out).resolve() if args.out else Path(__file__).resolve().parent
    out.mkdir(parents=True, exist_ok=True)

    check = run(root, out)
    controls = [] if args.skip_controls else negative_controls(root)

    controls_ok = all(
        control["detected"] for control in controls if control.get("applied")
    ) and len(controls) == 3 and all(control.get("applied") for control in controls)

    report = {
        "section": SECTION,
        "root": str(root),
        "passes": check.passes,
        "failures": check.failures,
        "notes": check.notes,
        "counts": check.counts,
        "negative_controls": controls,
        "negative_controls_ok": controls_ok,
        "result": "PASS" if not check.failures and controls_ok else "FAIL",
    }
    (out / "paper-check.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf8")
    lines = [
        f"result {report['result']}",
        f"passes {check.passes}",
        f"failures {len(check.failures)}",
    ]
    lines += [f"count {key} {value}" for key, value in sorted(check.counts.items())]
    lines += [f"control {control['control']} detected={control.get('detected')}" for control in controls]
    lines += [f"FAIL {failure}" for failure in check.failures]
    lines += [f"note {note}" for note in check.notes]
    (out / "paper-check.log").write_text("\n".join(lines) + "\n", encoding="utf8")
    print("\n".join(lines))
    return 0 if report["result"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
