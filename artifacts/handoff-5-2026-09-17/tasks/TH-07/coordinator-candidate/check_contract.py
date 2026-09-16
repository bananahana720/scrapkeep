#!/usr/bin/env python3
"""Paper check for docs/tech/sections/TH-07-four-slots-and-milestone-progression.md.

It compares the section against the admitted sibling sections at the recorded base
and exercises a model of the tree-shape rule over synthetic graphs. It proves
document consistency and the internal coherence of the stated rule. It proves
nothing about engine behaviour, storage, an implemented validator or feel.
"""

import argparse
import hashlib
import json
import re
from pathlib import Path

SECTION = "docs/tech/sections/TH-07-four-slots-and-milestone-progression.md"
MODULE_MAP = "docs/tech/sections/HF-03a-module-map.md"
GRAPH = "docs/tech/sections/HF-03b-dependency-graph.md"
ENVELOPE_CSV = "docs/tech/sections/HF-07a-save-envelope.csv"
BACKLOG = "BACKLOG.md"

MODULES = [
    "Session",
    "Encounter",
    "CollisionQueries",
    "ContentAdmission",
    "Persistence",
    "InputAdapter",
    "Presentation",
]

# HF-05 lines 101 and 117 name the two diagnostic types that HF-03a line 34 lists in
# prose as ContentAdmission's "compatibility and missing-ID diagnostics"; the type
# names are admitted here rather than treated as unlisted interfaces.
DIAGNOSTIC_TYPES = {"ContentReferenceFailure", "ContentAdmissionFailure"}

BACKTICK = re.compile(r"`([^`]+)`")
EDGE_ID = re.compile(r"\bD(\d{2})\b")
EDGE_RANGE = re.compile(r"\bD(\d{2}) to D(\d{2})\b")
QUESTION = re.compile(r"\bQ-[EP]\d+\b")
SOURCE_LINE = re.compile(r"\bline[s]?\s+\d+", re.IGNORECASE)
FIELD_PATH = re.compile(r"^(run|profile|preferences)\.[A-Za-z0-9_.\[\]]+$")

# Shapes a step would take if it decided Q-P18 rather than checking a permission.
QP18_ANSWERS = [
    re.compile(r"\brespec\w*\b[^.]{0,40}\b(?:once|twice|per run|per world|per level|every \w+)\b", re.IGNORECASE),
    re.compile(r"\brefunds?\b[^.]{0,40}\b\d+\s*(?:%|per cent|percent)\b", re.IGNORECASE),
    re.compile(r"\brefunds?\b[^.]{0,20}\b(?:full|half|partial|none of)\b", re.IGNORECASE),
    re.compile(r"\bopportunit\w+\b[^.]{0,40}\b(?:per|every|each)\s+(?:run|world|level|region|intermission)\b", re.IGNORECASE),
    re.compile(r"\brespec\w*\s+costs?\b[^.]{0,20}\d", re.IGNORECASE),
]


def rows(lines, start_predicate):
    out = []
    for index, line in enumerate(lines):
        if not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if cells and start_predicate(cells[0]):
            out.append((index + 1, cells))
    return out


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class Check:
    def __init__(self):
        self.results = []

    def add(self, name, ok, detail, count=None):
        self.results.append(
            {"check": name, "status": "PASS" if ok else "FAIL", "detail": detail, "count": count}
        )

    def note(self, name, detail):
        self.results.append({"check": name, "status": "NOTE", "detail": detail, "count": None})

    @property
    def failures(self):
        return [r for r in self.results if r["status"] == "FAIL"]


def parse_modules(text):
    table = rows(text.splitlines(), lambda first: first.split(".")[0].strip() in MODULES)
    modules = {}
    for _, cells in table:
        if len(cells) < 5:
            continue
        name = cells[0].split(".")[0].strip()
        modules[name] = {
            "records": set(BACKTICK.findall(cells[1])),
            "commands": set(BACKTICK.findall(cells[3])),
            "results": set(BACKTICK.findall(cells[4])),
        }
    return modules


def parse_edges(text):
    table = rows(text.splitlines(), lambda first: re.fullmatch(r"D\d{2}", first) is not None)
    return {
        cells[0]: {"from": cells[1], "to": cells[2], "interfaces": set(BACKTICK.findall(cells[3]))}
        for _, cells in table
    }


def parse_fields(csv_text):
    return {line.split(",")[0].strip() for line in csv_text.splitlines()[1:] if line.strip()}


def expand_edges(cell):
    found = set()
    for low, high in EDGE_RANGE.findall(cell):
        for value in range(int(low), int(high) + 1):
            found.add("D%02d" % value)
    for value in EDGE_ID.findall(cell):
        found.add("D" + value)
    return found


def modules_in(cell):
    if "Every module" in cell:
        return set(MODULES) | {"Values"}
    return {name for name in MODULES + ["Values"] if re.search(r"\b" + name + r"\b", cell)}


def check_step(check_id, cells, columns, modules, edges, problems):
    caller_cell, edge_cell, interface_cell = (cells[c] for c in columns)
    used = expand_edges(edge_cell)
    named = modules_in(caller_cell)
    for edge in sorted(used):
        if edge not in edges:
            problems.append("%s uses %s, absent from the adjacency list" % (check_id, edge))
            continue
        if not named:
            continue
        for end in ("from", "to"):
            if edges[edge][end] not in named:
                problems.append(
                    "%s uses %s whose %s is %s, not named in %r"
                    % (check_id, edge, end, edges[edge][end], caller_cell)
                )
    local = "local" in edge_cell or "none" in edge_cell
    allowed_row = set(DIAGNOSTIC_TYPES)
    allowed_edge = set(DIAGNOSTIC_TYPES)
    for edge in used:
        if edge in edges:
            target = edges[edge]["to"]
            if target in modules:
                allowed_row |= modules[target]["commands"] | modules[target]["results"]
            allowed_edge |= edges[edge]["interfaces"]
    if local:
        for name in named:
            if name in modules:
                own = modules[name]
                everything = own["commands"] | own["results"] | own["records"]
                allowed_row |= everything
                allowed_edge |= everything
    for token in BACKTICK.findall(interface_cell):
        if token not in allowed_row:
            problems.append("%s names %r, outside the target module's HF-03a row" % (check_id, token))
        if token not in allowed_edge:
            problems.append("%s names %r, outside the edge's permitted-use column" % (check_id, token))


# --- a model of the tree-shape rule (PT-01 to PT-08, PT-13) --------------------


def canonical_tree(depth=3, fanout=2):
    """The shape BIBLE line 529 and HF-05 line 50 fix: 1 + 2 + 4 + 8 nodes."""
    nodes, edges, frontier = ["r"], [], ["r"]
    for _ in range(depth):
        nxt = []
        for parent in frontier:
            for index in range(fanout):
                child = parent + str(index)
                nodes.append(child)
                edges.append((parent, child))
                nxt.append(child)
        frontier = nxt
    return nodes, edges


def shape_violations(nodes, edges):
    """PT-01 to PT-06 as independent checks; each returns its own finding."""
    found = []
    if len(set(nodes)) != len(nodes):
        found.append("PT-01 duplicate node identity")
    if len(nodes) != 15:
        found.append("PT-01 nodes=%d" % len(nodes))
    if len(edges) != 14:
        found.append("PT-02 edges=%d" % len(edges))
    parents = {}
    children = {node: [] for node in nodes}
    for parent, child in edges:
        parents.setdefault(child, []).append(parent)
        children.setdefault(parent, []).append(child)
    roots = [node for node in nodes if node not in parents]
    if len(roots) != 1:
        found.append("PT-02 roots=%d" % len(roots))
    multi = [child for child, ps in parents.items() if len(ps) > 1]
    if multi:
        found.append("PT-05 reconvergence at %s" % ",".join(sorted(multi)))
    endpoints = [node for node in nodes if not children.get(node)]
    if len(endpoints) != 8:
        found.append("PT-03 endpoints=%d" % len(endpoints))
    bad_fanout = [n for n in nodes if children.get(n) and len(children[n]) != 2]
    if bad_fanout:
        found.append("PT-04 fanout at %s" % ",".join(sorted(bad_fanout)))
    if len(roots) == 1 and not multi:
        seen, stack, depths = set(), [(roots[0], 0)], []
        while stack:
            node, d = stack.pop()
            if node in seen:
                found.append("PT-05 cycle at %s" % node)
                break
            seen.add(node)
            if not children.get(node):
                depths.append(d)
            for child in children.get(node, []):
                stack.append((child, d + 1))
        if len(seen) != len(nodes):
            found.append("PT-05 unreachable nodes=%d" % (len(nodes) - len(seen)))
        if depths and set(depths) != {3}:
            found.append("PT-06 endpoint depths=%s" % sorted(set(depths)))
    return found


def prefix_violations(nodes, edges, tree_id, slot_tree_id, keys, root_written):
    """PT-07, PT-08 and PT-13: the stored array, extended by the root when the root
    is not written, is a path from the root of the slot's own tree."""
    found = []
    if tree_id != slot_tree_id:
        found.append("PT-07 key sequence belongs to %s, slot names %s" % (tree_id, slot_tree_id))
        return found
    children = {node: [] for node in nodes}
    parents = {}
    for parent, child in edges:
        children[parent].append(child)
        parents[child] = parent
    roots = [node for node in nodes if node not in parents]
    if len(roots) != 1:
        return ["PT-02 roots=%d" % len(roots)]
    walk = list(keys) if root_written else [roots[0]] + list(keys)
    if not walk:
        return found
    if walk[0] != roots[0]:
        found.append("PT-08 first entry %s is not the root" % walk[0])
    for previous, nxt in zip(walk, walk[1:]):
        if nxt not in children.get(previous, []):
            found.append("PT-08 %s is not a child of %s" % (nxt, previous))
    if len(walk) > 4:
        found.append("PT-06 prefix length %d exceeds the four-node lineage" % len(walk))
    return found


def model_checks(check):
    nodes, edges = canonical_tree()
    check.add(
        "model:shape-accepts-canonical",
        not shape_violations(nodes, edges),
        "a 15-node, 14-edge, eight-endpoint binary connected tree of depth three is accepted",
        len(nodes),
    )

    # Malformed A: rewire one child so one nonterminal has three children and another one.
    # Node and edge totals are unchanged, so PT-04 alone must carry the rejection.
    rewired = [e for e in edges if e != ("r1", "r10")] + [("r0", "r10")]
    malformed_a = shape_violations(nodes, rewired)
    counts_intact = not any(v.startswith(("PT-01", "PT-02", "PT-03")) for v in malformed_a)
    # Malformed B: an extra node and edge break the totals.
    malformed_b = shape_violations(nodes + ["x"], edges + [("r000", "x")])
    check.add(
        "model:shape-rejects-malformed",
        any(v.startswith("PT-04") for v in malformed_a)
        and counts_intact
        and any(v.startswith("PT-01") for v in malformed_b)
        and any(v.startswith("PT-02") for v in malformed_b),
        "a nonterminal with three children is rejected by PT-04 with node, edge and endpoint totals intact (%s); "
        "a sixteenth node is rejected by PT-01 and PT-02 (%s)"
        % ("; ".join(malformed_a), "; ".join(malformed_b)),
        len(malformed_a) + len(malformed_b),
    )
    malformed = malformed_a

    # Illegal crosspath: an extra edge gives one node two parents.
    cross_edges = edges + [("r00", "r10")]
    crosspath = shape_violations(nodes, cross_edges)
    check.add(
        "model:shape-rejects-crosspath",
        any(v.startswith("PT-05") for v in crosspath) and any(v.startswith("PT-02") for v in crosspath),
        "an edge that gives a node two parents is rejected: %s" % "; ".join(crosspath),
        len(crosspath),
    )

    lineage = ["r0", "r00", "r000"]
    accepted = 0
    for length in range(0, 4):
        for root_written in (False, True):
            keys = (["r"] if root_written else []) + lineage[:length]
            if prefix_violations(nodes, edges, "t1", "t1", keys, root_written):
                check.add(
                    "model:prefix-accepts-len%d-root%s" % (length, root_written),
                    False,
                    "a connected prefix of length %d was rejected" % length,
                )
            else:
                accepted += 1
    check.add(
        "model:prefix-accepts-connected",
        accepted == 8,
        "every connected prefix from empty to a complete lineage is accepted under both PT-13 encodings",
        accepted,
    )
    check.add(
        "model:prefix-rejects-disconnected",
        bool(prefix_violations(nodes, edges, "t1", "t1", ["r0", "r10"], False)),
        "a prefix whose second entry is not a child of the first is rejected",
    )
    check.add(
        "model:prefix-rejects-skipped-rank",
        bool(prefix_violations(nodes, edges, "t1", "t1", ["r0", "r000"], False)),
        "a prefix that skips a rank is rejected",
    )
    check.add(
        "model:prefix-rejects-foreign-tree",
        bool(prefix_violations(nodes, edges, "t2", "t1", ["r0"], False)),
        "a key sequence from a tree the slot does not name is rejected",
    )
    check.add(
        "model:prefix-rejects-overlong",
        bool(prefix_violations(nodes, edges, "t1", "t1", ["r", "r0", "r00", "r000", "r000"], True)),
        "a prefix longer than the four-node lineage is rejected",
    )

    # Negative control 1: a checker that only counted nodes would admit both defects.
    counts_only = len(nodes) == 15
    check.add(
        "negative:count-only-check-would-admit",
        counts_only and bool(malformed) and bool(crosspath),
        "counting nodes alone admits the malformed tree and the crosspath, which PT-04 and PT-05 catch separately",
        2,
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    root = Path(args.root).resolve()
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)

    check = Check()
    section_path = root / SECTION
    section = section_path.read_text()
    lines = section.splitlines()
    modules = parse_modules((root / MODULE_MAP).read_text())
    edges = parse_edges((root / GRAPH).read_text())
    fields = parse_fields((root / ENVELOPE_CSV).read_text())

    check.add("sources:module-table", len(modules) == 7, "HF-03a module table parsed", len(modules))
    check.add("sources:adjacency", len(edges) == 16, "HF-03b adjacency list parsed", len(edges))
    check.add("sources:envelope", len(fields) == 70, "HF-07a CSV field paths parsed", len(fields))

    stated = {
        MODULE_MAP: "95fbd03d067fd0da2d122130ae3c54284116adc92f40c7f69c91946fd941e4cc",
        GRAPH: "7c29b6ee0fcff3749c0d30d69b3977d529732338dd794ee0019d6a6a1392d183",
        "docs/tech/sections/HF-04a-runtime-lifecycle.md": "cca7c341b0a163b0010e47c948af3d749e74c9a7fb61f475a3d332824215f91a",
        "docs/tech/sections/HF-05-content-admission.md": "7ef95df2fb25f05b7b544cd7dbf2239cd1106c382aab0e8bc5e76288146259a6",
        "docs/tech/sections/HF-06a-schema-inventory.md": "fd0bd9b345aef1e0b5aec4383055ed8e692ab01f7fb1194924cbed1201ff5fa7",
        "docs/tech/sections/HF-07a-save-envelope.md": "dfcd6a98d2fe8d07f69ff5bb336f563192604ad383a106b05902d9a60ea87d06",
        ENVELOPE_CSV: "96212b0087f2cd971e272078679e39e3ba24417d2ce8d01f92b312e4dc827941",
        "docs/tech/sections/HF-07b-commit-boundaries.md": "901ce28c13428fac7612aa10f242e72f211190d3fd838124154e52a2d6a9cd38",
        "docs/tech/sections/TH-01-complete-loop.md": "19be9309823a37bb833112a408a01898b59fa558f5288f168dacb1918119097c",
        "docs/tech/sections/TH-02-movement-camera-and-active-aim.md": "f688e706ef86b4dd645ca20c425a7eba2e354a875cb794448faeb1ac335db711",
        "docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md": "995a06e58bc73a2865abb01cd0a9775c36627ceff9f431fed6de1a6bb0a0a75b",
        "docs/tech/sections/TH-04-abilities-ultimates-and-combat-rhythm.md": "f14a3d92fcb142c697545b41c9d704bc37f7a4526c6a5200e007c8bc9de082d6",
        "docs/tech/sections/TH-05-electromagnetic-collection-recycling-and-growth.md": "23af82641b445bd8352db67dfb49b7f3ab249bae85aa8ef4348747d48bd34bda",
        "docs/tech/sections/TH-08-inventory-equipment-and-transformations.md": "4db92349abe3d357e3ba487a49b2b55abf0a9f40f333b769fe2a672b8bee3218",
        "docs/tech/sections/TH-11-runs-regions-exits-and-saves.md": "c094a1360ae62755b99888b1b1fac8ff76ae13f027a060d1dac6189e0dec21bd",
        "artifacts/foundation-sprint-2026-09/HF-10-foundation-review.md": "ba7e4cf9e5d0c50fb8f4bb438f737e60d9fd6702baaabcaabaab86018826da30",
        "src/orchard/simulation.js": "5c82acfbd87761f8d94976b0485e6c0b0eb2ec03d1b133af17f12ad1eb1121bd",
        "docs/project/INCREMENT-01-lightning-playtest.md": "12c28df3d6a612177bedb125197300d5d853c793e6acce7b83b2eb40d07c85f2",
        "docs/LIGHTNING-VERIFICATION.md": "594a42cab22f1ccfed202a982a09cf81392fea0b964839f61eed7efcc83e43fd",
        "docs/DISCOVERY.md": "aa63ea75bce3bfbff849631617ea9768d7cbb8a9a32aa8373edc40c73f242474",
    }
    drift = []
    for relative, expected in sorted(stated.items()):
        actual = sha256(root / relative)
        if actual != expected:
            drift.append("%s stated %s actual %s" % (relative, expected, actual))
        if ("`%s`" % expected) not in section:
            drift.append("%s hash absent from the section's Sources bullets" % relative)
    check.add("sources:hashes", not drift, "; ".join(drift) or "every stated dependency hash matches", len(stated))

    backlog = (root / BACKLOG).read_text().splitlines()
    card = []
    for index, line in enumerate(backlog):
        if line.startswith("### TH-07:"):
            card = [line]
            for follow in backlog[index + 1 :]:
                if follow.startswith("### ") or follow.startswith("<a id="):
                    break
                card.append(follow)
            break
    card_text = "\n".join(card).strip()
    card_hash = hashlib.sha256(card_text.encode()).hexdigest()
    check.add("card:present", bool(card_text), "exact TH-07 card text located and hashed %s" % card_hash, len(card))
    for phrase in ("15 nodes, 14 edges, eight endpoints", "Q-P18", "Q-P10/Q-P11", "malformed tree", "illegal crosspath"):
        check.add("card:phrase:%s" % phrase[:26], phrase in card_text, "card phrase present: %r" % phrase)

    headings = [line[3:].strip() for line in lines if line.startswith("## ")]
    required = [
        "Sources",
        "Contract",
        "Scenarios",
        "Unresolved questions",
        "Re-verification triggers",
        "Procedure performed",
        "Evidence limits",
    ]
    check.add(
        "section:headings",
        all(name in headings for name in required),
        "required level-two headings present: %s" % ", ".join(headings),
        len(headings),
    )
    dod5 = [
        "### Interfaces",
        "### Owned data",
        "### Algorithms and update order",
        "### Edge cases",
        "### Failure modes",
        "### Tunable parameters",
    ]
    check.add(
        "section:dod5-subsections",
        all(name in lines for name in dod5),
        "explicit subsections for interfaces, owned data, algorithms, edge cases, failure modes and parameters",
        len(dod5),
    )

    interface_rows = rows(lines, lambda first: re.fullmatch(r"PI-\d+", first) is not None)
    problems = []
    for _, cells in interface_rows:
        check_step(cells[0], cells, (2, 3, 4), modules, edges, problems)
    check.add(
        "interfaces:edges-and-commands",
        not problems,
        "; ".join(problems) or "every interface row uses a listed edge and a listed interface",
        len(interface_rows),
    )

    named_modules = set()
    for _, cells in interface_rows:
        named_modules |= modules_in(cells[2])
    check.add(
        "interfaces:every-module-named",
        set(MODULES) | {"Values"} <= named_modules,
        "modules named: %s" % ", ".join(sorted(named_modules)),
        len(named_modules),
    )

    walk_rows = rows(lines, lambda first: re.fullmatch(r"W[MCUR]\.\d+", first) is not None)
    walk_problems = []
    for _, cells in walk_rows:
        check_step(cells[0], cells, (2, 3, 4), modules, edges, walk_problems)
    check.add(
        "walks:edges-and-commands",
        not walk_problems,
        "; ".join(walk_problems) or "every walk step uses a listed edge and a listed interface",
        len(walk_rows),
    )

    walks = {"WM": "malformed tree", "WC": "illegal crosspath", "WU": "world-one unlock", "WR": "special respec"}
    outcomes = []
    for prefix, name in walks.items():
        steps = [cells for _, cells in walk_rows if cells[0].startswith(prefix + ".")]
        if not steps:
            outcomes.append("%s (%s) has no steps" % (prefix, name))
            continue
        text = " ".join(cells[-1] for cells in steps)
        if ("**%s outcome:" % prefix) not in text:
            outcomes.append("%s (%s) reaches no named outcome" % (prefix, name))
    check.add("walks:named-outcome", not outcomes, "; ".join(outcomes) or "each of the four walked cases reaches a named outcome", len(walks))

    answered = []
    for _, cells in walk_rows:
        row_text = " ".join(cells)
        for pattern in QP18_ANSWERS:
            if pattern.search(row_text):
                answered.append("%s: %s" % (cells[0], pattern.pattern))
    respec_text = " ".join(" ".join(c) for _, c in walk_rows if c[0].startswith("WR."))
    check.add(
        "walks:no-qp18-answer",
        not answered and "Q-P18" in respec_text,
        "; ".join(answered) or "no walk states a respec scope, frequency, refund or price, and the respec walk names Q-P18 as open",
        len(walk_rows),
    )

    parameter_rows = rows(lines, lambda first: re.fullmatch(r"PP-\d+", first) is not None)
    unsourced, unset = [], 0
    qp18_rows = []
    for _, cells in parameter_rows:
        if cells[2].strip() == "unset":
            unset += 1
        if not (QUESTION.search(cells[3]) or SOURCE_LINE.search(cells[3])):
            unsourced.append(cells[0])
        if "Q-P18" in cells[3]:
            qp18_rows.append((cells[0], cells[2].strip()))
    check.add(
        "parameters:sourced-or-gated",
        not unsourced,
        "unsourced rows: %s" % ", ".join(unsourced) if unsourced else "every parameter row carries a source line or a question ID",
        len(parameter_rows),
    )
    check.add("parameters:unset-count", unset > 0, "%d rows are unset and gate a dependent implementation" % unset, unset)
    check.add(
        "parameters:qp18-all-unset",
        bool(qp18_rows) and all(value == "unset" for _, value in qp18_rows),
        "Q-P18 rows and values: %s" % ", ".join("%s=%s" % r for r in qp18_rows),
        len(qp18_rows),
    )

    shape_rows = rows(lines, lambda first: re.fullmatch(r"PT-\d+", first) is not None)
    check.add("section:shape-rules", len(shape_rows) >= 8, "shape rules stated as table rows", len(shape_rows))

    cited_fields = {t for t in BACKTICK.findall(section) if FIELD_PATH.fullmatch(t)}
    unknown = sorted(f for f in cited_fields if f not in fields and f.rstrip("[]") not in fields)
    check.add(
        "durable:fields-in-envelope",
        not unknown,
        "unknown field paths: %s" % ", ".join(unknown) if unknown else "every durable field path named appears in HF-07a's CSV",
        len(cited_fields),
    )

    invented = re.findall(
        r"\b(?:node cost|respec cost|refund|milestone allocation|opportunit\w+)\s+(?:is|of|are)\s+(\d+)", section
    )
    check.add(
        "product:no-invented-values",
        not invented,
        "invented values: %s" % ", ".join(invented) if invented else "no numeric node cost, respec cost, refund, allocation or opportunity count is stated",
        len(invented),
    )

    model_checks(check)

    fake_step = ["NC-1", "PG-4", "Presentation to Encounter", "D99", "`install_effective_build`", "", ""]
    nc1 = []
    check_step("NC-1", fake_step, (2, 3, 4), modules, edges, nc1)
    check.add("negative:unlisted-edge-detected", bool(nc1), "; ".join(nc1) or "an unlisted edge was NOT detected", len(nc1))

    fake_parameter = ["NC-2", "An invented respec frequency", "one per world", "no source", "nothing"]
    nc2 = not (QUESTION.search(fake_parameter[3]) or SOURCE_LINE.search(fake_parameter[3]))
    check.add("negative:unsourced-parameter-detected", nc2, "a parameter row with neither a source line nor a question ID is rejected")

    fake_walk = (
        "NC-3 | PG-4 | Session | local | `request_respec` | F-PROCESS | "
        "A respec is permitted once per world, the refund is 50%, and one opportunity exists per region."
    )
    nc3 = any(pattern.search(fake_walk) for pattern in QP18_ANSWERS)
    check.add("negative:qp18-answer-detected", nc3, "a walk step that states a respec frequency or refund is detected")

    nc4 = "run.checkpoint.build.slots[].milestone_count" not in fields
    check.add("negative:unknown-durable-field-detected", nc4, "a field path absent from HF-07a's CSV is rejected")

    whole_backlog = sha256(root / BACKLOG)
    check.note("note:backlog-drift", "whole BACKLOG.md sha256 %s; the exact TH-07 card is hashed separately above" % whole_backlog)
    check.note(
        "note:limits",
        "Document and model consistency only. No engine, storage, browser or native behaviour is established, "
        "and the shape model is evidence about the rule as written, not about any validator.",
    )

    report = {
        "section": SECTION,
        "section_sha256": sha256(section_path),
        "root": str(root),
        "card_sha256": card_hash,
        "checks": check.results,
        "counts": {
            "interface_rows": len(interface_rows),
            "walk_steps": len(walk_rows),
            "walks": len(walks),
            "shape_rules": len(shape_rows),
            "parameter_rows": len(parameter_rows),
            "unset_parameters": unset,
            "modules": len(modules),
            "edges": len(edges),
            "envelope_fields": len(fields),
            "cited_field_paths": len(cited_fields),
            "pass": len([r for r in check.results if r["status"] == "PASS"]),
            "fail": len(check.failures),
            "note": len([r for r in check.results if r["status"] == "NOTE"]),
        },
    }
    (out / "paper-check.json").write_text(json.dumps(report, indent=2) + "\n")
    for result in check.results:
        print("%-6s %-46s %s" % (result["status"], result["check"], result["detail"]))
    print("counts %s" % json.dumps(report["counts"]))
    return 1 if check.failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
