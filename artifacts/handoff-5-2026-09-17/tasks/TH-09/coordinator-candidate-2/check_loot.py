#!/usr/bin/env python3
"""Paper check retained for TH-09.

Source-consistency only. A passing count is not evidence that a rule is right,
only that the rows it checks agree with the sections they name.

Usage: python check_loot.py <repository-root> --out <receipt-directory>
"""

import argparse
import hashlib
import json
import pathlib
import re
import sys

SECTION = "docs/tech/sections/TH-09-themed-loot-attunement-and-fixed-secrets.md"
HF03A = "docs/tech/sections/HF-03a-module-map.md"
HF03B = "docs/tech/sections/HF-03b-dependency-graph.md"
HF07A_CSV = "docs/tech/sections/HF-07a-save-envelope.csv"
TH08 = "docs/tech/sections/TH-08-inventory-equipment-and-transformations.md"

REQUIRED_HEADINGS = [
    "Sources",
    "Contract",
    "Scenarios",
    "Unresolved questions",
    "Re-verification triggers",
    "Procedure performed",
    "Evidence limits",
]

# The module names this contract may use. Each must be found in HF-03a's table.
MODULE_NAMES = [
    "Session",
    "Encounter",
    "CollisionQueries",
    "ContentAdmission",
    "Persistence",
    "InputAdapter",
    "Presentation",
]

# TH-08 rules this section builds on, with the verbatim fragment each must carry
# on the line the rule ID occupies in TH-08.
TH08_RULES = {
    "EQ-02": "The rebuild is whole-value replacement",
    "EQ-03": "The rebuild's inputs are exactly three",
    "EQ-04": "total deterministic function of the selection set",
    "EQ-05": "carries the provenance of the selection it derives from",
    "EQ-07": "A derived effect is never an input",
    "EQ-08": "Nothing derived is durable",
    "EQ-09": "a load cannot restore a stale effect",
    "EQ-10": "Acquisition never implies equipping",
    "EQ-11": "per-instance state lives in `instance_fields`",
    "EC-01": "A compatibility query has exactly three inputs",
    "EC-03": "`not eligible` is the default",
    "EC-05": "A compatibility outcome is never stored",
    "EC-06": "so it is pure",
    "EC-08": "Attunement is a build relationship",
    "EC-09": "A fixed secret bonus is a compatibility outcome over selected slot endpoints",
    "EC-10": "the rebuild emits one row per selection with its own provenance",
    "EN-01": "Selection invalidation",
    "EN-03": "Definition invalidation",
    "EN-09": "A held operation leaves all three states unchanged",
    "EO-04": "The rebuild runs in three passes in this order",
    "EO-05": "Resolution failure stops the rebuild before any pass emits",
    "EO-06": "Enumeration order is fixed",
    "EO-10": "Acquisition is a settlement, not a reconfiguration",
    "EO-11": "The intermission stages nothing and is not a checkpoint",
    "EO-12": "becomes durable at the next durable transition",
    "EO-14": "A load installs selections and rebuilds effects",
    "EX-16": "eligible endpoint combination is broken by a respec",
    "EP-26": "what fixed bonuses or tradeoffs they grant",
}

TH08_SEAM4 = (
    "**Seam 4: loot and fixed secret evaluation, to TH-09.** Which eligible "
    "endpoint combinations grant which fixed bonuses, and how a discovery is "
    "disclosed, belong to TH-09 and Q-P14. This section fixes only that a fixed "
    "secret bonus is a compatibility outcome over selected endpoints, that it is "
    "rebuilt rather than stored, and that re-equipping or reloading cannot stack "
    "another copy."
)

WALKS = {
    "WG": ["exactly once", "granted nothing a second time"],
    "WK": ["emitted once", "Nothing derived was written to the save"],
    "WR": ["exactly once", "discovery persisted through the reload"],
    "WQ": ["identical to `B1`", "never twice"],
    "WX": ["reappeared once", "discovery persisted unchanged", "never twice"],
}


class Checks:
    def __init__(self):
        self.results = []

    def check(self, name, ok, detail=""):
        self.results.append({"check": name, "ok": bool(ok), "detail": detail})
        return bool(ok)

    @property
    def failures(self):
        return [r for r in self.results if not r["ok"]]


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def table_rows(lines, first_cell_pattern):
    """Every pipe row whose first cell matches the pattern, as cell lists."""
    rows = []
    for index, line in enumerate(lines, start=1):
        stripped = line.strip()
        if not stripped.startswith("|"):
            continue
        cells = [c.strip() for c in stripped.strip("|").split("|")]
        if cells and re.fullmatch(first_cell_pattern, cells[0]):
            rows.append((index, cells))
    return rows


def backticked(text):
    return re.findall(r"`([^`]+)`", text)


def commands_in(text):
    """Backticked snake_case identifiers, which is how a command is written."""
    return [t for t in backticked(text) if re.fullmatch(r"[a-z][a-z0-9_]*", t) and "_" in t]


def parse_hf03a(text):
    """Module name -> {'commands': set, 'results': set, 'records': set}."""
    modules = {}
    for line in text.split("\n"):
        stripped = line.strip()
        if not stripped.startswith("|"):
            continue
        cells = [c.strip() for c in stripped.strip("|").split("|")]
        if len(cells) < 5:
            continue
        name = cells[0].split(".")[0].strip()
        if name not in MODULE_NAMES:
            continue
        modules[name] = {
            "records": set(backticked(cells[1])),
            "commands": set(backticked(cells[3])),
            "results": set(backticked(cells[4])),
        }
    return modules


def parse_hf03b(text):
    """Edge id -> {'from', 'to', 'use', 'interfaces'}."""
    edges = {}
    for line in text.split("\n"):
        stripped = line.strip()
        if not stripped.startswith("|"):
            continue
        cells = [c.strip() for c in stripped.strip("|").split("|")]
        if len(cells) < 4 or not re.fullmatch(r"D\d\d", cells[0]):
            continue
        edges[cells[0]] = {
            "from": cells[1],
            "to": cells[2],
            "use": cells[3],
            "interfaces": set(backticked(cells[3])),
        }
    return edges


def modules_in(cell):
    found = []
    for name in sorted(MODULE_NAMES, key=len, reverse=True):
        if re.search(r"\b" + name + r"\b", cell):
            found.append(name)
    if "Every module" in cell:
        found = list(MODULE_NAMES)
    return found


# A step is durable when it settles an accepted result, or when it travels the
# only two edges a candidate can reach: D04 to Persistence and D09, on which the
# candidate's references are validated. A walk may not perform one before the
# level's results may be read and accepted at all.
DURABLE_COMMANDS = ("accept_encounter_result", "stage_transition", "commit_transition")
DURABLE_EDGES = ("D04", "D09")


def walk_order_ok(precondition, steps):
    """No settle, stage, validate or commit step may precede the walk's gate.

    A walk whose precondition already places the run at or after the point where
    results are accepted -- an intermission at RL3 or later, or a restore -- is
    gated by its precondition. A walk that starts inside an unfinished level must
    reach RL3, or the level's objective completion, in an earlier step than any
    durable one.
    """
    gated = bool(re.search(r"\bRL[3-9]\b|\bRN-3\b|restore|reload", precondition, re.I))
    gate_index = durable_index = None
    for index, (_, cells) in enumerate(steps):
        row = " | ".join(cells)
        # A mention of RL3 is not the exit. The gate is the step that performs
        # the RL2-to-RL3 exit or satisfies the level's objective.
        if gate_index is None and re.search(
            r"RL2-to-RL3 exit|satisfies the level's objective|objective completion",
            row,
        ):
            gate_index = index
        is_durable = any(m in row for m in DURABLE_COMMANDS)
        if not is_durable and len(cells) > 3:
            is_durable = any(
                re.search(r"\b" + e + r"\b", cells[3]) for e in DURABLE_EDGES
            )
        if is_durable and durable_index is None:
            durable_index = index
    if durable_index is None:
        return True, "no durable step"
    if gated:
        return True, "gated by precondition"
    if gate_index is None:
        return False, "durable step %d with no RL3 or objective-completion step" % durable_index
    return gate_index <= durable_index, "gate %d, first durable %d" % (gate_index, durable_index)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    root = pathlib.Path(args.root).resolve()
    out = pathlib.Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)

    paths = {
        "section": root / SECTION,
        "hf03a": root / HF03A,
        "hf03b": root / HF03B,
        "hf07a_csv": root / HF07A_CSV,
        "th08": root / TH08,
    }
    for key, path in paths.items():
        if not path.exists():
            print("missing input: " + str(path), file=sys.stderr)
            return 2

    section = paths["section"].read_text()
    section_lines = section.split("\n")
    modules = parse_hf03a(paths["hf03a"].read_text())
    edges = parse_hf03b(paths["hf03b"].read_text())
    th08 = paths["th08"].read_text()
    th08_lines = th08.split("\n")

    csv_lines = paths["hf07a_csv"].read_text().strip().split("\n")
    csv_fields = {line.split(",")[0] for line in csv_lines[1:]}

    c = Checks()
    counts = {}

    # --- required headings -------------------------------------------------
    present = {
        m.group(1).strip().lower()
        for m in (re.match(r"#{1,6}\s+(.*?)\s*#*\s*$", ln) for ln in section_lines)
        if m
    }
    for heading in REQUIRED_HEADINGS:
        c.check("heading:" + heading, heading.lower() in present)

    # --- the three fact kinds ---------------------------------------------
    facts = table_rows(section_lines, r"LK-\d")
    counts["fact_kinds"] = len(facts)
    c.check("fact-kinds-are-three", len(facts) == 3, str(len(facts)))
    c.check(
        "fact-kind-ids-unique",
        len({r[1][0] for r in facts}) == len(facts),
    )

    # --- interface rows ----------------------------------------------------
    rows = table_rows(section_lines, r"LI-\d\d")
    counts["interface_rows"] = len(rows)
    c.check("interface-rows-present", len(rows) >= 20, str(len(rows)))
    c.check("interface-ids-unique", len({r[1][0] for r in rows}) == len(rows))

    named_modules, named_commands, named_edges = set(), set(), set()
    for line_no, cells in rows:
        rid = cells[0]
        if len(cells) < 8:
            c.check("interface-row-shape:" + rid, False, "expected 8 cells")
            continue
        c.check(
            "interface-row-shape:" + rid,
            all(cells[i] for i in (1, 2, 3, 4, 5, 6, 7)),
            "empty cell",
        )
        row_modules = modules_in(cells[2])
        named_modules.update(row_modules)
        c.check("interface-row-has-module:" + rid, bool(row_modules), cells[2])

        # (1) every module named appears in HF-03a's module table
        for name in row_modules:
            c.check("module-in-hf03a:" + name, name in modules)

        # (3) every edge used is an HF-03b allowed edge
        row_edges = re.findall(r"\bD\d\d\b", cells[3])
        if "D10 to D16" in cells[3]:
            row_edges = ["D%02d" % n for n in range(10, 17)]
        named_edges.update(row_edges)
        for edge in row_edges:
            if not c.check("edge-in-hf03b:" + rid + ":" + edge, edge in edges, cells[3]):
                continue
            pair = {edges[edge]["from"], edges[edge]["to"]}
            if edges[edge]["to"] == "Values":
                continue
            c.check(
                "edge-endpoints-match:" + rid + ":" + edge,
                pair.issubset(set(row_modules)) or pair & set(row_modules) == pair,
                cells[2] + " vs " + edges[edge]["from"] + "->" + edges[edge]["to"],
            )
        is_local = "local" in cells[3]
        is_none = cells[3].strip() == "none"

        for command in commands_in(cells[4]):
            named_commands.add(command)
            # (2) the command appears in a named module's exposed-command list
            owners = [m for m in row_modules if command in modules.get(m, {}).get("commands", set())]
            c.check(
                "command-in-hf03a:" + rid + ":" + command,
                bool(owners),
                cells[2],
            )
            # (3b) with a matching permitted use on one of the row's edges
            on_edge = any(command in edges[e]["interfaces"] for e in row_edges if e in edges)
            c.check(
                "command-permitted-use:" + rid + ":" + command,
                on_edge or is_local or is_none,
                "not in the permitted-use column of " + ",".join(row_edges),
            )

    counts["modules_named"] = len(named_modules)
    counts["commands_named"] = len(named_commands)
    counts["edges_named"] = len(named_edges)
    c.check(
        "every-hf03a-module-named",
        set(MODULE_NAMES).issubset(named_modules),
        str(sorted(set(MODULE_NAMES) - named_modules)),
    )
    # `sample_input` has no module caller (HF-03b line 44); the `none` edge is
    # the only way this section may carry it.
    c.check(
        "sample-input-has-no-module-caller",
        "`sample_input` has no module caller" in paths["hf03b"].read_text(),
    )

    # --- (4) tunable parameters -------------------------------------------
    params = table_rows(section_lines, r"LP-\d\d")
    counts["parameter_rows"] = len(params)
    sourced = unset = 0
    for line_no, cells in params:
        rid = cells[0]
        if len(cells) < 5:
            c.check("parameter-row-shape:" + rid, False)
            continue
        value, source = cells[2], cells[3]
        has_line = bool(re.search(r"(?:lines?|rows?) \d+", source))
        has_question = bool(re.search(r"Q-[EP]\d\d", source))
        c.check("parameter-sourced-or-gated:" + rid, has_line or has_question, source)
        gated = bool(re.search(r"Q-P14|Q-P37", source))
        if gated:
            c.check("gated-row-states-no-value:" + rid, value.strip() == "unset", value)
        if value.strip() == "unset":
            unset += 1
        else:
            sourced += 1
    counts["parameters_sourced"] = sourced
    counts["parameters_unset"] = unset
    c.check("parameter-count-matches-prose", len(params) == 31, str(len(params)))
    c.check("parameter-split-matches-prose", (sourced, unset) == (16, 15), str((sourced, unset)))

    # --- rule-family counts against the prose -----------------------------
    families = {"LA": 9, "LR": 11, "LD": 10, "LU": 13, "LX": 17, "LF": 15}
    for prefix, expected in families.items():
        found = table_rows(section_lines, prefix + r"-\d\d")
        counts["rows_" + prefix] = len(found)
        c.check("rule-count-matches-prose:" + prefix, len(found) == expected, str(len(found)))
        c.check(
            "rule-ids-unique:" + prefix,
            len({r[1][0] for r in found}) == len(found),
        )

    # --- (5) every durable field named appears in HF-07a's CSV -------------
    field_tokens = {
        t
        for t in backticked(section)
        if re.fullmatch(r"(profile|run|preferences)\.[A-Za-z0-9_.\[\]]*", t)
    }
    counts["durable_fields_named"] = len(field_tokens)
    for token in sorted(field_tokens):
        normalised = token[:-2] if token.endswith("[]") else token
        c.check("durable-field-in-csv:" + token, normalised in csv_fields, normalised)

    # --- (6) every TH-08 rule cited exists there verbatim ------------------
    cited_rules = {
        r
        for r in re.findall(r"\b(E[QCNOXFPSI]-\d\d?)\b", section)
        if r in TH08_RULES
    }
    counts["th08_rules_cited"] = len(cited_rules)
    for rule, fragment in TH08_RULES.items():
        if rule not in cited_rules:
            continue
        rule_lines = [ln for ln in th08_lines if ln.strip().startswith("| " + rule + " |")]
        ok = bool(rule_lines) and any(fragment in ln for ln in rule_lines)
        c.check("th08-rule-verbatim:" + rule, ok, fragment)
    c.check("th08-seam-4-verbatim", TH08_SEAM4 in th08)
    c.check("th08-seam-4-cited", "Seam 4 at line 310" in section)

    # every `TH-08 line N` citation names a non-empty line of TH-08
    th08_cited_lines = set()
    for match in re.finditer(r"TH-08 lines? ([0-9]+(?:(?:, | to | and )[0-9]+)*)", section):
        th08_cited_lines.update(int(n) for n in re.findall(r"\d+", match.group(1)))
    counts["th08_lines_cited"] = len(th08_cited_lines)
    for n in sorted(th08_cited_lines):
        ok = 1 <= n <= len(th08_lines) and bool(th08_lines[n - 1].strip())
        c.check("th08-line-nonempty:" + str(n), ok)

    # --- (7) the five walks -----------------------------------------------
    scenarios = section.split("## Scenarios", 1)
    c.check("scenarios-section-present", len(scenarios) == 2)
    body = scenarios[1] if len(scenarios) == 2 else ""
    walk_blocks = {}
    walk_preconditions = {}
    for match in re.finditer(r"^### (W[A-Z]): (.*)$", body, flags=re.M):
        start = match.end()
        nxt = re.search(r"^### |^## ", body[start:], flags=re.M)
        block = body[start : start + (nxt.start() if nxt else len(body))]
        walk_blocks[match.group(1)] = block
        walk_preconditions[match.group(1)] = block.split("| Step |", 1)[0]
    counts["walks"] = len(walk_blocks)
    c.check("five-walks", set(walk_blocks) == set(WALKS), str(sorted(walk_blocks)))

    step_count = 0
    for name, phrases in WALKS.items():
        block = walk_blocks.get(name, "")
        c.check("walk-has-outcome:" + name, "**Outcome.**" in block)
        outcome = block.split("**Outcome.**", 1)[-1]
        for phrase in phrases:
            c.check("walk-outcome-states:" + name + ":" + phrase, phrase in outcome)
        steps = table_rows(block.split("\n"), name + r"\.\d+")
        step_count += len(steps)
        c.check("walk-has-steps:" + name, len(steps) >= 6, str(len(steps)))
        ok, detail = walk_order_ok(walk_preconditions.get(name, ""), steps)
        c.check("walk-no-durable-step-before-rl3:" + name, ok, detail)
        for _, cells in steps:
            if len(cells) < 7:
                c.check("walk-step-shape:" + cells[0], False)
                continue
            for edge in re.findall(r"\bD\d\d\b", cells[3]):
                c.check("walk-step-edge:" + cells[0] + ":" + edge, edge in edges)
            c.check(
                "walk-step-edge-vocabulary:" + cells[0],
                bool(re.search(r"\bD\d\d\b|local|none", cells[3])),
                cells[3],
            )
            for ref in re.findall(r"\bLI-\d\d\b", cells[4]):
                c.check(
                    "walk-step-interface-exists:" + cells[0] + ":" + ref,
                    ref in {r[1][0] for r in rows},
                )
    counts["walk_steps"] = step_count

    # the bonus occurs once across repeated grant, reload and re-equip, and the
    # discovery persists across reload and lost eligibility
    c.check(
        "bonus-once-across-the-three",
        "the bonus was in force exactly when the selection set was eligible and never twice"
        in body,
    )
    c.check(
        "discovery-persists-reload-and-lost-eligibility",
        "survived a reload and a loss of eligibility" in body,
    )

    # --- dependency hashes stated in Sources -------------------------------
    sources = section.split("## Sources", 1)[1].split("\n## ", 1)[0]
    stated = 0
    for bullet in re.findall(r"^- .*(?:\n(?!- |\n|#).*)*", sources, flags=re.M):
        link = None
        for token in re.finditer(r"\[[^\]]*\]\(([^)]+)\)|SHA256 `([0-9a-f]{64})`", bullet):
            target, digest = token.group(1), token.group(2)
            if target is not None:
                base = target.split("#")[0].strip()
                if base and not base.startswith(("http", "//")):
                    if pathlib.PurePosixPath(base).name not in ("BACKLOG.md", "TRACKING.md"):
                        link = base
                continue
            if link is None:
                c.check("hash-bound-to-link:" + digest[:12], False)
                continue
            dependency = (root / "docs/tech/sections" / link).resolve()
            stated += 1
            c.check(
                "dependency-hash:" + dependency.name,
                dependency.exists() and sha256(dependency) == digest,
                dependency.name,
            )
    counts["stated_hashes"] = stated
    c.check("stated-hashes-present", stated >= 12, str(stated))

    # --- (8) three negative controls --------------------------------------
    negatives = [
        (
            "negative:invented-command-rejected",
            not any("grant_recipe_bonus" in m["commands"] for m in modules.values())
            and "grant_recipe_bonus" not in named_commands,
        ),
        (
            "negative:invented-durable-field-rejected",
            "profile.discovery_disclosure" not in csv_fields
            and "profile.discovery_disclosure" not in field_tokens,
        ),
        (
            "negative:invented-edge-rejected",
            "D17" not in edges and "D17" not in named_edges,
        ),
    ]
    wg_steps = table_rows(walk_blocks.get("WG", "").split("\n"), r"WG\.\d+")
    injected = list(wg_steps)
    injected.insert(
        3,
        (
            0,
            [
                "WG.3a",
                "LK-1",
                "Session",
                "local",
                "LI-16 `accept_encounter_result`; `RunState`",
                "F-PROCESS",
                "A mid-level settlement injected as a negative control.",
            ],
        ),
    )
    negatives.append(
        (
            "negative:mid-level-settlement-caught",
            bool(wg_steps)
            and walk_order_ok(walk_preconditions.get("WG", ""), wg_steps)[0]
            and not walk_order_ok(walk_preconditions.get("WG", ""), injected)[0],
        )
    )
    for name, ok in negatives:
        c.check(name, ok)
    counts["negative_controls"] = len(negatives)

    # --- receipts ----------------------------------------------------------
    manifest = {
        key: {"path": str(path.relative_to(root)), "sha256": sha256(path)}
        for key, path in paths.items()
    }
    counts["checks"] = len(c.results)
    counts["failures"] = len(c.failures)
    report = {
        "task": "TH-09",
        "repository_root": str(root),
        "counts": counts,
        "failures": c.failures,
        "results": c.results,
        "limits": (
            "Source-consistency only. Hash agreement proves the dependency bytes are "
            "the ones cited and nothing about whether a claim built on them is correct. "
            "No engine, runtime, browser or gameplay behavior is established."
        ),
    }
    (out / "paper-check.json").write_text(json.dumps(report, indent=2) + "\n")
    (out / "source-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")

    for failure in c.failures:
        print("FAIL " + failure["check"] + " " + failure["detail"])
    print(
        "check_loot: %d checks, %d failures; %d fact kinds, %d interface rows, "
        "%d modules, %d commands, %d edges, %d parameter rows (%d sourced, %d unset), "
        "%d durable fields, %d TH-08 rules, %d walks with %d steps, %d stated hashes, "
        "%d negative controls."
        % (
            counts["checks"],
            counts["failures"],
            counts["fact_kinds"],
            counts["interface_rows"],
            counts["modules_named"],
            counts["commands_named"],
            counts["edges_named"],
            counts["parameter_rows"],
            counts["parameters_sourced"],
            counts["parameters_unset"],
            counts["durable_fields_named"],
            counts["th08_rules_cited"],
            counts["walks"],
            counts["walk_steps"],
            counts["stated_hashes"],
            counts["negative_controls"],
        )
    )
    return 1 if c.failures else 0


if __name__ == "__main__":
    sys.exit(main())
