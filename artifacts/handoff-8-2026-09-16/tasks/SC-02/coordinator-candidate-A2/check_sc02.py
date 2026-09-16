#!/usr/bin/env python3
"""Paper check for docs/tech/schemas/SC-02.md, attempt 2.

Usage: python3 check_sc02.py <repository-root> --out <directory>

Exit 0 only when every check passes on the real contract and every negative
control produces at least one failure the clean run did not.
"""

import argparse
import csv
import hashlib
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

CONTRACT = "docs/tech/schemas/SC-02.md"
HF06A_MD = "docs/tech/sections/HF-06a-schema-inventory.md"
HF06A_CSV = "docs/tech/sections/HF-06a-schema-inventory.csv"
HF06B_CSV = "docs/tech/sections/HF-06b-persistence-projection.csv"
HF07A_CSV = "docs/tech/sections/HF-07a-save-envelope.csv"
HF05 = "docs/tech/sections/HF-05-content-admission.md"
BACKLOG = "BACKLOG.md"

HEADINGS = [
    "Sources",
    "Contract",
    "Scenarios",
    "Unresolved questions",
    "Re-verification triggers",
    "Procedure performed",
    "Evidence limits",
]

KIT = "N-021 ability definitions by ID and expected family `ability`"

# Sibling rows outside this family's scope that point into it. Each entry is
# the admitted wording the contract rests on and the set of this contract's
# types the row's inbound references must name; a changed row fails here
# instead of silently keeping an old reading.
SIBLINGS = {
    "F-01": ([KIT, "F-02 attacks it produces", "possibly none"], {"AbilityDefinition"}),
    "N-007": ([KIT, "F-02 attacks it produces", "possibly none"], {"AbilityDefinition"}),
    "N-008": ([KIT, "F-02 attacks it produces", "possibly none"], {"AbilityDefinition"}),
    "N-009": ([KIT, "F-02 attacks it produces", "possibly none"], {"AbilityDefinition"}),
    "N-010": ([KIT, "F-02 attacks it produces", "possibly none", "chaos-outcome references"], {"AbilityDefinition", "ChaosOutcomeDefinition"}),
    "N-011": ([KIT, "F-02 attacks it produces", "possibly none"], {"AbilityDefinition"}),
    "N-019": ([KIT, "F-02 attacks it produces", "possibly none"], {"AbilityDefinition"}),
    "N-013": (
        [KIT, "visual reference sits on its N-021 ability definition", "visual reference on its F-02 attack definition"],
        {"AbilityDefinition", "AttackDefinition"},
    ),
    "N-016": (
        ["effect reference to an N-021 ability definition", "effect reference to an F-02 attack definition"],
        {"AbilityDefinition", "AttackDefinition"},
    ),
}

# A chaos outcome's geometry key is always also outside its closed field set,
# so a trace naming S07 without S02 would under-report the findings.
IMPLIES = {"SC02-S07": ["SC02-S02"]}

CAF_FIELDS = ["`rule`", "`candidate_identity`", "definition ID", "location", "source path", "constraint", "catalogue revision"]

TRACES = {"AV": "pinned", "AM": "draft", "AI": "draft"}

SAVE_FIELD = re.compile(
    r"^(run|profile|preferences)\.[A-Za-z_.\[\]]+$|^(content_revision|schema_version|generation|transaction_id)$"
)
QID = re.compile(r"\bQ-[EP]\d{2}\b")
SPID = re.compile(r"\bSP-\d{2}\b")


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def cells(line):
    return [c.strip() for c in line.strip().strip("|").split("|")]


def tables(text):
    out, cur = [], []
    for line in text.split("\n"):
        if line.startswith("|"):
            cur.append(line)
        elif cur:
            out.append(cur)
            cur = []
    if cur:
        out.append(cur)
    parsed = []
    for block in out:
        if len(block) < 2:
            continue
        header = cells(block[0])
        rows = [dict(zip(header, cells(r))) for r in block[2:]]
        parsed.append((header, rows))
    return parsed


def section(text, heading, level):
    lines = text.split("\n")
    marker = "#" * level + " " + heading
    start = None
    for i, line in enumerate(lines):
        if line.strip() == marker:
            start = i + 1
            break
    if start is None:
        return None
    end = len(lines)
    for j in range(start, len(lines)):
        m = re.match(r"^(#+) ", lines[j])
        if m and len(m.group(1)) <= level:
            end = j
            break
    return "\n".join(lines[start:end])


def table_with(text, first_columns):
    for header, rows in tables(text or ""):
        if header[: len(first_columns)] == first_columns:
            return rows
    return None


def ticks(s):
    return re.findall(r"`([^`]+)`", s)


def unquote(s):
    s = s.strip()
    return s[1:-1] if s.startswith("`") and s.endswith("`") else s


def load_sources(root):
    root = Path(root)
    with open(root / HF06A_CSV, newline="") as f:
        hf06a = {r["row_id"]: r for r in csv.DictReader(f)}
    md_rows = table_with((root / HF06A_MD).read_text(), ["Row", "Subject", "Source", "Treatment"]) or []
    hf06a_md = {r["Row"]: r for r in md_rows}
    with open(root / HF06B_CSV, newline="") as f:
        hf06b = {r["row_id"]: r for r in csv.DictReader(f)}
    with open(root / HF07A_CSV, newline="") as f:
        hf07a = {r["field"] for r in csv.DictReader(f)}
    hf05 = (root / HF05).read_text()
    edges = {}
    crf_fields = []
    for header, rows in tables(hf05):
        if header[:4] == ["Edge", "From", "To", "Operation, owner and guard"]:
            for r in rows:
                edges[r["Edge"]] = (r["From"], r["To"])
        if header == ["Field", "Meaning"] and any(unquote(r["Field"]) == "referrer" for r in rows):
            crf_fields = [unquote(r["Field"]) for r in rows]
    codes = set(re.findall(r"`([a-z_]+)`", hf05.split("| `code` |")[1].split("\n")[0]))
    backlog = (root / BACKLOG).read_text()
    anchors = set(re.findall(r'<a id="([a-z0-9-]+)"></a>', backlog))
    return {
        "hf06a": hf06a,
        "hf06a_md": hf06a_md,
        "hf06b": hf06b,
        "hf07a": hf07a,
        "edges": edges,
        "codes": codes,
        "crf_fields": crf_fields,
        "anchors": anchors,
    }


def rationales(src, row):
    md = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", src["hf06a_md"].get(row, {}).get("Scope and rationale", ""))
    return md, src["hf06a"].get(row, {}).get("scope_and_rationale", "")


class Result:
    def __init__(self):
        self.items = []

    def check(self, cid, ok, detail):
        self.items.append({"id": cid, "passed": bool(ok), "detail": detail})

    def failures(self):
        return {(i["id"], i["detail"]) for i in self.items if not i["passed"]}


def parse_types(text):
    rows = table_with(section(text, "Scope, types and matrix rows", 3), ["Type", "Kind", "Family token"])
    types = {}
    for r in rows or []:
        name = unquote(r["Type"])
        basis = {}
        for row, phrase in re.findall(r'([FN]-\d{2,3}): "([^"]+)"', r.get("Rationale basis", "")):
            basis.setdefault(row, []).append(phrase)
        types[name] = {
            "kind": r["Kind"],
            "family": unquote(r["Family token"]),
            "rows": [x.strip() for x in r["HF-06a rows"].split(",")],
            "parent": unquote(r["Parent"]),
            "basis": basis,
        }
    return types


def field_specs(type_section):
    specs = {}
    for header, rows in tables(type_section):
        if header[:3] == ["Field", "Type", "Presence"]:
            for r in rows:
                specs[unquote(r["Field"])] = r
    return specs


def parse_params(text):
    rows = table_with(section(text, "Tunable parameters", 3), ["ID", "Parameter", "Value at this base"])
    return {r["ID"]: r for r in rows or []}


def norm(path):
    return re.sub(r"\[\d+\]", "[]", path)


def spec_kind(spec_type):
    t = unquote(spec_type)
    enum = re.fullmatch(r"enum\{([^}]*)\}", t)
    if enum:
        return "enum", [x.strip() for x in enum.group(1).split(",")]
    if t.startswith("array of id-string"):
        return "id-list", None
    if t.startswith("id-string"):
        return "id", None
    return "symbolic", None


CODEC = {"enum": "word"}


def encode(record, specs):
    """Emit one typed line per declared scalar field in table order; keys the
    tables do not declare are not emitted."""
    lines = []
    for fname, spec in specs.items():
        if unquote(spec["Type"]).startswith(("record", "array of record")):
            continue
        for path in sorted(p for p in record if norm(p) == fname):
            value = record[path]
            kind, vocab = spec_kind(spec["Type"])
            if kind == "enum":
                if value not in vocab:
                    token = {"k": "bad-enum", "v": value}
                elif CODEC["enum"] == "ordinal":
                    token = {"k": "enum", "v": vocab.index(value)}
                else:
                    token = {"k": "enum", "v": value}
            elif kind == "id-list":
                token = {"k": "ids", "v": [x.strip() for x in value.strip("[]").split(",") if x.strip()]}
            elif re.fullmatch(r"<SP-\d{2}>", value):
                token = {"k": "sym", "v": value}
            elif value == "null":
                token = {"k": "null", "v": None}
            else:
                token = {"k": "id", "v": value}
            lines.append(json.dumps({"path": path, **token}, sort_keys=True))
    return "\n".join(lines)


def decode(text, specs):
    out, errors = {}, []
    for line in text.split("\n"):
        if not line:
            continue
        item = json.loads(line)
        spec = specs.get(norm(item["path"]))
        kind, vocab = spec_kind(spec["Type"]) if spec else (None, None)
        k, v = item["k"], item["v"]
        if kind == "enum":
            if k != "enum" or not isinstance(v, str) or v not in vocab:
                errors.append("%s: enum value %r does not conform" % (item["path"], v))
                continue
            out[item["path"]] = v
        elif kind == "id-list":
            if k != "ids":
                errors.append("%s: expected id list" % item["path"])
                continue
            out[item["path"]] = "[" + ", ".join(v) + "]"
        elif k == "sym":
            out[item["path"]] = v
        elif k == "null":
            if "or null" not in spec["Type"] and kind != "symbolic":
                errors.append("%s: null not allowed" % item["path"])
            out[item["path"]] = "null"
        elif k == "id":
            out[item["path"]] = v
        else:
            errors.append("%s: undecodable kind %s" % (item["path"], k))
    return out, errors


def check_all(text, src, root):
    res = Result()
    types = parse_types(text)
    schema_types = [t for t, v in types.items() if v["kind"] == "schema"]
    embedded = [t for t, v in types.items() if v["kind"] == "embedded-record"]
    families = {t: types[t]["family"] for t in schema_types}
    params = parse_params(text)

    found = re.findall(r"^## (.+)$", text, re.M)
    res.check("C01-headings", found == HEADINGS, "found " + json.dumps(found))

    rowmap = table_with(section(text, "Scope, types and matrix rows", 3), ["Row", "Treatment", "Producing card", "Adds type"]) or []
    scope = {k for k, v in src["hf06a"].items() if v["producing_card"] == "SC-02"}
    mapped = {r["Row"] for r in rowmap}
    res.check("C02a-rows-equal-scope", mapped == scope, "doc %s scope %s" % (sorted(mapped), sorted(scope)))
    adds = {}
    for r in rowmap:
        added = ticks(r["Adds type"])
        restated = ticks(r["Restates"])
        csvrow = src["hf06a"].get(r["Row"], {})
        res.check("C02b-one-type-per-row:" + r["Row"], len(added) == 1 and added[0] in schema_types, "adds %s" % added)
        res.check(
            "C02c-treatment-and-card:" + r["Row"],
            csvrow.get("treatment") == r["Treatment"] and csvrow.get("producing_card") == r["Producing card"],
            "doc %s/%s csv %s/%s" % (r["Treatment"], r["Producing card"], csvrow.get("treatment"), csvrow.get("producing_card")),
        )
        for t in added:
            adds.setdefault(t, []).append(r["Row"])
        carried = {t for t in schema_types if r["Row"] in types[t]["rows"]}
        res.check("C02e-row-map-equals-allocation:" + r["Row"], carried == set(added) | set(restated), "carried %s map %s" % (sorted(carried), sorted(set(added) | set(restated))))
    for t in schema_types:
        res.check("C02f-type-added-once:" + t, len(adds.get(t, [])) == 1, "added by %s" % adds.get(t))
    for t, v in types.items():
        res.check("C02g-type-rows-in-scope:" + t, bool(v["rows"]) and set(v["rows"]) <= scope, str(v["rows"]))
        for row in v["rows"]:
            phrases = v["basis"].get(row, [])
            md, cs = rationales(src, row)
            ok = bool(phrases) and all(p.lower() in md.lower() and p.lower() in cs.lower() for p in phrases)
            res.check("C02d-basis-in-both-copies:%s:%s" % (t, row), ok, str(phrases))
        allp = [p for ps in v["basis"].values() for p in ps]
        for row in sorted(scope):
            md, cs = rationales(src, row)
            named = any(p.lower() in md.lower() or p.lower() in cs.lower() for p in allp)
            if named:
                res.check("C02i-allocation-complete:%s:%s" % (t, row), row in v["rows"], "rationale names %s" % t)
        if v["kind"] == "embedded-record":
            parent = v["parent"]
            ok = parent in schema_types and set(v["rows"]) <= set(types[parent]["rows"])
            res.check("C02h-embedded-parent-row:" + t, ok, "%s under %s" % (v["rows"], parent))

    all_specs = {}
    for t in schema_types:
        sec = section(text, "Type: " + t, 3)
        res.check("C03a-type-section:" + t, sec is not None, "")
        sec = sec or ""
        for sub in ["Fields", "Identity and version", "References", "Validation diagnostics", "Illustrative record"]:
            res.check("C03b-subsection:%s:%s" % (t, sub), section(sec, sub, 4) is not None, sub)
        specs = field_specs(sec)
        res.check("C03c-has-fields:" + t, "id" in specs, "%d field rows" % len(specs))
        all_specs[t] = specs
        for e in embedded:
            if types[e]["parent"] == t:
                esec = section(sec, "Embedded record: " + e, 4)
                res.check("C03d-embedded-section:" + e, esec is not None and field_specs(esec), "")

    for t, specs in all_specs.items():
        for name, r in specs.items():
            srcs = r["Source or parameter"]
            ok = bool(re.search(r"\blines? \d+", srcs) or SPID.search(srcs) or "SC02-ID" in srcs)
            res.check("C04a-field-sourced:%s.%s" % (t, name), ok, srcs)
            refs = SPID.findall(r["Value at this base"] + " " + srcs)
            missing = [p for p in refs if p not in params]
            res.check("C04b-field-params-exist:%s.%s" % (t, name), not missing, str(missing))
            if "unset" in r["Value at this base"]:
                sps = [x for g in re.findall(r"unset \(([^)]*)\)", r["Value at this base"]) for x in SPID.findall(g)]
                ok = bool(sps) and all(params.get(p, {}).get("Value at this base") == "unset" for p in sps)
                res.check("C04c-unset-field-symbolic:%s.%s" % (t, name), ok, r["Value at this base"])
            stripped = re.sub(r"SP-\d{2}|Q-[EP]\d{2}|lines? \d+( to \d+)?", "", r["Value at this base"])
            res.check("C04d-no-number-in-value:%s.%s" % (t, name), not re.search(r"\d", stripped), r["Value at this base"])
            pres = r["Presence"]
            ok = pres in ("required", "required, may be empty") or re.fullmatch(r"required if [a-z_.]+=[a-z_]+", pres)
            res.check("C04e-presence-form:%s.%s" % (t, name), bool(ok), pres)

    foreign_rows = set(src["hf06a"])
    outbound = {}
    for t in schema_types:
        sec = section(section(text, "Type: " + t, 3) or "", "References", 4) or ""
        rows = table_with(sec, ["Field", "Target", "Target kind"])
        res.check("C05a-references-stated:" + t, rows is not None or "No outbound" in sec, "")
        outbound[t] = rows or []
        for r in rows or []:
            kind = r["Target kind"]
            if kind == "type here":
                target = unquote(r["Target"])
                ok = target in schema_types and unquote(r["Expected family"]) == families.get(target)
            elif kind == "foreign HF-06a row":
                ids = re.findall(r"\b[FN]-\d{2,3}\b", r["Target"])
                ok = bool(ids) and set(ids) <= foreign_rows and not (set(ids) & scope)
            else:
                ok = False
            res.check("C05b-reference-target:%s:%s" % (t, r["Field"]), ok, "%s -> %s (%s)" % (kind, r["Target"], r["Expected family"]))
    fr = table_with(section(text, "Foreign references", 3), ["ID", "Direction"]) or []
    res.check("C05c-foreign-table", len(fr) > 0, "%d rows" % len(fr))
    inbound = {}
    for r in fr:
        ids = re.findall(r"\b[FN]-\d{2,3}\b", r["Foreign HF-06a row"])
        cards = {c.strip() for c in r["Producing card"].split(",")}
        actual = {src["hf06a"][i]["producing_card"] for i in ids if i in src["hf06a"]}
        named = [x.split(".")[0] for x in ticks(r["This contract's type"])]
        ok = ids and set(ids) <= foreign_rows and cards == actual and named and all(x in types for x in named)
        res.check("C05d-foreign-row:" + r["ID"], bool(ok), "%s cards %s csv %s" % (ids, sorted(cards), sorted(actual)))
        if r["Direction"] == "inbound":
            for i in ids:
                inbound.setdefault(i, set()).update(named)

    ability_commits = [
        r for r in outbound.get("AbilityDefinition", [])
        if r["Target kind"] == "type here" and unquote(r["Target"]) == "AttackDefinition"
    ]
    for row, (phrases, want) in SIBLINGS.items():
        md, cs = rationales(src, row)
        missing = [p for p in phrases if p not in md or p not in cs]
        res.check("C12a-sibling-wording:" + row, not missing, "missing %s" % missing)
        res.check("C12b-sibling-inbound-types:" + row, inbound.get(row, set()) == want, "inbound %s want %s" % (sorted(inbound.get(row, set())), sorted(want)))
        if KIT in phrases:
            res.check("C12c-kit-family:" + row, families.get("AbilityDefinition") == "ability", str(families.get("AbilityDefinition")))
        if "possibly none" in phrases:
            ok = bool(ability_commits) and all(
                all_specs.get("AbilityDefinition", {}).get(unquote(r["Field"]).replace("[]", ""), {}).get("Presence") == "required, may be empty"
                for r in ability_commits
            )
            res.check("C12d-ability-references-attacks-may-be-empty:" + row, ok, str([r["Field"] for r in ability_commits]))
    md21, cs21 = rationales(src, "N-021")
    ok = "expected family `ability`" in md21 and "expected family `ability`" in cs21 and "F-02 attack definitions" in md21 and "F-02 attack definitions" in cs21
    res.check("C12e-own-row-n021-wording", ok and families.get("AbilityDefinition") == "ability" and bool(ability_commits), "")

    adm = table_with(section(text, "Admission rules and diagnostics", 3), ["Rule", "Gate", "Check"]) or []
    rules = {r["Rule"]: r for r in adm}
    gate_from = {"structural": "imported", "cross-reference": "structurally valid", "manifest and compatibility": "structurally valid"}
    for r in adm:
        want = gate_from.get(r["Gate"])
        ini, rep = src["edges"].get(r["Initial edge"]), src["edges"].get(r["Replacement edge"])
        ok = want and ini == (want, "draft") and rep == (want, "rejected-reload")
        res.check("C06a-rule-edges:" + r["Rule"], bool(ok), "%s %s %s" % (r["Gate"], ini, rep))
        diag = r["Diagnostic"]
        if "ContentReferenceFailure" in diag:
            used = set(re.findall(r"`([a-z_]+)`", diag))
            ok = bool(used) and used <= src["codes"]
        else:
            ok = "ContentAdmissionFailure" in diag and r["Rule"] in diag
        res.check("C06b-rule-diagnostic:" + r["Rule"], ok, diag)
    for t in schema_types:
        sec = section(section(text, "Type: " + t, 3) or "", "Validation diagnostics", 4) or ""
        listed = [x.strip() for row in (table_with(sec, ["Rule", "Gate"]) or []) for x in row["Rule"].split(",")]
        missing = [x for x in listed if x not in rules]
        res.check("C06c-type-rules-exist:" + t, listed and not missing, "missing %s" % missing)

    save = section(text, "Save treatment", 3) or ""
    srows = table_with(save, ["Type", "HF-06b rows", "Save column"]) or []
    seen = set()
    for r in srows:
        t = unquote(r["Type"])
        rows = [x.strip() for x in r["HF-06b rows"].split(",")]
        res.check("C07a-save-rows-match-types:" + t, t in schema_types and rows == types.get(t, {}).get("rows"), str(rows))
        for row in rows:
            seen.add(row)
            c = src["hf06b"].get(row, {})
            pairs = [
                ("Save column", "save_column"),
                ("Case", "rationale_case"),
                ("Authoring codec", "authoring_codec"),
                ("Save projection", "save_projection"),
                ("Proof owner", "proof_owner"),
            ]
            diffs = [(a, r[a], c.get(b)) for a, b in pairs if r[a] != c.get(b)]
            res.check("C07b-save-equals-hf06b:%s:%s" % (t, row), not diffs, str(diffs))
            if r["Save column"] == "json-projection":
                toks = [x.strip() for x in r["Save projection"].split(";")]
                ok = all(x in src["hf07a"] for x in toks)
            else:
                ok = r["Save projection"] == "none" and r["Case"] in ("definition-by-id", "runtime-rebuilt", "no-definition-no-state")
            res.check("C07c-projection-or-exclusion:%s:%s" % (t, row), ok, r["Save projection"])
    res.check("C07d-every-scope-row-saved", seen == scope, str(sorted(seen)))
    paths = [p for p in ticks(save) if SAVE_FIELD.match(p)]
    absent = [p for p in paths if p not in src["hf07a"]]
    res.check("C07e-save-fields-in-hf07a", paths and not absent, "%d paths, absent %s" % (len(paths), absent))

    scen = section(text, "Scenarios", 2) or ""
    for name, final in TRACES.items():
        block = None
        for m in re.finditer(r"^### (%s): .+$" % name, scen, re.M):
            block = section(scen, m.group(0)[4:], 3)
        rows = table_with(block, ["Step", "Subject", "Edge", "From", "To", "Gate"]) if block else None
        res.check("C08a-trace-present:" + name, bool(rows), "")
        if not rows:
            continue
        prev = "draft"
        for r in rows:
            edge = src["edges"].get(r["Edge"])
            ok = edge == (r["From"], r["To"]) and r["From"] == prev
            res.check("C08b-trace-step:" + r["Step"], ok, "%s %s -> %s hf05 %s" % (r["Edge"], r["From"], r["To"], edge))
            prev = r["To"]
        res.check("C08c-trace-final:" + name, prev == final, "ends %s want %s" % (prev, final))
        last = rows[-1]["Result and diagnostic"]
        if name == "AV":
            ok = all("No diagnostic" in r["Result and diagnostic"] for r in rows)
        elif name == "AM":
            used = set(re.findall(r"`code` `([a-z_]+)`", last))
            ok = "ContentReferenceFailure" in last and used and used <= src["codes"]
            missing = [f for f in src["crf_fields"] if "`%s`" % f not in last]
            res.check("C08f-trace-required-fields:AM", src["crf_fields"] and not missing, "missing %s" % missing)
        else:
            named = sorted(set(re.findall(r"SC02-[SMC]\d{2}", last)))
            ok = "ContentAdmissionFailure" in last and named and all(
                n in rules and rules[n]["Gate"] in rows[-1]["Gate"] for n in named
            )
            unnamed = [i for n in named for i in IMPLIES.get(n, []) if i not in named]
            res.check("C08g-trace-all-firing-rules:AI", not unnamed, "unnamed %s" % unnamed)
            missing = [f for f in CAF_FIELDS if f not in last]
            res.check("C08f-trace-required-fields:AI", not missing, "missing %s" % missing)
        res.check("C08d-trace-diagnostic:" + name, bool(ok), last[:120])
        res.check("C08e-trace-outcome-line:" + name, re.search(r"\*\*%s outcome: " % name, block) is not None, "")

    codec = section(text, "Illustrative encode and decode", 3) or ""
    placeholders = dict((p, r) for p, r in re.findall(r"placeholder `(illustrative\.[a-z_.]+)` for row ([FN]-\d{2,3})", codec))
    records = {}
    for t in schema_types:
        sec = section(section(text, "Type: " + t, 3) or "", "Illustrative record", 4) or ""
        res.check("C09a-label:" + t, "**Illustrative, not canon.**" in sec, "")
        rows = table_with(sec, ["Field path", "Illustrative value"]) or []
        records[t] = {unquote(r["Field path"]): unquote(r["Illustrative value"]) for r in rows}
        res.check("C09b-one-record:" + t, len(tables(sec)) == 1 and records[t].get("id", "").startswith("illustrative."), "")
    ids = {t: rec.get("id") for t, rec in records.items()}
    for t, rec in records.items():
        specs = all_specs.get(t, {})
        for fname, spec in specs.items():
            if unquote(spec["Type"]).startswith(("record", "array of record")):
                continue
            parent = fname.split(".")[0] if "." in fname else None
            if parent and parent in specs and rec.get(parent) == "null":
                continue
            m = re.fullmatch(r"required if ([a-z_.]+)=([a-z_]+)", spec["Presence"])
            want = rec.get(m.group(1)) == m.group(2) if m else True
            have = any(norm(p) == fname for p in rec)
            res.check("C09d-presence:%s:%s" % (t, fname), have == want, "have %s want %s" % (have, want))
        for path, value in rec.items():
            spec = specs.get(norm(path), {})
            kind, vocab = spec_kind(spec.get("Type", "``"))
            listed = [x.strip() for x in value.strip("[]").split(",")] if value.startswith("[") else [value]
            form = all(
                x == "null" or re.fullmatch(r"<SP-\d{2}>", x) or x.startswith("illustrative.") or (vocab and x in vocab)
                for x in listed
            )
            res.check("C09e-value-form:%s:%s" % (t, path), form and not re.search(r"\d", re.sub(r"<SP-\d{2}>", "", value)), value)
            for s in SPID.findall(value):
                ok = params.get(s, {}).get("Value at this base") == "unset" and s in SPID.findall(spec.get("Value at this base", "") + spec.get("Source or parameter", ""))
                res.check("C09f-symbol-unset-and-cited:%s:%s:%s" % (t, path, s), ok, "")
        encoded = encode(rec, specs)
        decoded, errors = decode(encoded, specs)
        res.check("C09g-typed-decode:" + t, not errors, "; ".join(errors))
        lost = sorted(set(rec) - set(decoded))
        changed = sorted(p for p in rec if p in decoded and decoded[p] != rec[p])
        res.check("C09h-fields-preserved:" + t, not lost and not changed and set(decoded) == set(rec), "lost %s changed %s" % (lost, changed))
        for r in outbound.get(t, []):
            field = unquote(r["Field"]).replace("[]", "")
            before, after = rec.get(field), decoded.get(field)
            res.check("C09i-reference-preserved:%s:%s" % (t, field), before is not None and before == after, "%s -> %s" % (before, after))
            for x in [x.strip() for x in (after or "").strip("[]").split(",") if x.strip()]:
                if r["Target kind"] == "type here":
                    target = unquote(r["Target"])
                    ok = x == ids.get(target) and families.get(target) == unquote(r["Expected family"])
                else:
                    ok = placeholders.get(x) in re.findall(r"\b[FN]-\d{2,3}\b", r["Target"])
                res.check("C09j-reference-resolves-with-family:%s:%s:%s" % (t, field, x), ok, "")

    for pid, r in params.items():
        qs = QID.findall(r["Source line or question"])
        if r["Value at this base"] == "unset":
            ok = bool(qs)
        else:
            ok = bool(re.search(r"\blines? \d+", r["Source line or question"]))
        res.check("C10a-param-sourced:" + pid, ok, r["Source line or question"])
        if "Q-P13" in qs and r["Value at this base"] != "unset":
            res.check("C10b-q-p13-no-value:" + pid, "EV-0322" in r["Source line or question"], "")
    allq = set(QID.findall(text))
    missing = sorted(q for q in allq if q.lower() not in src["anchors"])
    res.check("C10c-questions-resolve", not missing, "%d ids, missing %s" % (len(allq), missing))

    stated = []
    src_text = section(text, "Sources", 2) or ""
    bullets, cur = [], None
    for line in src_text.split("\n"):
        if line.startswith("- "):
            cur = [line]
            bullets.append(cur)
        elif cur is not None and line.strip():
            cur.append(line)
        else:
            cur = None
    token = re.compile(r"SHA256\s+`([0-9a-f]{64})`|\[[^\]]*\]\(([^)]+)\)")
    for b in bullets:
        link = None
        for m in token.finditer(" ".join(b)):
            if m.group(2) is not None:
                target = m.group(2).split("#")[0]
                if target and not re.match(r"^[a-z]+:", target) and not ("#" in m.group(2) and Path(target).name in ("BACKLOG.md", "TRACKING.md")):
                    link = target
                continue
            path = (Path(root) / "docs/tech/schemas" / link).resolve() if link else None
            actual = sha256(path) if path and path.exists() else None
            stated.append({"link": link, "stated": m.group(1), "actual": actual})
            res.check("C11-hash:%s" % link, actual == m.group(1), "")
    res.check("C11-hash-count", len(stated) >= 1, "%d stated" % len(stated))
    return res, stated


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    root = Path(args.root).resolve()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    src = load_sources(root)
    text = (root / CONTRACT).read_text()

    clean, stated = check_all(text, src, root)
    base = clean.failures()
    controls = []

    def control(cid, description, old=None, new=None, enum_mode=None):
        t = text.replace(old, new) if old is not None else text
        if old is not None and (text.count(old) != 1 or t == text):
            controls.append({"id": cid, "description": description, "noticed": False, "new_failures": ["mutation did not apply"]})
            return
        if enum_mode:
            CODEC["enum"] = enum_mode
        try:
            r, _ = check_all(t, src, root)
        finally:
            CODEC["enum"] = "word"
        new_f = sorted(r.failures() - base)
        controls.append({"id": cid, "description": description, "noticed": bool(new_f), "new_failures": [a for a, _ in new_f][:10]})

    control("NC-1", "row N-021 removed from the row map, leaving AbilityDefinition added by no row",
            "| N-021 | schema | SC-02 | `AbilityDefinition` | `AttackDefinition` |\n", "")
    control("NC-2", "AttackDefinition given a JSON projection naming a field absent from HF-07a's CSV",
            "| `AttackDefinition` | F-02, N-020, N-021 | immutable-by-id | definition-by-id | tres | none | none |",
            "| `AttackDefinition` | F-02, N-020, N-021 | json-projection | projection | tres | run.checkpoint.attack_ids | TH-22 |")
    control("NC-3", "unset parameter SP-26 given a number with no source line",
            "| SP-26 | Miscast frequency | unset |", "| SP-26 | Miscast frequency | 3 |")
    control("NC-4", "field table no longer declares AbilityDefinition.commits, so the table-driven encoder drops the reference",
            "| `commits` | `array of id-string` | required, may be empty |", "| `commits_removed` | `array of id-string` | required, may be empty |")
    control("NC-5", "trace step AM.3 uses E08, whose from-state contradicts the step",
            "| AM.3 | candidate B | E09 |", "| AM.3 | candidate B | E08 |")
    control("NC-6", "kit-to-attack reference restored: FR-03 names AttackDefinition for the kit rows",
            "| FR-03 | inbound | `AbilityDefinition` |", "| FR-03 | inbound | `AttackDefinition` |")
    control("NC-7", "codec stores enum ordinals instead of vocabulary words", enum_mode="ordinal")
    control("NC-8", "illustrative slot_role outside its closed vocabulary",
            "| `slot_role` | `ultimate` |", "| `slot_role` | `sidearm` |")
    control("NC-9", "AM.3 omits the required candidate_identity field",
            "`candidate_identity` B's staged source revision and digest, ", "")
    control("NC-10", "AI.2 names only SC02-S07",
            "SC02-S02 and SC02-S07 both fail on the same key", "SC02-S07 fails on the key")

    passed = sum(1 for i in clean.items if i["passed"])
    failed = len(clean.items) - passed
    noticed = sum(1 for c in controls if c["noticed"])
    report = {
        "contract": CONTRACT,
        "contract_sha256": sha256(root / CONTRACT),
        "generated_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "passed": passed,
        "failed": failed,
        "failures": [i for i in clean.items if not i["passed"]],
        "negative_controls": controls,
        "negative_controls_noticed": noticed,
        "stated_hashes": stated,
        "checks": clean.items,
    }
    (out / "paper-check.json").write_text(json.dumps(report, indent=2) + "\n")
    manifest = {p: sha256(root / p) for p in [CONTRACT, HF06A_MD, HF06A_CSV, HF06B_CSV, HF07A_CSV, HF05, BACKLOG]}
    manifest["check_sc02.py"] = sha256(Path(__file__))
    (out / "source-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("SC-02 paper check: %d passed, %d failed; negative controls noticed %d of %d" % (passed, failed, noticed, len(controls)))
    for i in report["failures"]:
        print("FAIL", i["id"], i["detail"])
    for c in controls:
        print("CONTROL", c["id"], "noticed" if c["noticed"] else "NOT NOTICED", c["new_failures"][:3])
    return 0 if failed == 0 and noticed == len(controls) else 1


if __name__ == "__main__":
    sys.exit(main())
