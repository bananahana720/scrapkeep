#!/usr/bin/env python3
"""Paper check for docs/tech/sections/TH-13-chaos-outcomes.md.

Disposable evidence. It reads the repository at an explicit root and writes a
receipt to --out. It proves document agreement, never runtime behaviour.

Usage: check_chaos.py <repository-root> [--out <directory>]
"""

import hashlib
import json
import re
import sys
from pathlib import Path

SECTION = "docs/tech/sections/TH-13-chaos-outcomes.md"
HF03A = "docs/tech/sections/HF-03a-module-map.md"
HF03B = "docs/tech/sections/HF-03b-dependency-graph.md"
HF04A = "docs/tech/sections/HF-04a-runtime-lifecycle.md"
HF07A_CSV = "docs/tech/sections/HF-07a-save-envelope.csv"
TH03 = "docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md"
TH04 = "docs/tech/sections/TH-04-abilities-ultimates-and-combat-rhythm.md"
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

CARD_SUBSECTIONS = [
    "Interfaces",
    "Owned data",
    "Algorithms and update order",
    "Edge cases",
    "Failure modes",
    "Tunable parameters",
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
# `Values` is HF-03a's type vocabulary at its line 27, not a row of the module
# table, so it is a legal edge endpoint and never a module-table lookup.
ENDPOINTS = MODULES + ["Values"]

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

DURABLE_RNG = {"run.start.rng_state", "run.checkpoint.rng_state"}


class Findings:
    def __init__(self):
        self.failures = []
        self.counts = {}

    def check(self, ok, label):
        if not ok:
            self.failures.append(label)
        return ok

    def count(self, key, value):
        self.counts[key] = value


def read(root, rel):
    return (Path(root) / rel).read_text(encoding="utf-8")


def rows(text, prefix):
    """Table rows whose first cell starts with prefix."""
    out = []
    for line in text.split("\n"):
        stripped = line.strip()
        if not stripped.startswith("|"):
            continue
        cells = [c.strip() for c in stripped.strip("|").split("|")]
        if cells and cells[0].startswith(prefix):
            out.append(cells)
    return out


def ticked(cell):
    return set(re.findall(r"`([^`]+)`", cell))


def hf03a_vocabulary(text):
    """module -> set of exposed commands and published results named in its row."""
    vocabulary = {}
    for line in text.split("\n"):
        stripped = line.strip()
        if not stripped.startswith("|"):
            continue
        cells = [c.strip() for c in stripped.strip("|").split("|")]
        if len(cells) < 5:
            continue
        name = cells[0].split(".")[0].strip()
        if name in MODULES:
            vocabulary[name] = ticked(cells[3]) | ticked(cells[4]) | ticked(cells[1])
    return vocabulary


def hf03b_edges(text):
    """edge -> (from, to, permitted-use text)."""
    edges = {}
    for line in text.split("\n"):
        stripped = line.strip()
        if not stripped.startswith("|"):
            continue
        cells = [c.strip() for c in stripped.strip("|").split("|")]
        if len(cells) >= 4 and re.fullmatch(r"D\d\d", cells[0]):
            edges[cells[0]] = (cells[1], cells[2], cells[3])
    return edges


def sections_of(text):
    """heading text -> body, for level-3 headings."""
    out = {}
    current = None
    buffer = []
    for line in text.split("\n"):
        match = re.match(r"^###\s+(.*?)\s*$", line)
        if match:
            if current is not None:
                out[current] = "\n".join(buffer)
            current = match.group(1)
            buffer = []
        else:
            buffer.append(line)
    if current is not None:
        out[current] = "\n".join(buffer)
    return out


def stated_hashes(text):
    """(path, stated hash) pairs, binding each hash to its nearest preceding link."""
    token = re.compile(r"SHA256\s+`([0-9a-fA-F]{64})`|\[[^\]]*\]\(([^)]+)\)")
    pairs = []
    nearest = None
    for match in token.finditer(text):
        if match.group(2) is not None:
            target = match.group(2).split("#")[0].strip()
            if not target or re.match(r"^[a-z][a-z0-9+.-]*:", target):
                continue
            base = target.rsplit("/", 1)[-1]
            if "#" in match.group(0) and base in {"BACKLOG.md", "TRACKING.md"}:
                continue
            nearest = target
        else:
            pairs.append((nearest, match.group(1)))
    return pairs


def run_assertions(root, section_text, findings):
    hf03a = read(root, HF03A)
    hf03b = read(root, HF03B)
    hf04a = read(root, HF04A)
    csv = read(root, HF07A_CSV)
    th03 = read(root, TH03)
    th04 = read(root, TH04)
    backlog = read(root, BACKLOG)

    vocabulary = hf03a_vocabulary(hf03a)
    edges = hf03b_edges(hf03b)
    findings.count("hf03a_modules", len(vocabulary))
    findings.count("hf03b_edges", len(edges))
    findings.check(len(vocabulary) == 7, "HF-03a module table did not yield seven modules")
    findings.check(len(edges) == 16, "HF-03b adjacency list did not yield sixteen edges")

    # 1. Required headings and the card's named subsections.
    present = {
        m.group(1).strip().lower()
        for m in re.finditer(r"^#{1,6}\s+(.*?)\s*#*$", section_text, re.M)
    }
    for heading in REQUIRED_HEADINGS:
        findings.check(heading.lower() in present, f"missing required heading: {heading}")
    for heading in CARD_SUBSECTIONS:
        findings.check(heading.lower() in present, f"missing card subsection: {heading}")

    # 2. Every module named here is an HF-03a module; every HF-03a module is named.
    named = {m for m in MODULES if re.search(rf"\b{m}\b", section_text)}
    findings.count("modules_named", len(named))
    for module in named:
        findings.check(module in vocabulary, f"module not in HF-03a table: {module}")
    findings.check(named == set(MODULES), "not every HF-03a module is named in the section")

    # 3 and 4. Interface rows: commands, edges and per-edge permitted use.
    interface_rows = rows(section_text, "XI-")
    findings.count("interface_rows", len(interface_rows))
    findings.check(len(interface_rows) >= 25, "fewer than twenty-five interface rows")
    for cells in interface_rows:
        rid, caller, edge_cell, interface_cell, class_cell = (
            cells[0],
            cells[2],
            cells[3],
            cells[4],
            cells[5],
        )
        row_modules = {m for m in MODULES if re.search(rf"\b{m}\b", caller)}
        every = "Every module" in caller
        findings.check(
            bool(row_modules) or every, f"{rid}: no module named in the caller cell"
        )
        used = set(re.findall(r"\bD\d\d\b", edge_cell))
        if "D10 to D16" in edge_cell:
            used = {f"D{n}" for n in range(10, 17)}
        permitted = ""
        for edge in sorted(used):
            findings.check(edge in edges, f"{rid}: edge {edge} is not an HF-03b edge")
            if edge not in edges:
                continue
            source, target, use = edges[edge]
            permitted += " " + use
            if target == "Values":
                findings.check(
                    "Values" in caller and ("Every module" in caller or source in row_modules),
                    f"{rid}: edge {edge} to Values is not named by the row",
                )
                continue
            findings.check(
                source in row_modules and target in row_modules,
                f"{rid}: edge {edge} runs {source} to {target}, which the row does not name",
            )
        local = "local" in edge_cell or "none" in edge_cell
        for interface in ticked(interface_cell):
            anywhere = any(interface in v for v in vocabulary.values())
            findings.check(
                anywhere or interface in hf03a,
                f"{rid}: `{interface}` appears nowhere in HF-03a",
            )
            owned = any(
                interface in vocabulary.get(m, set()) or f"`{interface}`" in hf03a
                for m in row_modules
            )
            findings.check(
                f"`{interface}`" in permitted or (local and owned),
                f"{rid}: `{interface}` is not in the permitted use of the row's edges",
            )
        for token in re.findall(r"F-[A-Z]+|P\d\b", class_cell):
            findings.check(
                token in CALLBACK_FAMILIES or token in PHASES,
                f"{rid}: {token} is neither an HF-04a family nor a phase",
            )

    # 5. Parameters: sourced or gated, and no Q-P13 row states a value.
    parameter_rows = rows(section_text, "XT-")
    findings.count("parameter_rows", len(parameter_rows))
    findings.check(len(parameter_rows) >= 20, "fewer than twenty parameter rows")
    qp13 = 0
    for cells in parameter_rows:
        rid, value, source = cells[0], cells[2], cells[3]
        findings.check(
            bool(re.search(r"lines?\s+\d+", source) or re.search(r"Q-[A-Z]\d+", source)),
            f"{rid}: neither a source line nor a question ID",
        )
        if "Q-P13" in source:
            qp13 += 1
            findings.check(
                value.lower().startswith("unset"),
                f"{rid}: a Q-P13 row states a value: {value!r}",
            )
    findings.count("qp13_rows", qp13)
    findings.check(qp13 >= 6, "fewer than six parameter rows gated on Q-P13")

    # 5b. No instability meter or always-random kit is adopted anywhere.
    for phrase in ["instability meter", "always-random kit"]:
        for line in section_text.split("\n"):
            if phrase in line.lower():
                findings.check(
                    re.search(r"not adopted|no instability|refus|never|adopts no|are not approved|not an always-random|is not an always-random", line)
                    is not None,
                    f"a line mentions the {phrase} without refusing it: {line[:80]!r}",
                )

    # 6. Durable fields exist in HF-07a's CSV; only the two rng groups are named.
    csv_fields = {line.split(",")[0].strip() for line in csv.split("\n") if line.strip()}
    named_fields = {
        f.rstrip("[]") if f.endswith("[]") else f
        for f in re.findall(r"`(run\.[A-Za-z0-9_.\[\]]+)`", section_text)
    }
    findings.count("durable_fields_named", len(named_fields))
    for field in sorted(named_fields):
        findings.check(field in csv_fields, f"durable field not in HF-07a CSV: {field}")
    rng_named = {f for f in named_fields if "rng_state" in f}
    findings.check(
        rng_named == DURABLE_RNG,
        f"named durable generator fields are {sorted(rng_named)}, not the two rng_state groups",
    )

    # 7. The cited sibling rules exist verbatim.
    for n in range(1, 7):
        findings.check(
            re.search(rf"^\| CH-0{n} \|", th03, re.M) is not None,
            f"TH-03 CH-0{n} not found",
        )
    findings.check(
        re.search(r"^\| AO-11 \| A chaos miscast is that single `outcome`", th03, re.M)
        is not None,
        "TH-03 AO-11 not found verbatim",
    )
    findings.check(
        re.search(r"^\| AO-11 \| An action's random outcome is drawn once", th04, re.M)
        is not None,
        "TH-04 AO-11 not found verbatim",
    )
    findings.check(
        "no random draw and no partial descriptor" in th03,
        "TH-03 FM-02's no-random-draw clause not found",
    )
    findings.check(
        "consumes no random draw" in th04, "TH-04 AA-07's no-random-draw clause not found"
    )
    findings.check(
        "cannot decrement a cooldown, move an actor, consume gameplay randomness" in hf04a,
        "HF-04a line 24's control-drain clause not found",
    )
    findings.check(
        "no random draw" in hf03b, "HF-03b's handler no-random-draw clause not found"
    )

    # 8. The walks: one draw each, none outside P4, one intended and one harmful.
    walks = {k: v for k, v in sections_of(section_text).items() if re.match(r"^X[NML]:", k)}
    findings.count("walks", len(walks))
    findings.check(len(walks) == 3, "expected three walked routes")
    kinds = []
    outcome_walk_draws = []
    for title, body in walks.items():
        kind = re.search(r"outcome kind \*\*(\w+)\*\*", title)
        findings.check(kind is not None, f"walk {title}: no declared outcome kind")
        if kind:
            kinds.append(kind.group(1))
        step_rows = rows(body, "X")
        step_rows = [c for c in step_rows if re.match(r"^X[NML]\.\d+$", c[0])]
        findings.check(len(step_rows) >= 5, f"walk {title}: fewer than five steps")
        draws = 0
        for cells in step_rows:
            joined = " | ".join(cells)
            class_cell = cells[5] if len(cells) > 5 else ""
            interface_cell = cells[4] if len(cells) > 4 else ""
            if "EncounterRandomState" in interface_cell:
                draws += 1
                findings.check(
                    class_cell.strip() == "C-TICK P4",
                    f"{cells[0]}: a drawing step sits at {class_cell!r}, not C-TICK P4",
                )
            else:
                if "EncounterRandomState" in joined:
                    findings.check(
                        re.search(r"not reset|no draw|draws nothing|nothing is redrawn", joined)
                        is not None,
                        f"{cells[0]}: names the generator outside an interface cell without denying a draw",
                    )
                findings.check(
                    "reroll" not in joined.lower() or "no reroll" in joined.lower()
                    or "rerolls no" in joined.lower() or "no draw and no reroll" in joined.lower(),
                    f"{cells[0]}: an affirmative reroll appears in a walked step",
                )
        findings.check(draws <= 1, f"walk {title}: {draws} drawing steps, expected at most one")
        if title.startswith(("XN", "XM")):
            outcome_walk_draws.append(draws)
        findings.check(
            "**" in body and "end state" in body.lower(),
            f"walk {title}: no bolded end state",
        )
    findings.count("outcome_walk_draws", outcome_walk_draws)
    findings.check(
        outcome_walk_draws == [1, 1],
        f"the two outcome walks drew {outcome_walk_draws}, expected one each",
    )
    findings.check("intended" in kinds, "no walk declares the intended outcome kind")
    findings.check("harmful" in kinds, "no walk declares a harmful outcome kind")

    # 8b. No interface row outside C-TICK P4 names the generator record.
    for cells in interface_rows:
        if "EncounterRandomState" in (cells[4] if len(cells) > 4 else ""):
            findings.check(
                cells[5].strip() == "C-TICK P4",
                f"{cells[0]}: names the generator record outside C-TICK P4",
            )

    # 9. Every question ID resolves to a BACKLOG anchor.
    questions = sorted(set(re.findall(r"\bQ-[A-Z]\d+\b", section_text)))
    findings.count("questions_named", len(questions))
    for question in questions:
        findings.check(
            f'<a id="{question.lower()}">' in backlog,
            f"{question} has no BACKLOG anchor",
        )
    findings.check("Q-P13" in questions, "Q-P13 is not named")

    # 10. Every stated dependency hash matches the bytes it names.
    sources = section_text.split("## Contract")[0]
    pairs = stated_hashes(sources)
    findings.count("stated_hashes", len(pairs))
    findings.check(len(pairs) == 13, f"expected thirteen stated hashes, found {len(pairs)}")
    base = Path(root) / "docs/tech/sections"
    for target, stated in pairs:
        findings.check(target is not None, f"hash {stated[:12]} has no preceding link")
        if target is None:
            continue
        path = (base / target).resolve()
        findings.check(path.exists(), f"hash target does not exist: {target}")
        if not path.exists():
            continue
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        findings.check(
            actual == stated.lower(),
            f"hash mismatch for {target}: stated {stated[:12]}, actual {actual[:12]}",
        )


def main(argv):
    if len(argv) < 2:
        print("usage: check_chaos.py <repository-root> [--out <directory>]")
        return 2
    root = Path(argv[1]).resolve()
    out = None
    if "--out" in argv:
        out = Path(argv[argv.index("--out") + 1]).resolve()
        out.mkdir(parents=True, exist_ok=True)

    section_text = read(root, SECTION)

    main_findings = Findings()
    run_assertions(root, section_text, main_findings)

    # Negative controls. Each removes or corrupts one gate; the suite must notice.
    controls = {}

    c1 = section_text.replace(
        "| XN.11 | XA-07 |",
        "| XN.99 | XA-07 | Encounter | local | XI-12 `EncounterRandomState` | C-TICK P6 |"
        " A second draw at publication. |\n| XN.11 | XA-07 |",
        1,
    )
    c2 = section_text.replace(
        "| XI-01 |",
        "| XI-99 | Reroll the published outcome | Presentation to Encounter | D01 |"
        " `present_committed_result` | F-PROCESS | none | invented |\n| XI-01 |",
        1,
    )
    c3 = section_text.replace(
        "| XT-08 | Instability meter | not adopted; none exists |",
        "| XT-08 | Instability meter | a five-step meter |",
        1,
    ).replace(
        "| XT-11 | Chaos element and effect pool | unset |",
        "| XT-11 | Chaos element and effect pool | fire, ice and shock |",
        1,
    )

    for name, text in (
        ("C1_second_draw_at_P6", c1),
        ("C2_presentation_reroll_edge", c2),
        ("C3_valued_instability_meter", c3),
    ):
        control = Findings()
        if text == section_text:
            control.failures.append("control text is unchanged; the control did not apply")
            controls[name] = {"noticed": False, "failures": control.failures}
            continue
        run_assertions(root, text, control)
        new = [f for f in control.failures if f not in main_findings.failures]
        controls[name] = {"noticed": bool(new), "new_failures": new[:4]}

    controls_ok = all(c["noticed"] for c in controls.values())
    passed = not main_findings.failures and controls_ok

    receipt = {
        "check": "TH-13 chaos outcome commitment paper check",
        "root": str(root),
        "section": SECTION,
        "section_sha256": hashlib.sha256((root / SECTION).read_bytes()).hexdigest(),
        "result": "pass" if passed else "fail",
        "counts": main_findings.counts,
        "failures": main_findings.failures,
        "negative_controls": controls,
        "limits": (
            "Document agreement only. It establishes no runtime behaviour, no engine "
            "result and no product answer."
        ),
    }
    text = json.dumps(receipt, indent=2, sort_keys=True)
    print(text)
    if out:
        (out / "check_chaos.json").write_text(text + "\n", encoding="utf-8")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
