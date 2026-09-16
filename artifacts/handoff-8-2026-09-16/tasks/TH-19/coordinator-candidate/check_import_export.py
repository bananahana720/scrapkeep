#!/usr/bin/env python3
"""Paper check for docs/tech/sections/TH-19-asset-import-export.md.

Usage: python check_import_export.py <repository-root> --out <directory> [--base <sha>]
Exit 0 when every positive assertion passes and every negative control fails.
"""
import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

SECTION = "docs/tech/sections/TH-19-asset-import-export.md"
DEFAULT_BASE = "bb97c4111d1e7b2dd40cae575eccde17878b07c5"
HEADINGS = [
    "Sources",
    "Contract",
    "Scenarios",
    "Unresolved questions",
    "Re-verification triggers",
    "Procedure performed",
    "Evidence limits",
]
CALLBACKS = {
    "C-TICK", "F-PROCESS", "F-PHYSICS", "F-INPUT", "F-CONTROL",
    "F-LIFECYCLE", "F-SIGNAL", "F-ASYNC", "F-OTHER", "none",
}
NON_MODULE_ACTORS = {"Technical art", "Tooling", "Verification", "Coordinator"}
W1_ORDER = ["gate", "source", "settings", "cache", "reference", "manifest",
            "export", "admission", "exported-reference"]


def table_rows(text, first_cell_pattern):
    rows = []
    for line in text.split("\n"):
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if cells and re.fullmatch(first_cell_pattern, cells[0]):
            rows.append(cells)
    return rows


def ticks(cell):
    return re.findall(r"`([^`]+)`", cell)


def section_block(text, heading, level=3):
    marker = "#" * level + " " + heading
    start = text.find("\n" + marker + "\n")
    if start < 0:
        return ""
    rest = text[start + len(marker) + 2:]
    stop = re.search(r"\n#{1,%d} " % level, rest)
    return rest[: stop.start()] if stop else rest


def parse_hf03a(text):
    modules = {}
    for cells in table_rows(text, r"[A-Za-z]+\. \[.*"):
        name = cells[0].split(".")[0]
        modules[name] = {
            "commands": set(ticks(cells[3])),
            "results": set(ticks(cells[4])),
            "records": set(ticks(cells[1])),
        }
    return modules


def parse_hf03b(text):
    edges = {}
    for cells in table_rows(text, r"D\d\d"):
        edges[cells[0]] = {"from": cells[1], "to": cells[2], "use": set(ticks(cells[3]))}
    return edges


def parse_hf05_edges(text):
    return {c[0]: (c[1], c[2]) for c in table_rows(text, r"E\d\d")}


def check_all(root, text, base, record):
    hf03a = parse_hf03a((root / "docs/tech/sections/HF-03a-module-map.md").read_text())
    hf03b = parse_hf03b((root / "docs/tech/sections/HF-03b-dependency-graph.md").read_text())
    hf05 = parse_hf05_edges((root / "docs/tech/sections/HF-05-content-admission.md").read_text())
    backlog = (root / "BACKLOG.md").read_text()

    found = re.findall(r"^## (.+)$", text, flags=re.M)
    record("headings", found == HEADINGS, str(found))

    oc = {c[0]: c for c in table_rows(text, r"OC-\d\d")}
    ok = (
        len(oc) == 10
        and "OC-03" in oc and "OC-05" in oc
        and ".import" in oc["OC-03"][2] and oc["OC-03"][4] == "tracked"
        and "native/.godot/imported/" in oc["OC-05"][2] and oc["OC-05"][4] == "untracked"
        and oc["OC-03"][5] != oc["OC-05"][5]
        and oc["OC-03"][3] != oc["OC-05"][3]
        and "never ignored" in oc["OC-03"][5]
        and "Disposable" in oc["OC-05"][5]
    )
    record("ownership-classes-distinct", ok, "OC-03 tracked settings vs OC-05 untracked cache")

    quotes = table_rows(text, r"HR-Q\d")
    ok = len(quotes) >= 5
    detail = []
    for cells in quotes:
        path = cells[1].strip("`")
        line_no = int(cells[2])
        quoted = cells[3][1:-1] if cells[3].startswith("`") else cells[3]
        blob = subprocess.run(["git", "-C", str(root), "show", f"{base}:{path}"],
                              capture_output=True, text=True)
        lines = blob.stdout.split("\n")
        actual = lines[line_no - 1].strip() if blob.returncode == 0 and len(lines) >= line_no else None
        match = actual == quoted
        ok = ok and match
        detail.append(f"{path}:{line_no} {'ok' if match else 'MISMATCH ' + repr(actual)}")
    required = {(".gitignore", 20), ("scripts/native-smoke.mjs", 148), ("scripts/native-smoke.mjs", 742)}
    ok = ok and required <= {(c[1].strip("`"), int(c[2])) for c in quotes}
    record("quoted-lines-at-base", ok, "; ".join(detail))

    ig = table_rows(text, r"IG-\d\d")
    absent = [c[0] for c in ig if c[2] in ("absent", "open")]
    record("gates-absent-at-base", len(ig) == 7 and len(absent) == 7, f"{len(absent)} of {len(ig)} absent or open")

    walks = {}
    for name in ("W1", "W2", "W3"):
        block_start = text.find(f"### {name}:")
        block_end = text.find("\n### ", block_start + 1)
        if block_end < 0:
            block_end = text.find("\n## ", block_start + 1)
        walks[name] = text[block_start:block_end] if block_start >= 0 else ""

    for name, block in walks.items():
        verdict = re.search(r"Production asset readiness at this base: \*\*(\w+)\*\*", block)
        steps = table_rows(block, name + r"\.\d+")
        stages = [s[1] for s in steps]
        ok = bool(verdict) and bool(steps)
        if absent:
            ok = ok and verdict.group(1) == "rejected"
        ok = ok and stages[:1] == ["gate"] and "gate" not in stages[1:]
        record(f"{name}-readiness-rejected-gate-first", ok, f"verdict={verdict.group(1) if verdict else None} stages={stages}")

        edge_ok = True
        notes = []
        for s in steps:
            step, stage, actors, edge, interface, callback, hf05_edge = s[:7]
            if callback not in CALLBACKS:
                edge_ok = False
                notes.append(f"{step} callback {callback}")
            m = re.fullmatch(r"(E\d\d) (.+) to (.+)", hf05_edge)
            if hf05_edge != "none":
                if not m or hf05.get(m.group(1)) != (m.group(2), m.group(3)):
                    edge_ok = False
                    notes.append(f"{step} hf05 {hf05_edge}")
            parts = actors.split(" to ")
            for p in parts:
                if p not in hf03a and p not in NON_MODULE_ACTORS:
                    edge_ok = False
                    notes.append(f"{step} actor {p}")
            if re.fullmatch(r"D\d\d", edge):
                e = hf03b.get(edge)
                target = parts[1] if len(parts) == 2 else None
                if not e or e["from"] != parts[0] or e["to"] != target:
                    edge_ok = False
                    notes.append(f"{step} edge {edge}")
                    continue
                for token in ticks(interface):
                    in_row = token in hf03a[target]["commands"] | hf03a[target]["results"]
                    if not in_row or token not in e["use"]:
                        edge_ok = False
                        notes.append(f"{step} {token} not permitted on {edge}")
            elif edge not in ("none", "local"):
                edge_ok = False
                notes.append(f"{step} edge {edge}")
        record(f"{name}-edges-commands-callbacks", edge_ok, "; ".join(notes) or f"{len(steps)} steps")

    w1_stages = [s[1] for s in table_rows(walks["W1"], r"W1\.\d+")]
    positions = [w1_stages.index(t) if t in w1_stages else -1 for t in W1_ORDER]
    ok = -1 not in positions and positions == sorted(positions) and w1_stages[-1] == "exported-reference"
    ok = ok and "**End state: exported reference**" in walks["W1"]
    record("W1-source-to-exported-reference", ok, f"stage positions {positions}")

    w2_steps = table_rows(walks["W2"], r"W2\.\d+")
    rejection = [s for s in w2_steps if s[1] == "rejection"]
    rejected_edge = [s for s in w2_steps if s[6].endswith("to rejected-reload")]
    ok = (
        bool(rejection) and bool(rejected_edge)
        and "ContentAdmissionFailure" in rejection[0][7]
        and w2_steps.index(rejected_edge[0]) <= w2_steps.index(rejection[0])
        and "**End state: rejection**" in walks["W2"]
    )
    record("W2-missing-reference-named-rejection", ok, rejected_edge[0][6] if rejected_edge else "no rejected-reload edge")

    w3_steps = table_rows(walks["W3"], r"W3\.\d+")
    stages = [s[1] for s in w3_steps]
    checkout = [s for s in w3_steps if s[1] == "checkout"]
    identity = [s for s in w3_steps if s[1] == "identity"]
    cache = [s for s in w3_steps if s[1] == "cache"]
    ok = (
        stages[:2] == ["gate", "settings"]
        and bool(checkout) and "byte-identical in a fresh clone" in checkout[0][7]
        and bool(identity) and "settings digest changed" in identity[0][7] and "SI-01 differs" in identity[0][7]
        and bool(cache) and "rebuilds OC-05" in cache[0][7]
        and stages.index("settings") < stages.index("checkout") < stages.index("identity") < stages.index("cache")
        and "survived a clean checkout, changed the admitted source identity, and the generated cache was rebuilt" in walks["W3"]
    )
    record("W3-changed-setting", ok, f"stages={stages}")

    ag = table_rows(text, r"AG-\d\d")
    bad = [c[0] for c in ag if re.search(r"concept|OC-07", c[2], re.I) or "OC-07 concept images" not in c[3]]
    ci = table_rows(text, r"CI-\d\d")
    ok = len(ag) == 9 and not bad and any("satisfies no production admission requirement" in c[1] for c in ci)
    record("concept-never-satisfies-admission", ok, f"violations={bad}")

    ai = table_rows(text, r"AI-\d\d")
    notes = []
    for c in ai:
        _, _, actors, edge, interface, callback, _ = c[:7]
        parts = actors.split(" to ")
        if callback not in CALLBACKS:
            notes.append(f"{c[0]} callback")
        for p in parts:
            if p not in hf03a and p not in NON_MODULE_ACTORS:
                notes.append(f"{c[0]} actor {p}")
        if re.fullmatch(r"D\d\d", edge):
            e = hf03b.get(edge)
            if not e or len(parts) != 2 or e["from"] != parts[0] or e["to"] != parts[1]:
                notes.append(f"{c[0]} edge {edge}")
                continue
            for token in ticks(interface):
                if token not in hf03a[parts[1]]["commands"] | hf03a[parts[1]]["results"] or token not in e["use"]:
                    notes.append(f"{c[0]} {token}")
        elif edge == "local":
            for token in ticks(interface):
                if token not in hf03a.get(parts[0], {}).get("records", set()):
                    notes.append(f"{c[0]} local {token}")
        elif edge != "none":
            notes.append(f"{c[0]} edge {edge}")
    record("interfaces-in-hf03a-hf03b", len(ai) == 8 and not notes, "; ".join(notes) or "8 rows")

    snake = set(re.findall(r"`([a-z]+(?:_[a-z]+)+)`", text))
    all_commands = set().union(*(m["commands"] for m in hf03a.values()))
    command_like = {t for t in snake if re.fullmatch(r"(stage|validate|admit|resolve|retain|release|present|import|load|commit|register|reimport)_[a-z_]+", t)}
    engine_api = {"reimport_files", "get_files_to_export", "get_customized_files"}
    unknown = sorted(command_like - all_commands - engine_api)
    record("named-commands-exist", not unknown, f"unknown={unknown}")

    aq = table_rows(text, r"AQ-\d\d")
    notes = []
    for c in aq:
        src = c[3]
        qids = re.findall(r"Q-[EP]\d\d", src)
        if not (re.search(r"line", src) or qids):
            notes.append(f"{c[0]} no source")
        for q in qids:
            if f'<a id="{q.lower()}"></a>' not in backlog:
                notes.append(f"{c[0]} {q} unregistered")
    record("parameters-sourced", len(aq) == 18 and not notes, "; ".join(notes) or "18 rows")

    answered = re.findall(r"Q-E06[^.|]*\b(?:is resolved|was answered|answered at|resolved at)", text)
    record("q-e06-not-answered", not answered and "Q-E06 is open" in text, f"hits={answered}")

    hash_notes = []
    count = 0
    in_sources = False
    for line in text.split("\n"):
        if line.startswith("## "):
            in_sources = line == "## Sources"
            continue
        if not in_sources or not line.startswith("- "):
            continue
        link = None
        for m in re.finditer(r"SHA256\s+`([0-9a-f]{64})`|\[[^\]]*\]\(([^)]+)\)", line):
            if m.group(2) is not None:
                target = m.group(2).split("#")[0]
                if target and not re.match(r"[a-z]+:", target) and not (
                    "#" in m.group(2) and Path(target).name in ("BACKLOG.md", "TRACKING.md")):
                    link = target
                continue
            count += 1
            dep = (root / SECTION).parent / link if link else None
            actual = hashlib.sha256(dep.read_bytes()).hexdigest() if dep and dep.exists() else None
            if actual != m.group(1):
                hash_notes.append(f"{link}: {actual}")
    record("source-hashes", count == 21 and not hash_notes, "; ".join(hash_notes) or f"{count} hashes")


def run(text, root, base):
    results = []

    def record(name, ok, detail):
        results.append({"check": name, "pass": bool(ok), "detail": detail})

    try:
        check_all(root, text, base, record)
    except Exception as error:  # a crash on a mutated text counts as that text failing
        record("internal", False, repr(error))
    return results


def negative_controls(text):
    return {
        "N1-settings-step-removed-from-W1": re.sub(r"\n\| W1\.3 \|[^\n]*", "", text),
        "N2-readiness-claimed-ready": text.replace(
            "Production asset readiness at this base: **rejected**", "Production asset readiness at this base: **ready**", 1),
        "N3-cache-class-tracked": re.sub(
            r"(\| OC-05 \|[^|]*\|[^|]*\|[^|]*\| )untracked", r"\1tracked", text),
        "N4-unknown-command-on-D03": text.replace("| `stage_catalogue` | F-LIFECYCLE |", "| `import_asset` | F-LIFECYCLE |", 1),
        "N5-gitignore-quote-altered": text.replace("| `native/**/*.import` |", "| `native/**/*.imports` |", 1),
        "N6-concept-satisfies-admission": text.replace(
            "| OC-01 record with PF-01 to PF-15 and two-way links |", "| OC-07 concept images or OC-01 record |", 1),
        "N7-missing-reference-not-rejected": text.replace("E15 draft to rejected-reload", "E02 draft to imported", 1),
        "N8-settings-identity-unchanged": text.replace("settings digest changed, so SI-01 differs", "settings digest unchanged", 1),
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root")
    parser.add_argument("--out", required=True)
    parser.add_argument("--base", default=DEFAULT_BASE)
    args = parser.parse_args()
    root = Path(args.root).resolve()
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    text = (root / SECTION).read_text()

    positive = run(text, root, args.base)
    controls = []
    for name, mutated in negative_controls(text).items():
        if mutated == text:
            controls.append({"control": name, "mutated": False, "failed_as_required": False, "failing_checks": []})
            continue
        failing = [r["check"] for r in run(mutated, root, args.base) if not r["pass"]]
        controls.append({"control": name, "mutated": True, "failed_as_required": bool(failing), "failing_checks": failing})

    positives_pass = all(r["pass"] for r in positive)
    controls_fail = all(c["failed_as_required"] for c in controls)
    verdict = "pass" if positives_pass and controls_fail else "fail"
    manifest = {
        path: hashlib.sha256((root / path).read_bytes()).hexdigest()
        for path in [SECTION, "docs/tech/sections/HF-03a-module-map.md",
                     "docs/tech/sections/HF-03b-dependency-graph.md",
                     "docs/tech/sections/HF-05-content-admission.md", "BACKLOG.md"]
    }
    head = subprocess.run(["git", "-C", str(root), "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
    report = {
        "section": SECTION,
        "repository_head": head,
        "base": args.base,
        "positive_checks": positive,
        "positive_passed": sum(r["pass"] for r in positive),
        "positive_total": len(positive),
        "negative_controls": controls,
        "negative_failed_as_required": sum(c["failed_as_required"] for c in controls),
        "negative_total": len(controls),
        "verdict": verdict,
        "limits": "Paper consistency of one section against cited files at one base. No engine, import, export or asset behaviour is established.",
    }
    (out / "paper-check.json").write_text(json.dumps(report, indent=2) + "\n")
    (out / "source-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    for r in positive:
        print(("PASS " if r["pass"] else "FAIL ") + r["check"] + " :: " + str(r["detail"]))
    for c in controls:
        print(("CONTROL-OK " if c["failed_as_required"] else "CONTROL-MISSED ") + c["control"] + " :: " + ",".join(c["failing_checks"]))
    print(f"positive {report['positive_passed']}/{report['positive_total']}; negative controls failing as required {report['negative_failed_as_required']}/{report['negative_total']}; verdict {verdict}")
    sys.exit(0 if verdict == "pass" else 1)


if __name__ == "__main__":
    main()
