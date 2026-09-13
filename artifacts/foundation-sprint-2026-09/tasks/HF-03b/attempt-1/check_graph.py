#!/usr/bin/env python3
"""HF-03b paper checks. Source review only; no engine runs.

usage: check_graph.py [repository-root] [--out receipt-directory]

The adjacency list, walkthroughs and register are read from the section file
in the given repository. Receipts (graph-check.json, graph-check.log) are
written beside this script unless --out names another directory.
"""
import hashlib
import json
import re
import subprocess
import sys
from collections import deque
from pathlib import Path

SECTION = "docs/tech/sections/HF-03b-dependency-graph.md"
HF03A = "docs/tech/sections/HF-03a-module-map.md"
HF03A_SHA = "95fbd03d067fd0da2d122130ae3c54284116adc92f40c7f69c91946fd941e4cc"
HF04A = "docs/tech/sections/HF-04a-runtime-lifecycle.md"
BASE = "d98803c555bedcd3d68e5d82efafb1a2d0bcf31b"
MODULES = ["Session", "Encounter", "CollisionQueries", "ContentAdmission", "Persistence", "InputAdapter", "Presentation"]
NODES = MODULES + ["Values"]
PROOF_DIR = "native/proofs/tadr-002"
PROOF_REPORT = "artifacts/prepare-stage-2026-09-06/tasks/S0-04/native-smoke-report.json"
EXPECTED_PROOF_EDGES = {
    ("session_owner", "encounter_coordinator"),
    ("session_owner", "input_adapter"),
    ("encounter_coordinator", "input_adapter"),
    ("encounter_coordinator", "encounter_state"),
    ("encounter_state", "encounter_state"),
    ("intruder", "encounter_coordinator"),
    ("intruder", "encounter_state"),
    ("proof_runner", "session_owner"),
    ("proof_runner", "encounter_coordinator"),
    ("proof_runner", "encounter_state"),
    ("proof_runner", "input_adapter"),
    ("proof_runner", "menu_probe"),
    ("proof_runner", "intruder"),
}
CLAUSES = {
    "adr/TADR-002-runtime-model.md": {
        24: "global gameplay event bus",
        26: "One application/session owner",
        28: "One collision-query owner",
        30: "resolves the attack once",
        32: "Signals may report committed results through scoped connections",
        34: "Input release, prepared-action cancellation and solo pause are distinct",
    },
    "adr/TADR-004-persistence.md": {
        26: "checkpoint projection retains build selections",
        28: "One owner stages a complete candidate",
        32: "hold the transition",
    },
    "docs/adr/0003-authoritative-attack-geometry.md": {
        7: "world-space capsules",
        11: "resolves obstruction from the weapon origin",
        13: "Preserve one authoritative geometry definition",
    },
    "BIBLE.md": {
        483: "active aim",
        491: "committed danger shape",
        493: "weapon-origin geometry remains authoritative",
        495: "preview, choose, commit and observe",
        519: "Compact levels can mix waves",
        521: "Enemies pressure movement",
        548: "Acquisition and equipment are separate states",
        550: "what will stop working",
        552: "removed equipment stops contributing",
        608: "it must not reroll loot",
    },
    HF03A: {
        19: "sole application/session authority",
        27: "Values is a type vocabulary",
        31: "all six other modules",
        32: "InputAdapter frame reader injected by Session",
        33: "only on Encounter's ordered request",
        34: "no live run or presentation module",
        35: "Session-supplied catalogue resolver contract",
        36: "Session supplies routing, Encounter reads frames",
        37: "UI commands remain requests read by Session",
        39: "Presentation holds no callback that mutates Session",
        46: "Encounter cannot keep a writable RunState alias",
        49: "Session alone installs it",
        51: "cue consumption does not settle rewards",
        55: "Submission may append to an owner's inbox",
        56: "detached value snapshots",
        57: "rebuilds EffectiveBuild from selections",
        59: "Both count as dependency edges",
        60: "gameplay callers cannot use a global name",
        61: "A listener cannot turn a result notification into a hidden mutation chain",
        67: "`encounter_state.gd` self-preloads its return type",
        71: "production modules must not import it as implementation",
        83: "| M05 |",
        84: "| M06 |",
        99: "autoload versus persistent composition-node bootstrap",
    },
    HF04A: {
        26: "control drain",
        28: "The existing HF-03a dependency directions remain binding",
        36: "Encounter never reads SessionControl through a reverse import",
        44: "F-PROCESS",
        46: "F-INPUT",
        49: "F-SIGNAL",
        53: "signals can still invoke connected methods on paused nodes",
        62: "P1: command boundary",
        64: "P3: movement and synchronization",
        65: "P4: attack commitments",
        66: "P5: outcome application",
        67: "P6: commit and publish",
        75: "Encounter owns EncounterInbox",
        79: "clear the old interpolation pair",
        81: "Committed gameplay result batches are retained",
        87: "O1: release held physical input",
        88: "O2: cancel prepared actions",
        89: "O3: solo pause",
        90: "O4: resume",
        108: "Session marks the outgoing identity as closing",
        109: "Session calls Encounter `retire`",
        110: "Session disconnects each scoped subscription",
        111: "Session calls Presentation `release_encounter_views`",
        112: "Session resolves the admitted pinned content",
        113: "Publish an initial same-encounter snapshot",
    },
    "docs/tech/sections/HF-05-content-admission.md": {
        31: "Persistence receives a resolver through Session",
        56: "Session rebuilds `EffectiveBuild`",
    },
    "docs/tech/proofs/S0-04-runtime-ownership.md": {
        53: "### Not proven",
        57: "controller feel, rendering interpolation",
        115: "does not prove that GDScript prevents such writes",
    },
    PROOF_DIR + "/session_owner.gd": {
        3: 'preload("res://proofs/tadr-002/encounter_coordinator.gd")',
        4: 'preload("res://proofs/tadr-002/input_adapter.gd")',
        8: "InputAdapter.new()",
        9: "EncounterCoordinator.new()",
        14: "coordinator.input = input",
        15: "add_child(coordinator)",
        19: "get_tree().paused = true",
        23: "get_tree().paused = false",
        27: "input.clear_held()",
        28: "CMD_CANCEL_PREPARED",
    },
    PROOF_DIR + "/encounter_coordinator.gd": {
        3: 'preload("res://proofs/tadr-002/encounter_state.gd")',
        4: 'preload("res://proofs/tadr-002/input_adapter.gd")',
        9: "var input: InputAdapter",
        13: "EncounterState.new()",
        27: "_state.snapshot()",
        50: "input.frame()",
    },
    PROOF_DIR + "/encounter_state.gd": {3: 'preload("res://proofs/tadr-002/encounter_state.gd")'},
    PROOF_DIR + "/intruder.gd": {
        3: 'preload("res://proofs/tadr-002/encounter_coordinator.gd")',
        4: 'preload("res://proofs/tadr-002/encounter_state.gd")',
        37: "coordinator.advance_external()",
        42: "coordinator._state.tick += 1",
    },
    PROOF_DIR + "/proof_runner.gd": {
        3: "session_owner.gd",
        8: "intruder.gd",
        28: "intruder.coordinator = session.coordinator",
        52: "session.coordinator",
        72: "rejected_out_of_phase >= 2",
        80: 'session.input.press("cast")',
    },
}


def parse_args(argv):
    root = Path.cwd()
    out = Path(__file__).resolve().parent
    positional = []
    index = 0
    while index < len(argv):
        if argv[index] == "--out" and index + 1 < len(argv):
            out = Path(argv[index + 1]).resolve()
            index += 2
        else:
            positional.append(argv[index])
            index += 1
    if len(positional) > 1:
        sys.exit(__doc__)
    if positional:
        root = Path(positional[0]).resolve()
    return root, out


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def git(root, *args):
    result = subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else "unavailable: " + result.stderr.strip()


def table_rows(text, first_cell):
    pattern = re.compile(r"^\|\s*(" + first_cell + r")\s*\|")
    rows = []
    for line in text.splitlines():
        if pattern.match(line):
            rows.append([cell.strip() for cell in line.strip().strip("|").split("|")])
    return rows


def between(text, start, end):
    head = text.split(start, 1)
    if len(head) < 2:
        return ""
    return head[1].split(end, 1)[0]


def backticked(cell):
    return re.findall(r"`([^`]+)`", cell)


class Checks:
    def __init__(self):
        self.items = []

    def add(self, name, passed, detail):
        self.items.append({"name": name, "status": "pass" if passed else "fail", "detail": detail})
        return passed

    @property
    def failures(self):
        return [item for item in self.items if item["status"] == "fail"]


def load_hf03a(root, checks):
    doc = (root / HF03A).read_bytes()
    checks.add("hf03a-admitted-bytes", sha256(doc) == HF03A_SHA, sha256(doc))
    text = doc.decode()
    table = between(text, "### Module table", "### Record meanings")
    modules = {}
    for row in table_rows(table, r"[A-Za-z]+\.[^|]*"):
        name = row[0].split(".", 1)[0].strip()
        modules[name] = {
            "records": backticked(row[1]),
            "commands": backticked(row[3]),
            "results": backticked(row[4]),
        }
    checks.add("hf03a-seven-module-rows", sorted(modules) == sorted(MODULES), sorted(modules))
    return modules


def load_graph(section, checks):
    rows = table_rows(section, r"D\d\d")
    edges = {}
    for row in rows:
        edge_id, source, target, use = row[0], row[1], row[2], row[3]
        checks.add("edge-nodes-" + edge_id, source in NODES and target in NODES and source != target, source + " -> " + target)
        checks.add("edge-unique-" + edge_id, edge_id not in edges, edge_id)
        edges[edge_id] = (source, target, use)
    pairs = {(s, t) for s, t, _ in edges.values()}
    checks.add("edge-count", len(edges) == 16 and len(pairs) == 16, str(len(edges)))
    return edges, pairs


def kahn(pairs):
    indegree = {node: 0 for node in NODES}
    for _, target in pairs:
        indegree[target] += 1
    queue = deque(node for node in NODES if indegree[node] == 0)
    order = []
    while queue:
        node = queue.popleft()
        order.append(node)
        for source, target in sorted(pairs):
            if source == node:
                indegree[target] -= 1
                if indegree[target] == 0:
                    queue.append(target)
    return order


def dfs_cycle(pairs):
    adjacency = {node: sorted(t for s, t in pairs if s == node) for node in NODES}
    state = {node: 0 for node in NODES}

    def visit(node):
        state[node] = 1
        for nxt in adjacency[node]:
            if state[nxt] == 1 or (state[nxt] == 0 and visit(nxt)):
                return True
        state[node] = 2
        return False

    return any(state[node] == 0 and visit(node) for node in NODES)


def reachable(pairs, start):
    seen = {start}
    stack = [start]
    while stack:
        node = stack.pop()
        for source, target in pairs:
            if source == node and target not in seen:
                seen.add(target)
                stack.append(target)
    return seen


def check_graph_properties(pairs, checks):
    order = kahn(pairs)
    checks.add("acyclic-kahn", len(order) == len(NODES), " ".join(order))
    checks.add("acyclic-dfs", not dfs_cycle(pairs), "depth-first back-edge search")
    incoming = {node for _, node in pairs}
    checks.add("single-root-session", [n for n in MODULES if n not in incoming] == ["Session"], "modules without incoming edge")
    checks.add("session-reaches-all", reachable(pairs, "Session") == set(NODES), sorted(reachable(pairs, "Session")))
    for leaf in ["Presentation", "CollisionQueries", "ContentAdmission", "InputAdapter"]:
        checks.add("leaf-" + leaf, {t for s, t in pairs if s == leaf} == {"Values"}, "reaches only Values")
    checks.add("values-sink", not any(s == "Values" for s, _ in pairs), "Values has no outgoing edge")
    for module in MODULES:
        checks.add("values-edge-" + module, (module, "Values") in pairs, "every module may use Values")
    expected_module_pairs = {
        ("Session", "Encounter"), ("Session", "CollisionQueries"), ("Session", "ContentAdmission"),
        ("Session", "Persistence"), ("Session", "InputAdapter"), ("Session", "Presentation"),
        ("Encounter", "CollisionQueries"), ("Encounter", "InputAdapter"), ("Persistence", "ContentAdmission"),
    }
    module_pairs = {(s, t) for s, t in pairs if t != "Values"}
    checks.add("module-pairs-match-hf03a-line-39", module_pairs == expected_module_pairs, sorted(module_pairs))
    absent = [(s, t) for s in NODES for t in NODES if s != t and (s, t) not in pairs]
    checks.add("forbidden-pair-count", len(absent) == len(NODES) * (len(NODES) - 1) - 16, str(len(absent)))
    return order


def parse_names(cell):
    if "any node" in cell.lower():
        return list(NODES)
    if "any module" in cell.lower():
        return list(MODULES)
    return [name.strip() for name in re.split(r",| or ", cell) if name.strip() in NODES]


def check_forbidden_table(section, pairs, checks):
    table = between(section, "### Forbidden pairs", "### Properties the check reproduces")
    rows = table_rows(table, r"[A-Z][^|]*")
    counted = 0
    for row in rows:
        if "native/proofs" in row[0] or " to " not in row[0] or row[0].startswith("Pair"):
            continue
        left, right = row[0].split(" to ", 1)
        for source in parse_names(left):
            for target in parse_names(right):
                if source != target:
                    counted += 1
                    checks.add("forbidden-" + source + "->" + target, (source, target) not in pairs, "named forbidden pair is absent")
    checks.add("forbidden-rows-parsed", counted >= 30, str(counted))


def check_edge_interfaces(edges, modules, checks):
    for edge_id, (source, target, use) in edges.items():
        if target == "Values":
            continue
        exposed = set(modules[target]["commands"]) | set(modules[target]["results"])
        tokens = backticked(use)
        unknown = [token for token in tokens if token not in exposed]
        checks.add("edge-interfaces-" + edge_id, tokens and not unknown, "unknown: " + ", ".join(unknown) if unknown else str(len(tokens)) + " interfaces in " + target + " row")


def check_walkthroughs(section, edges, modules, checks):
    tables = {"W1": r"A\d+", "W2": r"E\d+", "W3": r"R\d+"}
    counts = {}
    for name, first_cell in tables.items():
        rows = table_rows(section, first_cell)
        counts[name] = len(rows)
        checks.add("walkthrough-present-" + name, len(rows) >= 5, str(len(rows)) + " steps")
        for row in rows:
            step, route, edge, interface = row[0], row[1], row[2], row[3]
            tokens = backticked(interface)
            checks.add("step-no-defect-" + step, edge != "DEFECT", edge)
            if edge == "local":
                owner = route.strip()
                owned = set(modules.get(owner, {}).get("records", [])) | set(modules.get(owner, {}).get("commands", [])) | set(modules.get(owner, {}).get("results", []))
                unknown = [token for token in tokens if token not in owned]
                checks.add("step-local-" + step, "→" not in route and owner in MODULES and tokens and not unknown, owner + " own records/commands; unknown: " + ", ".join(unknown))
                continue
            if edge not in edges:
                checks.add("step-edge-" + step, False, "unlisted edge " + edge)
                continue
            source, target, _ = edges[edge]
            parts = [part.strip() for part in route.split("→")]
            checks.add("step-edge-" + step, parts == [source, target], edge + " " + source + " -> " + target + " vs " + route)
            exposed = set(modules[target]["commands"]) | set(modules[target]["results"])
            unknown = [token for token in tokens if token not in exposed]
            checks.add("step-interface-" + step, tokens and not unknown, "unknown in " + target + ": " + ", ".join(unknown) if unknown else ", ".join(tokens))
    return counts


def check_register(section, checks):
    rows = table_rows(section, r"DF-\d\d")
    checks.add("register-five-entries", [row[0] for row in rows] == ["DF-0%d" % i for i in range(1, 6)], str(len(rows)))
    checks.add("register-no-added-edge", all("Not added" in row[3] or "No edge needed" in row[3] or "Not an edge question" in row[3] for row in rows), "each disposition rejects the unlisted route")
    return len(rows)


def check_hf04a_arrows(root, pairs, checks):
    text = (root / HF04A).read_text()
    rows = table_rows(text, r"T\d\.\d")
    checked = 0
    for row in rows:
        owner = row[1]
        if "→" not in owner:
            continue
        segments = [[name.strip() for name in segment.split("/")] for segment in owner.split("→")]
        for left, right in zip(segments, segments[1:]):
            for target in right:
                checked += 1
                ok = any((source, target) in pairs for source in left)
                checks.add("hf04a-arrow-" + row[0] + "-" + target, ok, owner)
    checks.add("hf04a-rows-and-arrows", len(rows) == 29 and checked >= 25, "%d rows, %d arrows" % (len(rows), checked))
    return len(rows), checked


def check_proof(root, section, checks):
    report = json.loads((root / PROOF_REPORT).read_text())
    checks.add("s0-04-historical-verdict", report["verdict"] == "pass", report["generatedAt"])
    scripts = sorted((root / PROOF_DIR).glob("*.gd"))
    checks.add("s0-04-seven-scripts", len(scripts) == 7, str(len(scripts)))
    proof_edges = set()
    for script in scripts:
        relative = str(script.relative_to(root))
        data = script.read_bytes()
        checks.add("s0-04-hash-" + script.stem, sha256(data) == report["files"].get(relative), "retained report hash; not execution")
        text = data.decode()
        checks.add("s0-04-no-class-name-" + script.stem, not re.search(r"^class_name\s", text, re.M), "explicit preloads only")
        for target in re.findall(r'preload\("res://proofs/tadr-002/(\w+)\.gd"\)', text):
            proof_edges.add((script.stem, target))
    checks.add("s0-04-preload-graph", proof_edges == EXPECTED_PROOF_EDGES, sorted(proof_edges))
    module_edges = {(s, t) for s, t in proof_edges if s != "proof_runner" and s != "intruder" and s != t}
    checks.add("s0-04-module-edges-map-to-D01-D05-D08-D11", module_edges == {("session_owner", "encounter_coordinator"), ("session_owner", "input_adapter"), ("encounter_coordinator", "input_adapter"), ("encounter_coordinator", "encounter_state")}, sorted(module_edges))
    checks.add("no-current-autoload", "[autoload]" not in (root / "native/project.godot").read_text(), "current settings")
    mapping = table_rows(between(section, "### S0-04 reconciliation by source review", "## Scenarios"), r"`[a-z_]+`[^|]*")
    checks.add("s0-04-mapping-rows", len(mapping) == 9, str(len(mapping)))


def check_clauses(root, checks):
    for name, lines in CLAUSES.items():
        text = (root / name).read_text().splitlines()
        for line, snippet in lines.items():
            present = line <= len(text) and snippet in text[line - 1]
            checks.add("clause-" + name + ":" + str(line), present, snippet)


def check_card(root, section, checks):
    backlog = (root / "BACKLOG.md").read_text()
    card = between(backlog, "### HF-03b: Specify dependency edges and interface walkthroughs", "\n### ")
    checks.add("card-present", bool(card), "BACKLOG.md HF-03b")
    for phrase in ["An adjacency list of allowed dependency edges", "Three walkthroughs (an attack, an equipment change, an encounter replacement)", "Every walkthrough step uses a listed edge", "Re-verify when S0-04 lands"]:
        checks.add("card-dod-" + phrase[:24], phrase in card, phrase)
    checks.add("section-cites-card-revision", "revision 1 at source base `" + BASE + "`" in section, BASE)
    required = ["## Sources", "## Contract", "## Scenarios", "## Unresolved questions", "## Re-verification triggers", "## Procedure performed", "## Evidence limits"]
    checks.add("section-required-headings", all(heading in section for heading in required), ", ".join(required))
    return sha256(card.encode())


def main():
    root, out = parse_args(sys.argv[1:])
    out.mkdir(parents=True, exist_ok=True)
    checks = Checks()
    section_bytes = (root / SECTION).read_bytes()
    section = section_bytes.decode()
    modules = load_hf03a(root, checks)
    edges, pairs = load_graph(section, checks)
    order = check_graph_properties(pairs, checks)
    check_forbidden_table(section, pairs, checks)
    check_edge_interfaces(edges, modules, checks)
    counts = check_walkthroughs(section, edges, modules, checks)
    register = check_register(section, checks)
    hf04a_rows, hf04a_arrows = check_hf04a_arrows(root, pairs, checks)
    check_proof(root, section, checks)
    check_clauses(root, checks)
    card_sha = check_card(root, section, checks)
    receipt = {
        "card": "HF-03b",
        "repository": str(root),
        "head": git(root, "rev-parse", "HEAD"),
        "branch": git(root, "branch", "--show-current"),
        "section_dirty": bool(git(root, "status", "--porcelain", "--", SECTION)),
        "base": BASE,
        "section_sha256": sha256(section_bytes),
        "hf03a_sha256": HF03A_SHA,
        "card_sha256": card_sha,
        "edges": {edge_id: [s, t] for edge_id, (s, t, _) in sorted(edges.items())},
        "topological_order": order,
        "walkthrough_steps": counts,
        "register_entries": register,
        "hf04a_rows": hf04a_rows,
        "hf04a_arrows_checked": hf04a_arrows,
        "checks": len(checks.items),
        "failures": len(checks.failures),
        "results": checks.items,
        "limits": "Paper and source review of documents and retained historical evidence. No engine, build, browser or proof execution.",
    }
    (out / "graph-check.json").write_text(json.dumps(receipt, indent=2) + "\n")
    log = ["%s %s %s" % (item["status"].upper(), item["name"], item["detail"]) for item in checks.items]
    log.append("checks %d failures %d order %s" % (len(checks.items), len(checks.failures), " > ".join(order)))
    (out / "graph-check.log").write_text("\n".join(log) + "\n")
    print("\n".join(log[-1:] + ["FAIL " + item["name"] + " " + str(item["detail"]) for item in checks.failures]))
    return 1 if checks.failures else 0


if __name__ == "__main__":
    sys.exit(main())
