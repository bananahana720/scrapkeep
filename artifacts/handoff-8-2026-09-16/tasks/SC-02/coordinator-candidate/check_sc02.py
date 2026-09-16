#!/usr/bin/env python3
"""Paper check for docs/tech/schemas/SC-02.md.

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

# The row map claims each added type is named by its row's HF-06a rationale;
# these are the phrases that claim rests on, so a renamed type without a
# matching phrase fails rather than passing on the type name alone.
RATIONALE_PHRASE = {
    "AttackDefinition": "attack definition",
    "ChaosOutcomeDefinition": "chaos-outcome definitions",
    "AbilityDefinition": "ability and ultimate definitions",
}

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
    with open(root / HF06B_CSV, newline="") as f:
        hf06b = {r["row_id"]: r for r in csv.DictReader(f)}
    with open(root / HF07A_CSV, newline="") as f:
        hf07a = {r["field"] for r in csv.DictReader(f)}
    hf05 = (root / HF05).read_text()
    edges = {}
    for header, rows in tables(hf05):
        if header[:4] == ["Edge", "From", "To", "Operation, owner and guard"]:
            for r in rows:
                edges[r["Edge"]] = (r["From"], r["To"])
    codes = set(re.findall(r"`([a-z_]+)`", hf05.split("| `code` |")[1].split("\n")[0]))
    backlog = (root / BACKLOG).read_text()
    anchors = set(re.findall(r'<a id="([a-z0-9-]+)"></a>', backlog))
    return {
        "hf06a": hf06a,
        "hf06b": hf06b,
        "hf07a": hf07a,
        "edges": edges,
        "codes": codes,
        "anchors": anchors,
    }


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
        types[name] = {
            "kind": r["Kind"],
            "family": unquote(r["Family token"]),
            "rows": [x.strip() for x in r["HF-06a rows"].split(",")],
            "parent": unquote(r["Parent"]),
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


def check_all(text, src, root):
    res = Result()
    types = parse_types(text)
    schema_types = [t for t, v in types.items() if v["kind"] == "schema"]
    embedded = [t for t, v in types.items() if v["kind"] == "embedded-record"]
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
        csvrow = src["hf06a"].get(r["Row"], {})
        ok = len(added) == 1 and added[0] in schema_types
        res.check("C02b-one-type-per-row:" + r["Row"], ok, "adds %s" % added)
        res.check(
            "C02c-treatment-and-card:" + r["Row"],
            csvrow.get("treatment") == r["Treatment"] and csvrow.get("producing_card") == r["Producing card"],
            "doc %s/%s csv %s/%s" % (r["Treatment"], r["Producing card"], csvrow.get("treatment"), csvrow.get("producing_card")),
        )
        for t in added:
            adds.setdefault(t, []).append(r["Row"])
            phrase = RATIONALE_PHRASE.get(t)
            ok = bool(phrase) and phrase in csvrow.get("scope_and_rationale", "").lower()
            res.check("C02d-rationale-names-type:" + t, ok, "phrase %r in %s" % (phrase, r["Row"]))
        for t in ticks(r["Restates"]):
            res.check("C02e-restated-is-type:" + r["Row"], t in schema_types, t)
    for t in schema_types:
        res.check("C02f-type-added-once:" + t, len(adds.get(t, [])) == 1, "added by %s" % adds.get(t))
        res.check("C02g-type-rows-in-scope:" + t, set(types[t]["rows"]) <= scope and types[t]["rows"], str(types[t]["rows"]))
    for t in embedded:
        parent = types[t]["parent"]
        ok = parent in schema_types and set(types[t]["rows"]) <= set(types[parent]["rows"])
        res.check("C02h-embedded-parent-row:" + t, ok, "%s under %s" % (types[t]["rows"], parent))

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
    for t in schema_types:
        sec = section(section(text, "Type: " + t, 3) or "", "References", 4) or ""
        rows = table_with(sec, ["Field", "Target", "Target kind"])
        res.check("C05a-references-stated:" + t, rows is not None or "No outbound" in sec, "")
        for r in rows or []:
            kind = r["Target kind"]
            if kind == "type here":
                ok = unquote(r["Target"]) in schema_types
            elif kind == "foreign HF-06a row":
                ids = re.findall(r"\b[FN]-\d{2,3}\b", r["Target"])
                ok = bool(ids) and set(ids) <= foreign_rows and not (set(ids) & scope)
            else:
                ok = False
            res.check("C05b-reference-target:%s:%s" % (t, r["Field"]), ok, "%s -> %s" % (kind, r["Target"]))
    fr = table_with(section(text, "Foreign references", 3), ["ID", "Direction"]) or []
    res.check("C05c-foreign-table", len(fr) > 0, "%d rows" % len(fr))
    for r in fr:
        ids = re.findall(r"\b[FN]-\d{2,3}\b", r["Foreign HF-06a row"])
        cards = {c.strip() for c in r["Producing card"].split(",")}
        actual = {src["hf06a"][i]["producing_card"] for i in ids if i in src["hf06a"]}
        ok = ids and set(ids) <= foreign_rows and cards == actual and all(x.split(".")[0] in types for x in ticks(r["This contract's type"]))
        res.check("C05d-foreign-row:" + r["ID"], bool(ok), "%s cards %s csv %s" % (ids, sorted(cards), sorted(actual)))

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
            used = set(re.findall(r"code `([a-z_]+)`", last))
            ok = "ContentReferenceFailure" in last and used and used <= src["codes"]
        else:
            named = re.findall(r"SC02-[SMC]\d{2}", last)
            ok = "ContentAdmissionFailure" in last and named and all(
                n in rules and rules[n]["Gate"] in rows[-1]["Gate"] for n in named
            )
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
    decoder = CODEC["decode"]
    for t, rec in records.items():
        specs = all_specs.get(t, {})
        norm = lambda p: re.sub(r"\[\d+\]", "[]", p)
        for path in rec:
            res.check("C09c-known-key:%s:%s" % (t, path), norm(path) in specs, "")
        for fname, spec in specs.items():
            if spec["Type"].startswith("`record") or spec["Type"].startswith("`array of record"):
                continue
            parent = fname.split(".")[0] if "." in fname else None
            if parent and parent in specs and rec.get(parent) == "null":
                continue
            m = re.fullmatch(r"required if ([a-z_.]+)=([a-z_]+)", spec["Presence"])
            want = rec.get(m.group(1)) == m.group(2) if m else True
            have = any(norm(p) == fname for p in rec)
            res.check("C09d-presence:%s:%s" % (t, fname), have == want, "have %s want %s" % (have, want))
        for path, value in rec.items():
            v = value
            symbols = SPID.findall(v)
            spec = specs.get(norm(path), {})
            enum = re.findall(r"enum\{([^}]*)\}", spec.get("Type", ""))
            vocab = {x.strip() for x in enum[0].split(",")} if enum else set()
            listed = [x.strip() for x in v.strip("[]").split(",")] if v.startswith("[") else [v]
            form = all(
                x == "null" or re.fullmatch(r"<SP-\d{2}>", x) or x.startswith("illustrative.") or x in vocab
                for x in listed
            )
            res.check("C09e-value-form:%s:%s" % (t, path), form and not re.search(r"\d", re.sub(r"<SP-\d{2}>", "", v)), v)
            for s in symbols:
                ok = params.get(s, {}).get("Value at this base") == "unset" and s in SPID.findall(spec.get("Value at this base", "") + spec.get("Source or parameter", ""))
                res.check("C09f-symbol-unset-and-cited:%s:%s:%s" % (t, path, s), ok, "")
        encoded = "\n".join("%s = %s" % (p, rec[p]) for p in sorted(rec))
        decoded = decoder(encoded)
        res.check("C09g-roundtrip-fields:" + t, decoded == rec, "%d fields" % len(rec))
        sec = section(section(text, "Type: " + t, 3) or "", "References", 4) or ""
        for r in table_with(sec, ["Field", "Target", "Target kind"]) or []:
            field = unquote(r["Field"]).replace("[]", "")
            before = rec.get(field)
            after = decoded.get(field)
            res.check("C09h-roundtrip-reference:%s:%s" % (t, field), before is not None and before == after, "%s -> %s" % (before, after))
            targets = [x.strip() for x in (after or "").strip("[]").split(",") if x.strip()]
            for x in targets:
                if r["Target kind"] == "type here":
                    ok = x == ids.get(unquote(r["Target"]))
                else:
                    rowids = re.findall(r"\b[FN]-\d{2,3}\b", r["Target"])
                    ok = placeholders.get(x) in rowids
                res.check("C09i-reference-resolves:%s:%s:%s" % (t, field, x), ok, "")

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


def encode(rec):
    return "\n".join("%s = %s" % (p, rec[p]) for p in sorted(rec))


def decode(text):
    out = {}
    for line in text.split("\n"):
        if line:
            k, v = line.split(" = ", 1)
            out[k] = v
    return out


CODEC = {"decode": decode}


def lossy_decode(text):
    out = decode(text)
    out.pop("commits", None)
    return out


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

    def control(cid, description, mutate_text=None, codec=None):
        t = mutate_text(text) if mutate_text else text
        if t == text and not codec:
            controls.append({"id": cid, "description": description, "noticed": False, "new_failures": ["mutation did not apply"]})
            return
        if codec:
            CODEC["decode"] = codec
        try:
            r, _ = check_all(t, src, root)
        finally:
            CODEC["decode"] = decode
        new = sorted(r.failures() - base)
        controls.append({"id": cid, "description": description, "noticed": bool(new), "new_failures": [a for a, _ in new][:10]})

    control(
        "NC-1",
        "row N-021 removed from the row map, leaving AbilityDefinition added by no row",
        lambda s: s.replace("| N-021 | schema | SC-02 | `AbilityDefinition` | none |\n", ""),
    )
    control(
        "NC-2",
        "AttackDefinition given a JSON projection naming a field absent from HF-07a's CSV",
        lambda s: s.replace(
            "| `AttackDefinition` | F-02, N-020 | immutable-by-id | definition-by-id | tres | none | none |",
            "| `AttackDefinition` | F-02, N-020 | json-projection | projection | tres | run.checkpoint.attack_ids | TH-22 |",
        ),
    )
    control(
        "NC-3",
        "unset parameter SP-26 given a number with no source line",
        lambda s: s.replace("| SP-26 | Miscast frequency | unset |", "| SP-26 | Miscast frequency | 3 |"),
    )
    control("NC-4", "documentary codec that drops the commits reference on decode", codec=lossy_decode)
    control(
        "NC-5",
        "trace step AM.3 uses E08, whose from-state contradicts the step",
        lambda s: s.replace("| AM.3 | candidate B | E09 |", "| AM.3 | candidate B | E08 |"),
    )

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
    manifest = {p: sha256(root / p) for p in [CONTRACT, HF06A_CSV, HF06B_CSV, HF07A_CSV, HF05, BACKLOG]}
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
