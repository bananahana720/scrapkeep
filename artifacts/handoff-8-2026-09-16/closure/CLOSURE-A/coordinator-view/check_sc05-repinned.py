#!/usr/bin/env python3
"""Paper check for docs/tech/schemas/SC-05.md.

Usage: check_sc05.py <repository-root> --out <directory> [--main-root <path>] [--doc <path>] [--no-controls]
"""
import argparse
import copy
import csv
import hashlib
import json
import re
import sys
from pathlib import Path

HEADINGS = [
    "Sources",
    "Contract",
    "Scenarios",
    "Unresolved questions",
    "Re-verification triggers",
    "Procedure performed",
    "Evidence limits",
]
TYPES = ["T1", "T2", "T3", "T4", "T5"]
FIELD_TYPES = {
    "domain-id", "int", "string", "token", "array of token", "ref",
    "ref or null", "array of ref", "object", "array of object",
}
QID = re.compile(r"\bQ-[PE]\d{2}\b")
ILLUSTRATIVE_ID = re.compile(
    r"\b(?:illustrative\.)?(?:region|exit|level_module|route|generation_constraint|encounter|objective)\.[a-z0-9][a-z0-9.-]*"
)
CANDIDATE_NAMES = ["yard", "spillway", "orchard", "foundry", "pale", "commons", "basin", "crown"]


class Doc:
    def __init__(self, text):
        self.text = text
        self.lines = text.split("\n")
        self.fence = self._fence_mask()

    def _fence_mask(self):
        mask, inside = [], False
        for line in self.lines:
            if line.strip().startswith("```"):
                mask.append(True)
                inside = not inside
                continue
            mask.append(inside)
        return mask

    def section(self, name):
        start = end = None
        for i, line in enumerate(self.lines):
            if self.fence[i]:
                continue
            if line == "## " + name:
                start = i
            elif start is not None and line.startswith("## "):
                end = i
                break
        if start is None:
            return None
        return start, end if end is not None else len(self.lines)

    def span(self, heading, level):
        prefix = "#" * level + " "
        start = None
        for i, line in enumerate(self.lines):
            if self.fence[i]:
                continue
            if start is None and line.startswith(prefix + heading):
                start = i
            elif start is not None and re.match(r"^#{1,%d} " % level, line):
                return start, i
        return (start, len(self.lines)) if start is not None else None

    def tables(self, header, lo=0, hi=None):
        hi = len(self.lines) if hi is None else hi
        want = [c.strip() for c in header]
        found = []
        i = lo
        while i < hi:
            line = self.lines[i]
            if not self.fence[i] and line.startswith("|") and split_row(line) == want:
                rows = []
                j = i + 2
                while j < hi and self.lines[j].startswith("|"):
                    rows.append(dict(zip(want, split_row(self.lines[j]))))
                    j += 1
                found.append(rows)
                i = j
            else:
                i += 1
        return found

    def json_after(self, label, lo=0, hi=None):
        hi = len(self.lines) if hi is None else hi
        for i in range(lo, hi):
            if not self.fence[i] and label in self.lines[i]:
                for j in range(i + 1, hi):
                    if self.lines[j].strip().startswith("```json"):
                        body = []
                        for k in range(j + 1, hi):
                            if self.lines[k].strip().startswith("```"):
                                return json.loads("\n".join(body))
                            body.append(self.lines[k])
                    if self.lines[j].startswith("#"):
                        return None
                return None
        return None


def split_row(line):
    cells = line.strip().strip("|").split("|")
    return [c.strip() for c in cells]


def unlink(text):
    return re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text)


def term_pattern(term):
    return re.compile(r"(?<![A-Za-z])" + re.escape(term) + r"s?(?![A-Za-z])", re.I)


class Result:
    def __init__(self):
        self.checks = []

    def add(self, cid, ok, detail):
        self.checks.append({"id": cid, "pass": bool(ok), "detail": detail})

    def failed(self):
        return [c for c in self.checks if not c["pass"]]


def read_csv(path):
    with open(path, newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def load_sources(root):
    sections = root / "docs/tech/sections"
    hf06a = {r["row_id"]: r for r in read_csv(sections / "HF-06a-schema-inventory.csv")}
    hf06b = {r["row_id"]: r for r in read_csv(sections / "HF-06b-persistence-projection.csv")}
    hf07a = {r["field"]: r for r in read_csv(sections / "HF-07a-save-envelope.csv")}
    md = (sections / "HF-06a-schema-inventory.md").read_text(encoding="utf-8")
    hf06a_md = {}
    for line in md.split("\n"):
        cells = split_row(line) if line.startswith("| ") else []
        if len(cells) == 7 and re.fullmatch(r"[FN]-\d{2,3}", cells[0]):
            hf06a_md[cells[0]] = unlink(cells[6])
    hf05 = (sections / "HF-05-content-admission.md").read_text(encoding="utf-8")
    codes_line = next(l for l in hf05.split("\n") if l.startswith("| `code` |"))
    codes = set(re.findall(r"`([a-z_]+)`", codes_line)) - {"code"}
    edges = set(re.findall(r"^\| (E\d{2}) \|", hf05, re.M))
    backlog = (root / "BACKLOG.md").read_text(encoding="utf-8")
    anchors = set(re.findall(r'<a id="(q-[pe]\d{2})"></a>', backlog))
    return {
        "hf06a": hf06a, "hf06a_md": hf06a_md, "hf06b": hf06b, "hf07a": hf07a,
        "codes": codes, "edges": edges, "anchors": anchors,
    }


def parse_contract(doc):
    contract = doc.section("Contract")
    lo, hi = contract
    types = {r["Type"]: r for r in doc.tables(["Type", "Name", "Family token", "Accepted rationale terms"], lo, hi)[0]}
    for t in types.values():
        t["terms"] = [x.strip() for x in t["Accepted rationale terms"].split(";")]
    allocation = doc.tables(["Row", "HF-06a treatment", "Type", "Rationale term", "Relation"], lo, hi)[0]
    mentions = doc.tables(["ID", "Row", "Producing card", "Type", "Term", "Why it is not a row of the type"], lo, hi)[0]
    fields, spans = {}, {}
    for t in TYPES:
        span = doc.span("%s %s" % (t, types[t]["Name"]), 3)
        spans[t] = span
        fspan = doc.span("%s fields" % t, 4)
        tables = doc.tables(["Field", "Type", "Required", "Reference target", "Rule"], *fspan) if fspan else []
        fields[t] = tables[0] if tables else []
    diagnostics = doc.tables(
        ["ID", "Type", "Gate", "Condition", "HF-05 diagnostic", "Initial edge", "Replacement edge"], lo, hi)[0]
    save = doc.tables(
        ["Type", "HF-06a row", "HF-06b save column", "HF-06b case", "HF-07a fields", "Treatment here"], lo, hi)[0]
    no_ref = doc.tables(["HF-06a row", "HF-06b group", "Why no SC-05 definition reference"], lo, hi)[0]
    params = doc.tables(["ID", "Parameter", "Value", "Source line or question", "Gates"], lo, hi)[0]
    foreign = doc.tables(["ID", "Direction", "Foreign HF-06a row", "Producing card", "Foreign type", "Field or path", "State"], lo, hi)[0]
    return {
        "foreign": foreign,
        "types": types, "allocation": allocation, "mentions": mentions, "fields": fields,
        "spans": spans, "diagnostics": diagnostics, "save": save, "no_ref": no_ref, "params": params,
    }


def check_headings(doc, res):
    found = [l[3:] for i, l in enumerate(doc.lines) if l.startswith("## ") and not doc.fence[i]]
    res.add("A0-headings", found == HEADINGS, found)


def check_allocation(c, src, res):
    hf06a, md = src["hf06a"], src["hf06a_md"]
    scope = {rid for rid, r in hf06a.items() if r["producing_card"] == "SC-05"}
    problems = []
    allocated = {}
    for line in c["allocation"]:
        rid, ty, term, rel = line["Row"], line["Type"], line["Rationale term"], line["Relation"]
        row = hf06a.get(rid)
        if row is None or rid not in scope:
            problems.append("%s is not an SC-05 row" % rid)
            continue
        if line["HF-06a treatment"] != row["treatment"]:
            problems.append("%s treatment %s differs from CSV %s" % (rid, line["HF-06a treatment"], row["treatment"]))
        expected_rel = {"schema": "defines", "excluded": "constrains"}.get(row["treatment"])
        if rel != expected_rel:
            problems.append("%s relation %s for treatment %s" % (rid, rel, row["treatment"]))
        if ty not in c["types"] or term not in c["types"][ty]["terms"]:
            problems.append("%s term %r is not accepted for %s" % (rid, term, ty))
        for label, text in (("CSV", row["scope_and_rationale"]), ("Markdown", md.get(rid, ""))):
            if not term_pattern(term).search(text):
                problems.append("%s term %r absent from %s rationale" % (rid, term, label))
        key = (rid, ty)
        if key in allocated:
            problems.append("%s allocated to %s twice" % key)
        allocated[key] = rel
    mentioned = {}
    for line in c["mentions"]:
        mentioned[(line["Row"], line["Type"])] = line
        row = hf06a.get(line["Row"])
        if row is None or row["producing_card"] == "SC-05" or line["Producing card"] != row["producing_card"]:
            problems.append("FM row %s is not a foreign row with that card" % line["Row"])
    for rid, row in hf06a.items():
        md_text = md.get(rid)
        if md_text is None or md_text != row["scope_and_rationale"]:
            if rid in scope or any(k[0] == rid for k in mentioned):
                problems.append("%s Markdown and CSV rationales differ" % rid)
        named = set()
        for text in (row["scope_and_rationale"], md_text or ""):
            for ty in TYPES:
                if any(term_pattern(t).search(text) for t in c["types"][ty]["terms"]):
                    named.add(ty)
        if rid in scope:
            have = {ty for (r, ty) in allocated if r == rid}
            if have != named:
                problems.append("%s names %s but is allocated to %s" % (rid, sorted(named), sorted(have)))
        else:
            have = {ty for (r, ty) in mentioned if r == rid}
            if have != named:
                problems.append("foreign %s names %s but FM lists %s" % (rid, sorted(named), sorted(have)))
    for ty in TYPES:
        if not any(t == ty and rel == "defines" for (r, t), rel in allocated.items()):
            problems.append("%s has no defining row" % ty)
    missing_rows = scope - {r for r, _ in allocated}
    if missing_rows:
        problems.append("unallocated SC-05 rows %s" % sorted(missing_rows))
    res.add("A1-row-allocation", not problems, problems or {
        "rows": sorted(scope), "pairs": len(allocated), "foreign_mentions": len(mentioned)})
    return allocated


def check_types(doc, c, res):
    problems = []
    dg_ids = {d["ID"] for d in c["diagnostics"]}
    records = {}
    for ty in TYPES:
        span = c["spans"][ty]
        if span is None:
            problems.append("%s section missing" % ty)
            continue
        fields = c["fields"][ty]
        names = [f["Field"] for f in fields]
        if "id" not in names or "schema_version" not in names:
            problems.append("%s lacks id or schema_version" % ty)
        for f in fields:
            if f["Type"] not in FIELD_TYPES:
                problems.append("%s.%s type %r" % (ty, f["Field"], f["Type"]))
            if f["Required"] not in ("yes", "no") or not f["Rule"]:
                problems.append("%s.%s required or rule cell" % (ty, f["Field"]))
        body = "\n".join(doc.lines[span[0]:span[1]])
        if "**Identity and version.**" not in body:
            problems.append("%s identity and version rule missing" % ty)
        diag = re.search(r"\*\*Diagnostics\.\*\*(.*)", body)
        if not diag or not re.search(r"DG-\d{2}", diag.group(1)):
            problems.append("%s diagnostics missing" % ty)
        else:
            for a, b in re.findall(r"DG-(\d{2})(?: to DG-(\d{2}))?", diag.group(1)):
                for n in range(int(a), int(b or a) + 1):
                    if "DG-%02d" % n not in dg_ids:
                        problems.append("%s names absent DG-%02d" % (ty, n))
        if "references" not in body.lower():
            problems.append("%s references paragraph missing" % ty)
        record = doc.json_after("**Illustrative authored record, not canon.**", *span)
        if record is None:
            problems.append("%s illustrative record missing or unlabelled" % ty)
        else:
            records[ty] = record if isinstance(record, list) else [record]
    res.add("A2-type-completeness", not problems, problems or {"types": len(records)})
    return records


def check_targets(c, src, res):
    problems = []
    for ty in TYPES:
        for f in c["fields"][ty]:
            target = f["Reference target"]
            if target == "none" or target in TYPES:
                continue
            row = src["hf06a"].get(target)
            if row is None or row["producing_card"] == "SC-05" or row["treatment"] not in ("schema", "embedded-record"):
                problems.append("%s.%s target %s is neither a type here nor a foreign schema row" % (ty, f["Field"], target))
            is_ref = f["Type"] in ("ref", "ref or null", "array of ref", "object", "array of object")
            if not is_ref:
                problems.append("%s.%s has a target but no reference type" % (ty, f["Field"]))
    res.add("A3-reference-targets", not problems, problems or "all targets resolve")


def check_save(c, src, allocated, res):
    problems = []
    hf06b, hf07a = src["hf06b"], src["hf07a"]
    lines = {(l["HF-06a row"], l["Type"]): l for l in c["save"]}
    covered = {}
    for (rid, ty), rel in allocated.items():
        row = hf06b[rid]
        groups = {g.strip() for g in row["save_projection"].split(";")} - {"none"}
        if rel == "constrains":
            if row["save_column"] != "immutable-by-id" or row["rationale_case"] != "no-definition-no-state":
                problems.append("%s constrains but HF-06b stores state" % rid)
            continue
        line = lines.get((rid, ty))
        if line is None:
            problems.append("no save line for %s %s" % (ty, rid))
            continue
        if line["HF-06b save column"] != row["save_column"] or line["HF-06b case"] != row["rationale_case"]:
            problems.append("%s %s save cells differ from HF-06b CSV" % (ty, rid))
        cell = line["HF-07a fields"]
        fields = [] if cell == "none" else [f.strip().strip("`") for f in cell.split(";")]
        if row["save_column"] == "immutable-by-id" and fields:
            problems.append("%s %s immutable row lists fields" % (ty, rid))
        if row["save_column"] == "json-projection" and not fields and "Seam" not in line["Treatment here"]:
            problems.append("%s %s projection row with no field and no seam" % (ty, rid))
        for f in fields:
            if f not in hf07a:
                problems.append("%s is not an HF-07a CSV field" % f)
                continue
            group = hf07a[f]["projection_group"]
            if group not in groups:
                problems.append("%s group %s is not in %s's groups" % (f, group, rid))
            covered.setdefault(rid, set()).add(group)
    extra = set(lines) - {k for k, v in allocated.items() if v == "defines"}
    if extra:
        problems.append("save lines for unallocated pairs %s" % sorted(extra))
    for line in c["no_ref"]:
        covered.setdefault(line["HF-06a row"], set()).add(line["HF-06b group"])
    for rid in {r for (r, _), rel in allocated.items() if rel == "defines"}:
        row = hf06b[rid]
        if row["save_column"] != "json-projection":
            continue
        groups = {g.strip() for g in row["save_projection"].split(";")}
        if covered.get(rid, set()) != groups:
            problems.append("%s groups %s covered as %s" % (rid, sorted(groups), sorted(covered.get(rid, set()))))
    res.add("A4-save-treatment", not problems, problems or {"save_lines": len(lines)})


class Model:
    def __init__(self, c, profile, params):
        self.c = c
        self.profile = profile
        self.family = {t: c["types"][t]["Family token"] for t in TYPES}
        role_row = next(p for p in params if p["ID"] == "SP-24")
        self.roles = set(re.findall(r"`([a-z]+)`", role_row["Value"]))
        boss_row = next(p for p in params if p["ID"] == "SP-25")
        self.boss_count = int(boss_row["Value"])
        set_row = next(p for p in params if p["ID"] == "SP-03")
        self.region_set = int(set_row["Value"])
        self.foreign_family = {}
        for fr in c["foreign"]:
            if fr["Direction"] == "outbound":
                name = re.findall(r"`([a-z_]+)", fr["Field or path"])[0]
                self.foreign_family[name] = fr["Foreign type"]

    def value_ok(self, kind, v):
        if kind in ("domain-id", "string", "token"):
            return isinstance(v, str) and v != ""
        if kind == "int":
            return isinstance(v, int) and not isinstance(v, bool)
        if kind == "ref":
            return isinstance(v, str) and v != ""
        if kind == "ref or null":
            return v is None or (isinstance(v, str) and v != "")
        if kind in ("array of token", "array of ref"):
            return isinstance(v, list) and all(isinstance(x, str) and x for x in v) and len(set(v)) == len(v)
        if kind == "object":
            return isinstance(v, dict)
        if kind == "array of object":
            return isinstance(v, list) and all(isinstance(x, dict) for x in v)
        return False

    def refs(self, ty, record):
        out = []
        for f in self.c["fields"][ty]:
            target, kind, name = f["Reference target"], f["Type"], f["Field"]
            if target == "none" or name not in record:
                continue
            v = record[name]
            if kind in ("ref", "ref or null") and v is not None:
                out.append((name, v, target))
            elif kind == "array of ref":
                out += [(name, x, target) for x in v]
            elif kind == "object":
                out += [(name, x, target) for x in v.values()]
            elif kind == "array of object":
                out += [(name, x[k], target) for x in v for k in sorted(x) if k.endswith("_id")]
        return out

    def run(self, candidate):
        structural, reference, semantic = [], [], []
        ids = {}
        for ty, record in candidate:
            spec = {f["Field"]: f for f in self.c["fields"][ty]}
            for name, f in spec.items():
                if f["Required"] == "yes" and name not in record:
                    structural.append(("SC05-S-REQUIRED", record.get("id"), name))
            for name in record:
                if name not in spec:
                    structural.append(("SC05-S-UNKNOWN-FIELD", record.get("id"), name))
                elif not self.value_ok(spec[name]["Type"], record[name]):
                    structural.append(("SC05-S-TYPE", record.get("id"), name))
            rid = record.get("id")
            if isinstance(rid, str):
                if not re.fullmatch(re.escape(self.family[ty]) + r"\.[a-z0-9][a-z0-9-]*", rid):
                    structural.append(("SC05-S-ID-GRAMMAR", rid, "id"))
                if rid in ids:
                    structural.append(("SC05-S-DUPLICATE-ID", rid, "id"))
                ids[rid] = (ty, record)
            if "schema_version" in record and record["schema_version"] not in self.profile["supported_schema_versions"]:
                structural.append(("SC05-S-SCHEMA-VERSION", rid, "schema_version"))
            if ty == "T4":
                if record.get("level_role") not in self.roles:
                    structural.append(("SC05-S-LEVEL-ROLE", rid, "level_role"))
                boss = record.get("level_role") == "boss"
                onward = record.get("onward_exit_ids", [])
                if boss != (not onward) or boss != (record.get("boss_encounter_id") is not None):
                    structural.append(("SC05-S-EXIT-SHAPE", rid, "level_role"))
            if ty == "T3":
                members = record.get("run_region_ids", [])
                if len(set(members)) != len(members) or record.get("starting_region_id") not in members:
                    structural.append(("SC05-S-ROUTE-SHAPE", rid, "run_region_ids"))
            if ty == "T5" and not record.get("module_pool_ids"):
                structural.append(("SC05-S-POOL-EMPTY", rid, "module_pool_ids"))
            if ty == "T2":
                keys = [s.get("slot_key") for s in record.get("encounter_slots", [])]
                if len(set(keys)) != len(keys):
                    structural.append(("SC05-S-SLOT-KEY", rid, "encounter_slots"))
        if structural:
            return ["E02", "E08"], "draft", structural
        foreign = self.profile["foreign"]
        for ty, record in candidate:
            for name, value, target in self.refs(ty, record):
                if target in TYPES:
                    hit = ids.get(value)
                    if hit is None:
                        reference.append(("missing_id", record["id"], name, value, self.family[target]))
                    elif hit[0] != target:
                        reference.append(("wrong_family", record["id"], name, value, self.family[target]))
                else:
                    stub = foreign.get(value)
                    expected = self.foreign_family.get(name)
                    if stub is None:
                        kind = "wrong_family" if value in ids else "missing_id"
                        reference.append((kind, record["id"], name, value, expected))
                    elif stub["row"] != target or stub.get("family") != expected:
                        reference.append(("wrong_family", record["id"], name, value, expected))
        prefix = self.profile["known_token_prefix"]
        for ty, record in candidate:
            for f in self.c["fields"][ty]:
                name, kind = f["Field"], f["Type"]
                if name not in record or name == "level_role":
                    continue
                v = record[name]
                if kind == "token" and not v.startswith(prefix):
                    semantic.append(("SC05-M-UNKNOWN-RULE", record["id"], name))
                if kind == "array of token" and any(not x.startswith(prefix) for x in v):
                    semantic.append(("SC05-M-UNKNOWN-RULE", record["id"], name))
                if kind == "object" and (any(not k.startswith(prefix) for k in v) or (ty == "T3" and not v)):
                    semantic.append(("SC05-M-UNKNOWN-RULE", record["id"], name))
        exits = {i: r for i, (t, r) in ids.items() if t == "T4"}
        for rid, (ty, region) in ids.items():
            if ty != "T1":
                continue
            entry = exits.get(region.get("entry_exit_id"))
            bad = entry is None or entry.get("region_id") != rid
            seen, stack, order, bosses = set(), [], [], 0

            def walk(eid):
                nonlocal bad, bosses
                if eid in stack:
                    bad = True
                    return
                if eid in seen or eid not in exits:
                    return
                seen.add(eid)
                stack.append(eid)
                e = exits[eid]
                if e.get("region_id") != rid:
                    bad = True
                bosses += e.get("level_role") == "boss"
                for nxt in e.get("onward_exit_ids", []):
                    walk(nxt)
                stack.pop()

            if entry is not None:
                walk(region["entry_exit_id"])
            own = {i for i, e in exits.items() if e.get("region_id") == rid}
            if bad or own - seen or bosses != self.boss_count:
                semantic.append(("SC05-M-REGION-GRAPH", rid, "entry_exit_id"))
        for rid, (ty, record) in ids.items():
            if ty == "T5":
                pool = set(record.get("module_pool_ids", []))
                if not set(record.get("decision_key_decode", {}).values()) <= pool:
                    semantic.append(("SC05-M-DECODE-POOL", rid, "decision_key_decode"))
            if ty == "T4" and record.get("boss_encounter_id") is not None:
                stub = foreign.get(record["boss_encounter_id"])
                if stub is not None and stub.get("boss_tier") != "boss":
                    semantic.append(("SC05-M-ENCOUNTER-KIND", rid, "boss_encounter_id"))
            if ty == "T2":
                if record.get("composition_key") not in self.profile["asset_manifest"]:
                    semantic.append(("SC05-C-COMPOSITION", rid, "composition_key"))
        routes = [i for i, (t, _) in ids.items() if t == "T3"]
        for i in routes:
            if len(ids[i][1].get("run_region_ids", [])) != self.region_set:
                semantic.append(("SC05-M-RUN-REGION-SET", i, "run_region_ids"))
        if len(routes) > 1:
            semantic.append(("SC05-M-ROUTE-COUNT", routes[1], "id"))
        if reference or semantic:
            return ["E02", "E03", "E09"], "draft", reference + semantic
        return ["E02", "E03", "E04", "E05"], "admitted", []


def diagnostic_string(findings):
    if not findings:
        return "none"
    first = findings[0]
    if first[0].startswith("SC05-"):
        return "ContentAdmissionFailure " + first[0]
    return "ContentReferenceFailure " + first[0]


def check_traces(doc, c, src, records, res):
    problems = []
    lo, hi = doc.section("Scenarios")
    profile = doc.json_after("Illustrative trace fixture profile, not canon.", lo, hi)
    tb = doc.json_after("Illustrative trace fixture TB, not canon.", lo, hi)
    tc = doc.json_after("Illustrative trace fixture TC, not canon.", lo, hi)
    supplement = doc.json_after("Illustrative trace fixture TA supplement, not canon.", lo, hi)
    table = doc.tables(["Trace", "Candidate", "Edges", "Outcome", "Diagnostic"], lo, hi)
    if not (profile and tb and tc and supplement and table and all(t in records for t in TYPES)):
        res.add("A5-admission-traces", False, "fixtures, trace table or records missing")
        return None
    model = Model(c, profile, c["params"])
    ta = [(ty, rec) for ty in TYPES for rec in records[ty]] + [(s["type"], s["record"]) for s in supplement]

    def replace(candidate, ty, record):
        return [(t, record if (t == ty and r["id"] == record["id"]) else r) for t, r in candidate]

    candidates = {"TA": ta, "TB": replace(ta, "T4", tb), "TC": replace(ta, "T1", tc)}
    rule_names = {d["HF-05 diagnostic"].split()[-1] for d in c["diagnostics"] if "rule" in d["HF-05 diagnostic"]}
    observed = {}
    for row in table[0]:
        name = row["Trace"]
        edges, outcome, findings = model.run(candidates[name])
        got = diagnostic_string(findings)
        observed[name] = {"edges": edges, "outcome": outcome, "diagnostic": got, "findings": [list(f) for f in findings]}
        want_edges = [e.strip() for e in row["Edges"].split(",")]
        if want_edges != edges or row["Outcome"] != outcome or row["Diagnostic"] != got:
            problems.append("%s documented %s/%s/%s, model %s/%s/%s" % (
                name, want_edges, row["Outcome"], row["Diagnostic"], edges, outcome, got))
        if len(findings) > 1:
            problems.append("%s has extra findings %s" % (name, findings[1:]))
        for e in edges:
            if e not in src["edges"]:
                problems.append("%s edge %s not in HF-05" % (name, e))
        for f in findings:
            if f[0].startswith("SC05-") and f[0] not in rule_names:
                problems.append("rule %s not in the diagnostics table" % f[0])
            if not f[0].startswith("SC05-") and f[0] not in src["codes"]:
                problems.append("code %s not in HF-05's closed set" % f[0])
    if set(observed) != {"TA", "TB", "TC"}:
        problems.append("traces present %s" % sorted(observed))
    tb_text = "\n".join(doc.lines[lo:hi])
    if "referrer" not in tb_text or "`exit.illustrative-a-entry` field `generation_constraint_id`" not in tb_text:
        problems.append("TB referrer not stated")
    res.add("A5-admission-traces", not problems, problems or observed)
    return model


def flatten(value, path, out, element=False):
    if isinstance(value, dict):
        if path and not element:
            out.add(path)
        for k, v in value.items():
            flatten(v, path + "." + k if path else k, out)
    elif isinstance(value, list):
        out.add(path)
        for item in value:
            if isinstance(item, (dict, list)):
                flatten(item, path + "[]", out, element=True)
    else:
        out.add(path)


def encode(c, model, ty, record):
    declared = {f["Field"]: f for f in c["fields"][ty]}
    errors = ["undeclared key %s cannot be encoded" % k for k in record if k not in declared]
    lines = []
    for f in c["fields"][ty]:
        name = f["Field"]
        if name not in record:
            if f["Required"] == "yes":
                errors.append("required %s absent" % name)
            continue
        if not model.value_ok(f["Type"], record[name]):
            errors.append("%s is not a %s" % (name, f["Type"]))
        lines.append("%s = %s" % (name, json.dumps(record[name], sort_keys=True)))
    return "\n".join(lines), errors


def decode(c, ty, text):
    declared = [f["Field"] for f in c["fields"][ty]]
    record = {}
    for line in text.split("\n"):
        if not line:
            continue
        name, value = line.split(" = ", 1)
        if name not in declared:
            raise ValueError("decoded undeclared field " + name)
        record[name] = json.loads(value)
    return record


def check_codec(doc, c, src, records, model, res):
    problems, count = [], 0
    if model is None:
        res.add("A6-encode-decode", False, "no model; traces did not parse")
        return
    for ty, recs in records.items():
        for record in recs:
            variants = [record, dict(record, id=model.family[ty] + ".7")]
            for variant in variants:
                count += 1
                text, errors = encode(c, model, ty, variant)
                problems += ["%s %s: %s" % (ty, variant.get("id"), e) for e in errors]
                decoded = decode(c, ty, text)
                if decoded != variant:
                    problems.append("%s %s fields not preserved" % (ty, variant.get("id")))
                if model.refs(ty, decoded) != model.refs(ty, variant):
                    problems.append("%s %s references not preserved" % (ty, variant.get("id")))
                if not isinstance(decoded.get("id"), str):
                    problems.append("%s %s id not a string" % (ty, variant.get("id")))
    lo, hi = doc.section("Scenarios")
    fragment = doc.json_after("Illustrative save fragment, not canon.", lo, hi)
    paths = set()
    if fragment is None:
        problems.append("save fragment missing")
    else:
        flatten(fragment, "", paths)
        csv_rows = src["hf07a"]
        for p in sorted(paths):
            if p not in csv_rows:
                problems.append("fragment path %s is not an HF-07a field" % p)

        def leaves(value, path):
            if isinstance(value, dict):
                for k, v in value.items():
                    yield from leaves(v, path + "." + k if path else k)
            elif isinstance(value, list) and value and isinstance(value[0], dict):
                for item in value:
                    yield from leaves(item, path + "[]")
            else:
                yield path, value

        for p, v in leaves(fragment, ""):
            kind = csv_rows.get(p, {}).get("type", "")
            if kind == "int" and not (isinstance(v, int) and not isinstance(v, bool)):
                problems.append("%s is not an int" % p)
            elif kind.startswith("array of"):
                element = "id-string" if "id-string" in kind else "string"
                if not isinstance(v, list) or not all(isinstance(x, str) for x in v):
                    problems.append("%s is not an array of %s" % (p, element))
            elif "string" in kind and not (isinstance(v, str) or (v is None and "null" in kind)):
                problems.append("%s is not a %s" % (p, kind))
        cp = fragment["run"]["checkpoint"]
        for o in cp["offered_choices"]:
            if o["chosen_option_id"] is not None and o["chosen_option_id"] not in o["option_ids"]:
                problems.append("chosen option not among options")
    res.add("A6-encode-decode", not problems, problems or {"record_encodings": count, "fragment_paths": len(paths)})


def check_objective_path(doc, c, res):
    problems = []
    rows = [f for f in c["foreign"] if f["Foreign HF-06a row"] == "F-04" and f["Foreign type"] == "ObjectiveDefinition" and f["Direction"].startswith("outbound")]
    if not rows:
        problems.append("no outbound F-04 ObjectiveDefinition reference")
    for f in rows:
        for token in ("encounter_slots", "boss_encounter_id", "objective_ids"):
            if token not in f["Field or path"]:
                problems.append("objective path lacks %s" % token)
    span = doc.span("Events and secret rooms are F-04 objectives", 3)
    if span is None:
        problems.append("ownership section missing")
    else:
        body = "\n".join(doc.lines[span[0]:span[1]])
        for token in ("AM-H8-004", "encounter_slots[].encounter_id", "objective_ids", "Q-P38", "DG-13"):
            if token not in body:
                problems.append("ownership section lacks %s" % token)
    enc = [f for f in c["foreign"] if f["Foreign type"] == "EncounterDefinition" and f["Direction"] == "outbound"]
    fields = " ".join(f["Field or path"] for f in enc)
    if "encounter_slots" not in fields or "boss_encounter_id" not in fields:
        problems.append("encounter references FR-01 and FR-02 incomplete")
    dg20 = next((d for d in c["diagnostics"] if d["ID"] == "DG-20"), None)
    if dg20 is None or "boss_id" not in dg20["Condition"] or "tier" not in dg20["Condition"]:
        problems.append("DG-20 does not read SC-04 boss_id and tier")
    res.add("A10-objective-path", not problems, problems or {"objective_references": len(rows)})


def check_symbolic(doc, c, src, res):
    problems = []
    for p in c["params"]:
        value, source = p["Value"], p["Source line or question"]
        has_q = bool(QID.search(source))
        if value.startswith("unset") or value.startswith("withheld"):
            if not has_q and "line" not in source:
                problems.append("%s unset without a question or source line" % p["ID"])
            if value.startswith("unset") and not has_q and "HF-05 line 50" not in source:
                problems.append("%s unset without a question ID" % p["ID"])
        elif re.search(r"\d", value) and not (has_q or "line" in source or "EV-" in source):
            problems.append("%s value %r without a source" % (p["ID"], value))
        if not (has_q or "line" in source or "CSV" in source):
            problems.append("%s has neither source line nor question" % p["ID"])
    for q in set(QID.findall(doc.text)):
        if q.lower() not in src["anchors"]:
            problems.append("%s has no BACKLOG anchor" % q)
    sp_ids = {p["ID"] for p in c["params"]}
    for ty in TYPES:
        for f in c["fields"][ty]:
            for sp in re.findall(r"SP-\d{2}", f["Rule"]):
                if sp not in sp_ids:
                    problems.append("%s.%s names absent %s" % (ty, f["Field"], sp))
    scen = doc.section("Scenarios")
    for i, line in enumerate(doc.lines):
        if doc.fence[i]:
            for m in ILLUSTRATIVE_ID.findall(line):
                if "illustrative" not in m:
                    problems.append("line %d non-illustrative id %s in a record" % (i + 1, m))
            low = line.lower()
            for name in CANDIDATE_NAMES:
                if re.search(r'"[^"]*' + name + r'[^"]*"', low):
                    problems.append("line %d candidate name %s in a record" % (i + 1, name))
            continue
        if ILLUSTRATIVE_ID.search(line) and not (scen[0] <= i < scen[1]):
            problems.append("line %d names an id outside illustrative context" % (i + 1))
    res.add("A7-symbolic-values", not problems, problems or {"parameters": len(c["params"])})


def check_hashes(doc, root, roots, res):
    problems, count = [], 0
    lo, hi = doc.section("Sources")
    base = root / "docs/tech/schemas"
    for line in doc.lines[lo:hi]:
        link = None
        for m in re.finditer(r"\[[^\]]*\]\(([^)]+)\)|`(docs/[^`]+\.(?:md|csv))`|SHA256\s+`([0-9a-f]{64})`", line):
            if m.group(1):
                target = m.group(1)
                if not ("#" in target and target.split("#")[0].endswith(("BACKLOG.md", "TRACKING.md"))):
                    link = target.split("#")[0] or link
                continue
            if m.group(2):
                link = "repo:" + m.group(2)
                continue
            count += 1
            if link and link.startswith("repo:"):
                rel = link[5:]
                path = next((r / rel for r in roots if (r / rel).exists()), None)
            else:
                path = (base / link).resolve() if link else None
            actual = hashlib.sha256(path.read_bytes()).hexdigest() if path and path.exists() else None
            if actual != m.group(3):
                problems.append("%s stated %s actual %s" % (link, m.group(3), actual))
    res.add("A8-stated-hashes", not problems and count > 0, problems or {"hashes": count})


def check_ownership(doc, c, roots, res):
    problems = []
    request = "artifacts/handoff-8-2026-09-16/amendments/AM-H8-004/request.md"
    lo, hi = doc.section("Sources")
    opening = "\n".join(doc.lines[lo:hi])
    if "revision 2" not in opening.split("\n- ")[0] or request not in opening.split("\n- ")[0]:
        problems.append("the Sources opening does not cite revision 2 and AM-H8-004")
    if not any((r / request).exists() for r in roots):
        problems.append("AM-H8-004 request not found under the given roots")
    for stale in ("### Withheld", "pending an amendment", "pending the amendment", "withheld pending"):
        if stale.lower() in doc.text.lower():
            problems.append("stale framing: %s" % stale)
    for p in c["params"]:
        if p["Value"].startswith("withheld"):
            problems.append("%s still withheld" % p["ID"])
    for t in c["types"].values():
        if re.search(r"event|secret", t["Name"], re.I):
            problems.append("type %s has no row" % t["Name"])
    res.add("A9-settled-ownership", not problems, problems or request)


def run_checks(root, roots, text, src):
    res = Result()
    doc = Doc(text)
    try:
        check_headings(doc, res)
        c = parse_contract(doc)
        allocated = check_allocation(c, src, res)
        records = check_types(doc, c, res)
        check_targets(c, src, res)
        check_save(c, src, allocated, res)
        model = check_traces(doc, c, src, records, res)
        check_codec(doc, c, src, records, model, res)
        check_symbolic(doc, c, src, res)
        check_hashes(doc, root, roots, res)
        check_ownership(doc, c, roots, res)
        check_objective_path(doc, c, res)
    except Exception as error:  # a mutated copy that no longer parses must count as a failure
        res.add("A-parse", False, "%s: %s" % (type(error).__name__, error))
    return res


CONTROLS = [
    ("NC1-unallocated-rationale-noun", "A1-row-allocation",
     "| N-036 | excluded | T3 | route | constrains |\n", ""),
    ("NC2-retreated-row", "A1-row-allocation",
     "| N-002 | schema | T1 | region | defines |", "| N-002 | excluded | T1 | region | constrains |"),
    ("NC3-field-outside-csv", "A4-save-treatment",
     "`run.start.entrance_id`; `run.checkpoint.next_entrance`", "`run.start.entrance_id`; `run.checkpoint.level_id`"),
    ("NC4-trace-reference-resolves", "A5-admission-traces",
     '"generation_constraint_id": "generation_constraint.illustrative-missing"',
     '"generation_constraint_id": "generation_constraint.illustrative-a"'),
    ("NC5-parameter-without-question", "A7-symbolic-values",
     "| unset | Q-P12; TH-11 RP-09 at line 267 |", "| unset | none |"),
    ("NC6-unlabelled-record", "A2-type-completeness",
     "**Illustrative authored record, not canon.** The values are placeholders.\n\n```json\n{\n  \"id\": \"level_module",
     "The values are placeholders.\n\n```json\n{\n  \"id\": \"level_module"),
    ("NC7-own-row-as-foreign-target", "A3-reference-targets",
     "| encounter_slots | array of object | yes | F-04 |", "| encounter_slots | array of object | yes | F-05 |"),
    ("NC9-objective-reference-removed", "A10-objective-path",
     "| FR-03 | outbound, through FR-01 or FR-02 |", "| FR-03 | inbound |"),
    ("NC10-pending-framing", "A9-settled-ownership",
     "It follows amendment AM-H8-004, accepted as option 1 at `artifacts/handoff-8-2026-09-16/amendments/AM-H8-004/request.md`.",
     "Events and secrets are withheld pending an amendment request."),
    ("NC11-undeclared-field", "A6-encode-decode",
     '"composition_key": "illustrative-composition-a",', '"composition_key": "illustrative-composition-a",\n  "event_ids": [],'),
    ("NC12-stale-sc04-hash", "A8-stated-hashes",
     "8ab8f0cc5df16a036717e649db9610fc4f0b378645a441b2f01f4e5e37972f25",
     "2bb8c5696a7e4f211e0cc00a4522473b1934d68c192b6f32bdcb8b1685eb2c7c"),
    ("NC8-stale-hash", "A8-stated-hashes",
     "7ef95df2fb25f05b7b544cd7dbf2239cd1106c382aab0e8bc5e76288146259a6",
     "7ef95df2fb25f05b7b544cd7dbf2239cd1106c382aab0e8bc5e76288146259a7"),
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root")
    parser.add_argument("--out", required=True)
    parser.add_argument("--doc")
    parser.add_argument("--main-root")
    parser.add_argument("--no-controls", action="store_true")
    args = parser.parse_args()
    root = Path(args.root).resolve()
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    doc_path = Path(args.doc).resolve() if args.doc else root / "docs/tech/schemas/SC-05.md"
    text = doc_path.read_text(encoding="utf-8")
    src = load_sources(root)
    roots = [root] + ([Path(args.main_root).resolve()] if args.main_root else [])
    res = run_checks(root, roots, text, src)
    controls = []
    if not args.no_controls:
        for name, target, old, new in CONTROLS:
            applied = text.count(old) >= 1
            mutated = text.replace(old, new, 1)
            cres = run_checks(root, roots, mutated, src)
            failed_ids = [f["id"] for f in cres.failed()]
            controls.append({
                "control": name, "applied": applied, "expected_failure": target,
                "failed_checks": failed_ids, "caught": applied and target in failed_ids,
            })
    manifest = {}
    for rel in [
        "docs/tech/schemas/SC-05.md",
        "docs/tech/sections/HF-06a-schema-inventory.md",
        "docs/tech/sections/HF-06a-schema-inventory.csv",
        "docs/tech/sections/HF-06b-persistence-projection.csv",
        "docs/tech/sections/HF-07a-save-envelope.csv",
        "docs/tech/sections/HF-05-content-admission.md",
        "BACKLOG.md",
        "docs/tech/schemas/SC-04.md",
        "artifacts/handoff-8-2026-09-16/amendments/AM-H8-004/request.md",
        "artifacts/handoff-8-2026-09-16/amendments/AM-H8-002/request.md",
        "artifacts/local/tasks/SC-05/check_sc05.py",
    ]:
        path = next((r / rel for r in roots if (r / rel).exists()), None)
        manifest[rel] = hashlib.sha256(path.read_bytes()).hexdigest() if path else None
    passed = sum(1 for ch in res.checks if ch["pass"])
    caught = sum(1 for ctl in controls if ctl["caught"])
    report = {
        "doc": str(doc_path),
        "checks_passed": passed,
        "checks_failed": len(res.checks) - passed,
        "controls_caught": caught,
        "controls_total": len(controls),
        "checks": res.checks,
        "controls": controls,
    }
    (out / "paper-check.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    (out / "source-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    for ch in res.checks:
        print("%s %s" % ("PASS" if ch["pass"] else "FAIL", ch["id"]))
        if not ch["pass"]:
            print("  " + json.dumps(ch["detail"])[:2000])
    for ctl in controls:
        print("%s %s (expected %s; failed %s)" % (
            "CAUGHT" if ctl["caught"] else "MISSED", ctl["control"], ctl["expected_failure"], ctl["failed_checks"]))
    print("checks %d passed, %d failed; controls %d of %d caught" % (
        passed, len(res.checks) - passed, caught, len(controls)))
    ok = not res.failed() and caught == len(controls)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
