#!/usr/bin/env python3
"""Paper check for docs/tech/schemas/SC-04.md.

Usage: check_schema.py <repository-root> --out <directory>
Exit 0 when every check passes and every negative control is caught, 1 otherwise.
"""
import argparse
import csv
import hashlib
import json
import re
import sys
from pathlib import Path

SECTION = "docs/tech/schemas/SC-04.md"
HEADINGS = [
    "Sources",
    "Contract",
    "Scenarios",
    "Unresolved questions",
    "Re-verification triggers",
    "Procedure performed",
    "Evidence limits",
]
CARD = "SC-04"
FAILURE_KINDS = {"ContentAdmissionFailure", "ContentReferenceFailure"}
STRUCTURAL_GATES = {"Import and source", "Structural/domain"}
SEMANTIC_GATES = {"Cross-reference/semantic", "Manifest and compatibility"}
GATE_EDGES = {
    "Import and source": {"E02", "E08", "E11", "E15"},
    "Structural/domain": {"E03", "E08", "E11"},
    "Cross-reference/semantic": {"E04", "E09", "E12"},
    "Manifest and compatibility": {"E16", "E05", "E09", "E12"},
}
SAVE_PATH = re.compile(r"`((?:run|profile|preferences)\.[A-Za-z0-9_.\[\]]+)`")
SYMBOLIC = re.compile(r"^SYMBOLIC\((ST-\d+); (Q-[EP]\d+)\)$")
QID = re.compile(r"\bQ-[EP]\d+\b")
NUMBER = re.compile(r"^-?\d+(\.\d+)?$")


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def cells(line):
    return [c.strip() for c in line.strip().strip("|").split("|")]


def tables(lines):
    """Every Markdown table as (first line number, header, rows)."""
    found = []
    i = 0
    while i < len(lines):
        if lines[i].startswith("|") and i + 1 < len(lines) and re.match(r"^\|\s*-", lines[i + 1]):
            header = cells(lines[i])
            rows = []
            j = i + 2
            while j < len(lines) and lines[j].startswith("|"):
                rows.append(cells(lines[j]))
                j += 1
            found.append((i + 1, header, rows))
            i = j
        else:
            i += 1
    return found


def table_with(lines, first_columns):
    for start, header, rows in tables(lines):
        if header[: len(first_columns)] == first_columns:
            return header, rows
    return None, []


def slice_heading(lines, prefix, level):
    """Lines under the first heading starting with prefix, up to the next heading of the same or higher level."""
    marker = "#" * level + " "
    fenced, visible = False, []
    for line in lines:
        if line.startswith("```"):
            fenced = not fenced
        visible.append(not fenced and not line.startswith("```"))
    for i, line in enumerate(lines):
        if visible[i] and line.startswith(marker + prefix):
            end = len(lines)
            for j in range(i + 1, len(lines)):
                m = re.match(r"^(#+) ", lines[j])
                if visible[j] and m and len(m.group(1)) <= level:
                    end = j
                    break
            return lines[i + 1 : end]
    return None


def fenced_blocks(lines):
    blocks, current, inside = [], None, False
    for line in lines:
        if line.startswith("```"):
            if inside:
                blocks.append(current)
                inside = False
            else:
                current, inside = [], True
            continue
        if inside:
            current.append(line)
    return blocks


def load_repo(root):
    tech = root / "docs/tech/sections"
    hf06a = list(csv.DictReader(open(tech / "HF-06a-schema-inventory.csv", encoding="utf-8")))
    hf06b = {r["row_id"]: r for r in csv.DictReader(open(tech / "HF-06b-persistence-projection.csv", encoding="utf-8"))}
    hf07a = [r["field"] for r in csv.DictReader(open(tech / "HF-07a-save-envelope.csv", encoding="utf-8"))]
    edges = {}
    for line in (tech / "HF-05-content-admission.md").read_text(encoding="utf-8").splitlines():
        m = re.match(r"^\| (E\d\d) \| ([a-z -]+?) \| ([a-z -]+?) \|", line)
        if m:
            edges[m.group(1)] = (m.group(2), m.group(3))
    codes = set()
    for line in (tech / "HF-05-content-admission.md").read_text(encoding="utf-8").splitlines():
        if line.startswith("| `code` |"):
            codes = set(re.findall(r"`([a-z_]+)`", line.split("|")[2]))
    anchors = set(re.findall(r'<a id="(q-[ep]\d+)"></a>', (root / "BACKLOG.md").read_text(encoding="utf-8")))
    return {
        "hf06a": {r["row_id"]: r for r in hf06a},
        "family_rows": {r["row_id"] for r in hf06a if r["producing_card"] == CARD},
        "hf06b": hf06b,
        "hf07a": set(hf07a),
        "edges": edges,
        "codes": codes,
        "anchors": anchors,
    }


def parse_value(raw):
    raw = raw.strip()
    if raw == "null":
        return None
    if raw == "[]":
        return []
    if raw.startswith('"') and raw.endswith('"'):
        return raw[1:-1]
    return raw


def build_record(lines):
    record, meta = {}, {}
    for line in lines:
        if line.startswith("#"):
            m = re.match(r"^# type (T\d)$", line)
            if m:
                meta["type"] = m.group(1)
            m = re.match(r"^# embedded in (\S+) at (\S+)$", line)
            if m:
                meta["embedded_in"], meta["embedded_at"] = m.group(1), m.group(2)
            continue
        if not line.strip():
            continue
        path, _, raw = line.partition(" = ")
        set_path(record, path.strip(), parse_value(raw))
    return record, meta


def set_path(target, path, value):
    parts = path.split(".")
    node = target
    for k, part in enumerate(parts):
        last = k == len(parts) - 1
        m = re.match(r"^([a-z_]+)\[(\d+)\]$", part)
        if m:
            name, index = m.group(1), int(m.group(2))
            seq = node.setdefault(name, [])
            while len(seq) <= index:
                seq.append({} if not last else None)
            if last:
                seq[index] = value
            else:
                if not isinstance(seq[index], dict):
                    seq[index] = {}
                node = seq[index]
        else:
            if last:
                node[part] = value
            else:
                node = node.setdefault(part, {})


def get_path(record, path):
    node = record
    for part in path.split("."):
        m = re.match(r"^([a-z_]+)\[(\d+)\]$", part)
        if m:
            node = node[m.group(1)][int(m.group(2))]
        else:
            node = node[part]
    return node


def leaf_paths(value, prefix=""):
    if isinstance(value, dict):
        out = []
        for key, inner in value.items():
            out += leaf_paths(inner, f"{prefix}.{key}" if prefix else key)
        return out
    if isinstance(value, list) and value:
        out = []
        for index, inner in enumerate(value):
            out += leaf_paths(inner, f"{prefix}[{index}]")
        return out
    return [(prefix, value)]


def normal(path):
    return re.sub(r"\[\d+\]", "[]", path)


class Checker:
    def __init__(self, root, text, repo):
        self.root, self.text, self.repo = root, text, repo
        self.lines = text.splitlines()
        self.results = []
        self.counts = {}

    def check(self, name, failures):
        self.results.append({"check": name, "passed": not failures, "failures": failures})

    def run(self):
        for fn in [
            self.headings,
            self.coverage,
            self.types,
            self.references,
            self.save,
            self.traces,
            self.records,
            self.parameters,
            self.questions,
            self.hashes,
        ]:
            try:
                fn()
            except Exception as error:  # a parse failure is a failed check, never a pass
                self.check(fn.__name__, [f"internal: {type(error).__name__}: {error}"])
        return self.results

    def headings(self):
        found = [l[3:].strip() for l in self.lines if l.startswith("## ")]
        self.check("seven required headings in order", [] if found == HEADINGS else [f"found {found}"])

    def scope(self):
        header, rows = table_with(self.lines, ["Card item", "Type", "Name", "HF-06a row", "Row root"])
        types = {}
        for r in rows:
            item, tid, name, row, root, treatment, identity, parent = r
            types[tid] = {"item": item, "name": name, "row": row, "root": root, "treatment": treatment, "parent": parent}
        return types

    def coverage(self):
        types = self.scope()
        failures = []
        if not types:
            failures.append("scope table not found")
        family = self.repo["family_rows"]
        used = {t["row"] for t in types.values()}
        for tid, t in types.items():
            if t["row"] not in family:
                failures.append(f"{tid} maps to {t['row']}, which HF-06a does not assign to {CARD}")
        for row in family:
            roots = [tid for tid, t in types.items() if t["row"] == row and t["root"] == "yes"]
            if row not in used:
                failures.append(f"HF-06a row {row} has no type")
            if len(roots) != 1:
                failures.append(f"HF-06a row {row} has {len(roots)} root types, expected exactly one")
        for tid, t in types.items():
            if t["parent"] != "—":
                for parent in [p.strip() for p in t["parent"].split(",")]:
                    if parent not in types or types[parent]["row"] != t["row"]:
                        failures.append(f"{tid} parent {parent} is missing or on another row")
            if self.repo["hf06a"].get(t["row"], {}).get("treatment") != "schema":
                failures.append(f"{tid} row {t['row']} treatment is not schema")
        self.counts["types"] = len(types)
        self.counts["family_rows"] = len(family)
        self.check("every family row maps to types and every type to one family row", failures)

    def type_section(self, tid, name):
        return slice_heading(self.lines, f"{tid} {name}", 3)

    def fields(self, tid):
        types = self.scope()
        section = self.type_section(tid, types[tid]["name"])
        sub = slice_heading(section or [], f"{tid} Fields", 4) or []
        header, rows = table_with(sub, ["Field", "Type", "Presence", "Reference", "Rule", "Source or question"])
        return rows

    def diagnostic_rows_ok(self, rows, where):
        failures = []
        edges = self.repo["edges"]
        for r in rows:
            if len(r) != 7:
                failures.append(f"{where} {r[0]} has {len(r)} cells")
                continue
            did, condition, gate, kind, code, initial, replacement = r
            if gate in STRUCTURAL_GATES:
                expected_from, pair = "imported", ("E08", "E11")
            elif gate in SEMANTIC_GATES:
                expected_from, pair = "structurally valid", ("E09", "E12")
            else:
                failures.append(f"{where} {did} gate {gate!r} is not an HF-05 gate")
                continue
            if (initial, replacement) != pair:
                failures.append(f"{where} {did} edges {initial}/{replacement} do not match gate {gate}")
            for e in (initial, replacement):
                if e not in edges or edges[e][0] != expected_from:
                    failures.append(f"{where} {did} edge {e} does not leave {expected_from}")
            if kind.strip("`") not in FAILURE_KINDS:
                failures.append(f"{where} {did} diagnostic {kind} is not an HF-05 diagnostic")
            names = re.findall(r"`([a-z0-9_.]+)`", code)
            if not names:
                failures.append(f"{where} {did} names no code or rule")
            for n in names:
                if kind.strip("`") == "ContentReferenceFailure" and n not in self.repo["codes"]:
                    failures.append(f"{where} {did} code {n} is not an HF-05 ContentReferenceFailure code")
                if kind.strip("`") == "ContentAdmissionFailure" and not n.startswith("sc04."):
                    failures.append(f"{where} {did} rule {n} is not an sc04 rule")
        return failures

    def types(self):
        types = self.scope()
        failures = []
        header, family = table_with(self.lines, ["ID", "Condition", "Gate", "Diagnostic", "Code or rule", "Initial", "Replacement"])
        failures += self.diagnostic_rows_ok(family, "family")
        diagnostics = len(family)
        fields = 0
        for tid, t in types.items():
            section = self.type_section(tid, t["name"])
            if section is None:
                failures.append(f"{tid} has no section")
                continue
            rows = self.fields(tid)
            if not rows:
                failures.append(f"{tid} has no fields table")
            for r in rows:
                fields += 1
                field, ftype, presence, ref, rule, source = r
                if not ftype or not presence:
                    failures.append(f"{tid} {field} lacks a type or presence")
                if not (QID.search(source) or "line" in source):
                    failures.append(f"{tid} {field} has neither a source line nor a question")
            identity = slice_heading(section, f"{tid} Identity and version", 4)
            if not identity or not "".join(identity).strip():
                failures.append(f"{tid} has no identity and version rule")
            elif not re.search(r"domain ID|parent", "".join(identity), re.IGNORECASE):
                failures.append(f"{tid} identity rule names neither a domain ID nor a parent")
            if "revision" not in "".join(identity or []):
                failures.append(f"{tid} identity rule names no revision rule")
            diag = slice_heading(section, f"{tid} Diagnostics", 4) or []
            _, drows = table_with(diag, ["ID", "Condition", "Gate", "Diagnostic", "Code or rule", "Initial", "Replacement"])
            if not drows:
                failures.append(f"{tid} has no diagnostics table")
            failures += self.diagnostic_rows_ok(drows, tid)
            diagnostics += len(drows)
            record = slice_heading(section, f"{tid} Illustrative record", 4) or []
            blocks = fenced_blocks(record)
            if len(blocks) != 1:
                failures.append(f"{tid} has {len(blocks)} illustrative records, expected one")
            if not any("Illustrative, not canon." in l for l in record):
                failures.append(f"{tid} record is not labelled illustrative")
        self.counts["fields"] = fields
        self.counts["diagnostics"] = diagnostics
        self.check("every type carries fields, identity and version, diagnostics and one labelled illustrative record", failures)

    def references(self):
        types = self.scope()
        failures = []
        declared = set()
        for tid, t in types.items():
            for field, ftype, presence, ref, rule, source in self.fields(tid):
                if ref == "—":
                    continue
                targets = [x.strip() for x in ref.split(",")]
                for target in targets:
                    if target in types:
                        continue
                    row = self.repo["hf06a"].get(target)
                    if row is None:
                        failures.append(f"{tid} {field} target {target} is neither a type here nor an HF-06a row")
                    elif row["producing_card"] == CARD:
                        failures.append(f"{tid} {field} target {target} is a family row, not a foreign one")
                declared.add((f"{tid} {field}", tuple(targets)))
        header, rows = table_with(self.lines, ["Ref", "From", "Target", "Target kind", "Expected family", "Producing card", "Missing-reference outcome"])
        tabled = set()
        for r in rows:
            tabled.add((r[1], tuple(x.strip() for x in r[2].split(","))))
            for target in [x.strip() for x in r[2].split(",")]:
                row = self.repo["hf06a"].get(target)
                if row is not None and row["producing_card"] not in r[5]:
                    failures.append(f"{r[0]} producing card {r[5]} does not match HF-06a {row['producing_card']}")
        for missing in declared - tabled:
            failures.append(f"references table lacks {missing}")
        for extra in tabled - declared:
            failures.append(f"references table row {extra} has no field")
        self.counts["references"] = len(rows)
        self.check("every reference target is a type here or a foreign HF-06a row", failures)

    def save(self):
        types = self.scope()
        failures = []
        header, rows = table_with(self.lines, ["Type", "HF-06a row", "HF-06b save column", "Case", "Authoring codec", "Projection fields", "Exclusion"])
        seen = set()
        for r in rows:
            tid, row, column, case, codec, projection, exclusion = r
            seen.add(tid)
            if tid not in types or types[tid]["row"] != row:
                failures.append(f"save row {tid} names {row}, scope table disagrees")
            b = self.repo["hf06b"].get(row)
            if b is None:
                failures.append(f"save row {tid}: HF-06b has no row {row}")
                continue
            if (column, case, codec) != (b["save_column"], b["rationale_case"], b["authoring_codec"]):
                failures.append(f"save row {tid}: {column}/{case}/{codec} differs from HF-06b {b['save_column']}/{b['rationale_case']}/{b['authoring_codec']}")
            if column == "json-projection":
                named = re.findall(r"`([^`]+)`", projection)
                if not named:
                    failures.append(f"save row {tid}: projection names no field")
                for f in named:
                    if f not in self.repo["hf07a"]:
                        failures.append(f"save row {tid}: projection field {f} is not an HF-07a CSV field")
            else:
                if projection != "none" or b["save_projection"] != "none":
                    failures.append(f"save row {tid}: an exclusion must project none")
                if not exclusion.strip():
                    failures.append(f"save row {tid}: exclusion has no rationale")
        for tid in types:
            if tid not in seen:
                failures.append(f"type {tid} has no save row")
        for path in SAVE_PATH.findall(self.text):
            if path not in self.repo["hf07a"]:
                failures.append(f"save path {path} is not an HF-07a CSV field")
        self.check("each type's save treatment matches HF-06b and names only HF-07a fields", failures)

    def traces(self):
        failures = []
        edges = self.repo["edges"]
        expectations = {
            "SA": ("admitted", None),
            "SM": ("draft", "missing_id"),
            "SI": ("draft", "sc04.attack_value_override"),
            "SX": ("draft", "sc04.illustrative_id"),
        }
        rules = set(re.findall(r"`(sc04\.[a-z_]+)`", self.text))
        steps = 0
        for key, (final, diagnostic) in expectations.items():
            section = slice_heading(self.lines, f"{key}:", 3)
            if section is None:
                failures.append(f"trace {key} missing")
                continue
            _, rows = table_with(section, ["Step", "Subject", "Gate", "Edge", "From", "To", "Diagnostic", "Source"])
            if not rows:
                failures.append(f"trace {key} has no steps")
                continue
            previous = "draft"
            for r in rows:
                steps += 1
                step, subject, gate, edge, frm, to, diag, source = r
                if edge not in edges:
                    failures.append(f"{step} edge {edge} is not an HF-05 edge")
                    continue
                if edges[edge] != (frm, to):
                    failures.append(f"{step} {edge} is {edges[edge]}, trace says {(frm, to)}")
                if frm != previous:
                    failures.append(f"{step} starts at {frm}, previous step ended at {previous}")
                if edge not in GATE_EDGES.get(gate, set()):
                    failures.append(f"{step} edge {edge} is not an outcome of gate {gate}")
                for named in re.findall(r"`(sc04\.[a-z_]+)`", diag):
                    if named not in rules:
                        failures.append(f"{step} rule {named} is not declared")
                previous = to
            if previous != final:
                failures.append(f"trace {key} ends at {previous}, expected {final}")
            if diagnostic and diagnostic not in rows[-1][6]:
                failures.append(f"trace {key} final step does not name {diagnostic}")
            if not any(l.startswith(f"**{key} outcome:") for l in section):
                failures.append(f"trace {key} has no stated outcome")
        self.counts["trace_steps"] = steps
        self.check("valid, missing-reference and invalid records trace to their HF-05 outcomes", failures)

    def parameter_rows(self):
        header, rows = table_with(self.lines, ["ID", "Parameter", "Field", "Value at this base", "Source or question"])
        return {r[0]: r for r in rows}

    def records(self):
        types = self.scope()
        params = self.parameter_rows()
        failures = []
        records = {}
        for tid, t in types.items():
            section = self.type_section(tid, t["name"]) or []
            blocks = fenced_blocks(slice_heading(section, f"{tid} Illustrative record", 4) or [])
            if not blocks:
                failures.append(f"{tid} record missing")
                continue
            record, meta = build_record(blocks[0])
            if meta.get("type") != tid:
                failures.append(f"{tid} record is labelled {meta.get('type')}")
            decoded = json.loads(json.dumps(record, sort_keys=True))
            if decoded != record:
                failures.append(f"{tid} encode then decode changed the record")
            before = dict(leaf_paths(record))
            after = dict(leaf_paths(decoded))
            if before != after:
                failures.append(f"{tid} encode then decode lost a field or reference")
            records[tid] = (record, meta)
        ids = {r.get("id") for r, _ in records.values() if isinstance(r, dict) and "id" in r}
        field_count = 0
        for tid, (record, meta) in records.items():
            rows = {r[0].strip("`"): r for r in self.fields(tid)}
            declared_top = {name.split("[")[0].split(".")[0] for name in rows}
            present_top = set(record.keys())
            for missing in declared_top - present_top:
                failures.append(f"{tid} record lacks field {missing}")
            for extra in present_top - declared_top:
                failures.append(f"{tid} record has undeclared field {extra}")
            for path, value in leaf_paths(record):
                field_count += 1
                spec = self.field_spec(tid, path, rows, types)
                if spec is None:
                    failures.append(f"{tid} {path} has no declared field")
                    continue
                failures += self.value_ok(tid, path, value, spec, params, ids)
            if "embedded_in" in meta:
                parent = next((r for r, _ in records.values() if r.get("id") == meta["embedded_in"]), None)
                if parent is None:
                    failures.append(f"{tid} embedded parent {meta['embedded_in']} not printed")
                else:
                    try:
                        if get_path(parent, meta["embedded_at"]) != record:
                            failures.append(f"{tid} differs from its copy at {meta['embedded_in']} {meta['embedded_at']}")
                    except (KeyError, IndexError, TypeError):
                        failures.append(f"{tid} parent has no {meta['embedded_at']}")
        self.counts["records"] = len(records)
        self.counts["record_values"] = field_count
        self.check("illustrative records round-trip, cover their fields and keep values symbolic", failures)

    def field_spec(self, tid, path, rows, types):
        norm = normal(path)
        candidates = [norm, re.sub(r"\[\]$", "", norm)]
        for c in candidates:
            if c in rows:
                return rows[c]
        top = norm.split(".")[0]
        top_name = top.replace("[]", "")
        if top_name in rows:
            ref = rows[top_name][3]
            if ref in types and types[ref]["parent"] != "—":
                inner = norm[len(top) + 1 :]
                inner_rows = {r[0].strip("`"): r for r in self.fields(ref)}
                for c in (inner, re.sub(r"\[\]$", "", inner)):
                    if c in inner_rows:
                        return inner_rows[c]
        return None

    def value_ok(self, tid, path, value, spec, params, ids):
        failures = []
        field, ftype, presence, ref, rule, source = spec
        where = f"{tid} {path}"
        if value is None:
            if "or null" not in ftype:
                failures.append(f"{where} is null but its type does not allow null")
            return failures
        if value == []:
            if "array" not in ftype:
                failures.append(f"{where} is empty but not an array")
            return failures
        if not isinstance(value, str):
            failures.append(f"{where} holds a non-scalar value")
            return failures
        if NUMBER.match(value):
            failures.append(f"{where} holds a bare number")
            return failures
        m = SYMBOLIC.match(value)
        if m:
            st, q = m.groups()
            if st not in params:
                failures.append(f"{where} names missing parameter {st}")
            elif q not in params[st][4]:
                failures.append(f"{where} names {q}, parameter {st} names {params[st][4]}")
            if st not in rule:
                failures.append(f"{where} token {st} is not the field's parameter")
            if not re.search(r"symbolic|behaviour", ftype):
                failures.append(f"{where} is symbolic but typed {ftype}")
            return failures
        if re.search(r"symbolic|behaviour", ftype):
            failures.append(f"{where} is typed {ftype} but holds a literal")
            return failures
        enum = re.findall(r"`([a-z_]+)`", ftype) if ftype.startswith("enum") else []
        if enum:
            if value not in enum:
                failures.append(f"{where} value {value} is not in {enum}")
            return failures
        if value.startswith("illustrative.foreign."):
            row = value.split(".")[2].upper()
            if ref == "—":
                failures.append(f"{where} holds a foreign reference in a non-reference field")
            elif row not in [x.strip() for x in ref.split(",")]:
                failures.append(f"{where} foreign placeholder row {row} is not the field's target {ref}")
            elif row not in self.repo["hf06a"] or self.repo["hf06a"][row]["producing_card"] == CARD:
                failures.append(f"{where} foreign placeholder row {row} is not a foreign HF-06a row")
            return failures
        if value.startswith("illustrative."):
            if re.search(r"\d", value):
                failures.append(f"{where} placeholder carries a digit")
            if ref != "—" and value not in ids:
                failures.append(f"{where} local reference {value} names no printed record")
            return failures
        if value.startswith("illustrative-") and ftype == "string":
            return failures
        failures.append(f"{where} value {value!r} is neither a placeholder, a declared token nor symbolic")
        return failures

    def parameters(self):
        params = self.parameter_rows()
        failures = []
        if not params:
            failures.append("parameter table missing")
        for pid, r in params.items():
            source = r[4]
            if not (QID.search(source) or "line" in source):
                failures.append(f"{pid} has neither a source line nor a question")
            if "unset" in r[3] and not QID.search(source):
                failures.append(f"{pid} is unset and names no question")
        types = self.scope()
        for tid in types:
            for field, ftype, presence, ref, rule, source in self.fields(tid):
                for st in re.findall(r"ST-\d+", rule):
                    if st not in params:
                        failures.append(f"{tid} {field} names missing {st}")
                        continue
                    owners = set(QID.findall(params[st][4]))
                    if owners and not owners & set(QID.findall(source)):
                        failures.append(f"{tid} {field} source {source} shares no question with {st}")
        for start, header, rows in tables(self.lines):
            for r in rows:
                joined = " ".join(r)
                if "Q-E10" in joined and "Q-P38" in joined:
                    failures.append(f"table at line {start} row {r[0]} names both Q-E10 and Q-P38")
        self.counts["parameters"] = len(params)
        self.check("unchosen values are symbolic with a question and no row joins Q-E10 and Q-P38", failures)

    def questions(self):
        failures = []
        named = sorted(set(QID.findall(self.text)))
        for q in named:
            if q.lower() not in self.repo["anchors"]:
                failures.append(f"{q} has no BACKLOG anchor")
        self.counts["questions"] = len(named)
        self.check("every question ID resolves in BACKLOG", failures)

    def hashes(self):
        failures = []
        section = slice_heading(self.lines, "Sources", 2) or []
        base = self.root / "docs/tech/schemas"
        stated = 0
        bullets, current = [], None
        for line in section:
            if line.startswith("- "):
                current = [line]
                bullets.append(current)
            elif current is not None and line.strip():
                current.append(line)
            else:
                current = None
        for bullet in bullets:
            text = " ".join(bullet)
            link = None
            for m in re.finditer(r"\[[^\]]*\]\(([^)]+)\)|SHA256 `([0-9a-f]{64})`", text):
                if m.group(1):
                    target = m.group(1)
                    if "#" in target and Path(target.split("#")[0]).name in ("BACKLOG.md", "TRACKING.md"):
                        continue
                    link = target.split("#")[0]
                    continue
                stated += 1
                if link is None:
                    failures.append(f"hash {m.group(2)} has no preceding link")
                    continue
                path = (base / link).resolve()
                actual = sha256(path) if path.exists() else "missing"
                if actual != m.group(2):
                    failures.append(f"{link} stated {m.group(2)} actual {actual}")
        self.counts["hashes"] = stated
        self.check("every stated dependency hash matches", failures if stated else ["no hashes stated"])


NEGATIVE_CONTROLS = [
    ("type moved to a row outside the family", "coverage", "| Waves | T3 | WaveDefinition | F-04 |", "| Waves | T3 | WaveDefinition | F-05 |"),
    ("bare number in a record", "records", "durability = SYMBOLIC(ST-04; Q-P25)", "durability = 40"),
    ("projection field HF-07a lacks", "save", "| T1 | N-023 | immutable-by-id | definition-by-id | tres | none |", "| T1 | N-023 | json-projection | definition-by-id | tres | `run.checkpoint.encounter_id` |"),
    ("reference to a nonexistent row", "references", "| `attack_id` | id-string | required | F-02 |", "| `attack_id` | id-string | required | F-99 |"),
    ("trace edge with the wrong from state", "traces", "| SM.3 | candidate | Cross-reference/semantic | E09 |", "| SM.3 | candidate | Cross-reference/semantic | E08 |"),
    ("field dropped from a record", "records", "entry_rule = SYMBOLIC(ST-10; Q-P23)\n", ""),
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    root = Path(args.root).resolve()
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    repo = load_repo(root)
    text = (root / SECTION).read_text(encoding="utf-8")

    checker = Checker(root, text, repo)
    results = checker.run()

    controls = []
    for label, method, before, after in NEGATIVE_CONTROLS:
        if before not in text:
            controls.append({"control": label, "caught": False, "reason": "mutation anchor not found"})
            continue
        baseline = Checker(root, text, repo)
        getattr(baseline, method)()
        known = {f for r in baseline.results for f in r["failures"]}
        mutated = Checker(root, text.replace(before, after, 1), repo)
        getattr(mutated, method)()
        # Caught only by a failure the mutation introduced, so a check that already fails cannot mask a missed control.
        new = [f for r in mutated.results for f in r["failures"] if f not in known]
        controls.append({"control": label, "caught": bool(new), "failures": new[:3]})

    manifest = {
        path: sha256(root / path)
        for path in [
            SECTION,
            "docs/tech/sections/HF-06a-schema-inventory.csv",
            "docs/tech/sections/HF-06b-persistence-projection.csv",
            "docs/tech/sections/HF-07a-save-envelope.csv",
            "docs/tech/sections/HF-05-content-admission.md",
            "BACKLOG.md",
        ]
    }
    passed = sum(r["passed"] for r in results)
    caught = sum(c["caught"] for c in controls)
    ok = passed == len(results) and caught == len(controls) and len(controls) >= 3
    report = {
        "section": SECTION,
        "passed": passed,
        "failed": len(results) - passed,
        "negative_controls": len(controls),
        "negative_controls_caught": caught,
        "counts": checker.counts,
        "results": results,
        "controls": controls,
        "manifest": manifest,
        "ok": ok,
    }
    (out / "paper-check.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    for r in results:
        print(("PASS " if r["passed"] else "FAIL ") + r["check"])
        for f in r["failures"]:
            print("  - " + f)
    for c in controls:
        print(("CAUGHT " if c["caught"] else "MISSED ") + "negative control: " + c["control"])
    print(f"checks {passed}/{len(results)} passed; negative controls {caught}/{len(controls)} caught; counts {json.dumps(checker.counts, sort_keys=True)}")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
