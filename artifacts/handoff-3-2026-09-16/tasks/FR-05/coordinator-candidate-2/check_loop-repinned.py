#!/usr/bin/env python3
"""TH-01 paper check.

Checks docs/tech/sections/TH-01-complete-loop.md against the admitted HF-03a
module table, the HF-03b adjacency list, the HF-04a callback families and the
BACKLOG question register, at an explicit repository root.

    python check_loop.py <repository-root> [--out <directory>]

It checks documents, not engine behaviour. A passing run is a consistency
result for one file at one base and establishes no runtime.
"""

import argparse
import hashlib
import json
import pathlib
import re
import sys

SECTION = "docs/tech/sections/TH-01-complete-loop.md"
HF03A = "docs/tech/sections/HF-03a-module-map.md"
HF03B = "docs/tech/sections/HF-03b-dependency-graph.md"
HF04A = "docs/tech/sections/HF-04a-runtime-lifecycle.md"
HF07B = "docs/tech/sections/HF-07b-commit-boundaries.md"
HF07A = "docs/tech/sections/HF-07a-save-envelope.md"
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
# The six subsections TH-01 item 4 names by word.
REQUIRED_SUBSECTIONS = [
    "Interfaces",
    "Owned data",
    "Algorithms and update order",
    "Edge cases",
    "Failure modes",
    "Tunable parameters",
]
CALLBACK_FAMILIES = {
    "C-TICK",
    "F-PROCESS",
    "F-PHYSICS",
    "F-INPUT",
    "F-CONTROL",
    "F-LIFECYCLE",
    "F-SIGNAL",
    "F-ASYNC",
    "F-OTHER",
}
# `Values` is a type vocabulary, not a module row: HF-03a line 27, HF-03b line 19.
VALUES_NODE = "Values"
# FR-05 re-pin. Q-P16, Q-E09 and Q-P39 were resolved by Andrew at TRACKING EV-0247 and EV-0250,
# so this section must now read under those recorded answers instead of naming them as gating. The
# questions that remain open keep the original prohibition, and Q-P32 joins them because FR-05 left
# the reduced-motion bound open. Strictness is unchanged: one list still forbids, one still requires.
UNANSWERABLE = ["Q-P12", "Q-P32", "Q-P37"]
ADOPTION_PHRASES = [
    "this section adopts the",
    "the answer to Q-",
    "we select policy",
]
# The recorded answers this section must read under, each as (label, required substrings).
RESOLVED_READINGS = [
    ("EC-05 reads under P1 and Q-E09", ["| EC-05 |", "interruption policy P1", "next durable transition"]),
    ("EC-05 reads under R2", ["| EC-05 |", "revive in place"]),
    ("EC-06 reads under P1 and R2", ["| EC-06 |", "under [Q-P16](../../../BACKLOG.md#q-p16)'s P1", "under R2"]),
    ("EC-08 reads under the abandonment ordering",
     ["| EC-08 |", "abandoning a live run is a defeat", "Two transactions, two generations"]),
    ("the three answers are cited to their events", ["EV-0247", "EV-0250"]),
]


class Report:
    def __init__(self):
        self.checks = 0
        self.failures = []
        self.counts = {}

    def ok(self, condition, message):
        self.checks += 1
        if not condition:
            self.failures.append(message)
        return bool(condition)


def read(root, relative):
    path = pathlib.Path(root) / relative
    if not path.is_file():
        raise SystemExit("missing required file: %s" % relative)
    return path.read_text(encoding="utf-8")


def sha256(root, relative):
    path = pathlib.Path(root) / relative
    return hashlib.sha256(path.read_bytes()).hexdigest()


def table_rows(text):
    """Every Markdown table row as a list of stripped cells."""
    rows = []
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped.startswith("|"):
            continue
        cells = [cell.strip() for cell in stripped.strip("|").split("|")]
        rows.append(cells)
    return rows


def ticked(cell):
    return re.findall(r"`([^`]+)`", cell)


def parse_hf03a(text):
    """Owner name -> {commands, results, records} from the module table."""
    modules = {}
    for cells in table_rows(text):
        if len(cells) != 5:
            continue
        name = re.match(r"([A-Za-z]+)\.", cells[0])
        if not name:
            continue
        module = name.group(1)
        modules[module] = {
            "records": set(ticked(cells[1])),
            "commands": set(ticked(cells[3])),
            "results": set(ticked(cells[4])),
        }
    return modules


def parse_hf03b(text):
    """Edge id -> (from, to) for every D-row of the adjacency list."""
    edges = {}
    for cells in table_rows(text):
        if len(cells) < 4:
            continue
        if not re.fullmatch(r"D\d\d", cells[0]):
            continue
        edges[cells[0]] = (cells[1], cells[2])
    return edges


def split_pairs(cell):
    """'Session to Encounter, then Encounter to CollisionQueries' -> pairs.

    A fragment without ' to ' is a local or engine-driven step and yields
    (caller, None). 'X to A and B' yields one pair per target.
    """
    pairs = []
    for fragment in cell.split(","):
        fragment = fragment.strip()
        for lead in ("then ", "and ", "or "):
            if fragment.startswith(lead):
                fragment = fragment[len(lead):].strip()
        if not fragment:
            continue
        if " to " in fragment:
            caller, _, targets = fragment.partition(" to ")
            for target in targets.split(" and "):
                pairs.append((caller.strip(), target.strip()))
        else:
            pairs.append((fragment, None))
    return pairs


def split_edges(cell):
    tokens = []
    for fragment in cell.split(","):
        fragment = fragment.strip()
        for lead in ("then ", "and "):
            if fragment.startswith(lead):
                fragment = fragment[len(lead):].strip()
        if fragment:
            tokens.append(fragment)
    return tokens


def check_step_rows(report, section, modules, edges):
    """Every interface and scenario row: edge legality and command membership."""
    interface_rows = 0
    scenario_rows = 0
    pair_checks = 0
    token_checks = 0
    strict_rows = 0

    for cells in table_rows(section):
        if not cells:
            continue
        row_id = cells[0]
        if re.fullmatch(r"IF-\d\d", row_id) and len(cells) == 8:
            interface_rows += 1
            caller_cell, edge_cell, iface_cell, class_cell = (
                cells[2],
                cells[3],
                cells[4],
                cells[5],
            )
        elif re.fullmatch(r"R[ST]\.\d+", row_id) and len(cells) == 7:
            scenario_rows += 1
            caller_cell, edge_cell, iface_cell, class_cell = (
                cells[2],
                cells[3],
                cells[4],
                cells[5],
            )
        else:
            continue

        # Two rows are exempt by their own admitted source and are checked
        # explicitly instead of by the generic pair rule.
        if row_id == "IF-33":
            report.ok(
                edge_cell == "none" and "sample_input" in iface_cell,
                "IF-33 must be the engine-driven sampling exemption (HF-03b line 44)",
            )
            report.ok(
                "sample_input" in modules["InputAdapter"]["commands"],
                "IF-33 sample_input must be an InputAdapter command",
            )
            continue
        if row_id == "IF-34":
            for index in range(10, 17):
                edge = "D%d" % index
                report.ok(
                    edges.get(edge, (None, None))[1] == VALUES_NODE,
                    "IF-34 names %s, which must be an edge to Values" % edge,
                )
            continue

        pairs = split_pairs(caller_cell)
        edge_tokens = split_edges(edge_cell)
        if not report.ok(
            len(pairs) == len(edge_tokens),
            "%s names %d caller/target pairs and %d edge tokens"
            % (row_id, len(pairs), len(edge_tokens)),
        ):
            continue

        named_modules = set()
        for (caller, target), edge in zip(pairs, edge_tokens):
            pair_checks += 1
            named_modules.add(caller)
            if target is None:
                report.ok(
                    edge == "local",
                    "%s: a step with no target must use edge `local`, not %s"
                    % (row_id, edge),
                )
                report.ok(
                    caller in modules,
                    "%s: local caller %s is not an HF-03a module" % (row_id, caller),
                )
                continue
            named_modules.add(target)
            report.ok(
                caller in modules,
                "%s: caller %s is not an HF-03a module" % (row_id, caller),
            )
            report.ok(
                target in modules or target == VALUES_NODE,
                "%s: target %s is not an HF-03a module" % (row_id, target),
            )
            if not report.ok(
                edge in edges, "%s: %s is not an HF-03b allowed edge" % (row_id, edge)
            ):
                continue
            source, destination = edges[edge]
            report.ok(
                source == caller and destination == target,
                "%s: edge %s is %s to %s, not %s to %s"
                % (row_id, edge, source, destination, caller, target),
            )

        # Strict membership for a single-pair row: a token must belong to the
        # target module (or to the caller for a local step).
        allowed = set()
        for module in named_modules:
            entry = modules.get(module)
            if entry:
                allowed |= entry["commands"] | entry["results"] | entry["records"]
        if len(pairs) == 1:
            strict_rows += 1
            owner = pairs[0][1] or pairs[0][0]
            entry = modules.get(owner, {"commands": set(), "results": set(), "records": set()})
            allowed = entry["commands"] | entry["results"] | entry["records"]
        for token in ticked(iface_cell):
            token_checks += 1
            report.ok(
                token in allowed,
                "%s: `%s` is not an exposed command, published result or owned "
                "record of %s in the HF-03a table"
                % (row_id, token, " / ".join(sorted(named_modules))),
            )

        for family in re.findall(r"\bC-TICK\b|\bF-[A-Z]+\b", class_cell):
            report.ok(
                family in CALLBACK_FAMILIES,
                "%s: %s is not an HF-04a callback family" % (row_id, family),
            )

    report.counts["interface_rows"] = interface_rows
    report.counts["scenario_rows"] = scenario_rows
    report.counts["edge_pair_checks"] = pair_checks
    report.counts["interface_token_checks"] = token_checks
    report.counts["single_pair_strict_rows"] = strict_rows
    return interface_rows, scenario_rows


def check_parameters(report, section, backlog):
    rows = 0
    questions = set()
    for cells in table_rows(section):
        if not cells or not re.fullmatch(r"TP-\d\d", cells[0]) or len(cells) != 5:
            continue
        rows += 1
        basis = cells[3]
        found = re.findall(r"Q-[EP]\d\d", basis)
        questions |= set(found)
        report.ok(
            bool(found) or re.search(r"lines? \d+", basis),
            "%s has neither a source line nor a question ID: %r" % (cells[0], basis),
        )
    report.ok(rows >= 20, "expected at least 20 tunable parameter rows, found %d" % rows)
    for question in sorted(questions):
        report.ok(
            ('<a id="%s"></a>' % question.lower()) in backlog,
            "%s does not resolve to a BACKLOG anchor" % question,
        )
    report.counts["parameter_rows"] = rows
    report.counts["parameter_questions"] = len(questions)


def check_routes(report, section):
    """Both walked routes must reach a bolded named end state."""
    ends = re.findall(r"\*\*End state: ([^*]+)\*\*", section)
    report.ok(len(ends) == 2, "expected exactly two named end states, found %d" % len(ends))
    successful = [end for end in ends if "RL2" in end]
    terminal = [end for end in ends if "RL9" in end]
    report.ok(bool(successful), "the successful route must end in a named RL state")
    report.ok(bool(terminal), "the terminal route must end in a named RL state")
    report.counts["named_end_states"] = len(ends)

    states = set(re.findall(r"^\| (RL\d) \|", section, re.MULTILINE))
    report.ok(len(states) >= 10, "expected at least ten run-loop states, found %d" % len(states))
    for end in ends:
        named = re.findall(r"RL\d", end)
        report.ok(
            bool(named) and all(state in states for state in named),
            "end state %r names no state from the run-loop state table" % end,
        )
    report.counts["run_loop_states"] = len(states)


def check_structure(report, section, modules):
    for heading in REQUIRED_HEADINGS:
        report.ok(
            ("\n## %s\n" % heading) in section,
            "missing required heading: %s" % heading,
        )
    for heading in REQUIRED_SUBSECTIONS:
        report.ok(
            ("\n### %s\n" % heading) in section,
            "missing card-named subsection: %s" % heading,
        )
    # Every module name the section uses must be an HF-03a module or Values.
    used = set()
    for candidate in re.findall(r"\b(?:Session|Encounter|CollisionQueries|"
                               r"ContentAdmission|Persistence|InputAdapter|"
                               r"Presentation|Values)\b", section):
        used.add(candidate)
    for module in sorted(used):
        report.ok(
            module in modules or module == VALUES_NODE,
            "%s is named in the section but is not in the HF-03a module table" % module,
        )
    report.counts["modules_named"] = len(used)
    report.counts["hf03a_modules"] = len(modules)


def check_identities(report, root, section):
    for relative in (HF03A, HF03B, HF04A, HF07B, HF07A):
        digest = sha256(root, relative)
        report.ok(
            digest in section,
            "%s SHA256 %s is not stated in the section" % (relative, digest),
        )
    report.counts["dependency_hashes"] = 5


def check_no_adopted_answer(report, section):
    lowered = section.lower()
    for phrase in ADOPTION_PHRASES:
        report.ok(
            phrase.lower() not in lowered,
            "the section appears to adopt an answer: %r" % phrase,
        )
    for question in UNANSWERABLE:
        report.ok(
            question in section,
            "%s must be named as gating, and is absent" % question,
        )
    for label, needles in RESOLVED_READINGS:
        for needle in needles:
            report.ok(needle in section, "%s: %r is absent" % (label, needle))
    report.counts["resolved_readings"] = len(RESOLVED_READINGS)


def run(root, section_text, report):
    modules = parse_hf03a(read(root, HF03A))
    edges = parse_hf03b(read(root, HF03B))
    backlog = read(root, BACKLOG)
    report.ok(len(modules) == 7, "expected 7 HF-03a modules, found %d" % len(modules))
    report.ok(len(edges) == 16, "expected 16 HF-03b edges, found %d" % len(edges))
    report.counts["hf03b_edges"] = len(edges)
    check_structure(report, section_text, modules)
    check_step_rows(report, section_text, modules, edges)
    check_parameters(report, section_text, backlog)
    check_routes(report, section_text)
    check_no_adopted_answer(report, section_text)
    return modules, edges


CONTROLS = [
    (
        "unlisted-command",
        lambda text: text.replace("`load_aggregate`, `load_preferences`",
                                  "`load_aggregate`, `read_initial_snapshot`", 1),
    ),
    (
        "unlisted-edge",
        lambda text: text.replace("| D04 | `load_aggregate`, `load_preferences`",
                                  "| D99 | `load_aggregate`, `load_preferences`", 1),
    ),
    (
        "ungated-parameter",
        lambda text: text.replace("| TP-06 | Destination eligibility rule | unset | Q-P12 |",
                                  "| TP-06 | Destination eligibility rule | 3 | chosen here |",
                                  1),
    ),
]


def main(argv):
    parser = argparse.ArgumentParser(description="TH-01 run-loop paper check")
    parser.add_argument("root", help="repository root to check")
    parser.add_argument("--out", default=None, help="directory for the receipts")
    options = parser.parse_args(argv)

    root = pathlib.Path(options.root).resolve()
    out = pathlib.Path(options.out).resolve() if options.out else pathlib.Path.cwd()
    out.mkdir(parents=True, exist_ok=True)

    section_text = read(root, SECTION)
    report = Report()
    check_identities(report, root, section_text)
    run(root, section_text, report)

    detected = []
    for name, mutate in CONTROLS:
        mutated = mutate(section_text)
        if mutated == section_text:
            report.failures.append("negative control %s did not apply" % name)
            continue
        control = Report()
        run(root, mutated, control)
        if control.failures:
            detected.append(name)
        else:
            report.failures.append("negative control %s was not detected" % name)
    report.counts["controls_detected"] = len(detected)
    report.counts["controls_total"] = len(CONTROLS)

    result = {
        "root": str(root),
        "section": SECTION,
        "section_sha256": sha256(root, SECTION),
        "checks": report.checks,
        "failed": len(report.failures),
        "failures": report.failures,
        "counts": report.counts,
        "controls_detected": detected,
        "limits": "Document consistency at one base. No engine, browser, build "
                  "or hardware evidence is implied or claimed.",
    }
    (out / "paper-check.json").write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    manifest = {
        relative: sha256(root, relative)
        for relative in (SECTION, HF03A, HF03B, HF04A, HF07B, HF07A, BACKLOG)
    }
    (out / "source-manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )

    for failure in report.failures:
        print("FAIL %s" % failure)
    print(
        "%d checks, %d failed, %d/%d controls detected, %s"
        % (
            report.checks,
            len(report.failures),
            len(detected),
            len(CONTROLS),
            ", ".join("%s=%s" % item for item in sorted(report.counts.items())),
        )
    )
    return 1 if report.failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
