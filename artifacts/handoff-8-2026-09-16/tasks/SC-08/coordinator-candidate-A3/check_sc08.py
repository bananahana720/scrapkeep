#!/usr/bin/env python3
"""Paper check for docs/tech/schemas/SC-08.md.

usage: check_sc08.py <repository-root> --out <dir> [--contract <path>] [--no-controls]
Exit 0 when every assertion passes on the contract and every negative control
fails on its targeted assertion; 1 otherwise; 2 on an internal error.
"""
import argparse
import copy
import csv
import hashlib
import io
import json
import re
import sys
from pathlib import Path

HEADINGS = ["Sources", "Contract", "Scenarios", "Unresolved questions",
            "Re-verification triggers", "Procedure performed", "Evidence limits"]
TYPES = ["T1", "T2", "T3", "T4", "T5"]
SUBSECTIONS = ["fields", "identity and version", "references", "diagnostics", "illustrative record"]
FIELD_VOCAB_NUMERIC = re.compile(r"\b(int|float|number)\b")
ID_SHAPE = re.compile(r"^[a-z]+\.[a-z0-9]+(_[a-z0-9]+)*$")
WORDS = {w: i for i, w in enumerate(
    "zero one two three four five six seven eight nine ten eleven twelve thirteen "
    "fourteen fifteen sixteen seventeen eighteen nineteen twenty".split())}
ADMISSION_GATE = {"E02": "import", "E03": "structural", "E04": "semantic", "E05": "admission",
                  "E06": "pin", "E08": "structural", "E11": "structural", "E09": "semantic",
                  "E12": "semantic"}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def unlink(s):
    return re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", s)


def untick(s):
    s = s.strip()
    return s[1:-1] if len(s) >= 2 and s.startswith("`") and s.endswith("`") else s


def cells(line):
    return [c.strip() for c in line.strip().strip("|").split("|")]


def tables(lines):
    out, cur = [], None
    for line in lines:
        if line.startswith("|"):
            row = cells(line)
            if all(re.fullmatch(r"-+", c) for c in row):
                continue
            if cur is None:
                cur = {"header": row, "rows": []}
                out.append(cur)
            else:
                cur["rows"].append(row)
        else:
            cur = None
    return out


def block(lines, heading):
    level = len(heading) - len(heading.lstrip("#"))
    try:
        start = lines.index(heading)
    except ValueError:
        return None
    end = len(lines)
    for i in range(start + 1, len(lines)):
        m = re.match(r"^(#+)\s", lines[i])
        if m and len(m.group(1)) <= level:
            end = i
            break
    return lines[start + 1:end]


def value(cell):
    v = untick(cell)
    if v.startswith("[") or v.startswith('"'):
        return json.loads(v)
    return v


class Result:
    def __init__(self):
        self.items = []

    def check(self, aid, desc, ok, detail=""):
        self.items.append({"id": aid, "assertion": desc, "pass": bool(ok), "detail": detail})
        return ok

    def failed_ids(self):
        return sorted({i["id"] for i in self.items if not i["pass"]})


def load_sources(root):
    s = root / "docs/tech/sections"
    src = {}
    with open(s / "HF-06a-schema-inventory.csv", newline="", encoding="utf-8") as f:
        src["hf06a_csv"] = {r["row_id"]: r for r in csv.DictReader(f)}
    md = {}
    src["hf06a_md_lines"] = (s / "HF-06a-schema-inventory.md").read_text(encoding="utf-8").splitlines()
    for line in src["hf06a_md_lines"]:
        if re.match(r"^\| (F-\d\d|N-\d\d\d) \|", line):
            c = cells(line)
            md[c[0]] = {"treatment": c[3], "producing_card": unlink(c[4]), "rationale": unlink(c[6])}
    src["hf06a_md"] = md
    with open(s / "HF-06b-persistence-projection.csv", newline="", encoding="utf-8") as f:
        src["hf06b_csv"] = {r["row_id"]: r for r in csv.DictReader(f)}
    with open(s / "HF-07a-save-envelope.csv", newline="", encoding="utf-8") as f:
        src["hf07a_csv"] = {r["field"]: r for r in csv.DictReader(f)}
    hf05 = (s / "HF-05-content-admission.md").read_text(encoding="utf-8").splitlines()
    edges = {}
    codes = set()
    for line in hf05:
        m = re.match(r"^\| (E\d\d) \| ([a-z -]+?) \| ([a-z -]+?) \|", line)
        if m:
            edges[m.group(1)] = (m.group(2).strip(), m.group(3).strip())
        if line.startswith("| `code` |"):
            codes = set(re.findall(r"`([a-z_]+)`", line.split("|", 2)[2]))
    src["edges"], src["crf_codes"] = edges, codes
    bible = (root / "BIBLE.md").read_text(encoding="utf-8").splitlines()
    g = block(bible, "## 9. Glossary") or []
    names = set()
    for t in tables(g):
        for r in t["rows"]:
            names.add(r[0])
    src["bible_names"] = names
    tracking = (root / "TRACKING.md").read_text(encoding="utf-8")
    src["questions"] = set(re.findall(r"^\| \[(Q-[PE]\d\d)\]\(BACKLOG\.md#q-", tracking, re.M))
    return src


def parse_contract(text):
    lines = text.splitlines()
    c = {"lines": lines, "text": text}
    contract = block(lines, "## Contract") or []
    alloc = block(lines, "### Row allocation") or []
    c["alloc_text"] = "\n".join(alloc)
    t = tables(alloc)
    c["alloc"] = {}
    for r in (t[0]["rows"] if t else []):
        types = re.findall(r"T\d", r[2]) if "exclusion" not in r[2] else []
        phrases = {m.group(1): m.group(2) for m in re.finditer(r"(T\d): `([^`]+)`", r[3])}
        excl = [untick(r[3])] if not phrases else []
        c["alloc"][r[0]] = {"treatment": r[1], "types": types, "phrases": phrases,
                            "exclusion_phrase": excl, "save_column": r[4]}
    m = re.search(r"Each type has one naming phrase: (.+?)\. A type", c["alloc_text"])
    c["naming"] = dict(re.findall(r"(T\d) `([^`]+)`", m.group(1))) if m else {}
    tt = tables(block(lines, "### Types") or [])
    c["types"] = {}
    for r in (tt[0]["rows"] if tt else []):
        c["types"][r[0]] = {"rows": re.findall(r"[FN]-\d+", r[2]), "save_column": r[3],
                            "durable": untick(r[4]), "group": untick(r[5])}
    ft = tables(block(lines, "### Field types") or [])
    c["field_vocab"] = [untick(r[0]) for r in ft[0]["rows"]] if ft else []
    iv = tables(block(lines, "### Identity and version rules") or [])
    c["iv_rows"] = iv[0]["rows"] if iv else []
    c["prefix"] = {}
    for r in c["iv_rows"]:
        if r[0] == "IV-01":
            c["prefix"] = {tp: p for p, tp in re.findall(r"`([a-z]+)` \((T\d)\)", r[1])}
    ef = tables(block(lines, "### Engine form") or [])
    c["ef_rows"] = ef[0]["rows"] if ef else []
    dc = tables(block(lines, "### Common diagnostics") or [])
    c["diag"] = {r[0]: r for r in (dc[0]["rows"] if dc else [])}
    rd = tables(block(lines, "### Restore diagnostic") or [])
    c["restore_diag"] = {r[0]: r for r in (rd[0]["rows"] if rd else [])}
    fr = tables(block(lines, "### Foreign reference resolution") or [])
    c["resolution"] = {r[0]: {"card": r[1], "state": r[2], "type": untick(r[3]), "source": r[4]} for r in (fr[0]["rows"] if fr else [])}
    c["sub"] = {}
    c["fields"], c["records"], c["refs"], c["enums"] = {}, {}, {}, {}
    for tp in TYPES:
        head = [l for l in lines if re.match(rf"^### {tp}: ", l)]
        c["sub"][tp] = {}
        for sub in SUBSECTIONS:
            b = block(lines, f"#### {tp} {sub}")
            c["sub"][tp][sub] = b
        fb = c["sub"][tp]["fields"] or []
        ftab = tables(fb)
        c["fields"][tp] = []
        for r in (ftab[0]["rows"] if ftab else []):
            c["fields"][tp].append({"name": untick(r[0]), "type": r[1], "presence": r[2],
                                    "refs": r[3], "rule": r[4]})
        db = c["sub"][tp]["diagnostics"] or []
        dt = tables(db)
        for r in (dt[0]["rows"] if dt else []):
            c["diag"][r[0]] = r
        rb = c["sub"][tp]["illustrative record"] or []
        rt = tables(rb)
        c["records"][tp] = {"labelled": any("Illustrative, not canon." in l for l in rb),
                            "values": {untick(r[0]): value(r[1]) for r in (rt[0]["rows"] if rt else [])},
                            "raw": {untick(r[0]): r[1] for r in (rt[0]["rows"] if rt else [])}}
        if len(ftab) > 1:
            c["kind_table"] = ftab[1]["rows"]
    stub = block(lines, "### Illustrative catalogue stubs and vocabulary") or []
    st = tables(stub)
    c["stubs"] = {untick(r[0]): {"family": r[1], "kind": untick(r[2])} for r in (st[0]["rows"] if st else [])}
    voc = [l for l in stub if l.startswith("Illustrative reviewed vocabulary:")]
    c["vocab"] = set(re.findall(r"`([^`]+)`", voc[0].split(". ")[0])) if voc else set()
    c["stub_labelled"] = any("Illustrative, not canon." in l for l in stub)
    sv = tables(block(lines, "### Save treatment and paper roundtrip") or [])
    c["save_rows"] = {r[0]: r for r in (sv[0]["rows"] if sv else [])}
    qo = tables(block(lines, "### Executable qualification obligation") or [])
    c["qo_rows"] = qo[0]["rows"] if qo else []
    sp = tables(block(lines, "### Tunable parameters") or [])
    c["sp_rows"] = sp[0]["rows"] if sp else []
    c["seams"] = len(re.findall(r"^\*\*Seam \d+:", text, re.M))
    scen = block(lines, "## Scenarios") or []
    c["walks"] = {}
    for i, l in enumerate(scen):
        m = re.match(r"^### (W[A-Z]): ", l)
        if m:
            wb = block(scen, l) or []
            meta = " ".join(x for x in wb if x and not x.startswith("|"))
            wt = tables(wb)
            c["walks"][m.group(1)] = {"meta": meta, "steps": wt[0]["rows"] if wt else []}
    c["contract_text"] = "\n".join(contract)
    return c


def refs_allowed(field):
    toks = []
    for part in field["refs"].split(";"):
        part = part.strip()
        if re.fullmatch(r"T\d", part):
            toks.append(part)
        elif re.fullmatch(r"HF-06a [FN]-\d+", part):
            toks.append(part)
        elif part != "none":
            toks.append("?" + part)
    return toks


def enum_set(field):
    first = field["rule"].split(". ")[0]
    return re.findall(r"`([a-z_]+)`", first)


def kind_map(c):
    out = {}
    for r in c.get("kind_table", []):
        k = untick(r[0])
        cell = r[2]
        mf = re.match(r"`([a-z_]+)`, (.+)$", cell)
        if not mf:
            out[k] = (None, None, None)
            continue
        field, fam = mf.group(1), mf.group(2)
        m = re.match(r"T1 with `identity_kind` `([a-z_]+)`", fam)
        if m:
            out[k] = (field, "T1", m.group(1))
        else:
            mh = re.match(r"HF-06a [FN]-\d+", fam)
            out[k] = (field, mh.group(0) if mh else None, None)
    return out


def prefixed(vals, prefix):
    return {k: v for k, v in vals.items() if k.startswith(prefix)}


def build_catalogue(c, overrides=None, additions=None):
    cat = {}
    records = []
    for tp in TYPES:
        rec = copy.deepcopy(c["records"][tp]["values"])
        if overrides and tp in overrides:
            rec.update(overrides[tp])
        records.append((tp, rec))
    records += [(tp, copy.deepcopy(rec)) for tp, rec in (additions or [])]
    for tp, rec in records:
        key = rec.get("id", f"<{tp}>")
        while key in cat:
            key += "#duplicate"
        cat[key] = {"family": tp, "values": rec, "stub": False}
    for sid, s in c["stubs"].items():
        vals = {"identity_kind": s["kind"]} if s["kind"] != "none" else {}
        cat[sid] = {"family": s["family"], "values": vals, "stub": True}
    return cat


def validate(c, cat):
    findings = []
    km = kind_map(c)

    def add(diag, gate, did, detail):
        findings.append({"diag": diag, "gate": gate, "definition": did, "detail": detail})

    ids = [e["values"].get("id") for e in cat.values() if not e["stub"]]
    for did, e in cat.items():
        if e["stub"]:
            continue
        tp, vals = e["family"], e["values"]
        declared = {f["name"]: f for f in c["fields"][tp]}
        for name in vals:
            if name not in declared:
                add("DC-05", "structural", did, name)
        rid = vals.get("id")
        if not isinstance(rid, str) or not ID_SHAPE.match(rid) or rid.split(".")[0] != c["prefix"].get(tp):
            add("DC-01", "structural", did, "id")
        if ids.count(rid) > 1:
            add("DC-02", "structural", did, "id")
        for f in declared.values():
            if f["name"] == "id":
                continue
            if f["name"] not in vals:
                add("DC-03", "structural", did, f["name"])
                continue
            v, t = vals[f["name"]], f["type"]
            if t == "enum string":
                allowed = [untick(r[0]) for r in c.get("kind_table", [])] if f["name"] == "subject_kind" else enum_set(f)
                if v not in allowed:
                    add("DC-04", "structural", did, f["name"])
            elif t in ("string", "string or empty"):
                if not isinstance(v, str) or (t == "string" and v == ""):
                    add("DC-03", "structural", did, f["name"])
            elif t in ("id-string", "id-string or empty"):
                if not isinstance(v, str) or (v == "" and t == "id-string") or (v and not ID_SHAPE.match(v)):
                    add("DC-06", "structural", did, f["name"])
            elif t.startswith("array of"):
                if not isinstance(v, list) or not all(isinstance(x, str) for x in v):
                    add("DC-03", "structural", did, f["name"])
                    continue
                if f["presence"] == "required, nonempty" and not v and f["name"] not in ("line_speaker_identity_ids", "line_speaker_character_ids", "line_texts"):
                    add("DC-03", "structural", did, f["name"])
                if t == "array of id-string" and (any(not ID_SHAPE.match(x) for x in v) or len(set(v)) != len(v)):
                    add("DC-06", "structural", did, f["name"])
                if t == "array of id-string or empty" and any(x and not ID_SHAPE.match(x) for x in v):
                    add("DC-06", "structural", did, f["name"])
                if t == "array of string" and any(x == "" for x in v):
                    add("DC-03", "structural", did, f["name"])
            else:
                add("DC-03", "structural", did, f["name"] + " undeclared type " + t)
        if tp == "T2":
            if not vals.get("participant_identity_ids") and not vals.get("participant_character_ids"):
                add("DT2-01", "structural", did, "participant_identity_ids")
            si, sc, lt = vals.get("line_speaker_identity_ids") or [], vals.get("line_speaker_character_ids") or [], vals.get("line_texts") or []
            if not si or not sc or not lt or not (len(si) == len(sc) == len(lt)):
                add("DT2-02", "structural", did, "line_texts")
            elif any(bool(a) == bool(b) for a, b in zip(si, sc)):
                add("DT2-04", "structural", did, "line_speaker_identity_ids")
        if tp == "T3" and vals.get("subject_kind") in km:
            field, fam, _ = km[vals["subject_kind"]]
            must_empty = field is None or vals.get("status_class") in ("prototype", "implemented")
            subjects = {k: v for k, v in vals.items() if k.startswith("subject_") and k.endswith("_id")}
            if any(v for k, v in subjects.items() if k != field) or (must_empty and field and vals.get(field)):
                add("DT3-01", "structural", did, field or "subject")
            if not must_empty and not vals.get(field):
                add("DT3-02", "structural", did, field)
        if tp == "T4" and not any(v for k, v in vals.items() if k.startswith("subject_") and k.endswith("_ids")):
            add("DT4-01", "structural", did, "subject arrays")
        if tp == "T5":
            if vals.get("unlock_kind") in ("option", "expanded_option") and not any(v for k, v in prefixed(vals, "grant_").items()):
                add("DT5-01", "structural", did, "grant arrays")
            if vals.get("unlock_kind") == "challenge" and not vals.get("rule_id"):
                add("DT5-02", "structural", did, "rule_id")
    if any(f["gate"] == "structural" for f in findings):
        return findings
    for did, e in cat.items():
        if e["stub"]:
            continue
        tp, vals = e["family"], e["values"]
        for f in c["fields"][tp]:
            allowed = refs_allowed(f)
            if not allowed or f["name"] == "id":
                continue
            v = vals.get(f["name"])
            members = v if isinstance(v, list) else ([v] if v else [])
            for i, ref in enumerate(members):
                path = f"{f['name']}[{i}]" if isinstance(v, list) else f["name"]
                if ref == "":
                    continue
                if ref not in cat:
                    add("DC-07", "semantic", did, path)
                    continue
                target = cat[ref]["family"]
                if target not in allowed:
                    add("DC-08", "semantic", did, path)
            if "Reviewed behavior identifier" in f["rule"]:
                pass
        for f in c["fields"][tp]:
            if "Reviewed behavior identifier" in f["rule"]:
                v = vals.get(f["name"])
                if v and v not in c["vocab"]:
                    add("DC-09", "semantic", did, f["name"])
        if tp == "T1":
            for ref in vals.get("affiliation_ids", []):
                if ref in cat and cat[ref]["family"] == "T1" and cat[ref]["values"].get("identity_kind") != "organization":
                    add("DT1-01", "semantic", did, "affiliation_ids")
            if cycle(cat, did, "affiliation_ids", "T1"):
                add("DT1-02", "semantic", did, "affiliation_ids")
        if tp == "T2":
            if any(x and x not in vals.get("participant_identity_ids", []) for x in vals.get("line_speaker_identity_ids", [])) or \
                    any(x and x not in vals.get("participant_character_ids", []) for x in vals.get("line_speaker_character_ids", [])):
                add("DT2-03", "semantic", did, "line_speaker_identity_ids")
        if tp == "T3":
            field, fam, kind = km.get(vals.get("subject_kind"), (None, None, None))
            sid = vals.get("subject_identity_id")
            if sid and sid in cat and kind and cat[sid]["values"].get("identity_kind") != kind:
                add("DT3-03", "semantic", did, "subject_identity_id")
            if vals.get("subject_kind") == "companion" and vals.get("status_class") in ("candidate", "established"):
                add("DT3-06", "semantic", did, "subject_kind")
            others = [o for o in cat.values() if not o["stub"] and o["family"] == "T3" and o["values"].get("id") != did]
            mine_subjects = {(k, v) for k, v in vals.items() if k.startswith("subject_") and k.endswith("_id") and v}
            if any(mine_subjects & {(k, v) for k, v in o["values"].items() if k.startswith("subject_") and k.endswith("_id") and v} for o in others):
                add("DT3-04", "semantic", did, "subject")
            mine = {vals.get("canonical_name")} | set(vals.get("short_forms", []))
            for o in others:
                theirs = {o["values"].get("canonical_name")} | set(o["values"].get("short_forms", []))
                if mine & theirs:
                    add("DT3-05", "semantic", did, "canonical_name")
        if tp == "T4":
            def only_exchange(vs):
                ex = vs.get("subject_exchange_ids", [])
                rest = any(v for k, v in vs.items() if k.startswith("subject_") and k.endswith("_ids") and k != "subject_exchange_ids")
                return ex[0] if len(ex) == 1 and not rest else None
            mine = only_exchange(vals)
            if mine and any(k != did and o["family"] == "T4" and not o["stub"] and only_exchange(o["values"]) == mine for k, o in cat.items()):
                add("DT4-02", "semantic", did, "subject_exchange_ids")
        if tp == "T5" and cycle(cat, did, "prerequisite_unlock_ids", "T5"):
            add("DT5-03", "semantic", did, "prerequisite_ids")
    return findings


def cycle(cat, start, field, family):
    stack, seen = list(cat[start]["values"].get(field, [])), set()
    while stack:
        n = stack.pop()
        if n == start:
            return True
        if n in seen or n not in cat or cat[n]["family"] != family:
            continue
        seen.add(n)
        stack.extend(cat[n]["values"].get(field, []))
    return False


def encode_field(f, v, lossy=None):
    t = f["type"]
    if lossy == "drop-empty" and v in ("", []):
        return None
    if t == "enum string":
        if lossy == "enum-ordinal":
            return str(enum_set(f).index(v)) if v in enum_set(f) else "-1"
        return v
    if t.startswith("array of"):
        return "[" + ", ".join(json.dumps(x, ensure_ascii=False) for x in v) + "]"
    return json.dumps(v, ensure_ascii=False)


def decode_field(f, token, kinds):
    t = f["type"]
    if t == "enum string":
        allowed = kinds if f["name"] == "subject_kind" else enum_set(f)
        if not re.fullmatch(r"[a-z_]+", token) or token not in allowed:
            raise ValueError(f"{f['name']}: enum token {token!r}")
        return token
    if t.startswith("array of"):
        v = json.loads(token)
        if not isinstance(v, list) or not all(isinstance(x, str) for x in v):
            raise ValueError(f"{f['name']}: not an array of strings")
        return v
    v = json.loads(token)
    if not isinstance(v, str):
        raise ValueError(f"{f['name']}: not a string")
    if t in ("string", "id-string") and v == "":
        raise ValueError(f"{f['name']}: empty where the type forbids it")
    return v


def resource_text_roundtrip(c, fields, rec, lossy=None):
    kinds = [untick(r[0]) for r in c.get("kind_table", [])]
    lines = []
    for f in fields:
        token = encode_field(f, rec[f["name"]], lossy)
        if token is not None:
            lines.append(f"{f['name']} = {token}")
    text = "\n".join(lines)
    back, errors = {}, []
    for line in text.splitlines():
        k, token = line.split(" = ", 1)
        field = next((f for f in fields if f["name"] == k), None)
        if field is None:
            errors.append(f"undeclared field {k}")
            continue
        try:
            back[k] = decode_field(field, token, kinds)
        except (ValueError, json.JSONDecodeError) as exc:
            errors.append(str(exc))
    declared = [f["name"] for f in fields]
    if sorted(back) != sorted(declared):
        errors.append(f"field set {sorted(back)} != declared {sorted(declared)}")
    for f in fields:
        if f["name"] in back and back[f["name"]] != rec[f["name"]]:
            errors.append(f"{f['name']} changed")
    return text, back, errors


def profile_projection(ids):
    return sorted(set(ids), key=lambda s: s.encode("utf-8"))


def run_checks(root, contract_path, src, fallback=None):
    r = Result()
    text = Path(contract_path).read_text(encoding="utf-8")
    c = parse_contract(text)
    h2 = [l[3:].strip() for l in c["lines"] if l.startswith("## ")]
    r.check("A01", "seven required headings in order", h2 == HEADINGS, h2)

    sc08_rows = sorted(k for k, v in src["hf06a_csv"].items() if v["producing_card"] == "SC-08")
    r.check("A02", "allocation table lists exactly HF-06a's SC-08 rows with their treatments",
            sorted(c["alloc"]) == sc08_rows and all(c["alloc"][k]["treatment"] == src["hf06a_csv"][k]["treatment"] for k in sc08_rows if k in c["alloc"]),
            {"contract": sorted(c["alloc"]), "hf06a": sc08_rows})

    naming_ok = set(c["naming"]) == set(TYPES)
    detail = []
    for row in sc08_rows:
        a = c["alloc"].get(row, {"types": [], "phrases": {}})
        md_rat, csv_rat = src["hf06a_md"][row]["rationale"], src["hf06a_csv"][row]["scope_and_rationale"]
        for tp in TYPES:
            ph = c["naming"].get(tp, "\0")
            in_md, in_csv, alloc = ph in md_rat, ph in csv_rat, tp in a["types"]
            if not (in_md == in_csv == alloc):
                naming_ok = False
                detail.append({"row": row, "type": tp, "md": in_md, "csv": in_csv, "allocated": alloc})
        if src["hf06a_csv"][row]["treatment"] == "excluded" and a["types"]:
            naming_ok = False
            detail.append({"row": row, "excluded_row_has_types": a["types"]})
    carriers = {tp: [k for k in sc08_rows if tp in c["alloc"].get(k, {}).get("types", [])] for tp in TYPES}
    no_orphan = all(carriers[tp] for tp in TYPES)
    stray = [k for k, v in src["hf06a_csv"].items() if k not in sc08_rows and any(p in v["scope_and_rationale"] for p in c["naming"].values())]
    r.check("A03", "each type carries exactly the SC-08 rows whose Markdown and CSV rationale contains its naming phrase; no orphan type; no type on an excluded row",
            naming_ok and no_orphan, {"mismatches": detail, "carriers": carriers})
    r.check("A03b", "no row outside SC-08's list names a type phrase", not stray, stray)

    quoted_ok = True
    for row, a in c["alloc"].items():
        rat = src["hf06a_csv"].get(row, {}).get("scope_and_rationale", "")
        for ph in list(a["phrases"].values()) + a["exclusion_phrase"]:
            if ph not in rat:
                quoted_ok = False
        if a["phrases"] and any(c["naming"].get(tp) != ph for tp, ph in a["phrases"].items()):
            quoted_ok = False
    r.check("A04", "every quoted rationale phrase is a substring of its row's CSV rationale and equals the type's naming phrase", quoted_ok)

    r.check("A05", "types table rows equal the allocation carriers",
            set(c["types"]) == set(TYPES) and all(sorted(c["types"][tp]["rows"]) == sorted(carriers[tp]) for tp in TYPES),
            {tp: c["types"].get(tp, {}).get("rows") for tp in TYPES})

    subs_ok = all(c["sub"][tp][s] is not None for tp in TYPES for s in SUBSECTIONS) and all(c["records"][tp]["labelled"] for tp in TYPES)
    r.check("A06", "every type has fields, identity and version, references, diagnostics and an illustrative record labelled illustrative",
            subs_ok and all(c["fields"][tp] for tp in TYPES), {tp: [s for s in SUBSECTIONS if c["sub"][tp][s] is None] for tp in TYPES})

    ref_detail, types_ok = [], True
    for tp in TYPES:
        for f in c["fields"][tp]:
            if f["type"] not in c["field_vocab"] or FIELD_VOCAB_NUMERIC.search(f["type"]):
                types_ok = False
                ref_detail.append({"type": tp, "field": f["name"], "bad_type": f["type"]})
            for tok in refs_allowed(f):
                if tok.startswith("?"):
                    ref_detail.append({"type": tp, "field": f["name"], "unknown": tok})
                elif tok.startswith("T"):
                    if tok not in TYPES:
                        ref_detail.append({"type": tp, "field": f["name"], "unknown_type": tok})
                else:
                    row = tok.split()[1]
                    h = src["hf06a_csv"].get(row)
                    if not h or h["treatment"] != "schema" or h["producing_card"] == "SC-08":
                        ref_detail.append({"type": tp, "field": f["name"], "bad_foreign_row": row})
            if refs_allowed(f) and "id-string" not in f["type"]:
                ref_detail.append({"type": tp, "field": f["name"], "reference_on_non_id": f["type"]})
    r.check("A07", "field types come from the declared vocabulary with no numeric type, and every reference target is a type here or another card's HF-06a schema row",
            types_ok and not ref_detail, ref_detail)

    used = set()
    for tp in TYPES:
        for f in c["fields"][tp]:
            used |= {tok.split()[1] for tok in refs_allowed(f) if tok.startswith("HF-06a")}
    for row in c.get("kind_table", []):
        m = re.match(r"HF-06a ([FN]-\d+)", row[2])
        if m:
            used.add(m.group(1))
    res_detail = []
    headings_read = set()
    for row in sorted(used):
        res = c["resolution"].get(row)
        h = src["hf06a_csv"].get(row, {})
        if not res:
            res_detail.append({row: "no resolution row"})
            continue
        if res["card"] != h.get("producing_card"):
            res_detail.append({row: "owning card differs from HF-06a", "contract": res["card"], "hf06a": h.get("producing_card")})
        if res["type"].startswith("unresolved"):
            if not re.search(r"SC-\d\d lines? \d+", res["source"]):
                res_detail.append({row: "unresolved row without a source line"})
            continue
        if res["state"].startswith("admitted, TRACKING EV-"):
            m = re.match(r"(SC-\d\d) lines? ([\d, ]+)", res["source"])
            if not m or m.group(1) != res["card"]:
                res_detail.append({row: "admitted resolution without a line in the owning schema"})
            else:
                candidates = [root / "docs/tech/schemas" / f"{m.group(1)}.md"] + ([Path(fallback) / f"{m.group(1)}.md"] if fallback else [])
                path = next((x for x in candidates if x.exists()), None)
                if path is None:
                    res_detail.append({row: "admitted schema file not found; pass --schemas-fallback", "card": m.group(1)})
                    continue
                headings_read.add(str(path))
                lines = path.read_text(encoding="utf-8").splitlines()
                cited = [int(x) for x in re.findall(r"\d+", m.group(2))]
                if not any(0 < n <= len(lines) and res["type"] in lines[n - 1] and lines[n - 1].startswith("###") for n in cited):
                    res_detail.append({row: "resolved type is not a heading at a cited line", "type": res["type"]})
        else:
            m = re.fullmatch(r"HF-06a line (\d+)", res["source"])
            md_lines = src["hf06a_md_lines"]
            if not m or not (0 < int(m.group(1)) <= len(md_lines)) or not md_lines[int(m.group(1)) - 1].startswith(f"| {row} |"):
                res_detail.append({row: "concurrent resolution does not cite the row's HF-06a line"})
    used_types = {c["resolution"][u]["type"] for u in used if u in c["resolution"]}
    extra = sorted(x for x in set(c["resolution"]) - used if c["resolution"][x]["type"] not in used_types and not c["resolution"][x]["type"].startswith("unresolved"))
    if extra:
        res_detail.append({"unused_resolution_rows": extra})
    r.check("A07b", "every referenced foreign row has one resolution row naming its owning card, and each admitted type is a heading at a cited line of that schema",
            not res_detail and bool(used), {"used": sorted(used), "problems": res_detail, "headings_read": sorted(headings_read)})

    save_detail = []
    for tp in TYPES:
        t = c["types"].get(tp)
        if not t:
            save_detail.append({tp: "missing"})
            continue
        for row in t["rows"]:
            b = src["hf06b_csv"].get(row, {})
            if b.get("save_column") != t["save_column"]:
                save_detail.append({tp: row, "hf06b": b.get("save_column"), "contract": t["save_column"]})
            proj = [p.strip() for p in b.get("save_projection", "").split(";")]
            if t["durable"] == "none":
                if proj != ["none"] or t["group"] != "none":
                    save_detail.append({tp: row, "expected_projection_none": proj})
            else:
                field = src["hf07a_csv"].get(t["durable"])
                if not field or field["projection_group"] != t["group"] or t["group"] not in proj:
                    save_detail.append({tp: row, "durable": t["durable"], "group": t["group"], "hf06b": proj})
    for row, a in c["alloc"].items():
        if src["hf06b_csv"].get(row, {}).get("save_column") != a["save_column"]:
            save_detail.append({"allocation_row": row})
    r.check("A08", "save columns and projection groups equal HF-06b, and durable fields exist in HF-07a's CSV with that group", not save_detail, save_detail)

    paths = set(re.findall(r"`((?:profile|run|preferences)\.[a-z_.\[\]0-9]+)`", text))
    missing_paths = sorted(p for p in paths if re.sub(r"\[\d+\]", "", p) not in src["hf07a_csv"])
    r.check("A08b", "every durable field path named anywhere is a row of HF-07a's CSV", not missing_paths, missing_paths)

    diag_detail = []
    edges = src["edges"]
    for did, row in c["diag"].items():
        gate, diag, ie, re_ = row[1], row[3], row[4], row[5]
        if gate == "structural":
            want = ("E08", "E11")
            if "ContentAdmissionFailure" not in diag:
                diag_detail.append({did: "structural must be ContentAdmissionFailure"})
        elif gate == "semantic":
            want = ("E09", "E12")
        else:
            diag_detail.append({did: "gate " + gate})
            continue
        if (ie, re_) != want:
            diag_detail.append({did: [ie, re_], "want": want})
        from_state = "imported" if gate == "structural" else "structurally valid"
        if edges.get(ie) != (from_state, "draft") or edges.get(re_) != (from_state, "rejected-reload"):
            diag_detail.append({did: "HF-05 edge table disagrees", "edges": [edges.get(ie), edges.get(re_)]})
        m = re.search(r"code `([a-z_]+)`", diag)
        if "ContentReferenceFailure" in diag and (not m or m.group(1) not in src["crf_codes"]):
            diag_detail.append({did: "unknown ContentReferenceFailure code"})
    dt_count = len([d for d in c["diag"] if d.startswith("DT")])
    dc_count = len([d for d in c["diag"] if d.startswith("DC")])
    r.check("A09", "each diagnostic pairs its gate with HF-05's failure edges and a valid diagnostic class", not diag_detail and dc_count and dt_count, diag_detail)
    dt402 = c["diag"].get("DT4-02", ["", "", ""])
    r.check("A09b", "DT4-02 is limited to discoveries whose subject_ids is exactly one T2 exchange, and SP-17 leaves other shared subject sets unset",
            "exactly one T2" in dt402[2] and any(row[0] == "SP-17" and row[2].startswith("unset") and "Q-P37" in row[3] and "Q-P14" in row[3] for row in c["sp_rows"]),
            dt402[2])
    dr = c["restore_diag"].get("DR-01")
    r.check("A09c", "the restore failure has its own label DR-01, outside the admission diagnostics, with no admission edge",
            bool(dr) and "DR-01" not in c["diag"] and "`missing_id`" in dr[3] and not re.search(r"\bE\d\d\b", " ".join(dr)), dr)

    rec_detail = []
    for tp in TYPES:
        rec = c["records"][tp]["values"]
        names = [f["name"] for f in c["fields"][tp]]
        if sorted(rec) != sorted(names):
            rec_detail.append({tp: "fields differ", "record": sorted(rec), "table": sorted(names)})
        for f in c["fields"][tp]:
            v = rec.get(f["name"])
            members = v if isinstance(v, list) else [v]
            for x in members:
                if not isinstance(x, str) or x == "":
                    continue
                if f["type"] == "enum string":
                    continue
                if "id-string" in f["type"] or "Reviewed behavior identifier" in f["rule"]:
                    if "illustrative" not in x:
                        rec_detail.append({tp: f["name"], "not_placeholder": x})
                elif "ILLUSTRATIVE" not in x:
                    rec_detail.append({tp: f["name"], "not_placeholder_text": x})
                for name in src["bible_names"]:
                    if re.search(rf"(?<![A-Za-z]){re.escape(name)}(?![A-Za-z])", x):
                        rec_detail.append({tp: f["name"], "bible_name": name})
    for sid in c["stubs"]:
        if "illustrative" not in sid:
            rec_detail.append({"stub": sid})
    if not c["stub_labelled"]:
        rec_detail.append({"stubs": "not labelled illustrative"})
    ticked = set(re.findall(r"`([^`]+)`", c["contract_text"]))
    canon = sorted(t for t in ticked if t in src["bible_names"])
    if canon:
        rec_detail.append({"canon_value_in_contract": canon})
    r.check("A10", "illustrative records match their field tables, use placeholder values and carry no Bible canonical name; no canonical name is a contract value", not rec_detail, rec_detail)

    cat = build_catalogue(c)
    findings = validate(c, cat)
    r.check("A11", "the illustrative catalogue passes the rule model with no finding", not findings, findings)

    walk_detail = []
    for wid, w in c["walks"].items():
        meta, steps = w["meta"], w["steps"]
        mo = re.search(r"Override: `(T\d)` `(\w+)` = `(.+?)`\.", meta)
        mj = re.search(r"Override: `(T\d)` `(\{.+?\})`\.", meta)
        ma = re.search(r"Addition: `(T\d)` `(\{.+?\})`\.", meta)
        mc = re.search(r"Candidate: (initial|replacement)\.", meta)
        if mc:
            overrides = {mo.group(1): {mo.group(2): json.loads(mo.group(3))}} if mo else ({mj.group(1): json.loads(mj.group(2))} if mj else None)
            additions = [(ma.group(1), json.loads(ma.group(2)))] if ma else None
            fnd = validate(c, build_catalogue(c, overrides, additions))
            s_fail = [f for f in fnd if f["gate"] == "structural"]
            m_fail = [f for f in fnd if f["gate"] == "semantic"]
            initial = mc.group(1) == "initial"
            expect = ["E02"]
            if s_fail:
                expect.append("E08" if initial else "E11")
            else:
                expect.append("E03")
                expect.append(("E09" if initial else "E12") if m_fail else "E04")
                if not m_fail:
                    expect += ["E05", "E06"]
            got = [s[1] for s in steps]
            if got != expect:
                walk_detail.append({wid: "edge order", "doc": got, "model": expect})
            state = "draft"
            for s in steps:
                e = edges.get(s[1])
                if not e or e[0] != state:
                    walk_detail.append({wid: "edge does not chain", "step": s[0], "from": state})
                    break
                state = e[1]
                if ADMISSION_GATE.get(s[1]) != s[2]:
                    walk_detail.append({wid: "gate mismatch", "step": s[0]})
            failing = s_fail or m_fail
            last = steps[-1] if steps else ["", "", "", ""]
            if failing:
                named = re.findall(r"\b(D[CT]\d?-\d\d)\b", last[3])
                if not last[3].startswith("fail") or not named or named[0] not in {f["diag"] for f in failing}:
                    walk_detail.append({wid: "diagnostic not produced by model", "doc": named, "model": failing})
                for f in failing:
                    if f["diag"] == named[0] if named else False:
                        if f["diag"] in ("DC-07", "DC-08") and f"`{f['detail']}`" not in last[3]:
                            walk_detail.append({wid: "referrer path missing", "want": f["detail"]})
            elif any(s[3].startswith("fail") for s in steps):
                walk_detail.append({wid: "doc fails where model passes"})
        elif wid == "WK":
            mt = re.search(r"Transition: ([A-Z])\. Settlement-caused: (yes|no)\.", meta)
            order = [s[1] for s in steps]
            if order != ["write", "stage", "validate", "commit", "acknowledge"]:
                walk_detail.append({wid: "stage order", "doc": order})
            if not mt:
                walk_detail.append({wid: "no transition"})
            else:
                tr, settled = mt.group(1), mt.group(2) == "yes"
                allowed = {"B"} if settled else {"A", "C", "D", "S"}
                if tr not in allowed:
                    walk_detail.append({wid: "transition not permitted", "transition": tr})
                if steps and steps[0][2] != "F-PROCESS":
                    walk_detail.append({wid: "write not F-PROCESS"})
                if any(s[2] != f"Transition {tr}" for s in steps[1:]):
                    walk_detail.append({wid: "stage gate names another transition"})
            did = c["records"]["T4"]["values"].get("id")
            committed = profile_projection([])
            staged = profile_projection(committed + [did])
            doc = json.loads(json.dumps({"discoveries": staged}))
            again = profile_projection(doc["discoveries"] + [did])
            if not (set(committed) <= set(staged) and again == staged and doc["discoveries"] == staged):
                walk_detail.append({wid: "set projection does not converge"})
        elif wid == "WS":
            mf = re.search(r"Saved field: `([a-z._]+)`\. Saved value: `(.+?)`\.", meta)
            if not mf or mf.group(1) not in src["hf07a_csv"]:
                walk_detail.append({wid: "saved field not in HF-07a CSV"})
            else:
                field, saved = mf.group(1), json.loads(mf.group(2))
                before = json.dumps(saved)
                unresolved = [i for i, x in enumerate(saved) if x not in cat]
                if [s[1] for s in steps] != ["resolve", "hold"]:
                    walk_detail.append({wid: "step order"})
                if not unresolved:
                    walk_detail.append({wid: "model resolves every saved ID"})
                else:
                    ref = f"`{field}[{unresolved[0]}]`"
                    dr = c["restore_diag"].get("DR-01")
                    if not dr or "`missing_id`" not in dr[3] or "restore" not in dr[3] or "DR-01" not in steps[0][3] or "`missing_id`" not in steps[0][3] or ref not in steps[0][3] or re.search(r"\bDC-\d\d\b", steps[0][3]):
                        walk_detail.append({wid: "restore diagnostic mismatch", "want": ref})
                if json.dumps(saved) != before:
                    walk_detail.append({wid: "held set changed"})
    r.check("A12", "each walk's edge or stage order follows HF-05's edges, HF-07b's stage order and the rule model's first failing gate", not walk_detail and len(c["walks"]) >= 6, walk_detail)

    rt_detail = []
    for tp in TYPES:
        rec = c["records"][tp]["values"]
        fields = c["fields"][tp]
        if any(f["name"] not in rec for f in fields):
            rt_detail.append({tp: "record incomplete"})
            continue
        _, back, errors = resource_text_roundtrip(c, fields, rec)
        if errors:
            rt_detail.append({tp: errors})
            continue
        for f in fields:
            if refs_allowed(f):
                dec_cat = build_catalogue(c, {tp: back})
                members = back[f["name"]] if isinstance(back[f["name"]], list) else ([back[f["name"]]] if back[f["name"]] else [])
                for ref in [m for m in members if m]:
                    if ref not in dec_cat or dec_cat[ref]["family"] not in refs_allowed(f):
                        rt_detail.append({tp: f["name"], "reference no longer resolves to an allowed family": ref})
        if validate(c, build_catalogue(c, {tp: back})):
            rt_detail.append({tp: "decoded catalogue fails the rule model"})
        for lossy in ("drop-empty", "enum-ordinal"):
            _, _, lossy_errors = resource_text_roundtrip(c, fields, rec, lossy)
            has_target = (lossy == "drop-empty" and any(rec[f["name"]] in ("", []) for f in fields)) or (lossy == "enum-ordinal" and any(f["type"] == "enum string" for f in fields))
            if has_target and not lossy_errors:
                rt_detail.append({tp: f"lossy codec control {lossy} was not detected"})
        t = c["types"].get(tp, {})
        if t.get("durable", "none") != "none":
            row = src["hf07a_csv"].get(t["durable"], {})
            key = t["durable"].split(".", 1)[1]
            committed = {"discoveries": [], "recipes": [], "unlocks": []}
            committed[key] = profile_projection([rec["id"], "illustrative.zz_other"])
            encoded = json.dumps(committed[key], ensure_ascii=False)
            decoded = json.loads(encoded)
            ordered = decoded == sorted(set(decoded), key=lambda s: s.encode("utf-8"))
            if row.get("type") != "array of id-string" or not ordered or not all(isinstance(x, str) and x for x in decoded) or rec["id"] not in decoded:
                rt_detail.append({tp: "profile set violates HF-07a's array-of-id-string rule", "field": t["durable"]})
            if profile_projection(decoded + [rec["id"]]) != decoded:
                rt_detail.append({tp: "repeated commit changed the set"})
    r.check("A13", "field-and-reference preservation against the declared field tables; lossy codec controls are detected; profile sets keep HF-07a's array-of-id-string rule", not rt_detail, rt_detail)

    rc_detail = []
    t4 = c["records"]["T4"]["values"]
    rule_controls = [
        ("RC-01", "DC-02", True, None, [("T1", dict(c["records"]["T1"]["values"]))]),
        ("RC-02", "DT4-01", True, {"T4": {"subject_identity_ids": []}}, None),
        ("RC-03", "DT4-02", True, {"T4": {"subject_identity_ids": [], "subject_exchange_ids": ["dialogue.illustrative_exchange"]}},
         [("T4", dict(t4, id="discovery.illustrative_second", subject_identity_ids=[], subject_exchange_ids=["dialogue.illustrative_exchange"]))]),
        ("RC-04", "DT4-02", False, None, [("T4", dict(t4, id="discovery.illustrative_second"))]),
        ("RC-05", "DC-09", True, {"T4": {"creating_fact_id": "illustrative.not_in_vocabulary"}}, None),
        ("RC-06", "DT2-04", True, {"T2": {"line_speaker_character_ids": ["character.illustrative_pilot", "character.illustrative_pilot"]}}, None),
        ("RC-07", "DT3-06", True, {"T3": {"subject_kind": "companion", "subject_identity_id": ""}}, None),
        ("RC-08", "DT3-06", False, {"T3": {"subject_kind": "companion", "status_class": "prototype", "subject_identity_id": ""}}, None),
    ]
    rc_results = []
    for rid, diag, expected, ov, add in rule_controls:
        got = {f["diag"] for f in validate(c, build_catalogue(c, ov, add))}
        ok = (diag in got) == expected
        rc_results.append({"id": rid, "diagnostic": diag, "expected": expected, "produced": sorted(got), "ok": ok})
        if not ok:
            rc_detail.append(rc_results[-1])
    r.check("A17", "rule controls produce DC-02, DT4-01, DT4-02, DC-09, DT2-04 and DT3-06, and DT4-02 and DT3-06 do not fire outside their cases", not rc_detail, rc_results)

    b1 = []
    for tp in TYPES:
        for f in c["fields"][tp]:
            toks = refs_allowed(f)
            if f["refs"].strip() != "none" and len(toks) != 1:
                b1.append({tp: f["name"], "families": f["refs"]})
    common = " ".join(l for l in (block(c["lines"], "### Common diagnostics") or []) if not l.startswith("|"))
    if "one family as `expected_family`" not in common or re.search(r"family set", common):
        b1.append({"common_diagnostics": "expected_family is not stated as one family"})
    r.check("A18", "B1: every reference field names exactly one family, so expected_family is one family (HF-05 line 108)", not b1, b1)

    b5 = []
    for tp in TYPES:
        for f in c["fields"][tp]:
            if "HF-06a F-07" in f["refs"]:
                b5.append({tp: f["name"], "F-07 field": f["refs"]})
    f07 = c["resolution"].get("F-07", {})
    if not f07.get("type", "").startswith("unresolved") or "DT3-06" not in c["diag"] or not re.search(r"^\*\*Seam 8: companion families\.\*\*", text, re.M):
        b5.append({"F-07": "not stated as unresolved with DT3-06 and Seam 8"})
    r.check("A19", "B5: no field references the three-family F-07 row; it is unresolved with a refusing diagnostic and a stated seam", not b5, b5)

    SEEN = "HF-06b permits discovery or unlock knowledge keyed by the exchange ID. This schema currently uses T4 discovery knowledge; TH-20 must confirm that narrowing."
    wording = []
    if text.count(SEEN) < 2:
        wording.append("A16 wording missing from T2 or Seam 6")
    if "Adding, removing, retyping, or changing a reference field's allowed target families changes the supported representation." not in text:
        wording.append("EV-0428 N2 IV-07 wording missing")
    if "SC-04 line 236, `BossDefinition.narrative_identity_id`" not in text:
        wording.append("EV-0428 N6 citation missing")
    if "FR-07 applied AM-H8-001 through AM-H8-004 at accepted identity `93989a43aa93f3c3c8d964646141f95df297ce21` (EV-0437)." not in text:
        wording.append("amendment status wording missing")
    if "AM-H8-001 typed slot definitions within existing row N-024; it did not add a row." not in text:
        wording.append("slot-row wording missing")
    if "Line references use the stated base except the explicitly identified admitted SC-03 and SC-04 references." not in text:
        wording.append("provenance wording missing")
    for stale in ("not yet applied", "may add a slot definition row", "concurrent, not admitted", "Every line reference below is a line at that base", "AM-H8-001 slot row", "are still concurrent"):
        if stale in text:
            wording.append({"stale": stale})
    r.check("A20", "A-class wording from the integrated read is present and the stale seam language is gone", not wording, wording)

    sp_detail = []
    unset = sourced = 0
    for row in c["sp_rows"]:
        val, src_cell = row[2], row[3]
        qids = re.findall(r"Q-[PE]\d\d", src_cell)
        cited = re.search(r"\b(line|lines|row|rows)\s+\d", src_cell)
        if val.startswith("unset"):
            unset += 1
            if not qids:
                sp_detail.append({row[0]: "unset without question"})
        else:
            sourced += 1
            if not cited:
                sp_detail.append({row[0]: "value without source line"})
        if re.search(r"\d", val) and val.startswith("unset"):
            sp_detail.append({row[0]: "digit in unset value"})
    unknown_q = sorted(set(re.findall(r"Q-[PE]\d\d", text)) - src["questions"])
    if unknown_q:
        sp_detail.append({"unknown_questions": unknown_q})
    r.check("A14", "every parameter row carries a source line or a question ID, and every cited question exists in TRACKING", not sp_detail and c["sp_rows"], sp_detail)

    hash_detail, citations = [], 0
    sources = block(c["lines"], "## Sources") or []
    base = root / "docs/tech/schemas"
    bound_by_fallback = []
    for line in sources:
        if not line.startswith("- "):
            continue
        link = None
        for tok in re.finditer(r"\[(?:[^\]]*)\]\(([^)]+)\)|SHA256\s+`([0-9a-f]{64})`", line):
            if tok.group(1):
                target = tok.group(1).split("#")[0]
                if target and not ("#" in tok.group(1) and Path(target).name in ("BACKLOG.md", "TRACKING.md")):
                    link = target
                continue
            citations += 1
            p = (base / link).resolve() if link else None
            if p and not p.exists() and fallback:
                p = (Path(fallback) / link).resolve()
                bound_by_fallback.append(link)
            if not p or not p.exists() or sha(p) != tok.group(2):
                hash_detail.append({"link": link, "stated": tok.group(2)})
    r.check("A15", "every stated dependency hash matches the linked file", not hash_detail and citations > 0, {"citations": citations, "mismatches": hash_detail, "bound_by_fallback": bound_by_fallback})

    counts = re.search(r"Counts for a reviewer: (.+)", text)
    actual = {
        "allocated rows": len(c["alloc"]), "types": len(c["types"]), "common diagnostics": dc_count,
        "type-specific diagnostics": dt_count, "identity and version rules": len(c["iv_rows"]),
        "engine-form rules": len(c["ef_rows"]), "qualification obligations": len(c["qo_rows"]),
        "parameter rows": len(c["sp_rows"]), "with a source value": sourced, "`unset` with a question ID": unset,
        "seams": c["seams"], "walks": len(c["walks"]),
        "foreign resolution rows": len(c["resolution"]), "restore diagnostic": len(c["restore_diag"]),
    }
    stated = {}
    if counts:
        for word, label in re.findall(r"\b([a-z]+) ((?:foreign resolution rows|restore diagnostic|allocated rows|types|common diagnostics|type-specific diagnostics|identity and version rules|engine-form rules|qualification obligations|parameter rows|with a source value|`unset` with a question ID|seams|walks))", counts.group(1)):
            stated[label] = WORDS.get(word)
    r.check("A16", "the stated counts equal the counted tables", stated == actual, {"stated": stated, "actual": actual})
    return r, c


NEGATIVE_CONTROLS = [
    ("NC-01", "drop N-057 from the allocation table", "A02",
     lambda t: re.sub(r"^\| N-057 \|.*\n", "", t, count=1, flags=re.M)),
    ("NC-02", "allocate T4 to N-056, whose rationale does not name it", "A03",
     lambda t: t.replace("| N-056 | schema | T3 |", "| N-056 | schema | T3; T4 |", 1)),
    ("NC-03", "point T5 at a durable field HF-07a's CSV does not carry", "A08",
     lambda t: t.replace("| `profile.unlocks` | `profile.permanent-unlocks` |", "| `profile.unlock_counts` | `profile.permanent-unlocks` |", 1)),
    ("NC-04", "reference a row HF-06a does not have", "A07",
     lambda t: t.replace("| required, may be empty | HF-06a F-05 |", "| required, may be empty | HF-06a F-09 |", 1)),
    ("NC-05", "take the wrong failure edge in walk WM", "A12",
     lambda t: t.replace("| WM.3 | E12 |", "| WM.3 | E11 |", 1)),
    ("NC-06", "put a Bible canonical name in an illustrative record", "A10",
     lambda t: t.replace("| `canonical_name` | `ILLUSTRATIVE NAME` |", "| `canonical_name` | `Moss` |", 1)),
    ("NC-07", "make the valid illustrative unlock declare a discovery kind", "A11",
     lambda t: t.replace("| `unlock_kind` | `option` |", "| `unlock_kind` | `discovery` |", 1)),
    ("NC-08", "drop the question from an unset parameter", "A14",
     lambda t: t.replace("| unset | Q-P28 | T2 |", "| unset | none | T2 |", 1)),
    ("NC-09", "state a wrong dependency hash", "A15",
     lambda t: t.replace("98e19c20d6b0247af5b8b573bf6b5e3c1bdcfb2958dba11def8f834f8d9d01e3", "08e19c20d6b0247af5b8b573bf6b5e3c1bdcfb2958dba11def8f834f8d9d01e3", 1)),
    ("NC-10", "commit a discovery before it is validated", "A12",
     lambda t: t.replace("| WK.3 | validate | Transition A |", "| WK.3 | commit | Transition A |", 1)),
    ("NC-11", "add a numeric field to the permanent unlock", "A07",
     lambda t: t.replace("| `rule_id` | string or empty |", "| `unlock_count` | int | required | none | A count. |\n| `rule_id` | string or empty |", 1)),
    ("NC-12", "commit a level-completion discovery in Transition B", "A12",
     lambda t: t.replace("Transition: A. Settlement-caused: no.", "Transition: B. Settlement-caused: no.", 1)),
    ("NC-13", "widen DT4-02 back to every shared subject set", "A09b",
     lambda t: t.replace("Two discoveries each have exactly one T2 exchange in `subject_exchange_ids` and every other subject array empty, and it is the same exchange", "Two discoveries carry the same set of subject IDs", 1)),
    ("NC-14", "let walk WD pass the semantic gate", "A12",
     lambda t: t.replace("| WD.3 | E09 |", "| WD.3 | E04 |", 1)),
    ("NC-15", "label the restore failure with an admission diagnostic", "A12",
     lambda t: t.replace("| WS.1 | resolve | restore | fail: DR-01", "| WS.1 | resolve | restore | fail: DC-07", 1)),
    ("NC-16", "drop the F-04 resolution row", "A07b",
     lambda t: re.sub(r"^\| F-04 \| SC-04 \|.*\n", "", t, count=1, flags=re.M)),
    ("NC-17", "resolve N-023 to a type SC-04's cited line does not head", "A07b",
     lambda t: t.replace("| `EnemyArchetypeDefinition` | SC-04 lines 94, 423 |", "| `WaveDefinition` | SC-04 lines 94, 423 |", 1)),
    ("NC-18", "B1: give one reference field two families", "A18",
     lambda t: t.replace("| `participant_identity_ids` | array of id-string | required, may be empty | T1 |", "| `participant_identity_ids` | array of id-string | required, may be empty | T1; HF-06a F-01 |", 1)),
    ("NC-19", "B1: put the allowed family set back in expected_family", "A18",
     lambda t: t.replace("the field's one family as `expected_family` (HF-05 line 108), because every reference field names exactly one family,", "the field's allowed family set as `expected_family`,", 1)),
    ("NC-20", "B5: reference the three-family F-07 row from a discovery", "A19",
     lambda t: t.replace("| `subject_device_ids` | array of id-string | required, may be empty | HF-06a F-06 |", "| `subject_companion_part_ids` | array of id-string | required, may be empty | HF-06a F-07 | Companion parts. |\n| `subject_device_ids` | array of id-string | required, may be empty | HF-06a F-06 |", 1)),
    ("NC-21", "A16: drop the seen-state wording from Seam 6", "A20",
     lambda t: t.replace("**Seam 6: seen-state keyed by an exchange.** HF-06b permits discovery or unlock knowledge keyed by the exchange ID. This schema currently uses T4 discovery knowledge; TH-20 must confirm that narrowing.", "**Seam 6: seen-state keyed by an exchange.**", 1)),
    ("NC-22", "restore the pending amendment language", "A20",
     lambda t: t.replace("- FR-07 applied AM-H8-001 through AM-H8-004", "- Accepted amendments not yet applied. FR-07 applied AM-H8-001 through AM-H8-004", 1)),
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root")
    ap.add_argument("--out", required=True)
    ap.add_argument("--contract")
    ap.add_argument("--no-controls", action="store_true")
    ap.add_argument("--schemas-fallback")
    a = ap.parse_args()
    root = Path(a.root).resolve()
    out = Path(a.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    contract = Path(a.contract).resolve() if a.contract else root / "docs/tech/schemas/SC-08.md"
    src = load_sources(root)
    result, _ = run_checks(root, contract, src, a.schemas_fallback)
    report = {
        "contract": str(contract),
        "contract_sha256": sha(contract),
        "inputs": {p: sha(root / p) for p in [
            "docs/tech/sections/HF-06a-schema-inventory.md", "docs/tech/sections/HF-06a-schema-inventory.csv",
            "docs/tech/sections/HF-06b-persistence-projection.csv", "docs/tech/sections/HF-07a-save-envelope.csv",
            "docs/tech/sections/HF-05-content-admission.md", "BIBLE.md", "TRACKING.md"]},
        "assertions": result.items,
        "passed": sum(1 for i in result.items if i["pass"]),
        "failed": sum(1 for i in result.items if not i["pass"]),
    }
    controls = []
    if not a.no_controls:
        neg = out / "negative"
        neg.mkdir(exist_ok=True)
        original = contract.read_text(encoding="utf-8")
        for cid, desc, target, mutate in NEGATIVE_CONTROLS:
            mutated = mutate(original)
            path = neg / f"{cid}.md"
            path.write_text(mutated, encoding="utf-8")
            nr, _ = run_checks(root, path, src, a.schemas_fallback)
            failed = nr.failed_ids()
            controls.append({"id": cid, "mutation": desc, "target": target, "applied": mutated != original,
                             "failed_assertions": failed,
                             "fails_on_target": mutated != original and target in failed})
    report["negative_controls"] = controls
    report["negative_controls_failing_on_target"] = sum(1 for x in controls if x["fails_on_target"])
    ok = report["failed"] == 0 and all(x["fails_on_target"] for x in controls)
    report["verdict"] = "pass" if ok else "fail"
    (out / "paper-check.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"assertions passed {report['passed']} failed {report['failed']}")
    for i in result.items:
        if not i["pass"]:
            print("FAIL", i["id"], i["assertion"], json.dumps(i["detail"], ensure_ascii=False)[:600])
    for x in controls:
        print(x["id"], "fails-on-target" if x["fails_on_target"] else "DID-NOT-FAIL", x["target"], x["failed_assertions"])
    print(f"negative controls {len(controls)} failing on target {report['negative_controls_failing_on_target']}")
    print("verdict", report["verdict"])
    return 0 if ok else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except SystemExit:
        raise
    except Exception as exc:
        print("internal error:", repr(exc), file=sys.stderr)
        sys.exit(2)
