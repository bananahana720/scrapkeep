#!/usr/bin/env python3
"""Paper check for docs/tech/sections/TH-14-randomness-generation.md."""

import argparse
import json
import pathlib
import re
import sys

SECTION = "docs/tech/sections/TH-14-randomness-generation.md"
HF03A = "docs/tech/sections/HF-03a-module-map.md"
HF03B = "docs/tech/sections/HF-03b-dependency-graph.md"
HF04A = "docs/tech/sections/HF-04a-runtime-lifecycle.md"
CSV = "docs/tech/sections/HF-07a-save-envelope.csv"

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
    "Four independent random responsibilities",
    "Stream identity and what is durable",
    "The level-generation request",
    "The level-generation result",
    "Clearance, validation and what rejects a candidate",
    "Stored outcomes and seeds are different things",
    "Repeatability across engine, OS and timing",
    "Interfaces",
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
    "any",
}

PHASES = {"P0", "P1", "P2", "P3", "P4", "P5", "P6"}

STREAMS = ["route", "layout", "loot", "miscast"]

WALK_SCOPE = {"GA": {"miscast", "loot"}, "GB": {"route", "layout"}, "GC": {"layout"}}

DECLARED_FIELDS = {
    "run.start.rng_state",
    "run.checkpoint.rng_state",
    "run.checkpoint.offered_choices",
    "run.checkpoint.route",
    "run.checkpoint.resolved_rewards",
    "run.checkpoint.generation_decisions",
    "run.checkpoint.next_entrance",
    "run.start.entrance_id",
}
STRUCTURAL_CONTAINERS = {"run", "run.start", "run.checkpoint"}

NEGATIONS = ("not ", "no ", "never", "unchanged", "nowhere", "n't", "neither")
CONSUMPTION = ("is consumed", "consumes", "consumed once", "advanced by", "advances by")


class Report:
    def __init__(self):
        self.failures = []
        self.counts = {}

    def check(self, gate, ok, message):
        if not ok:
            self.failures.append(gate + ": " + message)

    def count(self, key, value):
        self.counts[key] = value


def rows(lines, start_predicate):
    out = []
    for line in lines:
        if line.startswith("|") and start_predicate(line):
            out.append([cell.strip() for cell in line.strip().strip("|").split("|")])
    return out


def backticked(text):
    return re.findall(r"`([^`]+)`", text)


def expand_edges(cell):
    found = []
    for match in re.finditer(r"D(\d\d)(?:\s+to\s+D(\d\d))?", cell):
        low = int(match.group(1))
        high = int(match.group(2)) if match.group(2) else low
        for value in range(low, high + 1):
            found.append("D%02d" % value)
    return found


def module_pairs(cell):
    pairs = []
    singles = []
    for part in re.split(r",|\bthen\b", cell):
        part = part.strip()
        if not part:
            continue
        if " to " in part:
            left, right = part.split(" to ", 1)
            pairs.append((left.strip(), right.strip()))
        else:
            singles.append(part)
    return pairs, singles


def load_hf03a(root):
    lines = (root / HF03A).read_text().splitlines()
    modules = {}
    for row in rows(lines, lambda line: re.match(r"\|\s*(Session|Encounter|CollisionQueries|ContentAdmission|Persistence|InputAdapter|Presentation)\.", line)):
        name = re.match(r"([A-Za-z]+)\.", row[0]).group(1)
        vocabulary = set()
        for column in (row[1], row[3], row[4]):
            vocabulary.update(backticked(column))
        modules[name] = vocabulary
    modules["Values"] = set()
    modules["Every module"] = set()
    return modules


def load_hf03b(root):
    lines = (root / HF03B).read_text().splitlines()
    edges = {}
    for row in rows(lines, lambda line: re.match(r"\|\s*D\d\d\s*\|", line)):
        edges[row[0]] = {"from": row[1], "to": row[2], "use": row[3]}
    return edges


def load_csv_fields(root):
    fields = set()
    for line in (root / CSV).read_text().splitlines()[1:]:
        field = line.split(",", 1)[0].strip()
        if field:
            fields.add(field.replace("[]", ""))
    return fields


def run_checks(root, text):
    report = Report()
    lines = text.splitlines()
    modules = load_hf03a(root)
    edges = load_hf03b(root)
    csv_fields = load_csv_fields(root)
    hf04a = (root / HF04A).read_text()

    headings = {re.sub(r"^#+\s+", "", line).strip() for line in lines if line.startswith("#")}
    for heading in REQUIRED_HEADINGS + REQUIRED_SUBSECTIONS:
        report.check("A-headings", heading in headings, "missing heading " + heading)

    interface_rows = rows(lines, lambda line: re.match(r"\|\s*GN-\d\d\s*\|", line))
    report.count("interface_rows", len(interface_rows))
    report.check("B-interfaces", len(interface_rows) == 26, "expected 26 interface rows, found %d" % len(interface_rows))

    named_modules = set()
    edges_used = set()
    for row in interface_rows:
        rid, caller, edge_cell, interface_cell, klass = row[0], row[2], row[3], row[4], row[5]
        pairs, singles = module_pairs(caller)
        row_modules = set(singles)
        for left, right in pairs:
            row_modules.update([left, right])
        named_modules.update(row_modules)
        for module in row_modules:
            report.check("B-modules", module in modules, "%s names module %r absent from HF-03a" % (rid, module))
        row_edges = expand_edges(edge_cell)
        edges_used.update(row_edges)
        for edge in row_edges:
            report.check("D-edges", edge in edges, "%s uses unlisted edge %s" % (rid, edge))
            if edge in edges:
                source, target = edges[edge]["from"], edges[edge]["to"]
                matched = any(
                    (left == source or left == "Every module") and right == target
                    for left, right in pairs
                )
                report.check("D-edges", matched, "%s edge %s (%s to %s) has no matching caller pair" % (rid, edge, source, target))
        vocabulary = set()
        for module in row_modules:
            vocabulary.update(modules.get(module, set()))
        if "Every module" in row_modules:
            for value in modules.values():
                vocabulary.update(value)
        for token in backticked(interface_cell):
            report.check("C-commands", token in vocabulary, "%s invokes `%s` outside the named modules' HF-03a lists" % (rid, token))
            if row_edges:
                permitted = any(token in edges[edge]["use"] for edge in row_edges if edge in edges)
                if not permitted and re.search(r"\b(local|none)\b", edge_cell):
                    permitted = any(token in modules.get(module, set()) for module in singles)
                report.check("D-permitted", permitted, "%s: `%s` is not in the permitted use of %s" % (rid, token, ",".join(row_edges)))
        for part in re.split(r",|\bthen\b", klass):
            part = part.strip()
            if not part:
                continue
            head = part.split()[0]
            report.check("E-class", head in CALLBACK_FAMILIES, "%s uses callback class %r absent from HF-04a" % (rid, head))
            for phase in re.findall(r"\bP\d\b", part):
                report.check("E-class", phase in PHASES, "%s uses phase %s" % (rid, phase))
    report.count("modules_named", len(named_modules))
    report.count("edges_used", len(edges_used))
    report.check("B-modules", named_modules >= {"Session", "Encounter", "CollisionQueries", "ContentAdmission", "Persistence", "InputAdapter", "Presentation"}, "not every HF-03a module appears")
    report.check("E-class", "F-PROCESS" in hf04a and "C-TICK" in hf04a, "HF-04a does not define the families used")

    parameter_rows = rows(lines, lambda line: re.match(r"\|\s*GP-\d\d\s*\|", line))
    report.count("parameter_rows", len(parameter_rows))
    report.check("F-parameters", len(parameter_rows) == 26, "expected 26 parameter rows, found %d" % len(parameter_rows))
    gated = 0
    for row in parameter_rows:
        rid, value, source = row[0], row[2], row[3]
        has_question = bool(re.search(r"Q-[EP]\d\d", source))
        has_line = "line" in source.lower()
        report.check("F-parameters", has_question or has_line, "%s carries neither a source line nor a question ID" % rid)
        if re.search(r"Q-P23|Q-E03", source):
            gated += 1
            recorded = bool(re.search(r"TRACKING EV-\d{4}", source))
            report.check(
                "F-parameters",
                value.startswith("unset") or recorded,
                "%s is gated on Q-P23 or Q-E03 and states %r without a recorded answer" % (rid, value),
            )
    report.count("parameter_rows_gated_on_qp23_or_qe03", gated)
    report.check("F-parameters", gated >= 6, "expected at least six rows gated on Q-P23 or Q-E03, found %d" % gated)

    named_fields = {token.replace("[]", "") for token in backticked(text) if token.startswith(("run.", "profile.", "preferences.", "run"))}
    named_fields = {field for field in named_fields if re.match(r"^(run|profile|preferences)(\.|$)", field)}
    report.count("durable_fields_named", len(named_fields))
    for field in sorted(named_fields):
        if field in STRUCTURAL_CONTAINERS:
            continue
        report.check("G-fields", field in csv_fields, "`%s` is not an HF-07a CSV field" % field)
        root_group = ".".join(field.split(".")[:3]) if field.startswith("run.checkpoint") or field.startswith("run.start") else field
        report.check("G-fields", root_group in DECLARED_FIELDS, "`%s` is a durable field outside the declared set" % field)

    responsibility_rows = rows(lines, lambda line: re.match(r"\|\s*GR-\d\d\s*\|", line))
    report.count("responsibilities", len(responsibility_rows))
    report.check("H-streams", len(responsibility_rows) == 4, "expected 4 responsibilities, found %d" % len(responsibility_rows))
    stream_owner = {}
    stream_responsibility = {}
    for row in responsibility_rows:
        rid, responsibility, owner, stream = row[0], row[1], row[3], row[4]
        key = stream.split()[0].lower()
        report.check("H-streams", key in STREAMS, "%s names stream %r outside the four" % (rid, key))
        report.check("H-streams", key not in stream_responsibility, "%s reuses stream %r already bound to %s" % (rid, key, stream_responsibility.get(key)))
        stream_responsibility[key] = responsibility
        stream_owner[key] = owner
    report.check("H-streams", set(stream_responsibility) == set(STREAMS), "the four responsibilities do not partition the four streams")
    for key, owner in stream_owner.items():
        head = owner.split(",")[0]
        drawing = set(re.findall(r"\b(Session|Encounter|CollisionQueries|ContentAdmission|Persistence|InputAdapter|Presentation)\b", head))
        report.check("H-streams", len(drawing) == 1, "stream %r has %d drawing owners in %r" % (key, len(drawing), head))

    walk_steps = {}
    for line in lines:
        match = re.match(r"\|\s*(G[ABC])\.(\d+)\s*\|", line)
        if match:
            cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
            walk_steps.setdefault(match.group(1), []).append(cells)
    report.count("walk_steps", sum(len(v) for v in walk_steps.values()))
    for walk, scope in WALK_SCOPE.items():
        steps = walk_steps.get(walk, [])
        report.check("I-walks", len(steps) >= 5, "walk %s has %d steps" % (walk, len(steps)))
        consumed = set()
        for cells in steps:
            step_id, edge_cell, interface_cell, klass, result = cells[0], cells[3], cells[4], cells[5], cells[-1]
            for edge in expand_edges(edge_cell):
                report.check("I-walks", edge in edges, "%s uses unlisted edge %s" % (step_id, edge))
            for token in re.findall(r"GN-\d\d", interface_cell):
                report.check("I-walks", any(row[0] == token for row in interface_rows), "%s names absent interface row %s" % (step_id, token))
            for part in re.split(r",|\bthen\b", klass):
                part = part.strip()
                if part:
                    report.check("I-walks", part.split()[0] in CALLBACK_FAMILIES, "%s uses callback class %r" % (step_id, part))
            body = (result + " " + cells[1]).lower()
            for sentence in re.split(r"(?<=[.;])\s+", body):
                for key in STREAMS:
                    if key + " stream" not in sentence.replace("**", ""):
                        continue
                    if key in scope:
                        if any(phrase in sentence for phrase in CONSUMPTION) and not any(
                            negation in sentence.split(key)[0][-24:] for negation in NEGATIONS
                        ):
                            consumed.add(key)
                        continue
                    report.check(
                        "I-walks",
                        any(negation in sentence for negation in NEGATIONS),
                        "%s mentions the %s stream outside walk %s's responsibilities without denying it: %r"
                        % (step_id, key, walk, sentence.strip()[:120]),
                    )
        for key in scope:
            report.check("I-walks", key in consumed, "walk %s never consumes its own %s stream" % (walk, key))

    outcome_lines = [line for line in lines if re.match(r"\*\*G[ABC] outcome:", line)]
    report.count("walk_outcomes", len(outcome_lines))
    report.check("I-walks", len(outcome_lines) == 3, "expected three bolded walk outcomes, found %d" % len(outcome_lines))

    question_ids = set(re.findall(r"Q-[EP]\d\d", text))
    backlog = (root / "BACKLOG.md").read_text()
    for question in sorted(question_ids):
        report.check("J-questions", '<a id="%s">' % question.lower() in backlog, "%s has no BACKLOG anchor" % question)
    report.count("questions_named", len(question_ids))

    import hashlib

    stated = re.findall(r"SHA256 `([0-9a-f]{64})`", text)
    report.count("stated_hashes", len(stated))
    report.check("K-hashes", len(stated) == 14, "expected 14 stated dependency hashes, found %d" % len(stated))
    actual = set()
    for path in root.rglob("docs/tech/sections/*.md"):
        actual.add(hashlib.sha256(path.read_bytes()).hexdigest())
    for extra in ("docs/tech/sections/HF-07a-save-envelope.csv", "artifacts/foundation-sprint-2026-09/HF-10-foundation-review.md", "docs/DISCOVERY.md"):
        actual.add(hashlib.sha256((root / extra).read_bytes()).hexdigest())
    for value in stated:
        report.check("K-hashes", value in actual, "stated hash %s matches no dependency at this root" % value[:12])

    return report


def apply_control(text, name):
    if name == "shared-stream":
        return text.replace("| Loot stream, encounter-scoped, not durable |", "| Miscast stream, encounter-scoped, not durable |", 1)
    if name == "presentation-draw":
        marker = "| GA.6 |"
        injected = "| GA.9 | GI-04 | Session to Presentation | D06 | GN-26 `present_committed_result` | F-PROCESS | The view consumes the route stream once to pick a spark colour. |\n"
        return text.replace(marker, injected + marker, 1)
    if name == "gated-value":
        return text.replace(
            "| GP-09 | Generation technique | unset; seeded authored assembly",
            "| GP-09 | Generation technique | seeded authored assembly",
            1,
        )
    raise ValueError(name)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root")
    parser.add_argument("--out", required=True)
    arguments = parser.parse_args()
    root = pathlib.Path(arguments.root).resolve()
    out = pathlib.Path(arguments.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    text = (root / SECTION).read_text()

    clean = run_checks(root, text)
    controls = {}
    for name in ("shared-stream", "presentation-draw", "gated-value"):
        mutated = apply_control(text, name)
        if mutated == text:
            controls[name] = {"noticed": False, "reason": "control did not modify the section"}
            continue
        result = run_checks(root, mutated)
        new = sorted(set(result.failures) - set(clean.failures))
        controls[name] = {"noticed": bool(new), "new_failures": new[:4]}

    receipt = {
        "root": str(root),
        "section": SECTION,
        "clean_failures": clean.failures,
        "counts": clean.counts,
        "controls": controls,
    }
    (out / "paper-check.json").write_text(json.dumps(receipt, indent=2) + "\n")

    for key in sorted(clean.counts):
        print("%-42s %s" % (key, clean.counts[key]))
    for failure in clean.failures:
        print("FAIL " + failure)
    for name, value in controls.items():
        print("control %-20s %s" % (name, "noticed" if value["noticed"] else "NOT NOTICED"))

    ok = not clean.failures and all(value["noticed"] for value in controls.values())
    print("RESULT " + ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
