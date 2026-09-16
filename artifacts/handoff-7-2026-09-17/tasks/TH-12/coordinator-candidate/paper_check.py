#!/usr/bin/env python3
"""TH-12 paper check.

Checks the admitted-form section docs/tech/sections/TH-12-hud-dashboard-and-settings.md
against the admitted corpus it cites. It checks documents, not engine behaviour.

Usage: python3 paper_check.py <repository-root> [--out <directory>]
"""
import argparse
import hashlib
import json
import os
import re
import sys

SECTION = "docs/tech/sections/TH-12-hud-dashboard-and-settings.md"
CSV = "docs/tech/sections/HF-07a-save-envelope.csv"
PD02 = "docs/product/sections/PD-02-interface-states.md"
HF03A = "docs/tech/sections/HF-03a-module-map.md"
HF03B = "docs/tech/sections/HF-03b-dependency-graph.md"

CITED = {
    "HF-03a": HF03A,
    "HF-03b": HF03B,
    "HF-04a": "docs/tech/sections/HF-04a-runtime-lifecycle.md",
    "HF-07a": "docs/tech/sections/HF-07a-save-envelope.md",
    "HF-07b": "docs/tech/sections/HF-07b-commit-boundaries.md",
    "TH-01": "docs/tech/sections/TH-01-complete-loop.md",
    "TH-02": "docs/tech/sections/TH-02-movement-camera-and-active-aim.md",
    "TH-04": "docs/tech/sections/TH-04-abilities-ultimates-and-combat-rhythm.md",
    "TH-07": "docs/tech/sections/TH-07-four-slots-and-milestone-progression.md",
    "TH-08": "docs/tech/sections/TH-08-inventory-equipment-and-transformations.md",
    "TH-10": "docs/tech/sections/TH-10-devices-and-one-main-companion.md",
    "TH-11": "docs/tech/sections/TH-11-runs-regions-exits-and-saves.md",
    "PD-02": PD02,
    "BIBLE": "BIBLE.md",
    "TADR-002": "adr/TADR-002-runtime-model.md",
}

REQUIRED_H2 = ["Sources", "Contract", "Scenarios", "Unresolved questions",
               "Re-verification triggers", "Procedure performed", "Evidence limits"]
REQUIRED_H3 = ["Interfaces", "Owned data", "Algorithms and update order",
               "Edge cases", "Failure modes", "Tunable parameters"]
WALKS = ["UN", "US", "UM", "UR"]
CLASSES_NEVER = {"navigation", "ui-request", "control", "display"}


class Check:
    def __init__(self):
        self.results = []

    def ok(self, name, detail=""):
        self.results.append({"check": name, "level": "pass", "detail": detail})

    def fail(self, name, detail=""):
        self.results.append({"check": name, "level": "fail", "detail": detail})

    def want(self, cond, name, detail=""):
        (self.ok if cond else self.fail)(name, detail)
        return cond

    @property
    def failures(self):
        return [r for r in self.results if r["level"] == "fail"]


def read(root, rel):
    with open(os.path.join(root, rel), "rb") as handle:
        return handle.read()


def text(root, rel):
    return read(root, rel).decode("utf-8")


def lines(root, rel):
    return text(root, rel).split("\n")


def visible(raw):
    """Blank fenced blocks, keeping line numbers, as the repository checkers do."""
    out, fenced = [], False
    for line in raw.split("\n"):
        if re.match(r"^\s*(```|~~~)", line):
            fenced = not fenced
            out.append("")
            continue
        out.append("" if fenced else line)
    return out


def cells(line):
    return [c.strip() for c in line.strip().strip("|").split("|")]


def section_span(doc, heading):
    """[start, end) line indices of a `### heading` block."""
    start = None
    for index, line in enumerate(doc):
        if start is None and re.fullmatch(r"###\s+%s\s*" % re.escape(heading), line):
            start = index
            continue
        if start is not None and re.match(r"^#{2,3}\s", line):
            return start, index
    return (start, len(doc)) if start is not None else (0, 0)


def rows(doc, prefix, heading=None):
    """Table rows whose first cell matches the prefix, optionally inside one section."""
    lo, hi = (0, len(doc)) if heading is None else section_span(doc, heading)
    found = []
    for index in range(lo, hi):
        line = doc[index]
        if not line.startswith("|"):
            continue
        cs = cells(line)
        if cs and re.match(prefix, cs[0]):
            found.append((index + 1, cs))
    return found


def ticks(cell):
    return re.findall(r"`([^`]+)`", cell)


# ---------------------------------------------------------------- HF-03a table
def module_table(root):
    doc = visible(text(root, HF03A))
    table = {}
    for line in doc:
        if not line.startswith("|"):
            continue
        cs = cells(line)
        if len(cs) < 5:
            continue
        name = re.match(r"([A-Za-z]+)\.", cs[0])
        if not name:
            continue
        table[name.group(1)] = {
            "records": set(ticks(cs[1])),
            "commands": set(ticks(cs[3])),
            "results": set(ticks(cs[4])),
        }
    return table


def adjacency(root):
    doc = visible(text(root, HF03B))
    edges = {}
    for line in doc:
        if not line.startswith("|"):
            continue
        cs = cells(line)
        if cs and re.fullmatch(r"D\d\d", cs[0]):
            edges[cs[0]] = {"from": cs[1], "to": cs[2], "use": set(ticks(cs[3])), "raw": cs[3]}
    return edges


def csv_fields(root):
    out = []
    for line in text(root, CSV).split("\n")[1:]:
        if line.strip():
            out.append(line.split(",")[0].strip())
    return set(out)


# ------------------------------------------------------------------- the check
def run(root, doc_text, check):
    doc = visible(doc_text)
    modules = module_table(root)
    edges = adjacency(root)
    fields = csv_fields(root)
    counts = {}

    # 1. Required headings.
    heads2 = [re.match(r"^##\s+(.*?)\s*$", l).group(1) for l in doc if re.match(r"^##\s+\S", l)]
    heads3 = [re.match(r"^###\s+(.*?)\s*$", l).group(1) for l in doc if re.match(r"^###\s+\S", l)]
    for h in REQUIRED_H2:
        check.want(h in heads2, "heading:%s" % h)
    for h in REQUIRED_H3:
        check.want(h in heads3, "explicit-section:%s" % h)

    # 2. Sources bullets: nearest preceding repository-path link binds a hash.
    hashed = 0
    in_sources = False
    for index, line in enumerate(doc):
        if re.match(r"^##\s", line):
            in_sources = re.match(r"^##\s+Sources\s*$", line) is not None
            continue
        if not in_sources or not re.match(r"^\s*[-*]\s+", line):
            continue
        link = None
        for token in re.finditer(r"SHA256\s+`([0-9a-fA-F]{64})`|\[[^\]]*\]\(([^)]+)\)", line):
            digest, target = token.group(1), token.group(2)
            if target is not None:
                path = target.split("#")[0].strip()
                if not path or re.match(r"^[a-z][a-z0-9+.-]*:", path):
                    continue
                if "#" in target and os.path.basename(path) in ("BACKLOG.md", "TRACKING.md"):
                    continue
                link = os.path.normpath(os.path.join(os.path.dirname(SECTION), path))
                continue
            hashed += 1
            if link is None:
                check.fail("sources:unbound-hash", "line %d" % (index + 1))
                continue
            try:
                actual = hashlib.sha256(read(root, link)).hexdigest()
            except OSError:
                check.fail("sources:missing-dependency", link)
                continue
            check.want(actual == digest.lower(), "sources:hash:%s" % link,
                       "stated %s actual %s" % (digest.lower(), actual))
    counts["stated_hashes"] = hashed
    check.want(hashed >= 16, "sources:hash-count", str(hashed))

    # 3. Cited line numbers exist, and a cited rule ID sits at the cited line.
    body = "\n".join(doc)
    cited_lines = 0
    for match in re.finditer(r"\b(HF-0\d[ab]?|TH-\d\d|PD-02|BIBLE|TADR-002)\b"
                             r"(?:\s+([A-Z][A-Za-z0-9]*(?:-[A-Z0-9]+)?|F-[A-Z]+|RL\d|O\d|P\d|W\d))?"
                             r"\s+line\s+(\d+)\b", body):
        sec, rule, number = match.group(1), match.group(2), int(match.group(3))
        rel = CITED.get(sec)
        if rel is None:
            continue
        cited_lines += 1
        src = lines(root, rel)
        if not check.want(number <= len(src), "citation:in-range:%s:%d" % (sec, number)):
            continue
        if rule and re.fullmatch(r"[A-Z][A-Z0-9]*-[A-Z0-9]+|F-[A-Z]+|RL\d|SEAM-\d", rule):
            check.want(rule in src[number - 1],
                       "citation:rule-at-line:%s %s line %d" % (sec, rule, number),
                       src[number - 1][:90])
    counts["cited_lines"] = cited_lines

    # 4. Interface rows: module, command, edge and permitted use.
    iface = rows(doc, r"^UI-\d\d$", "Interfaces")
    counts["interface_rows"] = len(iface)
    check.want(len(iface) >= 20, "interfaces:row-count", str(len(iface)))
    iface_tokens = {}
    submit_rows = []
    for number, cs in iface:
        rid, caller_target, edge_cell, interface_cell = cs[0], cs[2], cs[3], cs[4]
        iface_tokens[rid] = set(ticks(interface_cell))
        check_row(check, "interfaces", rid, number, caller_target, edge_cell,
                  ticks(interface_cell), modules, edges)
        if "submit_action" in iface_tokens[rid]:
            submit_rows.append((rid, cs[6]))
    check.want(len(submit_rows) == 1, "interfaces:one-submit-row", str(submit_rows))
    for rid, states in submit_rows:
        check.want("RL2" in states and "only" in states,
                   "interfaces:submit-row-state:%s" % rid, states)

    # 5. Owned data: every owner is an HF-03a module, every record is its record.
    owned = rows(doc, r"^`[A-Za-z]", "Owned data")
    counts["owned_rows"] = len(owned)
    for number, cs in owned:
        owner = cs[1]
        if owner not in modules:
            check.fail("owned:module:%s" % owner, "line %d" % number)
            continue
        for record in ticks(cs[0]):
            check.want(record in modules[owner]["records"],
                       "owned:record:%s/%s" % (owner, record), "line %d" % number)

    # 6. Durable fields: every one is an HF-07a CSV field; nothing derived is.
    named = ordered_fields(body)
    counts["durable_fields_named"] = len(named)
    for field in named:
        check.want(field in fields, "durable:in-csv:%s" % field)
    check.want(len(named) >= 30, "durable:field-count", str(len(named)))
    not_durable = re.search(r"\*\*What is not durable[^*]*\*\*(.*?)\n\n", body, re.S)
    if check.want(not_durable is not None, "durable:not-durable-paragraph"):
        for term in re.split(r"[,;]|\band\b", not_durable.group(1)):
            term = term.strip().strip("`")
            if term and term in fields:
                check.fail("durable:derived-claimed-durable", term)
        check.ok("durable:no-derived-value-is-durable")

    # 7. PD-02 states, views and rules named exist there by ID at the cited line.
    pd = lines(root, PD02)
    pd_body = "\n".join(pd)
    pd_cited = 0
    for match in re.finditer(r"\b((?:VW|IS|FP|IP|VS|TW)-\d+|RS-[VS]\d+)\s+line\s+(\d+)\b", body):
        rid, number = match.group(1), int(match.group(2))
        pd_cited += 1
        if check.want(number <= len(pd), "pd02:in-range:%s" % rid, str(number)):
            check.want(rid in pd[number - 1], "pd02:id-at-line:%s line %d" % (rid, number),
                       pd[number - 1][:80])
    for match in re.finditer(r"\|\s*((?:IS|VW)-\d+ line \d+(?:,\s*(?:IS|VW)-\d+ line \d+)*)\s*\|", body):
        for part in match.group(1).split(","):
            rid, number = re.match(r"\s*((?:IS|VW)-\d+) line (\d+)", part).groups()
            pd_cited += 1
            check.want(rid in pd[int(number) - 1], "pd02:state-at-line:%s" % rid)
    for rid in sorted(set(re.findall(r"\b(?:VW|IS|FP|IP)-\d+\b", body))):
        check.want(re.search(r"\|\s*%s\s*\||\b%s\b" % (rid, rid), pd_body) is not None,
                   "pd02:id-exists:%s" % rid)
    counts["pd02_citations"] = pd_cited

    # 8. Tunable parameters: sourced or gated, and no Q-P30/Q-P32 row states a value.
    params = rows(doc, r"^UP-\d\d$", "Tunable parameters")
    counts["parameter_rows"] = len(params)
    check.want(len(params) >= 25, "parameters:row-count", str(len(params)))
    gated = 0
    for number, cs in params:
        rid, value, gate = cs[0], cs[2], cs[3]
        has_question = re.search(r"Q-[A-Z]\d+", gate) is not None
        has_line = re.search(r"\bline[s]?\s+\d+", gate) is not None
        check.want(has_question or has_line, "parameters:sourced-or-gated:%s" % rid, gate)
        if re.search(r"Q-P30|Q-P32", gate):
            gated += 1
            check.want(value.strip() == "unset", "parameters:no-value-under-Q-P30-or-Q-P32:%s" % rid,
                       value)
    counts["parameters_gated_on_QP30_QP32"] = gated
    check.want(gated >= 5, "parameters:gated-count", str(gated))

    # 9. The four walks.
    walk_steps = {}
    for walk in WALKS:
        steps = rows(doc, r"^%s\.\d+$" % walk)
        walk_steps[walk] = steps
        check.want(len(steps) >= 4, "walk:%s:step-count" % walk, str(len(steps)))
        outcome = re.search(r"\*\*%s\.\d+, named outcome\.\*\*" % walk, body)
        check.want(outcome is not None, "walk:%s:named-outcome" % walk)
        for number, cs in steps:
            klass, caller_target, edge_cell, interface_cell, reaches = cs[2], cs[3], cs[4], cs[5], cs[8]
            check.want(klass in CLASSES_NEVER | {"gameplay"}, "walk:%s:class:%s" % (walk, cs[0]), klass)
            check_row(check, "walk:%s" % walk, cs[0], number, caller_target, edge_cell,
                      [t for t in ticks(interface_cell)], modules, edges)
            if klass in CLASSES_NEVER:
                check.want(reaches.strip().startswith("No"),
                           "walk:%s:%s:no-submit-from-%s" % (walk, cs[0], klass), reaches)
                check.want("submit_action" not in ticks(interface_cell),
                           "walk:%s:%s:interface-is-not-submit" % (walk, cs[0]))
            else:
                check.want("RL2" in cs[1], "walk:%s:%s:gameplay-at-RL2" % (walk, cs[0]), cs[1])
    yes_rows = [(w, cs[0], cs[2], cs[1]) for w in WALKS for _, cs in walk_steps[w]
                if cs[8].strip().startswith("Yes")]
    counts["walk_steps"] = sum(len(walk_steps[w]) for w in WALKS)
    check.want(len(yes_rows) == 1, "walk:exactly-one-submit-row", str(yes_rows))
    for _, rid, klass, position in yes_rows:
        check.want(klass == "gameplay", "walk:submit-row-is-gameplay:%s" % rid, klass)
        check.want("RL2" in position and "Paused" not in position,
                   "walk:submit-row-unpaused-RL2:%s" % rid, position)

    # 10. Held edges cleared before re-arm, on both the modal and resume boundaries.
    for walk, after in (("UN", CLASSES_NEVER - {"control"}), ("UR", {"gameplay"})):
        steps = walk_steps[walk]
        clear = [i for i, (_, cs) in enumerate(steps)
                 if "clear_physical_input" in ticks(cs[5]) and cs[2] == "control"]
        later = [i for i, (_, cs) in enumerate(steps) if cs[2] in after]
        check.want(bool(clear), "walk:%s:clears-held-input" % walk)
        if clear and later:
            check.want(min(clear) < min(later),
                       "walk:%s:cleared-before-re-arm" % walk, "%s < %s" % (min(clear), min(later)))
        if clear:
            gate = steps[min(clear)][1][7]
            check.want("re-arm" in gate or "generation" in gate,
                       "walk:%s:re-arm-stated" % walk, gate[:80])

    # 11. Dashboard states the card requires, and the mockup treatment.
    ds = rows(doc, r"^DS-\d$")
    counts["dashboard_states"] = len(ds)
    check.want(len(ds) >= 5, "dashboard:state-count", str(len(ds)))
    for required in ("Locked slot", "Unavailable upgrade", "Equipment swap",
                     "Special respec", "Route choice"):
        check.want(any(required.lower() in cs[1].lower() for _, cs in ds),
                   "dashboard:required-state:%s" % required)
    check.want("layout studies" in body and "layout study" not in body.split("Sources")[0],
               "mockups:treated-as-layout-studies")
    check.want(re.search(r"###\s+The mockups are layout studies", body) is not None,
               "mockups:explicit-section")
    hs = rows(doc, r"^HS-\d$")
    counts["hud_snapshot_classes"] = len(hs)
    check.want(len(hs) >= 4, "hud:snapshot-class-count", str(len(hs)))

    # 12. No question the packet forbids deciding is answered here.
    for question in ("Q-P11", "Q-P12", "Q-P14", "Q-P15", "Q-P18", "Q-P19", "Q-P30", "Q-P32", "Q-E03"):
        check.want(not re.search(r"%s (?:is answered|is settled|is resolved here)" % question, body),
                   "questions:not-answered:%s" % question)
    return counts


def check_row(check, scope, rid, number, caller_target, edge_cell, interfaces, modules, edges):
    """One row's modules, edge and interfaces against HF-03a and HF-03b."""
    names = [n.strip() for n in re.split(r"\s+to\s+|,\s*then\s+", caller_target) if n.strip()]
    for name in names:
        if name not in modules:
            check.fail("%s:module-in-HF-03a:%s" % (scope, name), "%s line %d" % (rid, number))
    caller = names[0] if names else None
    allowed = set()
    edge_ids = re.findall(r"D\d\d", edge_cell)
    for edge_id in edge_ids:
        edge = edges.get(edge_id)
        if edge is None:
            check.fail("%s:edge-exists:%s" % (scope, edge_id), rid)
            continue
        pair = [n for n in names if n in modules]
        if edge["from"] not in pair or edge["to"] not in pair:
            check.fail("%s:edge-endpoints:%s" % (scope, edge_id),
                       "%s: %s -> %s against %s" % (rid, edge["from"], edge["to"], pair))
        else:
            check.ok("%s:edge-endpoints:%s:%s" % (scope, rid, edge_id))
        allowed |= edge["use"]
    if "local" in edge_cell or "none" in edge_cell:
        if caller in modules:
            allowed |= (modules[caller]["commands"] | modules[caller]["results"]
                        | modules[caller]["records"])
    for token in interfaces:
        if re.fullmatch(r"UI-\d\d|[A-Z]{1,3}-\d+", token):
            continue
        check.want(token in allowed, "%s:interface-permitted:%s:%s" % (scope, rid, token),
                   "edge %s" % edge_cell)


def ordered_fields(body):
    """Durable field names, expanding a leading-dot token against the previous field."""
    found, last = [], None
    for token in re.findall(r"`([^`]+)`", body):
        if re.match(r"^(run|profile|preferences)\.", token):
            if token.endswith(".*"):
                continue
            found.append(token[:-2] if token.endswith("[]") else token)
            last = token
        elif token.startswith(".") and last and re.match(r"^[a-z_.\[\]]+$", token):
            parent = last[:last.rindex(".")]
            found.append(parent + token)
    return sorted(set(found))


def controls(root, doc_text):
    """Three mutations a passing check must reject."""
    out = []
    mutated = doc_text.replace(
        "| UN.7 | Paused RL2 | navigation | Presentation | local | UI-10 `PresentationState` |",
        "| UN.7 | Paused RL2 | navigation | Session to Encounter | D01 | UI-18 `submit_action` |", 1)
    mutated = mutated.replace(
        "(HF-04a line 46; HD-01) | No |", "(HF-04a line 46; HD-01) | Yes |", 1)
    out.append(("navigation-step-reaches-submit_action", mutated))
    out.append(("Q-P30-gated-parameter-states-a-value",
                doc_text.replace(
                    "| UP-14 | Production viewing distances and target display sizes for interface acceptance | unset |",
                    "| UP-14 | Production viewing distances and target display sizes for interface acceptance | 2.5 m |",
                    1)))
    out.append(("durable-field-absent-from-the-CSV",
                doc_text.replace("`run.lifecycle.revival_spent`",
                                 "`run.lifecycle.revival_remaining`")))
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root")
    parser.add_argument("--out", default=None)
    args = parser.parse_args()
    root = os.path.abspath(args.root)
    out = os.path.abspath(args.out) if args.out else os.path.dirname(os.path.abspath(__file__))
    os.makedirs(out, exist_ok=True)

    doc_text = text(root, SECTION)
    check = Check()
    counts = run(root, doc_text, check)

    detected = []
    for name, mutated in controls(root, doc_text):
        probe = Check()
        try:
            run(root, mutated, probe)
            caught = bool(probe.failures)
        except Exception as error:  # a mutation that breaks parsing is still detected
            caught = True
            probe = Check()
            probe.fail("control-parse", str(error))
        detected.append({"control": name, "detected": caught,
                         "failures": len(probe.failures)})
        if not caught:
            check.fail("control:undetected:%s" % name)

    manifest = {rel: hashlib.sha256(read(root, rel)).hexdigest()
                for rel in sorted(set([SECTION, CSV] + list(CITED.values())))}
    report = {
        "result": "fail" if check.failures else "pass",
        "root": root,
        "section": SECTION,
        "counts": counts,
        "checks": len(check.results),
        "failed": len(check.failures),
        "controls": detected,
        "failures": check.failures,
        "limits": ("Document and citation checks only. No build, engine, browser, input device "
                   "or rendered interface was exercised; a passing run establishes contract "
                   "consistency, not interface behaviour."),
    }
    with open(os.path.join(out, "paper-check.json"), "w") as handle:
        json.dump(report, handle, indent=2)
        handle.write("\n")
    with open(os.path.join(out, "source-manifest.json"), "w") as handle:
        json.dump(manifest, handle, indent=2)
        handle.write("\n")
    for failure in check.failures:
        print("FAIL %s %s" % (failure["check"], failure["detail"]))
    print("TH-12 paper check %s: %d checks, %d failed, %d/%d controls detected." % (
        report["result"], report["checks"], report["failed"],
        sum(1 for d in detected if d["detected"]), len(detected)))
    print("counts: " + json.dumps(counts))
    print(report["limits"])
    return 1 if check.failures else 0


if __name__ == "__main__":
    sys.exit(main())
