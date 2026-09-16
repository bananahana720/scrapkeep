#!/usr/bin/env python3
"""Paper check for docs/tech/sections/TH-18-input-integration.md.

Usage: paper_check.py <repository-root> --out <directory> [--section <path>]
Exit 0 only when every assertion passes and every negative control is detected.
"""
import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

SECTION_REL = "docs/tech/sections/TH-18-input-integration.md"
REQUIRED_HEADINGS = [
    "Sources",
    "Contract",
    "Scenarios",
    "Unresolved questions",
    "Re-verification triggers",
    "Procedure performed",
    "Evidence limits",
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
CITED_FILES = {
    "HF-03a": "docs/tech/sections/HF-03a-module-map.md",
    "HF-03b": "docs/tech/sections/HF-03b-dependency-graph.md",
    "HF-04a": "docs/tech/sections/HF-04a-runtime-lifecycle.md",
    "HF-07a": "docs/tech/sections/HF-07a-save-envelope.md",
    "TH-01": "docs/tech/sections/TH-01-complete-loop.md",
    "TH-02": "docs/tech/sections/TH-02-movement-camera-and-active-aim.md",
    "TH-04": "docs/tech/sections/TH-04-abilities-ultimates-and-combat-rhythm.md",
    "TH-12": "docs/tech/sections/TH-12-hud-dashboard-and-settings.md",
    "PD-02": "docs/product/sections/PD-02-interface-states.md",
    "TADR-001": "adr/TADR-001-engine-language-platforms.md",
    "ADR 0005": "docs/adr/0005-caster-input-and-dashboard.md",
    "BIBLE": "BIBLE.md",
}
VOCABULARY_SECTIONS = {"TH-02", "TH-04", "TH-12"}
NUMBER_WORDS = {
    "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6,
    "seven": 7, "eight": 8, "nine": 9, "ten": 10, "eleven": 11,
    "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15,
    "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19,
    "twenty": 20, "thirty": 30,
}


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def cells(line):
    return [c.strip() for c in line.strip().strip("|").split("|")]


def ticks(text):
    return re.findall(r"`([^`]+)`", text)


def section_body(text, heading, level=2):
    marker = "#" * level + " " + heading
    lines = text.split("\n")
    out, inside = [], False
    for line in lines:
        if line.strip() == marker:
            inside = True
            continue
        if inside and re.match(r"^#{1,%d} " % level, line):
            break
        if inside:
            out.append(line)
    return "\n".join(out)


def rows_with_prefix(text, pattern):
    rows = {}
    order = []
    for line in text.split("\n"):
        if not line.startswith("| "):
            continue
        c = cells(line)
        if re.fullmatch(pattern, c[0]):
            rows[c[0]] = c
            order.append(c[0])
    return rows, order


class Report:
    def __init__(self):
        self.checks = []

    def add(self, name, ok, detail=""):
        self.checks.append({"check": name, "ok": bool(ok), "detail": detail})

    def failed(self):
        return [c for c in self.checks if not c["ok"]]


def load_hf03a(root):
    lines = (root / CITED_FILES["HF-03a"]).read_text().split("\n")
    table = {}
    for line in lines[30:37]:
        c = cells(line)
        name = c[0].split(".")[0]
        table[name] = {
            "records": set(ticks(c[1])),
            "commands": set(ticks(c[3])),
            "results": set(ticks(c[4])),
        }
    return table


def load_hf03b(root):
    edges = {}
    for line in (root / CITED_FILES["HF-03b"]).read_text().split("\n"):
        if re.match(r"^\| D\d\d ", line):
            c = cells(line)
            edges[c[0]] = {"from": c[1], "to": c[2], "use": set(ticks(c[3]))}
    return edges


def row_ids(root, key):
    ids = {}
    for n, line in enumerate((root / CITED_FILES[key]).read_text().split("\n"), 1):
        m = re.match(r"^\| ([A-Z]{1,3}-\d+|[A-Z]{2}\.\d+|RL\d) \|", line)
        if m:
            ids[m.group(1)] = n
    return ids


def parse_route(route):
    if " to " in route:
        caller, target = route.split(" to ", 1)
        return caller.strip(), target.strip()
    return route.strip(), None


def owner_tokens(hf03a, module):
    m = hf03a[module]
    return m["commands"] | m["results"] | m["records"]


def check_step(report, label, route, edge, tokens, hf03a, hf03b):
    caller, target = parse_route(route)
    ok = caller in MODULES and (target is None or target in MODULES)
    report.add("module-in-hf03a", ok, f"{label}: {route}")
    if not ok:
        return
    if edge == "local":
        report.add("local-has-no-target", target is None, label)
        bad = [t for t in tokens if t not in owner_tokens(hf03a, caller)]
        report.add("command-in-module-list", not bad, f"{label}: {bad}")
    elif edge == "none":
        report.add("none-edge-is-sampling", caller == "InputAdapter" and target is None and "sample_input" in tokens, label)
        bad = [t for t in tokens if t not in owner_tokens(hf03a, caller)]
        report.add("command-in-module-list", not bad, f"{label}: {bad}")
    else:
        e = hf03b.get(edge)
        report.add("edge-is-hf03b-allowed", e is not None, f"{label}: {edge}")
        if e is None:
            return
        report.add("edge-endpoints-match", e["from"] == caller and e["to"] == target, f"{label}: {edge} {e['from']}->{e['to']} vs {route}")
        bad = [t for t in tokens if t not in owner_tokens(hf03a, target)]
        report.add("command-in-module-list", not bad, f"{label}: {bad}")
        unused = [t for t in tokens if t not in e["use"]]
        report.add("edge-permitted-use-names-interface", not unused, f"{label}: {unused}")


def run_checks(text, root, section_path):
    report = Report()
    counts = {}
    hf03a = load_hf03a(root)
    hf03b = load_hf03b(root)

    for h in REQUIRED_HEADINGS:
        report.add("required-heading", re.search(r"^## " + re.escape(h) + r"$", text, re.M) is not None, h)

    sources = section_body(text, "Sources")
    hashes = 0
    for bullet in re.findall(r"^- .*$", sources, re.M):
        link = None
        for tok in re.finditer(r"\[[^\]]*\]\(([^)]+)\)|SHA256\s+`([0-9a-f]{64})`", bullet):
            if tok.group(1):
                target = tok.group(1).split("#")[0]
                if target and not re.match(r"^[a-z]+:", target) and not target.endswith("BACKLOG.md"):
                    link = target
                continue
            hashes += 1
            path = (section_path.parent / link).resolve() if link else None
            ok = path is not None and path.exists() and sha256(path) == tok.group(2)
            report.add("stated-hash-matches", ok, f"{link}")
    counts["stated_hashes"] = hashes

    vocab = {k: row_ids(root, k) for k in VOCABULARY_SECTIONS}
    ik, ik_order = rows_with_prefix(text, r"IK-\d\d")
    intents, in_order = rows_with_prefix(text, r"IN-\d\d")
    dp, dp_order = rows_with_prefix(text, r"DP-\d\d")
    counts["physical_action_kinds"] = len(ik_order)
    counts["intents"] = len(in_order)
    pd02_classes = set()
    for line in (root / CITED_FILES["PD-02"]).read_text().split("\n")[43:50]:
        m = re.match(r"^\| `([a-z-]+)` \|", line)
        if m:
            pd02_classes.add(m.group(1))
    report.add("pd02-vocabulary-read", pd02_classes == {"navigation", "ui-request", "control", "gameplay", "display"}, str(sorted(pd02_classes)))

    for iid in in_order:
        c = intents[iid]
        klass, vocab_cell, kbm, ctl = c[2], c[3], c[5], c[6]
        report.add("intent-class-in-pd02", klass in pd02_classes and klass != "display", f"{iid}: {klass}")
        refs = re.findall(r"(TH-0[24]|TH-12) ((?:[A-Z]{1,3}-\d+|[A-Z]{2}\.\d+)(?:, (?:[A-Z]{1,3}-\d+|[A-Z]{2}\.\d+))*)", vocab_cell)
        ok = bool(refs)
        for sec, ids in refs:
            for rid in ids.split(", "):
                if rid not in vocab[sec]:
                    ok = False
        report.add("intent-vocabulary-row-exists", ok, f"{iid}: {vocab_cell}")
        for cell, wanted in ((kbm, "keyboard/mouse"), (ctl, "controller")):
            kinds = re.findall(r"IK-\d\d", cell)
            gated = re.findall(r"DP-\d\d", cell)
            good = bool(kinds) and all(k in ik and ik[k][1] in (wanted, "both") for k in kinds)
            if not good and gated:
                good = all(g in dp and dp[g][2].startswith("unset") and re.search(r"Q-[PE]\d+", dp[g][3]) for g in gated)
            report.add("intent-covered-by-both-classes", good, f"{iid} {wanted}: {cell}")

    ii, ii_order = rows_with_prefix(text, r"II-\d\d")
    counts["interface_rows"] = len(ii_order)
    for iid in ii_order:
        c = ii[iid]
        check_step(report, iid, c[2], c[3], ticks(c[4]), hf03a, hf03b)

    summary_rows, trace_ids = rows_with_prefix(section_body(text, "Scenarios"), r"[A-Z]{2}")
    counts["traces"] = len(trace_ids)
    report.add("three-traces", len(trace_ids) == 3, str(trace_ids))
    trace_steps = 0
    for tid in trace_ids:
        steps, order = rows_with_prefix(text, re.escape(tid) + r"\.\d+")
        trace_steps += len(order)
        m = re.match(re.escape(tid) + r"\.1 to " + re.escape(tid) + r"\.(\d+)", summary_rows[tid][2])
        report.add("trace-step-range", m is not None and int(m.group(1)) == len(order), f"{tid}: {summary_rows[tid][2]} vs {len(order)}")
        outcome = summary_rows[tid][3]
        report.add("trace-named-outcome", re.search(r"^\*\*" + re.escape(outcome) + r", named outcome\.\*\*", text, re.M) is not None, f"{tid}: {outcome}")
        rows = [steps[s] for s in order]
        trigger = resume = None
        for i, r in enumerate(rows):
            iface = r[6].split(" ")[0]
            if trigger is None and iface in ("II-01", "II-02", "II-03") and r[3] == "control":
                trigger = i
            if trigger is not None and resume is None and iface == "II-09" and ticks(r[6]) == ["resume"]:
                resume = i
        report.add("trace-has-trigger", trigger is not None, tid)
        if trigger is None:
            continue
        for i, r in enumerate(rows):
            label = r[0]
            position, device, klass, route, edge, iface_cell, callback, gate, effect, submit = r[1:11]
            iface = iface_cell.split(" ")[0]
            report.add("step-class-in-pd02", klass in pd02_classes, f"{label}: {klass}")
            report.add("step-interface-defined", iface in ii, f"{label}: {iface}")
            if iface in ii:
                d = ii[iface]
                report.add("step-matches-interface-row", d[2] == route and d[3] == edge and callback == d[5], f"{label}: {route}/{edge}/{callback} vs {d[2]}/{d[3]}/{d[5]}")
                report.add("step-tokens-in-interface-row", set(ticks(iface_cell)) <= set(ticks(d[4])), f"{label}")
            check_step(report, label, route, edge, ticks(iface_cell), hf03a, hf03b)
            is_tick = callback.startswith("C-TICK")
            report.add("effect-vocabulary", effect in ("none", "tick"), f"{label}: {effect}")
            report.add("effect-matches-callback", (effect == "tick") == is_tick, f"{label}: {effect}/{callback}")
            if is_tick:
                report.add("tick-only-at-unpaused-rl2", position == "RL2", f"{label}: {position}")
                report.add("no-tick-between-trigger-and-resume", not (i > trigger and (resume is None or i < resume)), label)
            if submit == "Yes":
                report.add("submit-only-from-gameplay-at-rl2", klass == "gameplay" and position == "RL2" and iface == "II-14", label)
            else:
                report.add("submit-cell-is-no", submit == "No", f"{label}: {submit}")
        ifaces = [r[6].split(" ")[0] for r in rows]
        prepared_before = "II-16" in ifaces[:trigger]
        report.add("trace-prepares-before-trigger", prepared_before, tid)
        after = list(range(trigger + 1, len(rows)))
        o1 = next((i for i in after if ifaces[i] == "II-06"), None)
        o2 = next((i for i in after if ifaces[i] == "II-07"), None)
        o3 = next((i for i in after if ifaces[i] == "II-08"), None)
        view = next((i for i in after if ifaces[i] in ("II-10", "II-11")), None)
        commit = next((i for i in after if rows[i][7].startswith("C-TICK") or ifaces[i] == "II-14"), None)
        ordered = None not in (o1, o2, o3, view) and o1 < o2 < o3 < view
        report.add("modal-clears-prepared-before-view", ordered, f"{tid}: O1={o1} O2={o2} O3={o3} view={view}")
        report.add("modal-clears-prepared-before-commit", o2 is not None and (commit is None or o2 < commit), f"{tid}: O2={o2} commit={commit}")
    counts["trace_steps"] = trace_steps

    it, it_order = rows_with_prefix(text, r"IT-\d\d")
    nt, nt_order = rows_with_prefix(text, r"NT-\d\d")
    hq, hq_order = rows_with_prefix(text, r"HQ-\d\d")
    counts["transitions"] = len(it_order)
    counts["native_tests"] = len(nt_order)
    counts["hardware_rows"] = len(hq_order)
    for tid in it_order:
        tests = re.findall(r"NT-\d\d", it[tid][5])
        report.add("transition-names-native-test", bool(tests) and all(t in nt for t in tests), f"{tid}: {it[tid][5]}")
    for nid in nt_order:
        report.add("native-test-gated", re.search(r"Q-[PE]\d+", nt[nid][3]) is not None, nid)
    for hid in hq_order:
        report.add("hardware-row-unqualified", hq[hid][2] == "unqualified", f"{hid}: {hq[hid][2]}")
        tests = re.findall(r"NT-\d\d", hq[hid][3])
        report.add("hardware-row-names-native-test", bool(tests) and all(t in nt for t in tests), hid)

    counts["parameter_rows"] = len(dp_order)
    backlog = (root / "BACKLOG.md").read_text()
    for pid in dp_order:
        value, source = dp[pid][2], dp[pid][3]
        has_source = re.search(r"line \d+|row \d+|lines \d+", source) is not None
        qids = re.findall(r"Q-[PE]\d+", source)
        report.add("parameter-has-source-or-question", has_source or bool(qids), pid)
        if "Q-P30" in qids or "Q-P32" in qids:
            report.add("gated-parameter-has-no-value", value.startswith("unset"), f"{pid}: {value}")
    for q in sorted(set(re.findall(r"Q-[PE]\d+", text))):
        report.add("question-resolves-in-backlog", f'id="{q.lower()}"' in backlog, q)

    for label, rows in (("coverage_rules", r"IC-\d\d"), ("device_loss_rules", r"DL-\d\d"), ("focus_rules", r"FC-\d\d"), ("capture_rules", r"CA-\d\d"), ("edge_cases", r"IE-\d\d"), ("failure_modes", r"IX-\d\d")):
        counts[label] = len(rows_with_prefix(text, rows)[1])
    fixes = section_body(text, "What this section fixes", 3)
    stated = {
        "physical_action_kinds": r"(\w+) physical action kinds",
        "intents": r"(\w+) intents",
        "coverage_rules": r"(\w+) coverage rules",
        "device_loss_rules": r"(\w+) device-loss rules",
        "focus_rules": r"(\w+) focus and clearing rules",
        "capture_rules": r"(\w+) pointer-capture rules",
        "interface_rows": r"(\w+) interface rows",
        "transitions": r"(\w+) transitions",
        "native_tests": r"(\w+) native physical tests",
        "hardware_rows": r"(\w+) hardware rows",
        "edge_cases": r"(\w+) edge cases",
        "failure_modes": r"(\w+) failure modes",
        "parameter_rows": r"(\w+) tunable parameters",
        "traces": r"(\w+) paper traces",
    }
    for key, pattern in stated.items():
        m = re.search(pattern, fixes)
        n = NUMBER_WORDS.get(m.group(1).lower()) if m else None
        report.add("stated-count-matches", n == counts[key], f"{key}: stated {n} counted {counts[key]}")

    line_cache = {k: (root / v).read_text().split("\n") for k, v in CITED_FILES.items()}
    cited = 0
    for m in re.finditer(r"\b(HF-03a|HF-03b|HF-04a|HF-07a|TH-01|TH-02|TH-04|TH-12|PD-02) ([A-Z]{1,3}-\d+|[A-Z]{2}\.\d+|RL\d) line (\d+)\b", text):
        cited += 1
        sec, rid, n = m.group(1), m.group(2), int(m.group(3))
        line = line_cache[sec][n - 1] if n <= len(line_cache[sec]) else ""
        report.add("cited-row-at-line", line.startswith(f"| {rid} |"), f"{sec} {rid} line {n}")
    for m in re.finditer(r"\b(HF-03a|HF-03b|HF-04a|HF-07a|TH-01|TH-02|TH-04|TH-12|PD-02|TADR-001|ADR 0005|BIBLE) lines? (\d+)", text):
        cited += 1
        sec, n = m.group(1), int(m.group(2))
        report.add("cited-line-exists", 0 < n <= len(line_cache[sec]) and line_cache[sec][n - 1].strip() != "", f"{sec} line {n}")
    counts["line_citations"] = cited
    return report, counts


def mutate_row(text, row_id, column, new_value):
    out = []
    for line in text.split("\n"):
        if line.startswith(f"| {row_id} |"):
            c = cells(line)
            c[column] = new_value
            line = "| " + " | ".join(c) + " |"
        out.append(line)
    return "\n".join(out)


def swap_rows(text, a, b):
    lines = text.split("\n")
    ia = next(i for i, l in enumerate(lines) if l.startswith(f"| {a} |"))
    ib = next(i for i, l in enumerate(lines) if l.startswith(f"| {b} |"))
    lines[ia], lines[ib] = lines[ib], lines[ia]
    return "\n".join(lines)


NEGATIVE_CONTROLS = [
    ("NC-1 O2 moved after the view in CN", "modal-clears-prepared-before-view", lambda t: swap_rows(t, "CN.7", "CN.9")),
    ("NC-2 a paused diagnostic step advances the tick", "effect-matches-callback", lambda t: mutate_row(t, "DA.10", 9, "tick")),
    ("NC-3 a hardware row marked qualified", "hardware-row-unqualified", lambda t: mutate_row(t, "HQ-05", 2, "qualified")),
    ("NC-4 O1 routed on an edge that does not carry it", "edge-endpoints-match", lambda t: mutate_row(t, "II-06", 3, "D06")),
    ("NC-5 a menu intent with no controller coverage", "intent-covered-by-both-classes", lambda t: mutate_row(t, "IN-10", 6, "none")),
    ("NC-6 an intent citing a row TH-02 does not have", "intent-vocabulary-row-exists", lambda t: mutate_row(t, "IN-02", 3, "TH-02 MA-99, MO-02")),
    ("NC-7 a Q-P30 parameter given a value", "gated-parameter-has-no-value", lambda t: mutate_row(t, "DP-12", 2, "250 ms")),
    ("NC-8 a transition with no native test", "transition-names-native-test", lambda t: mutate_row(t, "IT-04", 5, "none")),
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root")
    ap.add_argument("--out", required=True)
    ap.add_argument("--section", default=SECTION_REL)
    args = ap.parse_args()
    root = Path(args.root).resolve()
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    section_path = (root / args.section).resolve()
    text = section_path.read_text()

    report, counts = run_checks(text, root, section_path)
    failures = report.failed()

    negatives = []
    for name, check, mutate in NEGATIVE_CONTROLS:
        mutated = mutate(text)
        changed = mutated != text
        neg_report, _ = run_checks(mutated, root, section_path)
        detected = changed and any(c["check"] == check for c in neg_report.failed())
        negatives.append({"control": name, "expected_failing_check": check, "mutation_applied": changed, "detected": detected})

    manifest = {rel: sha256(root / rel) for rel in [args.section, *CITED_FILES.values(), "docs/tech/sections/HF-07a-save-envelope.csv", "BACKLOG.md"]}
    result = {
        "section": args.section,
        "section_sha256": sha256(section_path),
        "assertions": len(report.checks),
        "passed": len(report.checks) - len(failures),
        "failed": len(failures),
        "failures": failures,
        "counts": counts,
        "negative_controls": negatives,
        "negative_controls_detected": sum(1 for n in negatives if n["detected"]),
    }
    (out / "paper-check.json").write_text(json.dumps(result, indent=2) + "\n")
    (out / "source-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    ok = not failures and all(n["detected"] for n in negatives)
    print(json.dumps({k: result[k] for k in ("assertions", "passed", "failed", "counts", "negative_controls_detected")}))
    for f in failures:
        print("FAIL", f["check"], f["detail"])
    for n in negatives:
        print("NEGATIVE", "detected" if n["detected"] else "MISSED", n["control"])
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
