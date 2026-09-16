#!/usr/bin/env python3
"""Executable paper check for docs/tech/sections/TH-06-encounters-waves-and-enemies.md.

Usage: check_schedule.py <repository-root> [--out <directory>]

It checks the TH-06 section against the admitted bytes it cites: HF-03a's module
table, HF-03b's adjacency list, HF-04a's callback families and phases, HF-07a's
CSV field list and BACKLOG's question anchors. It proves document agreement, not
engine behaviour. Three negative controls remove one gate each so that a passing
run is not a checker that cannot fail.
"""

import argparse
import csv
import hashlib
import json
import pathlib
import re
import sys

SECTION = "docs/tech/sections/TH-06-encounters-waves-and-enemies.md"
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

# Values the browser prototype fixes. Each must stay inside the separation table
# that records why it is not promoted; an occurrence anywhere else would be the
# copying the card forbids.
PROTOTYPE_TOKENS = [
    "8+2",
    "14+4",
    "20+4",
    "14 - workers",
    "two worker windups",
    "three-second",
    "at most four kinds",
]


def read(root, relative):
    return (root / relative).read_text(encoding="utf-8")


def table_rows(text):
    """Every pipe-table body row in the document, as a list of stripped cells."""
    rows = []
    for line in text.split("\n"):
        stripped = line.strip()
        if not stripped.startswith("|") or not stripped.endswith("|"):
            continue
        cells = [cell.strip() for cell in stripped.strip("|").split("|")]
        if all(re.fullmatch(r":?-{2,}:?", cell) for cell in cells):
            continue
        rows.append(cells)
    return rows


def ticked(cell):
    return re.findall(r"`([^`]+)`", cell)


def load_modules(root):
    """HF-03a's module table: module -> the interfaces that module owns."""
    modules = {}
    for cells in table_rows(read(root, HF03A)):
        if len(cells) != 5:
            continue
        name = cells[0].split(".")[0].strip()
        if not re.fullmatch(r"[A-Z][A-Za-z]+", name):
            continue
        interfaces = set(ticked(cells[1])) | set(ticked(cells[3])) | set(ticked(cells[4]))
        if not interfaces:
            continue
        modules[name] = interfaces
    modules["Values"] = set()
    return modules


def load_edges(root):
    edges = {}
    for cells in table_rows(read(root, HF03B)):
        if len(cells) < 4 or not re.fullmatch(r"D\d\d", cells[0]):
            continue
        edges[cells[0]] = (cells[1], cells[2])
    return edges


def load_durable_fields(root):
    with (root / HF07A_CSV).open(encoding="utf-8") as handle:
        return {row["field"] for row in csv.DictReader(handle)}


def load_question_anchors(root):
    return set(re.findall(r'<a id="(q-[ep]\d+)"></a>', read(root, BACKLOG)))


def section_block(text, heading, level=3):
    """The lines of one block, by its exact heading text and heading level."""
    marker = "#" * level + " "
    out, inside = [], False
    for line in text.split("\n"):
        if line.startswith(marker):
            inside = line[len(marker):].strip() == heading
            continue
        if level == 3 and line.startswith("## "):
            inside = False
            continue
        if level == 2 and line.startswith("## "):
            inside = False
            continue
        if inside:
            out.append(line)
    return "\n".join(out)


def modules_in(cell, known):
    # "Every module to Values" names the whole table rather than one caller.
    if "Every module" in cell:
        return sorted(known)
    return [name for name in known if re.search(r"\b" + name + r"\b", cell)]


def run_checks(text, root, modules, edges, durable, anchors):
    fails = []
    counts = {}

    def fail(gate, message):
        fails.append(gate + ": " + message)

    # 1. Required headings.
    present = {m.strip().lower() for m in re.findall(r"^##\s+(.*?)\s*$", text, re.M)}
    for heading in REQUIRED_HEADINGS:
        if heading.lower() not in present:
            fail("headings", "missing required heading " + heading)
    counts["required_headings"] = len(REQUIRED_HEADINGS)

    # 2. Module coverage, both directions.
    named = {name for name in modules if re.search(r"\b" + name + r"\b", text)}
    for name in modules:
        if name not in named:
            fail("modules", "HF-03a module never named: " + name)
    counts["modules_named"] = len(named)

    # 3 and 4. Interface rows: edge legality and interface membership.
    interface_rows = [c for c in table_rows(text) if re.fullmatch(r"EI-\d\d", c[0])]
    counts["interface_rows"] = len(interface_rows)
    if len(interface_rows) < 30:
        fail("interfaces", "expected at least 30 EI rows, found %d" % len(interface_rows))
    used_edges = set()
    for cells in interface_rows:
        rid, operation, route, edge_cell, iface_cell = cells[0], cells[1], cells[2], cells[3], cells[4]
        row_modules = modules_in(route, modules)
        if not row_modules:
            fail("interfaces", rid + " names no HF-03a module in its route cell")
        # Forward direction: every name the route cell uses as a module must be
        # one HF-03a names, so an invented module cannot ride beside a real one.
        for token in re.split(r",\s*then\s+|\s+then\s+|\s+to\s+", route):
            token = token.strip()
            if not token or token == "Every module":
                continue
            if token not in modules:
                fail("modules", rid + " routes through %r, absent from HF-03a's module table" % token)
        row_edges = re.findall(r"D\d\d", edge_cell)
        used_edges.update(row_edges)
        for edge in row_edges:
            if edge not in edges:
                fail("edges", rid + " uses unlisted edge " + edge)
                continue
            source, target = edges[edge]
            if source not in row_modules or target not in row_modules:
                fail(
                    "edges",
                    "%s uses %s (%s to %s) on a route that names %s"
                    % (rid, edge, source, target, ", ".join(row_modules)),
                )
        tokens = [t for t in ticked(iface_cell) if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", t)]
        for token in tokens:
            owners = [name for name, ifaces in modules.items() if token in ifaces]
            if not owners:
                fail("interfaces", rid + " invokes `%s`, absent from every HF-03a row" % token)
            elif not set(owners) & set(row_modules):
                fail(
                    "interfaces",
                    "%s invokes `%s`, owned by %s, on a route that names %s"
                    % (rid, token, "/".join(owners), ", ".join(row_modules)),
                )
    # Scenario steps travel on edges too.
    for cells in table_rows(text):
        if not re.fullmatch(r"W[OVLD]\.\d+", cells[0]):
            continue
        for edge in re.findall(r"D\d\d", " ".join(cells)):
            used_edges.add(edge)
            if edge not in edges:
                fail("edges", cells[0] + " uses unlisted edge " + edge)
    counts["edges_used"] = len(used_edges)

    # 5. Callback classes.
    classes = set()
    for cells in table_rows(text):
        if not re.fullmatch(r"(EI-\d\d|W[OVLD]\.\d+)", cells[0]):
            continue
        for token in re.findall(r"\b(?:F-[A-Z]+|C-TICK)\b", " ".join(cells)):
            classes.add(token)
            if token not in CALLBACK_FAMILIES:
                fail("classes", cells[0] + " names callback class " + token)
    for phase in re.findall(r"\bP[0-9]\b", text):
        if phase not in {"P0", "P1", "P2", "P3", "P4", "P5", "P6"}:
            fail("classes", "unknown tick phase " + phase)
    counts["callback_classes"] = len(classes)

    # 6. Durable field paths.
    paths = set()
    for path in re.findall(r"`((?:run|profile)[a-z_.\[\]]*)`", text):
        paths.add(path.rstrip("."))
    for path in ["`content_revision`", "`generation`"]:
        if path in text:
            paths.add(path.strip("`"))
    for path in sorted(paths):
        if path in {"run", "profile"}:
            continue
        if path not in durable:
            fail("durable", "names durable path `%s`, absent from HF-07a's CSV" % path)
    counts["durable_paths"] = len(paths)

    # 7 and 8. Parameter rows: sourced or gated, and never both questions.
    param_rows = [c for c in table_rows(text) if re.fullmatch(r"ET-\d\d", c[0])]
    counts["parameter_rows"] = len(param_rows)
    if len(param_rows) < 30:
        fail("parameters", "expected at least 30 ET rows, found %d" % len(param_rows))
    for cells in param_rows:
        rid, value, source = cells[0], cells[2], cells[3]
        questions = set(re.findall(r"Q-[EP]\d+", source))
        has_line = bool(re.search(r"line \d+", source))
        if not questions and not has_line:
            fail("parameters", rid + " carries neither a source line nor a question ID")
        if value.strip().startswith("unset") and not questions:
            fail("parameters", rid + " is unset with no question ID")
        if "Q-E10" in questions and "Q-P38" in questions:
            fail("separation", rid + " gates on Q-E10 and Q-P38 in one cell")

    # 8 continued. No gate cell anywhere may name both questions.
    gate_prefixes = (r"SP-\d\d", r"UN-\d\d", r"ET-\d\d", r"AM-\d\d", r"OB-\d\d", r"AV-\d\d", r"RC-\d\d")
    gate_cells = 0
    for cells in table_rows(text):
        if not any(re.fullmatch(p, cells[0]) for p in gate_prefixes):
            continue
        for cell in cells:
            gate_cells += 1
            if "Q-E10" in cell and "Q-P38" in cell:
                fail("separation", cells[0] + " names Q-E10 and Q-P38 in one cell: " + cell[:60])
    counts["gate_cells"] = gate_cells
    sp_rows = [c for c in table_rows(text) if re.fullmatch(r"SP-\d\d", c[0])]
    counts["separation_rows"] = len(sp_rows)
    if len(sp_rows) < 8:
        fail("separation", "expected at least 8 SP rows, found %d" % len(sp_rows))
    for cells in sp_rows:
        decided = [cell for cell in cells[2:4] if cell.strip() not in {"", "—", "-"}]
        if len(decided) != 1:
            fail("separation", cells[0] + " must be decided by exactly one of the two questions")
    for question in ("Q-E10", "Q-P38"):
        if question not in text:
            fail("separation", "the section never names " + question)

    # 9. Question IDs resolve.
    questions = set(re.findall(r"Q-[EP]\d+", text))
    for question in sorted(questions):
        if question.lower() not in anchors:
            fail("questions", question + " resolves to no BACKLOG anchor")
    counts["questions_named"] = len(questions)

    # 10. Walked routes reach a named outcome, and WO carries its gates.
    for walk in ("WO", "WV", "WL", "WD"):
        if not re.search(r"\*\*" + walk + r" outcome: [^*]+\*\*", text):
            fail("walks", walk + " reaches no bolded named outcome")
        steps = [c for c in table_rows(text) if re.fullmatch(walk + r"\.\d+", c[0])]
        counts["walk_" + walk] = len(steps)
        if len(steps) < 5:
            fail("walks", walk + " has fewer than five steps")
    gates = re.findall(r"\*\*GATE \d", text)
    counts["gates_in_WO"] = len(gates)
    if len(gates) != 3:
        fail("walks", "expected three gated Q-E10 choices in WO, found %d" % len(gates))

    # 11. Prototype values appear only where they are identified as prototype
    # evidence: the Sources bullet that records them and the separation table
    # that records why each is not promoted. Anywhere else would be the copying
    # the card forbids.
    prototype = section_block(text, "What the browser prototype's waves establish, and what they do not")
    sources = section_block(text, "Sources", level=2)
    for token in PROTOTYPE_TOKENS:
        outside = text.count(token) - prototype.count(token) - sources.count(token)
        if outside > 0:
            fail("prototype", "value %r appears %d time(s) outside its evidence context" % (token, outside))
        if prototype.count(token) == 0:
            fail("prototype", "value %r is not recorded in the separation table" % token)
    counts["prototype_tokens"] = len(PROTOTYPE_TOKENS)

    # 12. Stated dependency hashes.
    hashes = 0
    for bullet in re.findall(r"^- .*$", text, re.M):
        links = re.findall(r"\[[^\]]*\]\(([^)]+)\)", bullet)
        for match in re.finditer(r"SHA256 `([0-9a-f]{64})`", bullet):
            hashes += 1
            before = [
                link
                for link in links
                if bullet.index("](" + link + ")") < match.start()
                and "#" not in link.split("/")[-1]
            ]
            if not before:
                fail("hashes", "stated hash with no preceding repository link")
                continue
            target = (root / "docs/tech/sections" / before[-1]).resolve()
            if not target.exists():
                fail("hashes", "stated hash names a missing file: " + before[-1])
                continue
            actual = hashlib.sha256(target.read_bytes()).hexdigest()
            if actual != match.group(1):
                fail("hashes", "%s stated %s actual %s" % (before[-1], match.group(1), actual))
    counts["stated_hashes"] = hashes
    if hashes < 10:
        fail("hashes", "expected at least 10 stated dependency hashes, found %d" % hashes)

    return fails, counts


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root")
    parser.add_argument("--out", default=None)
    args = parser.parse_args()
    root = pathlib.Path(args.root).resolve()
    text = read(root, SECTION)
    modules = load_modules(root)
    edges = load_edges(root)
    durable = load_durable_fields(root)
    anchors = load_question_anchors(root)

    fails, counts = run_checks(text, root, modules, edges, durable, anchors)

    controls = []
    mutations = [
        (
            "unlisted-command",
            lambda t: t.replace("`read_committed_results`; `EncounterSnapshot`, `CommittedAttack`, `EncounterResult`, `AimPreview`",
                                "`read_initial_snapshot`; `EncounterSnapshot`", 1),
        ),
        (
            "mismatched-edge",
            lambda t: t.replace(
                "| EI-20 | Present the objective, the wave readout, the arrival cue and the threat cues as published values | Session to Presentation | D06 |",
                "| EI-20 | Present the objective, the wave readout, the arrival cue and the threat cues as published values | Session to Presentation | D09 |",
                1,
            ),
        ),
        (
            "ungated-parameter",
            lambda t: t.replace("| ET-09 | What pressure is measured in and what bounds it | unset | Q-E10 |",
                                "| ET-09 | What pressure is measured in and what bounds it | unset |  |", 1),
        ),
    ]
    for name, mutate in mutations:
        mutated = mutate(text)
        if mutated == text:
            controls.append({"control": name, "detected": False, "reason": "mutation did not apply"})
            continue
        control_fails, _ = run_checks(mutated, root, modules, edges, durable, anchors)
        controls.append(
            {"control": name, "detected": len(control_fails) > len(fails), "findings": control_fails[:3]}
        )

    undetected = [c for c in controls if not c.get("detected")]
    result = {
        "section": SECTION,
        "root": str(root),
        "counts": counts,
        "failures": fails,
        "controls": controls,
        "result": "pass" if not fails and not undetected else "fail",
        "limits": "Document agreement only. No engine, browser or build ran; no arrival, commitment or objective was executed.",
    }
    print(json.dumps(result, indent=2))
    if args.out:
        out = pathlib.Path(args.out).resolve()
        out.mkdir(parents=True, exist_ok=True)
        (out / "paper-check.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    if fails:
        print("FAIL %d finding(s)" % len(fails), file=sys.stderr)
    if undetected:
        print("FAIL %d undetected negative control(s)" % len(undetected), file=sys.stderr)
    return 1 if (fails or undetected) else 0


if __name__ == "__main__":
    sys.exit(main())
