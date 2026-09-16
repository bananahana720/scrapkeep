#!/usr/bin/env python3
"""Paper check for docs/tech/schemas/SC-06.md against the admitted sources at a repository root."""

import argparse
import copy
import csv
import hashlib
import json
import re
import sys
from pathlib import Path

DOC = "docs/tech/schemas/SC-06.md"
HEADINGS = [
    "Sources",
    "Contract",
    "Scenarios",
    "Unresolved questions",
    "Re-verification triggers",
    "Procedure performed",
    "Evidence limits",
]
REQUIRED_DEPENDENCIES = [
    "docs/tech/sections/HF-01-production-conventions.md",
    "docs/tech/sections/HF-03a-module-map.md",
    "docs/tech/sections/HF-04a-runtime-lifecycle.md",
    "docs/tech/sections/HF-05-content-admission.md",
    "docs/tech/sections/HF-06a-schema-inventory.md",
    "docs/tech/sections/HF-06a-schema-inventory.csv",
    "docs/tech/sections/HF-06b-persistence-projection.md",
    "docs/tech/sections/HF-06b-persistence-projection.csv",
    "docs/tech/sections/HF-07a-save-envelope.md",
    "docs/tech/sections/HF-07a-save-envelope.csv",
    "docs/tech/sections/HF-07b-commit-boundaries.md",
    "docs/tech/sections/HF-09-schema-migration.md",
    "docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md",
    "docs/tech/sections/TH-04-abilities-ultimates-and-combat-rhythm.md",
    "docs/tech/sections/TH-08-inventory-equipment-and-transformations.md",
    "docs/tech/sections/TH-10-devices-and-one-main-companion.md",
    "docs/tech/sections/TH-16-rendering-integration.md",
]
EDGE_GATE = {"E02": "import and source", "E03": "structural", "E04": "semantic"}
FAILURE_EDGES = {"structural": {"E08", "E11"}, "semantic": {"E09", "E12"}}
WALK_OUTCOME = {"AV": {"pinned"}, "AM": {"rejected-reload", "pinned"}, "AI": {"draft"}, "AX": {"draft"}}
NUMBER_WORDS = {"zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7,
                "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13,
                "fourteen": 14, "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18,
                "nineteen": 19, "twenty": 20}


class Report:
    def __init__(self):
        self.results = []

    def check(self, group, name, ok, detail=""):
        self.results.append({"group": group, "name": name, "ok": bool(ok), "detail": str(detail)[:400]})

    def failed_groups(self):
        return sorted({r["group"] for r in self.results if not r["ok"]})

    def counts(self):
        passed = sum(r["ok"] for r in self.results)
        return passed, len(self.results) - passed


def plain(cell):
    cell = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", cell)
    return cell.replace("**", "").replace("`", "").strip()


def split_row(line):
    return [c.strip() for c in line.strip().strip("|").split("|")]


def tables(lines):
    """Every pipe table as (start line index, header, rows of dicts keyed by plain header)."""
    found = []
    i = 0
    while i < len(lines) - 1:
        if lines[i].startswith("|") and re.match(r"^\|\s*-{3}", lines[i + 1]):
            header = [plain(c) for c in split_row(lines[i])]
            rows = []
            j = i + 2
            while j < len(lines) and lines[j].startswith("|"):
                cells = split_row(lines[j])
                rows.append(dict(zip(header, cells)))
                j += 1
            found.append((i, header, rows))
            i = j
        else:
            i += 1
    return found


def table_with(lines, first_columns, start=0, end=None):
    for index, header, rows in tables(lines[start:end]):
        if header[: len(first_columns)] == first_columns:
            return rows
    return None


def section_bounds(lines, pattern, level):
    marker = "#" * level + " "
    start = next((i for i, l in enumerate(lines) if l.startswith(marker) and re.match(pattern, l[len(marker):])), None)
    if start is None:
        return None, None
    end = len(lines)
    for j in range(start + 1, len(lines)):
        m = re.match(r"^(#{1,6}) ", lines[j])
        if m and len(m.group(1)) <= level:
            end = j
            break
    return start, end


def read_csv(path):
    with open(path, newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def parse_value(text):
    text = plain(text)
    if text.startswith("[") and text.endswith("]"):
        inner = text[1:-1].strip()
        return [v.strip() for v in inner.split(",")] if inner else []
    if re.fullmatch(r"\d+", text):
        return int(text)
    return text


def leaf_paths(value, prefix=""):
    if isinstance(value, dict):
        paths = []
        for key, child in value.items():
            path = f"{prefix}.{key}" if prefix else key
            paths.append((path, child))
            if not (isinstance(child, dict) and path.endswith("counters")):
                paths.extend(leaf_paths(child, path))
        return paths
    if isinstance(value, list):
        paths = []
        for child in value:
            if isinstance(child, dict):
                paths.extend(leaf_paths(child, prefix + "[]"))
        return paths
    return []


def run_checks(doc_text, root):
    report = Report()
    lines = doc_text.split("\n")
    doc_dir = (root / DOC).parent
    backlog = (root / "BACKLOG.md").read_text(encoding="utf-8")
    hf06a = read_csv(root / "docs/tech/sections/HF-06a-schema-inventory.csv")
    hf06a_by_id = {r["row_id"]: r for r in hf06a}
    hf06b_by_id = {r["row_id"]: r for r in read_csv(root / "docs/tech/sections/HF-06b-persistence-projection.csv")}
    hf07a_by_field = {r["field"]: r for r in read_csv(root / "docs/tech/sections/HF-07a-save-envelope.csv")}
    hf05_lines = (root / "docs/tech/sections/HF-05-content-admission.md").read_text(encoding="utf-8").split("\n")
    hf09_text = (root / "docs/tech/sections/HF-09-schema-migration.md").read_text(encoding="utf-8")

    def question_exists(qid):
        return f'<a id="{qid.lower()}"></a>' in backlog

    # C01 headings
    level2 = [l[3:].strip() for l in lines if l.startswith("## ")]
    report.check("C01-headings", "seven required headings in order", level2 == HEADINGS, level2)

    # C02 stated hashes
    s_start, s_end = section_bounds(lines, r"Sources$", 2)
    bullets = []
    for line in lines[s_start + 1:s_end]:
        if re.match(r"^\s*[-*]\s+", line):
            bullets.append(line)
        elif bullets and line.strip():
            bullets[-1] += " " + line.strip()
    stated = {}
    token = re.compile(r"SHA256\s+`([0-9a-fA-F]{64})`|\[(?:[^\]]*)\]\(([^)]+)\)")
    for bullet in bullets:
        last_link = None
        for m in token.finditer(bullet):
            if m.group(2):
                target = m.group(2)
                bare = target.split("#")[0]
                if not bare or re.match(r"^[a-z][a-z0-9+.-]*:", bare) or ("#" in target and Path(bare).name in {"BACKLOG.md", "TRACKING.md"}):
                    continue
                last_link = bare
            elif last_link:
                resolved = (doc_dir / last_link).resolve()
                rel = resolved.relative_to(root.resolve()).as_posix() if resolved.is_relative_to(root.resolve()) else str(resolved)
                actual = hashlib.sha256(resolved.read_bytes()).hexdigest() if resolved.exists() else "missing"
                stated[rel] = m.group(1)
                report.check("C02-hashes", f"{rel} stated hash matches", actual == m.group(1).lower(), f"stated {m.group(1)} actual {actual}")
            else:
                report.check("C02-hashes", "hash bound to a link", False, bullet[:120])
    for dependency in REQUIRED_DEPENDENCIES:
        report.check("C02-hashes", f"{dependency} hash stated", dependency in stated, dependency)

    # C03 rows and types
    scope = [r for r in hf06a if r["producing_card"] == "SC-06"]
    scope_ids = [r["row_id"] for r in scope]
    types_rows = table_with(lines, ["Type", "Name", "Family token", "HF-06a rows", "Named in rationale by"])
    alloc_rows = table_with(lines, ["Row", "Subject", "Treatment", "Questions", "Types"])
    report.check("C03-rows", "type table present", bool(types_rows))
    report.check("C03-rows", "allocation table present", bool(alloc_rows))
    types_rows = types_rows or []
    alloc_rows = alloc_rows or []
    types = {plain(r["Type"]): r for r in types_rows}
    alloc_ids = [plain(r["Row"]) for r in alloc_rows]
    report.check("C03-rows", "every SC-06 row allocated exactly once", sorted(alloc_ids) == sorted(scope_ids) and len(alloc_ids) == len(set(alloc_ids)), f"{alloc_ids} vs {scope_ids}")
    alloc = {}
    for row in alloc_rows:
        rid = plain(row["Row"])
        source = hf06a_by_id.get(rid)
        alloc[rid] = [t.strip() for t in plain(row["Types"]).split(",") if t.strip()]
        report.check("C03-rows", f"{rid} exists in HF-06a", source is not None, rid)
        if not source:
            continue
        questions = sorted(q.strip() for q in re.split(r"[;,]", source["questions"]))
        doc_questions = sorted(q.strip() for q in re.split(r"[;,]", plain(row["Questions"])))
        report.check("C03-rows", f"{rid} subject, treatment and questions equal HF-06a", source["subject"] == plain(row["Subject"]) and source["treatment"] == plain(row["Treatment"]) and questions == doc_questions, row)
        report.check("C03-rows", f"{rid} rationale basis quoted from HF-06a", plain(row.get("Rationale basis", "")) in source["scope_and_rationale"], row.get("Rationale basis"))
        report.check("C03-rows", f"{rid} types are defined", bool(alloc[rid]) and all(t in types for t in alloc[rid]), alloc[rid])
    md_rationale = {}
    hf06a_md = (root / "docs/tech/sections/HF-06a-schema-inventory.md").read_text(encoding="utf-8").split("\n")
    for l in hf06a_md:
        m = re.match(r"^\| ((?:F|N)-\d{2,3}) \|", l)
        if m:
            md_rationale[m.group(1)] = plain(split_row(l)[-1])
    nouns = {t: [n.strip() for n in plain(r["Named in rationale by"]).split(",") if n.strip()] for t, r in types.items()}

    def named_types(text):
        return sorted(t for t, ns in nouns.items() if any(re.search(rf"(?<![\w-]){re.escape(n)}(?![\w-])", text, re.I) for n in ns))

    type_rows = {t: sorted(x.strip() for x in plain(r["HF-06a rows"]).split(",")) for t, r in types.items()}
    for rid in scope_ids:
        csv_named = named_types(hf06a_by_id[rid]["scope_and_rationale"])
        md_named = named_types(md_rationale.get(rid, ""))
        report.check("C03-rows", f"{rid} Markdown and CSV rationales name the same types", bool(md_rationale.get(rid)) and csv_named == md_named, f"csv {csv_named} md {md_named}")
        report.check("C03-rows", f"{rid} allocated types equal the types its rationale names", sorted(alloc.get(rid, [])) == csv_named, f"{alloc.get(rid)} vs {csv_named}")
    for type_id in types:
        naming_rows = sorted(rid for rid in scope_ids if type_id in named_types(hf06a_by_id[rid]["scope_and_rationale"]))
        report.check("C03-rows", f"{type_id} rows equal the rows whose rationale names it", type_rows[type_id] == naming_rows and bool(naming_rows), f"{type_rows[type_id]} vs {naming_rows}")
        holders = sorted(rid for rid, ts in alloc.items() if type_id in ts)
        report.check("C03-rows", f"{type_id} rows agree with the allocation table", holders == type_rows[type_id], holders)
    all_allocated = {t for ts in alloc.values() for t in ts}
    report.check("C03-rows", "no type lacks an HF-06a row", set(types) <= all_allocated and bool(types), sorted(set(types) - all_allocated))

    # C04 per-type completeness and C05 references
    admission = table_with(lines, ["ID", "Gate", "Check", "Diagnostic"]) or []
    defined_rules = set(re.findall(r"sc06\.[a-z_]+", " ".join(r["Diagnostic"] for r in admission)))
    params = {plain(r["ID"]): r for r in (table_with(lines, ["ID", "Parameter", "Value at this base"]) or [])}
    edges = {}
    for l in hf05_lines:
        m = re.match(r"^\| (E\d\d) \| ([a-z -]+?) \| ([a-z -]+?) \|", l)
        if m:
            edges[m.group(1)] = (m.group(2).strip(), m.group(3).strip())
    type_fields = {}
    for type_id, row in types.items():
        name = plain(row["Name"])
        t_start, t_end = section_bounds(lines, rf"{type_id}: {name}$", 3)
        report.check("C04-types", f"{type_id} section present", t_start is not None, name)
        if t_start is None:
            continue
        block = lines[t_start:t_end]
        parts = {}
        for heading in ["Fields", "Identity and version", "References", "Diagnostics", "Illustrative record"]:
            h_start, h_end = section_bounds(block, rf"{heading}$", 4)
            parts[heading] = block[h_start + 1:h_end] if h_start is not None else None
            content = [l for l in (parts[heading] or []) if l.strip()]
            report.check("C04-types", f"{type_id} has {heading}", bool(content), heading)
        fields = table_with(parts["Fields"] or [], ["Field", "Type"]) or []
        type_fields[type_id] = fields
        report.check("C04-types", f"{type_id} fields carry types", bool(fields) and all(plain(f["Field"]) and plain(f["Type"]) for f in fields), len(fields))
        report.check("C04-types", f"{type_id} identity rule names id and version", "`id`" in " ".join(parts["Identity and version"] or []) and "VR-" in " ".join(parts["Identity and version"] or []))
        diag = table_with(parts["Diagnostics"] or [], ["Rule", "Diagnostic"]) or []
        diag_edges = [plain(d.get(c, "")) for d in diag for c in ("Initial edge", "Replacement edge")]
        report.check("C04-types", f"{type_id} diagnostics name HF-05 edges", bool(diag) and all(e in edges for e in diag_edges), diag_edges)
        report.check("C04-types", f"{type_id} illustrative record labelled", "Illustrative, not canon." in " ".join(parts["Illustrative record"] or []))
        for f in fields:
            value = plain(f.get("Value at this base", ""))
            ok = value == "issued with the definition" or (value in params)
            report.check("C09-symbolic", f"{type_id} {plain(f['Field'])} value names a parameter row or identity", ok, value)
        refs = table_with(parts["References"] or [], ["Field", "Target", "Target kind"]) or []
        ref_fields = {plain(r["Field"]).rstrip("[]") for r in refs}
        for f in fields:
            fname = plain(f["Field"])
            if "id-string" in f["Type"] and fname != "id":
                report.check("C05-references", f"{type_id} {fname} listed in references", fname in ref_fields, fname)
        for r in refs:
            target = plain(r["Target"])
            ok = target in types or (target in hf06a_by_id and hf06a_by_id[target]["treatment"] != "excluded")
            report.check("C05-references", f"{type_id} {plain(r['Field'])} target is a type here or a non-excluded HF-06a row", ok, target)
        illustrative = table_with(parts["Illustrative record"] or [], ["Field", "Illustrative value"]) or []
        record = {plain(r["Field"]): parse_value(r["Illustrative value"]) for r in illustrative}
        report.check("C08-roundtrip", f"{type_id} illustrative record covers every field in order", list(record) == [plain(f["Field"]) for f in fields], list(record))
        decoded = json.loads(json.dumps(record))
        report.check("C08-roundtrip", f"{type_id} illustrative encode then decode preserves every field", decoded == record and list(decoded) == list(record))
        for ref in refs:
            fname = plain(ref["Field"]).rstrip("[]")
            report.check("C08-roundtrip", f"{type_id} {fname} references preserved", decoded.get(fname) == record.get(fname) and isinstance(decoded.get(fname), list), decoded.get(fname))
        for key, value in record.items():
            values = value if isinstance(value, list) else [value]
            for v in values:
                if isinstance(v, str) and key == "id" or (isinstance(v, str) and key.endswith("_ids")):
                    report.check("C08-roundtrip", f"{type_id} {key} member is a placeholder", v.startswith("example."), v)
                if isinstance(v, str) and (key.endswith("_rule") or key == "display_name"):
                    m = re.fullmatch(r"unset:(Q-[PE]\d\d)", v)
                    report.check("C09-symbolic", f"{type_id} {key} illustrative value symbolic with a registered question", bool(m) and question_exists(m.group(1)), v)
            if isinstance(value, list):
                report.check("C08-roundtrip", f"{type_id} {key} is an ascending set", value == sorted(set(value), key=lambda s: s.encode()), value)
        action_field = "deployed_action_ids" if "deployed_action_ids" in record else "action_ids"
        report.check("C08-roundtrip", f"{type_id} illustrative compatibility actions drawn from own actions", set(record.get("compatibility_action_ids", [])) <= set(record.get(action_field, [])))
    for r in table_with(lines, ["Reference", "Direction", "HF-06a row"]) or []:
        target = plain(r["HF-06a row"])
        report.check("C05-references", f"foreign reference {plain(r['Reference'])} targets a non-excluded HF-06a row", target in hf06a_by_id and hf06a_by_id[target]["treatment"] != "excluded", target)
    for rule in set(re.findall(r"sc06\.[a-z_]+", doc_text)):
        report.check("C07-walks", f"{rule} defined in the admission table", rule in defined_rules, rule)

    # C06 save treatment
    save_rows = table_with(lines, ["Type", "HF-06b rows", "Save column", "Case"]) or []
    report.check("C06-save", "every type has one save row", sorted(plain(r["Type"]) for r in save_rows) == sorted(types), [plain(r["Type"]) for r in save_rows])
    for row in save_rows:
        type_id = plain(row["Type"])
        expected_rows = type_rows.get(type_id, [])
        doc_rows = sorted(r.strip() for r in plain(row["HF-06b rows"]).split(","))
        report.check("C06-save", f"{type_id} HF-06b rows equal its allocated rows", doc_rows == expected_rows, doc_rows)
        group = plain(row["Projection group"])
        for rid in doc_rows:
            source = hf06b_by_id.get(rid, {})
            ok = source.get("save_column") == plain(row["Save column"]) and source.get("rationale_case") == plain(row["Case"]) and group in [g.strip() for g in source.get("save_projection", "").split(";")]
            report.check("C06-save", f"{type_id} save column, case and group equal HF-06b row {rid}", ok, source.get("save_column"))
        report.check("C06-save", f"{type_id} definition never serialized", "never" in plain(row["Definition in save"]))
        for field in [f.strip() for f in plain(row["HF-07a fields"]).split(",")]:
            source = hf07a_by_field.get(field)
            report.check("C06-save", f"{type_id} {field} is an HF-07a CSV field", source is not None, field)
            if source:
                report.check("C06-save", f"{type_id} {field} group matches", source["projection_group"] in (group, "container"), source["projection_group"])
                if source["projection_group"] != "container":
                    credited = re.findall(r"(?:F|N)-\d{2,3}", source["source"])
                    report.check("C06-save", f"{type_id} {field} credits one of its HF-06b rows", bool(set(credited) & set(expected_rows)), source["source"])
        family = plain(types[type_id]["Family token"]) if type_id in types else ""
        report.check("C05-references", f"{type_id} load family equals its family token", plain(row["Expected family on load"]) == family, family)
    for token in set(re.findall(r"`((?:run|preferences)\.[a-z_.\[\]]+)`", doc_text)):
        normalized = re.sub(r"\[[a-z0-9]*\]", "[]", token)
        report.check("C06-save", f"{token} names an HF-07a CSV field", normalized in hf07a_by_field, normalized)

    # C07 walks
    codes_line = next((l for l in hf05_lines if l.startswith("| `code` |")), "")
    codes = set(re.findall(r"`([a-z_]+)`", codes_line)) - {"code"}
    field_table = table_with(hf05_lines, ["Field", "Meaning"]) or []
    failure_fields = [plain(r["Field"]) for r in field_table]
    report.check("C07-walks", "HF-05 closed code set and eleven fields parsed", len(codes) == 5 and len(failure_fields) == 11, (sorted(codes), failure_fields))
    for walk, outcomes in WALK_OUTCOME.items():
        w_start, w_end = section_bounds(lines, rf"{walk}: ", 3)
        rows = table_with(lines[w_start:w_end] if w_start is not None else [], ["Step", "Subject", "Gate", "Edge"]) or []
        report.check("C07-walks", f"{walk} walk present", bool(rows))
        last_to = {}
        reached = set()
        for row in rows:
            step, subject, gate, edge = plain(row["Step"]), plain(row["Subject"]), plain(row["Gate"]), plain(row["Edge"])
            frm, to = plain(row["From"]), plain(row["To"])
            report.check("C07-walks", f"{step} edge {edge} and endpoints match HF-05", edges.get(edge) == (frm, to), f"{edge} {frm}->{to} vs {edges.get(edge)}")
            if subject in last_to:
                report.check("C07-walks", f"{step} continues {subject}", last_to[subject] == frm, f"{last_to[subject]} -> {frm}")
            last_to[subject] = to
            reached.add(to)
            if edge in EDGE_GATE:
                report.check("C07-walks", f"{step} passing edge evaluated at its gate", gate == EDGE_GATE[edge], gate)
            failing = next((g for g, es in FAILURE_EDGES.items() if edge in es), None)
            if failing:
                report.check("C07-walks", f"{step} failure edge taken by the gate that failed", gate == failing, f"{gate} {edge}")
                text = row["Check and result"]
                named = set(re.findall(r"`([a-z_]+)`", text)) & codes
                rules = set(re.findall(r"sc06\.[a-z_]+", text))
                report.check("C07-walks", f"{step} names an HF-05 code or a defined rule", bool(named) or bool(rules & defined_rules), (named, rules))
                if walk == "AM":
                    missing = [f for f in failure_fields if f"`{f}`" not in text]
                    report.check("C07-walks", f"{step} carries all eleven ContentReferenceFailure fields", not missing, missing)
        report.check("C07-walks", f"{walk} reaches its outcome", bool(outcomes & reached) and last_to and list(last_to.values())[-1] in outcomes, reached)
    as_start, as_end = section_bounds(lines, r"AS: ", 3)
    as_rows = table_with(lines[as_start:as_end] if as_start is not None else [], ["Step", "Axis", "Value", "Row"]) or []
    report.check("C07-walks", "AS walk present", bool(as_rows))
    for row in as_rows:
        value, prow = plain(row["Value"]), plain(row["Row"])
        if value != "none":
            report.check("C07-walks", f"{plain(row['Step'])} axis value exists in HF-09", f"| `{value}` |" in hf09_text, value)
        if prow != "none":
            m = re.search(rf"^\| {prow} \|.*$", hf09_text, re.M)
            report.check("C07-walks", f"{plain(row['Step'])} row {prow} exists in HF-09", bool(m), prow)
            if m and "wrong-family" in value:
                report.check("C07-walks", f"{plain(row['Step'])} code matches HF-09 {prow}", "wrong_family" in m.group(0) and "wrong_family" in row["Result"], prow)

    # C08 projection round trip
    p_start, p_end = section_bounds(lines, r"Illustrative projection$", 4)
    block = "\n".join(lines[p_start:p_end]) if p_start is not None else ""
    report.check("C08-roundtrip", "illustrative projection labelled", "Illustrative, not canon." in block)
    m = re.search(r"```json\n(.*?)\n```", block, re.S)
    projection = json.loads(m.group(1)) if m else None
    report.check("C08-roundtrip", "illustrative projection parses", projection is not None)
    if projection is not None:
        report.check("C08-roundtrip", "projection encode then decode preserves every value", json.loads(json.dumps(projection)) == projection)
        empty = copy.deepcopy(projection)
        empty["run"]["checkpoint"]["companion"] = {"chassis_id": None, "component_ids": [], "command_ids": []}
        report.check("C08-roundtrip", "no-companion state round-trips with null and empty arrays", json.loads(json.dumps(empty)) == empty)
        for path, value in leaf_paths(projection):
            report.check("C08-roundtrip", f"{path} is an HF-07a field", path in hf07a_by_field, path)
            kind = hf07a_by_field.get(path, {}).get("type", "")
            if kind == "array of id-string":
                report.check("C08-roundtrip", f"{path} ascending id-strings", all(isinstance(v, str) for v in value) and value == sorted(value, key=lambda s: s.encode()), value)
            if kind.startswith("id-string"):
                report.check("C08-roundtrip", f"{path} is a string", isinstance(value, str) or (value is None and "null" in kind), value)
            if kind == "map of string to int":
                report.check("C08-roundtrip", f"{path} holds ints only", isinstance(value, dict) and all(isinstance(v, int) for v in value.values()), value)

    # C09 parameters
    report.check("C09-symbolic", "parameter table present", bool(params))
    sourced = unset = 0
    for pid, row in params.items():
        value, source = plain(row["Value at this base"]), plain(row["Source line or question"])
        if value == "unset":
            unset += 1
            qids = re.findall(r"Q-[PE]\d\d", source)
            report.check("C09-symbolic", f"{pid} unset with a registered question", bool(qids) and all(question_exists(q) for q in qids), source)
        else:
            sourced += 1
            report.check("C09-symbolic", f"{pid} value carries a source line", re.search(r"lines? \d+", source) is not None, source)
    summary = re.search(r"(\w+) rows: (\w+) carry a source line, (\w+) are `unset`", doc_text)
    report.check("C09-symbolic", "parameter summary counts match the table", bool(summary) and [NUMBER_WORDS.get(w.lower()) for w in summary.groups()] == [len(params), sourced, unset], (summary.groups() if summary else None, len(params), sourced, unset))
    for qid in set(re.findall(r"Q-[PE]\d\d", doc_text)):
        report.check("C09-symbolic", f"{qid} is a registered question", question_exists(qid), qid)

    # C10 guards
    report.check("C10-guards", "no EV-0144 proposal field name", not re.search(r"recall_policy|resource_policy", doc_text))
    report.check("C10-guards", "no Resource or script syntax", not re.search(r"\[gd_resource|^\s*extends\s+\w+|^\s*class_name\s+\w+|@export var", doc_text, re.M))
    report.check("C10-guards", "no revival field in any type", not any("reviv" in plain(f["Field"]) for fs in type_fields.values() for f in fs))
    return report


NEGATIVE_CONTROLS = [
    ("NC1 drop row N-027 from the allocation", "C03-rows",
     "| N-027 | Devices and one main companion | schema | Q-P15 | T1, T2, T3, T4 |", "| N-099 | Devices and one main companion | schema | Q-P15 | T1, T2, T3, T4 |"),
    ("NC2 give T3 row F-06, whose rationale does not name a component", "C03-rows",
     "| T3 | `CompanionComponentDefinition` | `companion_component` | F-07, N-027 |", "| T3 | `CompanionComponentDefinition` | `companion_component` | F-06, N-027 |"),
    ("NC3 project a field HF-07a does not carry", "C06-save",
     "`run.checkpoint.companion`, `run.checkpoint.companion.command_ids` |", "`run.checkpoint.companion`, `run.checkpoint.companion.command_names` |"),
    ("NC4 missing-reference walk skips to admission", "C07-walks",
     "| AM.3 | candidate B | semantic | E12 |", "| AM.3 | candidate B | semantic | E05 |"),
    ("NC5 remove the T2 illustrative label", "C04-types",
     "Illustrative, not canon. Every identifier is a placeholder and every rule and name value is symbolic; SM-03 refuses this record at admission (walk AX).", "Every identifier is a placeholder."),
    ("NC6 give capacity a number with no source", "C09-symbolic",
     "| SP-06 | Admissible `capacity_rule` identifiers, including what happens beyond capacity | unset |", "| SP-06 | Admissible `capacity_rule` identifiers, including what happens beyond capacity | 2 |"),
    ("NC7 reference an excluded row", "C05-references",
     "| `deployed_action_ids[]` | F-02 |", "| `deployed_action_ids[]` | N-022 |"),
    ("NC8 corrupt a stated hash", "C02-hashes",
     "7ef95df2fb25f05b7b544cd7dbf2239cd1106c382aab0e8bc5e76288146259a6", "0ef95df2fb25f05b7b544cd7dbf2239cd1106c382aab0e8bc5e76288146259a6"),
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    root = Path(args.root).resolve()
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    doc_text = (root / DOC).read_text(encoding="utf-8")

    report = run_checks(doc_text, root)
    passed, failed = report.counts()
    controls = []
    for name, group, old, new in NEGATIVE_CONTROLS:
        applied = doc_text.count(old) == 1
        mutated = run_checks(doc_text.replace(old, new), root) if applied else None
        groups = mutated.failed_groups() if mutated else []
        controls.append({"control": name, "expected_group": group, "mutation_applied": applied, "failed_groups": groups, "ok": applied and group in groups})
    controls_ok = sum(c["ok"] for c in controls)

    log = [f"{'PASS' if r['ok'] else 'FAIL'} {r['group']} :: {r['name']}" + ("" if r["ok"] else f" :: {r['detail']}") for r in report.results]
    log += [f"{'CONTROL-OK' if c['ok'] else 'CONTROL-MISSED'} {c['control']} -> expected {c['expected_group']}, failed {c['failed_groups']}" for c in controls]
    verdict = "PASS" if failed == 0 and controls_ok == len(controls) else "FAIL"
    log.append(f"{verdict}: {passed} passed, {failed} failed; negative controls {controls_ok}/{len(controls)} failed as intended")
    (out / "paper-check.log").write_text("\n".join(log) + "\n", encoding="utf-8")
    (out / "paper-check.json").write_text(json.dumps({"verdict": verdict, "passed": passed, "failed": failed, "results": report.results, "negative_controls": controls}, indent=2) + "\n", encoding="utf-8")
    manifest = {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in [DOC, "BACKLOG.md"] + REQUIRED_DEPENDENCIES}
    manifest["checker"] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    (out / "source-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(log[-1])
    return 0 if verdict == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
