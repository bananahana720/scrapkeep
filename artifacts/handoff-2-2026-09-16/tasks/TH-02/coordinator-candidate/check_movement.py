#!/usr/bin/env python3
"""Paper check for docs/tech/sections/TH-02-movement-camera-and-active-aim.md.

Usage:  python check_movement.py <repository-root> [--out <directory>]

It checks documents, not engine behaviour. A pass means the section's module,
command, edge, callback, parameter and traced-case claims agree with the
admitted HF-03a module table, the HF-03b adjacency list and the HF-04a callback
families at the checked bytes. It proves nothing about a runtime.
"""

import argparse
import hashlib
import json
import os
import re
import sys

SECTION = "docs/tech/sections/TH-02-movement-camera-and-active-aim.md"
HF03A = "docs/tech/sections/HF-03a-module-map.md"
HF03B = "docs/tech/sections/HF-03b-dependency-graph.md"
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

# HF-04a lines 44-51 name eight default-deny families; C-TICK at line 34 is the
# only gameplay-advancing callback and carries phases P0-P6 (lines 61-67).
CALLBACK_FAMILIES = {
    "F-PROCESS",
    "F-PHYSICS",
    "F-INPUT",
    "F-CONTROL",
    "F-LIFECYCLE",
    "F-SIGNAL",
    "F-ASYNC",
    "F-OTHER",
}
PHASES = {"P0", "P1", "P2", "P3", "P4", "P5", "P6"}

# The one interface row that names the Values type sink rather than a module
# pair; HF-03b lines 36-42 give it seven edges at once.
VALUES_ROW = "MI-25"

TRACED_CASES = ["TC-1", "TC-2", "TC-3", "TC-4"]

BACKTICK = re.compile(r"`([^`]+)`")
HASH_TOKEN = re.compile(r"SHA256\s+`([0-9a-fA-F]{64})`")
LINK_TOKEN = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
REGISTER_ANCHORS = {"BACKLOG.md", "TRACKING.md"}
QUESTION_ID = re.compile(r"\bQ-[A-Z]\d+\b")
SOURCE_LINE = re.compile(r"\blines?\s+\d+")


def read(root, relative):
    with open(os.path.join(root, relative), "r", encoding="utf-8") as handle:
        return handle.read()


def rows(text):
    """Every markdown table row as a list of stripped cells."""
    out = []
    for line in text.split("\n"):
        stripped = line.strip()
        if not stripped.startswith("|") or not stripped.endswith("|"):
            continue
        cells = [cell.strip() for cell in stripped[1:-1].split("|")]
        if all(set(cell) <= set("-: ") for cell in cells):
            continue
        out.append(cells)
    return out


def module_table(root):
    """HF-03a lines 31-37: owner -> its records, commands and results."""
    text = read(root, HF03A)
    start = text.index("### Module table")
    end = text.index("### Record meanings")
    table = {}
    for cells in rows(text[start:end]):
        if len(cells) < 5:
            continue
        name = re.split(r"[.\[]", cells[0])[0].strip()
        if not name or name == "Module":
            continue
        table[name] = {
            "records": set(BACKTICK.findall(cells[1])),
            "commands": set(BACKTICK.findall(cells[3])),
            "results": set(BACKTICK.findall(cells[4])),
        }
    return table


def adjacency(root):
    """HF-03b lines 27-42: edge id -> (from, to)."""
    text = read(root, HF03B)
    edges = {}
    for cells in rows(text):
        if len(cells) < 3 or not re.fullmatch(r"D\d\d", cells[0]):
            continue
        edges[cells[0]] = (cells[1], cells[2])
    return edges


def section_between(text, heading, stop_prefix="\n## "):
    start = text.index(heading)
    rest = text[start + len(heading):]
    end = rest.find(stop_prefix)
    nxt = rest.find("\n### ")
    if nxt != -1 and (end == -1 or nxt < end):
        end = nxt
    return rest if end == -1 else rest[:end]


def split_parts(cell):
    return [part.strip() for part in re.split(r",\s*then\s+|,\s*|\s+then\s+", cell) if part.strip()]


def pair_of(part):
    """'Session to Encounter' -> ('Session', 'Encounter'); 'Encounter' -> local."""
    if " to " in part:
        caller, target = part.split(" to ", 1)
        return caller.strip(), target.strip()
    return part.strip(), part.strip()


def check_access(section_text, modules, edges, table_rows, label, findings, counts):
    """Every module, command and edge of a step table against HF-03a/HF-03b.

    A backticked token is attributed to the row's target. A token that is some
    module's exposed command must be attributed to that module, which is what
    makes a plausible-looking misattribution fail rather than pass.
    """
    command_owner = {}
    for name, entry in modules.items():
        for command in entry["commands"]:
            command_owner.setdefault(command, set()).add(name)
    for cells in table_rows:
        row_id = cells[0]
        callers, edge_cell, interface_cell = cells[2], cells[3], cells[4]
        if row_id == VALUES_ROW:
            counts["values_rows"] += 1
            continue
        parts = split_parts(callers)
        edge_ids = split_parts(edge_cell)
        if len(parts) != len(edge_ids):
            findings.append(
                "%s %s: %d caller parts against %d edge parts" % (label, row_id, len(parts), len(edge_ids))
            )
            continue
        targets = set()
        for part, edge in zip(parts, edge_ids):
            caller, target = pair_of(part)
            targets.add(target)
            counts["module_mentions"] += 2
            for name in (caller, target):
                if name not in modules:
                    findings.append("%s %s: module %r is not in the HF-03a module table" % (label, row_id, name))
            if edge in ("local", "none"):
                counts["local_steps"] += 1
                if caller != target:
                    findings.append("%s %s: %r step names a cross-module pair" % (label, row_id, edge))
                continue
            counts["edge_uses"] += 1
            if edge not in edges:
                findings.append("%s %s: edge %r is not an HF-03b allowed edge" % (label, row_id, edge))
                continue
            source, sink = edges[edge]
            if (source, sink) != (caller, target):
                findings.append(
                    "%s %s: edge %s is %s to %s, used as %s to %s" % (label, row_id, edge, source, sink, caller, target)
                )
        vocabulary = set()
        for target in targets:
            entry = modules.get(target)
            if entry:
                vocabulary |= entry["commands"] | entry["results"] | entry["records"]
        for token in BACKTICK.findall(interface_cell):
            counts["interface_tokens"] += 1
            if token in command_owner:
                counts["commands_checked"] += 1
                if not (command_owner[token] & targets):
                    findings.append(
                        "%s %s: command %r belongs to %s, invoked on %s"
                        % (label, row_id, token, sorted(command_owner[token]), sorted(targets))
                    )
                continue
            if token not in vocabulary:
                findings.append(
                    "%s %s: %r is not a command, published result or owned record of %s"
                    % (label, row_id, token, sorted(targets))
                )
        classes = re.findall(r"\bF-[A-Z]+\b|\bC-TICK\b(?:\s+P\d)?", cells[5])
        if not classes and cells[5].strip() != "any":
            findings.append("%s %s: no callback class named" % (label, row_id))
        for token in classes:
            counts["class_uses"] += 1
            if token.startswith("F-"):
                if token not in CALLBACK_FAMILIES:
                    findings.append("%s %s: %r is not an HF-04a callback family" % (label, row_id, token))
            else:
                phase = token.split()[1] if len(token.split()) > 1 else None
                if phase and phase not in PHASES:
                    findings.append("%s %s: C-TICK phase %r is not P0 to P6" % (label, row_id, phase))


def interface_rows(section_text):
    body = section_between(section_text, "### Interfaces")
    return [cells for cells in rows(body) if re.fullmatch(r"MI-\d\d", cells[0]) and len(cells) >= 7]


def route_rows(section_text):
    body = section_text[section_text.index("## Scenarios"):]
    return [cells for cells in rows(body) if re.fullmatch(r"M[RC]\.\d+", cells[0]) and len(cells) >= 8]


def parameter_rows(section_text):
    body = section_between(section_text, "### Tunable parameters")
    return [cells for cells in rows(body) if re.fullmatch(r"MP-\d\d", cells[0]) and len(cells) >= 5]


def check_parameters(section_text, backlog, findings, counts):
    for cells in parameter_rows(section_text):
        counts["parameter_rows"] += 1
        gate = cells[3]
        questions = QUESTION_ID.findall(gate)
        if not questions and not SOURCE_LINE.search(gate):
            findings.append("parameters %s: neither a source line nor a question ID in %r" % (cells[0], gate))
        for question in questions:
            counts["question_gates"] += 1
            if ('<a id="%s"></a>' % question.lower()) not in backlog:
                findings.append("parameters %s: %s has no BACKLOG.md anchor" % (cells[0], question))


def check_cases(section_text, findings, counts):
    body = section_text[section_text.index("## Scenarios"):]
    declared = {cells[0]: cells for cells in rows(body) if re.fullmatch(r"TC-\d", cells[0]) and len(cells) >= 4}
    used = set()
    for cells in route_rows(section_text):
        used |= set(re.findall(r"\bTC-\d\b", cells[6]))
    for case in TRACED_CASES:
        counts["traced_cases"] += 1
        if case not in declared:
            findings.append("cases %s: no row in the traced-case table" % case)
            continue
        if not declared[case][3]:
            findings.append("cases %s: empty named outcome" % case)
        if case not in used:
            findings.append("cases %s: no route step carries it" % case)
        if not re.search(r"\*\*%s outcome:[^*]+\*\*" % case, body):
            findings.append("cases %s: no bolded named outcome in a route step" % case)


def check_headings(section_text, findings, counts):
    present = {line[3:].strip() for line in section_text.split("\n") if line.startswith("## ")}
    for heading in REQUIRED_HEADINGS:
        counts["headings"] += 1
        if heading not in present:
            findings.append("headings: missing required heading %r" % heading)


def citable(target):
    without = target.split("#")[0].strip()
    if not without or re.match(r"^[a-z][a-z0-9+.-]*:", without, re.I) or without.startswith("//"):
        return None
    if "#" in target and os.path.basename(without) in REGISTER_ANCHORS:
        return None
    return without


def check_hashes(root, section_text, findings, counts):
    """The same binding check:drift applies: nearest preceding path link wins."""
    here = os.path.dirname(os.path.join(root, SECTION))
    in_sources = False
    for line in section_text.split("\n"):
        if line.startswith("## "):
            in_sources = line.strip() == "## Sources"
            continue
        if not in_sources or not line.strip().startswith("- "):
            continue
        link = None
        for match in re.finditer(HASH_TOKEN.pattern + "|" + LINK_TOKEN.pattern, line):
            stated, target = match.group(1), match.group(2)
            if target is not None:
                link = citable(target) or link
                continue
            counts["stated_hashes"] += 1
            if not link:
                findings.append("hashes: %s has no preceding path link" % stated[:12])
                continue
            path = os.path.normpath(os.path.join(here, link))
            try:
                with open(path, "rb") as handle:
                    actual = hashlib.sha256(handle.read()).hexdigest()
            except OSError:
                findings.append("hashes: %s is missing for stated %s" % (link, stated[:12]))
                continue
            if actual != stated.lower():
                findings.append("hashes: %s stated %s actual %s" % (link, stated[:12], actual[:12]))


def gates(root, section_text, modules, edges, backlog):
    findings = []
    counts = {
        "headings": 0,
        "module_mentions": 0,
        "edge_uses": 0,
        "local_steps": 0,
        "values_rows": 0,
        "interface_tokens": 0,
        "commands_checked": 0,
        "class_uses": 0,
        "parameter_rows": 0,
        "question_gates": 0,
        "traced_cases": 0,
        "stated_hashes": 0,
        "interface_rows": 0,
        "route_rows": 0,
    }
    check_headings(section_text, findings, counts)
    interfaces = interface_rows(section_text)
    routes = route_rows(section_text)
    counts["interface_rows"] = len(interfaces)
    counts["route_rows"] = len(routes)
    check_access(section_text, modules, edges, interfaces, "interfaces", findings, counts)
    check_access(section_text, modules, edges, routes, "routes", findings, counts)
    check_parameters(section_text, backlog, findings, counts)
    check_cases(section_text, findings, counts)
    check_hashes(root, section_text, findings, counts)
    return findings, counts


def negative_controls(root, section_text, modules, edges, backlog):
    """Each control removes one gate's subject; the gate must notice."""
    controls = []

    broken = section_text.replace("`resolve_movement`;", "`resolve_movement_fast`;", 1)
    controls.append(("NC-1 unlisted command", broken, "is not a command"))

    broken = re.sub(
        r"(\| MI-07 \|[^\n]*?\| D)07( \|)",
        r"\g<1>06\g<2>",
        section_text,
        count=1,
    )
    controls.append(("NC-2 edge endpoints do not match", broken, "used as"))

    broken = section_text.replace(
        "| MP-28 |",
        "| MP-99 | An invented feel value | 0.35 | none stated | nothing |\n| MP-28 |",
        1,
    )
    controls.append(("NC-3 parameter with neither source nor question", broken, "neither a source line nor a question"))

    results = []
    for name, mutated, expected in controls:
        if mutated == section_text:
            results.append({"control": name, "noticed": False, "reason": "mutation did not apply"})
            continue
        findings, _ = gates(root, mutated, modules, edges, backlog)
        noticed = any(expected in finding for finding in findings)
        results.append({"control": name, "noticed": noticed, "findings": len(findings)})
    return results


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root")
    parser.add_argument("--out", default=None)
    arguments = parser.parse_args()
    root = os.path.abspath(arguments.root)
    out = os.path.abspath(arguments.out) if arguments.out else os.path.dirname(os.path.abspath(__file__))
    os.makedirs(out, exist_ok=True)

    section_text = read(root, SECTION)
    modules = module_table(root)
    edges = adjacency(root)
    backlog = read(root, BACKLOG)

    findings, counts = gates(root, section_text, modules, edges, backlog)
    controls = negative_controls(root, section_text, modules, edges, backlog)
    blind = [control for control in controls if not control["noticed"]]

    report = {
        "section": SECTION,
        "root": root,
        "section_sha256": hashlib.sha256(section_text.encode("utf-8")).hexdigest(),
        "modules_in_hf03a": sorted(modules),
        "edges_in_hf03b": len(edges),
        "counts": counts,
        "findings": findings,
        "negative_controls": controls,
        "result": "pass" if not findings and not blind else "fail",
        "limits": (
            "Document agreement only. It checks this section against the admitted HF-03a module "
            "table, the HF-03b adjacency list, the HF-04a callback families and the BACKLOG question "
            "anchors at the checked bytes. It establishes no engine, browser or hardware behaviour."
        ),
    }
    with open(os.path.join(out, "movement-check.json"), "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")

    for finding in findings:
        print("FINDING " + finding)
    for control in controls:
        print("CONTROL %s noticed=%s" % (control["control"], control["noticed"]))
    print(
        "check_movement %s: %d interface rows, %d route rows, %d module mentions, %d edge uses, "
        "%d local steps, %d commands checked, %d callback classes, %d parameter rows, %d question gates, "
        "%d traced cases, %d stated hashes, %d findings, %d blind controls"
        % (
            report["result"],
            counts["interface_rows"],
            counts["route_rows"],
            counts["module_mentions"],
            counts["edge_uses"],
            counts["local_steps"],
            counts["commands_checked"],
            counts["class_uses"],
            counts["parameter_rows"],
            counts["question_gates"],
            counts["traced_cases"],
            counts["stated_hashes"],
            len(findings),
            len(blind),
        )
    )
    print(report["limits"])
    return 0 if report["result"] == "pass" else 1


if __name__ == "__main__":
    sys.exit(main())
