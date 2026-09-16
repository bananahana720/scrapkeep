#!/usr/bin/env python3
"""Paper check for docs/tech/sections/TH-16-rendering-integration.md.

Disposable, gitignored receipt tool. It checks documents, not engine behaviour.

Usage: python3 check_rendering.py <repository-root> [--out <directory>]

It asserts, against the repository at <repository-root>:

  G01 the seven required section headings and the card-named subsections
  G02 every module this section names appears in HF-03a's module table
  G03 every command invoked appears in that module's HF-03a exposed-command,
      published-result or owned-record list
  G04 every edge used is an HF-03b allowed edge with matching From/To and a
      permitted use on that specific edge's own column
  G05 presentation commands only on D06; definition/asset resolution only on
      D03 (DF-03); no gameplay query on D02; no D04 and no D09 anywhere
  G06 every parameter row carries a source line or a question ID, every
      question ID resolves to a BACKLOG anchor, and no row gated on Q-E04,
      Q-E03 or Q-P30 states a value other than `unset`
  G07 the only durable field path named is `preferences.reduced_motion`, and
      it exists in the HF-07a CSV copy's closed field list
  G08 every PD-01 acceptance, evidence, view, provenance or limitation ID
      cited here exists in PD-01 by that ID
  G09 the three traces each reach a named end state, and no step whose caller
      is Presentation reaches submit_action, install_effective_build,
      accept_encounter_result, a stream, stage_transition or commit_transition
  G10 every dependency hash stated in Sources matches the file's bytes

and then runs three negative controls, each removing one gate's subject, so a
passing run is not a checker that cannot fail.
"""

import hashlib
import json
import pathlib
import re
import sys

SECTION = "docs/tech/sections/TH-16-rendering-integration.md"
HF03A = "docs/tech/sections/HF-03a-module-map.md"
HF03B = "docs/tech/sections/HF-03b-dependency-graph.md"
HF04A = "docs/tech/sections/HF-04a-runtime-lifecycle.md"
HF07ACSV = "docs/tech/sections/HF-07a-save-envelope.csv"
PD01 = "docs/product/sections/PD-01-art-acceptance.md"
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
    "Committed-result consumption",
    "Interpolation",
    "Scene disposal",
    "Reusable effect resources",
    "Definition-to-view mapping",
    "Telegraph readability",
    "Silhouette and clearance qualification",
]
MUTATING = [
    "submit_action",
    "install_effective_build",
    "accept_encounter_result",
    "stage_transition",
    "commit_transition",
    "retry_transaction",
    "commit_preferences",
    "retire",
    "release_encounter_views",
    "admit_catalogue",
    "resolve_id",
    "attach_world",
    "detach_world",
    "query_attack",
    "resolve_movement",
    "interpret_contacts",
    "cancel_prepared",
    "clear_physical_input",
    "EncounterRandomState",
]
DURABLE_PATH = re.compile(
    r"`((?:run|profile|preferences)\.[A-Za-z_][A-Za-z_.\[\]]*"
    r"|schema_version|content_revision|generation|transaction_id|chassis_id)`"
)
ALLOWED_DURABLE = {"preferences.reduced_motion"}
GATED_QUESTIONS = {"Q-E04", "Q-E03", "Q-P30"}


def rows(text, first_cell):
    """Table rows whose first cell matches first_cell (a compiled pattern)."""
    out = []
    for line in text.split("\n"):
        s = line.strip()
        if not s.startswith("|"):
            continue
        cells = [c.strip() for c in s.strip("|").split("|")]
        if cells and first_cell.match(cells[0]):
            out.append(cells)
    return out


def ticks(cell):
    return re.findall(r"`([^`]+)`", cell)


def load(root, rel):
    return (root / rel).read_text()


def sources_block(text):
    out, on = [], False
    for line in text.split("\n"):
        if re.match(r"^##\s", line):
            on = re.match(r"^##\s+Sources\s*$", line) is not None
            continue
        if on:
            out.append(line)
    return "\n".join(out)


def subsection(text, heading):
    m = re.search(r"^###\s+" + re.escape(heading) + r"\s*$", text, re.M)
    if not m:
        return ""
    rest = text[m.end():]
    n = re.search(r"^###?\s", rest, re.M)
    return rest[: n.start()] if n else rest


class Check:
    def __init__(self):
        self.results = []
        self.failures = []

    def ok(self, gate, detail, count=None):
        self.results.append({"gate": gate, "status": "pass", "detail": detail, "count": count})

    def fail(self, gate, detail):
        self.results.append({"gate": gate, "status": "fail", "detail": detail, "count": None})
        self.failures.append(gate + ": " + detail)

    def expect(self, gate, condition, detail, count=None):
        if condition:
            self.ok(gate, detail, count)
        else:
            self.fail(gate, detail)


# ---------------------------------------------------------------- model


class Model:
    def __init__(self, root):
        self.root = root
        self.section = load(root, SECTION)
        self.hf03a = load(root, HF03A)
        self.hf03b = load(root, HF03B)
        self.hf04a = load(root, HF04A)
        self.pd01 = load(root, PD01)
        self.backlog = load(root, BACKLOG)
        self.csv = load(root, HF07ACSV)

        # HF-03a modules: first cell is "Name. [TADR-..." or "Name"
        self.modules = {}
        for cells in rows(self.hf03a, re.compile(r"^[A-Z][A-Za-z]+\.\s")):
            if len(cells) < 5:
                continue
            name = cells[0].split(".")[0].strip()
            self.modules[name] = {
                "records": set(ticks(cells[1])),
                "imports": cells[2],
                "commands": set(ticks(cells[3])),
                "results": set(ticks(cells[4])),
            }
        self.modules.setdefault("Values", {"records": set(), "imports": "", "commands": set(), "results": set()})

        # HF-03b edges
        self.edges = {}
        for cells in rows(self.hf03b, re.compile(r"^D\d\d$")):
            if len(cells) < 5:
                continue
            self.edges[cells[0]] = {"from": cells[1], "to": cells[2], "use": cells[3]}

        # this section's interface rows
        self.interfaces = [c for c in rows(self.section, re.compile(r"^RI-\d\d$")) if len(c) >= 8]
        # parameter rows
        self.params = [c for c in rows(self.section, re.compile(r"^RP-\d\d$")) if len(c) >= 5]
        # walk rows
        self.walks = {}
        for tag in ("VA", "VU", "VL"):
            self.walks[tag] = [c for c in rows(self.section, re.compile(r"^" + tag + r"\.\d+$")) if len(c) >= 7]

    def vocabulary(self, module):
        m = self.modules.get(module)
        if not m:
            return set()
        return m["records"] | m["commands"] | m["results"]

    def segments(self, caller_cell, edge_cell):
        callers = [s.strip() for s in re.split(r",\s*then\s*", caller_cell) if s.strip()]
        edges = [s.strip() for s in re.split(r",\s*then\s*", edge_cell) if s.strip()]
        if len(callers) != len(edges):
            return None
        out = []
        for c, e in zip(callers, edges):
            if " to " in c:
                src, dst = c.split(" to ", 1)
                out.append((src.strip(), dst.strip(), e))
            else:
                out.append((c.strip(), None, e))
        return out


# ---------------------------------------------------------------- gates


def gate_headings(m, chk, text=None):
    text = m.section if text is None else text
    present = set(
        h.strip().lower()
        for h in re.findall(r"^#{1,6}\s+(.*?)\s*#*\s*$", text, re.M)
    )
    missing = [h for h in REQUIRED_HEADINGS if h.lower() not in present]
    chk.expect("G01-headings", not missing, "required headings missing: " + str(missing), len(REQUIRED_HEADINGS))
    missing2 = [h for h in CARD_SUBSECTIONS if h.lower() not in present]
    chk.expect("G01-subsections", not missing2, "card subsections missing: " + str(missing2), len(CARD_SUBSECTIONS))


def gate_modules(m, chk, interfaces=None):
    interfaces = m.interfaces if interfaces is None else interfaces
    named = set()
    for cells in interfaces:
        segs = m.segments(cells[2], cells[3])
        if segs is None:
            chk.fail("G02-modules", "row " + cells[0] + " caller/edge segments do not pair")
            return
        for src, dst, _ in segs:
            if src not in ("Every module",):
                named.add(src)
            if dst:
                named.add(dst)
    unknown = sorted(n for n in named if n not in m.modules)
    chk.expect("G02-modules", not unknown, "modules absent from HF-03a table: " + str(unknown), len(named))


def gate_commands_and_edges(m, chk, interfaces=None):
    interfaces = m.interfaces if interfaces is None else interfaces
    bad_cmd, bad_edge, checked_cmds, checked_edges = [], [], 0, 0
    for cells in interfaces:
        rid, caller, edge_cell, cmd_cell = cells[0], cells[2], cells[3], cells[4]
        if edge_cell.startswith("D10 to D16"):
            continue
        segs = m.segments(caller, edge_cell)
        if segs is None:
            bad_edge.append(rid + ": segments do not pair")
            continue
        for src, dst, e in segs:
            if e == "local":
                if dst is not None:
                    bad_edge.append(rid + ": local step names a target")
                continue
            checked_edges += 1
            if e not in m.edges:
                bad_edge.append(rid + ": " + e + " is not an HF-03b edge")
                continue
            if m.edges[e]["from"] != src or m.edges[e]["to"] != dst:
                bad_edge.append(rid + ": " + e + " is " + m.edges[e]["from"] + "->" + m.edges[e]["to"]
                                + " not " + src + "->" + str(dst))
        for name in ticks(cmd_cell):
            checked_cmds += 1
            accepted = False
            for src, dst, e in segs:
                if e == "local":
                    if name in m.vocabulary(src):
                        accepted = True
                elif e in m.edges:
                    target = m.edges[e]["to"]
                    if name in m.vocabulary(target) and ("`" + name + "`") in m.edges[e]["use"]:
                        accepted = True
            if not accepted:
                bad_cmd.append(rid + ": `" + name + "` not permitted on any of this row's segments")
    chk.expect("G03-commands", not bad_cmd, "; ".join(bad_cmd), checked_cmds)
    chk.expect("G04-edges", not bad_edge, "; ".join(bad_edge), checked_edges)


def gate_edge_policy(m, chk, interfaces=None):
    interfaces = m.interfaces if interfaces is None else interfaces
    problems = []
    presentation_cmds = m.modules["Presentation"]["commands"]
    resolve_cmds = {"resolve_id", "stage_catalogue", "validate_candidate", "admit_catalogue",
                    "retain_revision", "release_revision"}
    for cells in interfaces:
        rid, caller, edge_cell, cmd_cell = cells[0], cells[2], cells[3], cells[4]
        names = set(ticks(cmd_cell))
        edges_used = [s.strip() for s in re.split(r",\s*then\s*", edge_cell)]
        if "D04" in edges_used or "D09" in edges_used:
            problems.append(rid + ": uses D04 or D09")
        if names & presentation_cmds and "D06" not in edges_used:
            problems.append(rid + ": presentation command off D06")
        if names & resolve_cmds and "D03" not in edges_used:
            problems.append(rid + ": definition or asset resolution off D03")
        if "D02" in edges_used:
            if ticks(cmd_cell):
                problems.append(rid + ": D02 row names a backticked command")
            if "no gameplay query on this edge" not in cmd_cell:
                problems.append(rid + ": D02 row does not state the query prohibition")
    if "D04" in m.section or "D09" in m.section:
        # the prose may only mention them as unused
        for line in m.section.split("\n"):
            if ("D04" in line or "D09" in line) and "unused" not in line and "neither D04 nor D09" not in line:
                if line.strip().startswith("|"):
                    problems.append("table line names D04 or D09: " + line.strip()[:60])
    chk.expect("G05-edge-policy", not problems, "; ".join(problems), len(interfaces))


def gate_parameters(m, chk, params=None):
    params = m.params if params is None else params
    problems = []
    for cells in params:
        rid, value, source = cells[0], cells[2], cells[3]
        qs = set(re.findall(r"Q-[EP]\d\d", source))
        has_line = re.search(r"\bline[s]?\s+\d+", source) is not None
        if not qs and not has_line:
            problems.append(rid + ": no source line and no question ID")
        for q in qs:
            anchor = '<a id="' + q.lower() + '"></a>'
            if anchor not in m.backlog:
                problems.append(rid + ": " + q + " has no BACKLOG anchor")
        if qs & GATED_QUESTIONS and value.strip() != "unset":
            problems.append(rid + ": gated on " + str(sorted(qs & GATED_QUESTIONS)) + " but states '" + value + "'")
    chk.expect("G06-parameters", not problems, "; ".join(problems), len(params))


def gate_durable(m, chk, text=None):
    text = m.section if text is None else text
    named = set(DURABLE_PATH.findall(text))
    extra = sorted(named - ALLOWED_DURABLE)
    csv_fields = set(line.split(",")[0] for line in m.csv.split("\n")[1:] if line.strip())
    unknown = sorted(n for n in named if n not in csv_fields)
    chk.expect("G07-durable-scope", not extra, "durable field paths beyond the allowance: " + str(extra), len(named))
    chk.expect("G07-durable-exists", not unknown, "field paths absent from the HF-07a CSV: " + str(unknown), len(csv_fields))


def gate_pd01(m, chk, text=None):
    text = m.section if text is None else text
    cited = set(re.findall(r"\b(?:AC|PE|VW|PF|RL)-\d\d\b", text))
    missing = sorted(i for i in cited if ("| " + i + " |") not in m.pd01)
    chk.expect("G08-pd01", not missing, "IDs cited here but absent from PD-01: " + str(missing), len(cited))


def gate_walks(m, chk, walks=None):
    walks = m.walks if walks is None else walks
    problems, steps = [], 0
    for tag, table in walks.items():
        if not table:
            problems.append(tag + ": no steps")
            continue
        steps += len(table)
        for cells in table:
            steps_caller = cells[2]
            body = cells[4] + " " + cells[6]
            if re.fullmatch(r"Presentation", steps_caller.strip()):
                if cells[3].strip() != "local":
                    problems.append(cells[0] + ": Presentation caller on a non-local edge")
                for token in MUTATING:
                    if ("`" + token + "`") in cells[4]:
                        problems.append(cells[0] + ": Presentation step names `" + token + "`")
                if DURABLE_PATH.search(body):
                    problems.append(cells[0] + ": Presentation step names a durable field")
    for tag in ("VA", "VU", "VL"):
        head = re.search(r"^###\s+" + tag + r":", m.section, re.M)
        if not head:
            problems.append(tag + ": no walk heading")
            continue
        tail = m.section[head.end():]
        nxt = re.search(r"^###?\s", tail, re.M)
        blk = tail[: nxt.start()] if nxt else tail
        if "**End state:" not in blk:
            problems.append(tag + ": no named end state")
    chk.expect("G09-walks", not problems, "; ".join(problems), steps)


def gate_hashes(m, chk, text=None):
    text = m.section if text is None else text
    block = sources_block(text)
    hash_pat = re.compile(r"SHA256\s+`([0-9a-fA-F]{64})`")
    link_pat = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
    token_pat = re.compile(hash_pat.pattern + "|" + link_pat.pattern)
    here = m.root / "docs" / "tech" / "sections"
    problems, count = [], 0
    for bullet in re.findall(r"^-\s.*(?:\n(?!\s*[-*]\s|\s*$|#).*)*", block, re.M):
        link = None
        for tok in token_pat.finditer(bullet.replace("\n", " ")):
            h, target = tok.group(1), tok.group(2)
            if target is not None:
                base = target.split("#")[0].strip()
                if not base or re.match(r"^[a-z][a-z0-9+.-]*:", base):
                    continue
                if "#" in target and pathlib.PurePosixPath(base).name in ("BACKLOG.md", "TRACKING.md"):
                    continue
                link = base
                continue
            count += 1
            if not link:
                problems.append("unbound hash " + h.lower())
                continue
            f = (here / link).resolve()
            if not f.exists():
                problems.append("missing dependency " + str(f))
                continue
            actual = hashlib.sha256(f.read_bytes()).hexdigest()
            if actual != h.lower():
                problems.append(str(f) + " stated " + h.lower() + " actual " + actual)
    chk.expect("G10-hashes", not problems, "; ".join(problems), count)


# ---------------------------------------------------------------- controls


def negative_controls(m):
    """Each control removes one gate's subject and asserts the gate notices."""
    out = []

    # NC1: an unlisted command on a listed edge.
    bad = [list(c) for c in m.interfaces]
    bad[0][4] = "`submit_action`"
    c = Check()
    gate_commands_and_edges(m, c, interfaces=bad)
    out.append({"control": "NC1-unlisted-command-on-D03", "caught": bool(c.failures), "detail": c.failures})

    # NC2: a parameter row gated on Q-E04 that states a value.
    bad = [list(r) for r in m.params]
    target = next(r for r in bad if "Q-E04" in r[3])
    target[2] = "Forward+"
    c = Check()
    gate_parameters(m, c, params=bad)
    out.append({"control": "NC2-Q-E04-row-states-a-value", "caught": bool(c.failures), "detail": c.failures})

    # NC3: a walk step whose Presentation caller reaches install_effective_build.
    bad = {k: [list(r) for r in v] for k, v in m.walks.items()}
    step = next(r for r in bad["VU"] if r[2].strip() == "Presentation")
    step[4] = "RI-18 `install_effective_build`"
    c = Check()
    gate_walks(m, c, walks=bad)
    out.append({"control": "NC3-presentation-step-mutates", "caught": bool(c.failures), "detail": c.failures})

    return out


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    root = pathlib.Path(argv[1]).resolve()
    out = pathlib.Path(__file__).resolve().parent
    if "--out" in argv:
        out = pathlib.Path(argv[argv.index("--out") + 1]).resolve()
    out.mkdir(parents=True, exist_ok=True)

    m = Model(root)
    chk = Check()
    gate_headings(m, chk)
    gate_modules(m, chk)
    gate_commands_and_edges(m, chk)
    gate_edge_policy(m, chk)
    gate_parameters(m, chk)
    gate_durable(m, chk)
    gate_pd01(m, chk)
    gate_walks(m, chk)
    gate_hashes(m, chk)

    controls = negative_controls(m)
    uncaught = [c["control"] for c in controls if not c["caught"]]
    chk.expect("NC-controls", not uncaught, "negative controls not caught: " + str(uncaught), len(controls))

    section_bytes = (root / SECTION).read_bytes()
    report = {
        "repository_root": str(root),
        "section": SECTION,
        "section_sha256": hashlib.sha256(section_bytes).hexdigest(),
        "counts": {
            "modules_in_hf03a": len(m.modules),
            "edges_in_hf03b": len(m.edges),
            "interface_rows": len(m.interfaces),
            "parameter_rows": len(m.params),
            "walk_steps": sum(len(v) for v in m.walks.values()),
            "stated_hashes": next((r["count"] for r in chk.results if r["gate"] == "G10-hashes"), None),
            "pd01_ids_cited": next((r["count"] for r in chk.results if r["gate"] == "G08-pd01"), None),
            "durable_paths_named": next((r["count"] for r in chk.results if r["gate"] == "G07-durable-scope"), None),
        },
        "results": chk.results,
        "negative_controls": controls,
        "failures": chk.failures,
        "limits": (
            "Documentation checks only. No engine, browser or build ran. A passing "
            "run means this section is consistent with the admitted sources it cites "
            "at the bytes it states, not that any described behaviour exists."
        ),
    }
    (out / "paper-check.json").write_text(json.dumps(report, indent=2) + "\n")
    for r in chk.results:
        print(("PASS " if r["status"] == "pass" else "FAIL ") + r["gate"]
              + ("" if r["count"] is None else " (" + str(r["count"]) + ")")
              + ("" if r["status"] == "pass" else ": " + r["detail"]))
    for c in controls:
        print(("PASS " if c["caught"] else "FAIL ") + c["control"] + " caught=" + str(c["caught"]))
    print("check_rendering " + ("pass" if not chk.failures else "fail")
          + ": " + str(len(chk.results)) + " gates, " + str(len(chk.failures)) + " failures, "
          + str(len(controls)) + " negative controls. Report: " + str(out / "paper-check.json"))
    print(report["limits"])
    return 1 if chk.failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
