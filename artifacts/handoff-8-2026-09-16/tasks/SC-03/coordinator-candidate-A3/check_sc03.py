#!/usr/bin/env python3
"""Paper check for docs/tech/schemas/SC-03.md against its admitted sources.

Usage: python3 check_sc03.py <repository-root> --out <directory>
Exit 0 when every check passes and every negative control fails, 1 otherwise.
"""

import argparse
import csv
import hashlib
import json
import re
import sys
from pathlib import Path

SECTION = "docs/tech/schemas/SC-03.md"
HF06A_CSV = "docs/tech/sections/HF-06a-schema-inventory.csv"
HF06B_CSV = "docs/tech/sections/HF-06b-persistence-projection.csv"
HF07A_CSV = "docs/tech/sections/HF-07a-save-envelope.csv"
HF05_MD = "docs/tech/sections/HF-05-content-admission.md"

HEADINGS = [
    "Sources",
    "Contract",
    "Scenarios",
    "Unresolved questions",
    "Re-verification triggers",
    "Procedure performed",
    "Evidence limits",
]
QUESTION = re.compile(r"\bQ-[PE]\d{2}\b")
SP_ID = re.compile(r"\bSP-\d{2}\b")
ROW_ID = re.compile(r"^[FN]-\d{2,3}$")
HF05_CODES = {"missing_id", "missing_revision", "wrong_family", "incompatible_revision", "ambiguous_revision"}
GATE_EDGES = {"structural": ("E08", "E11"), "semantic": ("E09", "E12"), "manifest": ("E09", "E12")}
TRACE_END = {"AV": ("admitted", "no diagnostic"), "AM": ("draft", "missing_id"), "AI": ("draft", "ContentAdmissionFailure")}
TRACE_REPLACEMENT = {"AM": "E12", "AI": "E11"}


def strip_code(cell):
    return cell.strip().strip("`").strip()


def split_row(line):
    return [c.strip() for c in line.strip().strip("|").split("|")]


def parse_tables(lines, start):
    """Return the first Markdown table at or after `start`, stopping at a heading."""
    rows = []
    header = None
    for line in lines[start:]:
        if line.startswith("#"):
            break
        if line.startswith("|"):
            cells = split_row(line)
            if header is None:
                header = cells
            elif set("".join(cells)) <= set("-: "):
                continue
            else:
                rows.append(dict(zip(header, cells)))
        elif header is not None and line.strip():
            break
    return rows


def heading_index(lines, text):
    for index, line in enumerate(lines):
        if re.match(r"^#{2,4}\s", line) and line.lstrip("#").strip() == text:
            return index
    return None


def table_under(lines, text):
    index = heading_index(lines, text)
    if index is None:
        return None
    return parse_tables(lines, index + 1)


def normalize_path(path):
    return re.sub(r"\[[^\]]*\]", "[]", path)


class Result:
    def __init__(self):
        self.checks = {}

    def check(self, name, ok, detail=""):
        entry = self.checks.setdefault(name, {"passed": 0, "failed": 0, "failures": []})
        if ok:
            entry["passed"] += 1
        else:
            entry["failed"] += 1
            entry["failures"].append(detail)

    def failed(self):
        return sum(entry["failed"] for entry in self.checks.values())

    def passed(self):
        return sum(entry["passed"] for entry in self.checks.values())


def load_sources(root):
    with open(root / HF06A_CSV, newline="", encoding="utf-8") as handle:
        hf06a = {row["row_id"]: row for row in csv.DictReader(handle)}
    with open(root / HF06B_CSV, newline="", encoding="utf-8") as handle:
        hf06b = {row["row_id"]: row for row in csv.DictReader(handle)}
    with open(root / HF07A_CSV, newline="", encoding="utf-8") as handle:
        hf07a = {}
        for line_number, row in enumerate(csv.DictReader(handle), start=2):
            row["line"] = line_number
            hf07a[row["field"]] = row
    edges = {}
    for line in (root / HF05_MD).read_text(encoding="utf-8").splitlines():
        match = re.match(r"^\|\s*(E\d{2})\s*\|\s*([a-z -]+?)\s*\|\s*([a-z -]+?)\s*\|", line)
        if match:
            edges[match.group(1)] = (match.group(2), match.group(3))
    return hf06a, hf06b, hf07a, edges


def illustrative_records(lines, types):
    records = {}
    for type_name in types:
        index = heading_index(lines, "Illustrative record: " + type_name)
        if index is None:
            records[type_name] = None
            continue
        first = next((line for line in lines[index + 1:] if line.strip()), "")
        rows = parse_tables(lines, index + 1)
        records[type_name] = {
            "labelled": first.startswith("**Illustrative, not canon.**"),
            "fields": {strip_code(row["Field path"]): strip_code(row["Illustrative value"]) for row in rows},
        }
    return records


def list_value(value):
    if value.startswith("[") and value.endswith("]"):
        inner = value[1:-1].strip()
        return [item.strip() for item in inner.split(",")] if inner else []
    return None


def run_checks(text, root, sources):
    hf06a, hf06b, hf07a, edges = sources
    lines = text.splitlines()
    result = Result()

    level_two = [line[3:].strip() for line in lines if line.startswith("## ")]
    result.check("C01 seven headings in order", level_two == HEADINGS, str(level_two))

    type_rows = table_under(lines, "Types and matrix rows") or []
    types = {row["Type"]: row for row in type_rows}
    own_rows = {row_id for row_id, row in hf06a.items() if row["producing_card"] == "SC-03"}
    mapped = {}
    for type_name, row in types.items():
        rows = [r.strip() for r in row["HF-06a rows"].split(";") if r.strip()]
        result.check("C02 every type has an HF-06a row", bool(rows), type_name)
        for row_id in rows:
            mapped.setdefault(row_id, []).append(type_name)
            known = row_id in hf06a
            result.check("C02 type rows exist in HF-06a", known, row_id)
            if known:
                result.check("C02 type rows are SC-03 rows", hf06a[row_id]["producing_card"] == "SC-03", row_id)
                result.check("C02 treatment equals HF-06a", hf06a[row_id]["treatment"] == row["Treatment"], row_id)
    for row_id in sorted(own_rows):
        result.check("C02 each SC-03 row maps to exactly one type", len(mapped.get(row_id, [])) == 1, row_id + " -> " + str(mapped.get(row_id)))
    for type_name, row in types.items():
        if row["Treatment"] == "embedded-record":
            result.check("C02 embedded record names a parent type", row["Parent"] in types, type_name)

    field_tables = {}
    for type_name in types:
        rows = table_under(lines, "Fields: " + type_name)
        result.check("C03 field table present", bool(rows), type_name)
        field_tables[type_name] = rows or []
        for row in rows or []:
            for column in ("Field", "Type", "Required", "Reference target", "Value at this revision", "Rule"):
                result.check("C03 field row complete", bool(row.get(column, "").strip()), type_name + " " + row.get("Field", "?") + " " + column)

    iv_rows = table_under(lines, "Identity and version rules") or []
    dg_rows = table_under(lines, "Validation diagnostics") or []
    for type_name in types:
        result.check("C04 identity or version rule names the type", any(type_name in row["Types"] for row in iv_rows), type_name)
        result.check("C05 diagnostic names the type", any(type_name in row["Types"] for row in dg_rows), type_name)
    for row in dg_rows:
        gate = row["Gate"]
        expected = GATE_EDGES.get(gate)
        result.check("C05 diagnostic gate known", expected is not None, row["ID"])
        if expected:
            result.check("C05 diagnostic edges match gate", (row["Initial edge"], row["Replacement edge"]) == expected, row["ID"])
        diagnostic = row["Diagnostic"]
        if "ContentReferenceFailure" in diagnostic:
            codes = set(re.findall(r"`([a-z_]+)`", diagnostic)) & HF05_CODES
            result.check("C05 reference failure uses an HF-05 code", bool(codes), row["ID"])
        else:
            result.check("C05 admission failure names a rule", "ContentAdmissionFailure" in diagnostic and "rule" in diagnostic, row["ID"])

    records = illustrative_records(lines, types)
    illustrative_headings = [line for line in lines if line.startswith("#### Illustrative record: ")]
    for type_name in types:
        record = records[type_name]
        result.check("C06 one illustrative record per type", record is not None and illustrative_headings.count("#### Illustrative record: " + type_name) == 1, type_name)
        if record:
            result.check("C06 illustrative record labelled", record["labelled"], type_name)
            for value in record["fields"].values():
                for symbol in re.findall(r"<symbolic:([^>]*)>", value):
                    result.check("C06 symbolic illustrative value names a question", bool(QUESTION.search(symbol)), type_name + " " + value)

    foreign_rows = table_under(lines, "Foreign references") or []
    for row in foreign_rows:
        row_id = row["Row"]
        known = row_id in hf06a
        result.check("C07 foreign reference row exists", known, row_id)
        if known:
            result.check("C07 foreign producing card equals HF-06a", hf06a[row_id]["producing_card"] == row["Producing card"], row_id)
            result.check("C07 foreign row is not this card's", hf06a[row_id]["producing_card"] != "SC-03", row_id)
    for type_name, rows in field_tables.items():
        for row in rows:
            target = row["Reference target"]
            if target == "none":
                ok = True
            elif target in types:
                ok = True
            elif ROW_ID.match(target):
                ok = target in hf06a and hf06a[target]["producing_card"] != "SC-03" and any(f["Row"] == target for f in foreign_rows)
            else:
                ok = False
            result.check("C07 reference target is a type here or a foreign HF-06a row", ok, type_name + " " + row["Field"] + " -> " + target)

    type_names = set(types)
    for type_name, rows in field_tables.items():
        for row in rows:
            target = row["Reference target"]
            tokens = [t for t in re.split(r"[;,/]|\bor\b|\band\b", target) if t.strip()]
            named = [t.strip() for t in tokens if t.strip() == "none" or t.strip() in type_names or ROW_ID.match(t.strip())]
            result.check("C14 reference target names exactly one family", len(tokens) == 1 and len(named) == 1, type_name + " " + row["Field"] + " -> " + target)

    item_fields = {strip_code(row["Field"]): row for row in field_tables.get("ItemDefinition", [])}
    replacement_fields = {name: row for name, row in item_fields.items() if name.startswith("replacements[].")}
    result.check("C15 no generic action replacement field", not any(name.endswith("_action_id") for name in replacement_fields), str(sorted(replacement_fields)))
    kinds = {"attack": "F-02", "ability": "N-021"}
    for kind, row_id in kinds.items():
        for role in ("replaces", "provides"):
            name = "replacements[]." + role + "_" + kind + "_id"
            row = replacement_fields.get(name)
            result.check("C15 replacement field present per kind and role", row is not None, name)
            if row is not None:
                result.check("C15 attack replacement targets F-02 and mobility replacement targets N-021", row["Reference target"] == row_id, name + " -> " + row["Reference target"])
    for name in replacement_fields:
        result.check("C15 every replacement field is an attack or ability field", re.match(r"^replacements\[\]\.(replaces|provides)_(attack|ability)_id$", name) is not None, name)
    foreign_n021 = [f for f in foreign_rows if f["Row"] == "N-021"]
    result.check("C15 N-021 in the foreign-reference table with its producing card", bool(foreign_n021) and foreign_n021[0]["Producing card"] == hf06a.get("N-021", {}).get("producing_card"), "")
    item_record = (records.get("ItemDefinition") or {"fields": {}})["fields"]
    indexes = sorted({m.group(1) for k in item_record for m in [re.match(r"replacements\[(\d+)\]\.", k)] if m})
    result.check("C15 illustrative item exercises a replacement", bool(indexes), "")
    for index in indexes:
        def value(field):
            return item_record.get("replacements[" + index + "]." + field, "").strip('"')
        replaced = [kind for kind in kinds if value("replaces_" + kind + "_id")]
        result.check("C15 illustrative replacement names exactly one replaced kind", len(replaced) == 1, index + " " + str(replaced))
        if len(replaced) == 1:
            other = [k for k in kinds if k != replaced[0]][0]
            ok = bool(value("provides_" + replaced[0] + "_id")) and not value("provides_" + other + "_id")
            result.check("C15 illustrative replacement provides its own kind only", ok, index)
    result.check("C16 replacement-kind diagnostic present", any("sc03.replacement_kind" in row["Diagnostic"] and row["Gate"] == "structural" for row in dg_rows), "")

    sp15 = [row for row in (table_under(lines, "Tunable parameters") or []) if row["ID"] == "SP-15"]
    result.check("C17 SP-15 present", len(sp15) == 1, "")
    if sp15:
        value, source = sp15[0]["Value at this revision"], sp15[0]["Source line or question"]
        result.check("C17 instance-field value types are unset under Q-P14", value.startswith("unset") and "Q-P14" in source, value)
        result.check("C17 HF-07a line 46 stays cited as a constraint", "HF-07a line 46" in source, source)
        result.check("C17 the proposal is labelled a proposal", "proposal" in value, value)
    gate = [row for row in dg_rows if "sc03.instance_field_types_unset" in row["Diagnostic"]]
    result.check("C17 admission refuses instance fields while the value set is unset", len(gate) == 1 and gate[0]["Gate"] == "semantic" and (gate[0]["Initial edge"], gate[0]["Replacement edge"]) == ("E09", "E12") and "Q-P14" in gate[0]["Source"], str(gate))
    value_type_rows = [row for row in field_tables.get("ItemDefinition", []) if strip_code(row["Field"]) == "instance_fields[].value_type"]
    result.check("C17 value_type field is not a closed set", len(value_type_rows) == 1 and "closed set" not in value_type_rows[0]["Type"], "")
    item_illustrative = (records.get("ItemDefinition") or {"fields": {}})["fields"]
    result.check("C17 illustrative item declares no instance field while the set is unset", item_illustrative.get("instance_fields") == "[]" and not any(k.startswith("instance_fields[") for k in item_illustrative), "")
    result.check("C17 JSON fragment carries no instance field value", '"instance_fields": {}' in text and "placeholder_state" not in text, "")

    stale = {
        "A10 no durable trace wording": "leaves no durable trace",
        "A10 eleven-field claim without the list": "HF-05's eleven fields",
        "A11 version sourced to the save envelope": "HF-09 line 376",
        "A11 noun-row pairing sourced to HF-06a line 22": "`ItemDefinition` from two directions",
        "A12 foreign cards name nothing here": "the foreign card names nothing here",
        "A12 cross-kind needs a new field": "A new cross-kind replacement field",
        "stale sibling status": "being revised concurrently",
        "stale sibling status after first attempt": "admitted after the first attempt",
    }
    for name, phrase in stale.items():
        result.check("C18 repaired wording: " + name, phrase not in text, phrase)
    required = [
        "Material is consumed as collected; milestone unlocks and the rebuilt chassis are its durable trace. No material balance is stored on the item",
        "`code`, `operation`, `requested_id`, `expected_family`, `requested_content_revision`, `catalogue_revision`, `referrer`, `candidate_identity`, `available_revision`, `held_operation` and `message_key`",
        "N-015 and N-025 share this item type because HF-07a CSV rows 28 and 30 and HF-06b line 224 place them in the same item-instance projection; TH-20 records this pairing.",
        "Definition schema version 1 is this card's initial supported representation under HF-05 line 50, not the save-envelope version.",
        "References in this table are outbound; inbound references are declared by their owning cards.",
        "A Q-P22 answer allowing cross-kind replacement requires review of RP-02 and DG-19; the existing separately typed fields can represent the pair. This contract does not currently permit it.",
        "This contract's present choice",
        "integrated-read-R1.md",
    ]
    for phrase in required:
        result.check("C18 required repair wording present", phrase in text, phrase[:60])
    for row in foreign_rows:
        result.check("C18 foreign row status is the closure-target wording", row["State at this base"].startswith("admitted at the Handoff-8 closure target"), row["Row"])

    save_rows = table_under(lines, "Save treatment") or []
    save_by_type = {row["Type"]: row for row in save_rows}
    for type_name, type_row in types.items():
        row = save_by_type.get(type_name)
        result.check("C08 save treatment row per type", row is not None, type_name)
        if row is None:
            continue
        rows = [r.strip() for r in row["HF-06b rows"].split(";")]
        result.check("C08 save rows equal type rows", rows == [r.strip() for r in type_row["HF-06b rows"].split(";")], type_name)
        groups = set()
        for row_id in rows:
            source = hf06b.get(row_id)
            result.check("C08 HF-06b row exists", source is not None, row_id)
            if not source:
                continue
            result.check("C08 save column equals HF-06b", source["save_column"] == row["Save column"], row_id)
            result.check("C08 case equals HF-06b", source["rationale_case"] == row["Case"], row_id)
            result.check("C08 codec equals HF-06b", source["authoring_codec"] == row["Authoring codec"], row_id)
            if source["save_projection"] != "none":
                groups.update(g.strip() for g in source["save_projection"].split(";"))
        fields = [strip_code(f) for f in row["Projection fields"].split(";") if f.strip()]
        if row["Save column"] == "json-projection":
            result.check("C08 projection has fields", fields and fields != ["none"], type_name)
            covered = set()
            for field in fields:
                source = hf07a.get(field)
                result.check("C08 projection field is an HF-07a CSV field", source is not None, field)
                if source:
                    in_group = source["projection_group"] in groups
                    result.check("C08 projection field group belongs to the type's rows", in_group, field + " " + source["projection_group"])
                    covered.add(source["projection_group"])
            for group in groups:
                result.check("C08 every row group has a projection field", group in covered, type_name + " " + group)
        else:
            result.check("C08 exclusion has no projection field", fields == ["none"], type_name)
            result.check("C08 exclusion states an immutable or transient rationale", bool(re.search(r"(?i)immutable|transient", row["Rationale"])), type_name)
    supply_index = heading_index(lines, "Save treatment")
    if supply_index is not None:
        tables_seen = 0
        for index in range(supply_index + 1, len(lines)):
            if lines[index].startswith("#"):
                break
            if lines[index].startswith("| Field | HF-07a CSV row"):
                for row in parse_tables(lines, index):
                    paths = [strip_code(p) for p in row["Field"].split(",")]
                    numbers = [int(n) for n in re.findall(r"\d+", row["HF-07a CSV row"])]
                    base = paths[0].rsplit(".", 1)[0] if len(paths) > 1 else ""
                    full = [paths[0]] + [base + "." + p if "." not in p else p for p in paths[1:]]
                    for path, number in zip(full, numbers):
                        source = hf07a.get(path)
                        result.check("C08 supplied field row number equals HF-07a CSV line", source is not None and source["line"] == number, path + " " + str(number))
                tables_seen += 1
        result.check("C08 supplied-field table present", tables_seen == 1, str(tables_seen))

    trace_rows = table_under(lines, "Admission traces") or []
    for prefix, (end_state, diagnostic) in TRACE_END.items():
        steps = [row for row in trace_rows if row["Step"].startswith(prefix + ".")]
        result.check("C09 trace present", bool(steps), prefix)
        if not steps:
            continue
        result.check("C09 trace starts at draft", steps[0]["From"] == "draft", prefix)
        previous = None
        for step in steps:
            edge = edges.get(step["Edge"])
            result.check("C09 step edge matches HF-05", edge == (step["From"], step["To"]), step["Step"] + " " + str(edge))
            if previous is not None:
                result.check("C09 steps chain", previous == step["From"], step["Step"])
            previous = step["To"]
        result.check("C09 trace ends at named state", previous == end_state, prefix + " " + str(previous))
        result.check("C09 trace names its outcome diagnostic", diagnostic in steps[-1]["Result and diagnostic"], prefix)
        if prefix in TRACE_REPLACEMENT:
            result.check("C09 failing trace names its replacement edge", TRACE_REPLACEMENT[prefix] in steps[-1]["Result and diagnostic"], prefix)
            cited = re.findall(r"DG-\d{2}", steps[-1]["Result and diagnostic"])
            dg = {row["ID"]: row for row in dg_rows}
            ok = bool(cited) and all(c in dg and step["Edge"] == dg[c]["Initial edge"] for c in cited)
            result.check("C09 failing trace edge equals its diagnostic's initial edge", ok, prefix + " " + str(cited))

    for type_name, record in records.items():
        if not record:
            continue
        fields = record["fields"]
        decoded = json.loads(json.dumps(fields, sort_keys=True))
        result.check("C10 illustrative encode and decode preserves every field", decoded == fields, type_name)
        illustrative_paths = [normalize_path(path) for path in fields]
        for row in field_tables.get(type_name, []):
            field = strip_code(row["Field"])
            covered = any(p == field or field.startswith((p + ".", p + "[]")) or p.startswith((field + ".", field + "[]")) for p in illustrative_paths)
            result.check("C10 every field appears in the illustrative record", covered, type_name + " " + field)
            if row["Reference target"] != "none":
                for path, value in fields.items():
                    if normalize_path(path) != field:
                        continue
                    values = list_value(value)
                    values = values if values is not None else [value]
                    target = row["Reference target"]
                    embedded = target in types and types[target]["Treatment"] == "embedded-record"
                    for item in values:
                        if item in ("", '""'):
                            continue
                        if embedded and list_value(value) is None:
                            ok = target in item and bool(records.get(target))
                        elif embedded:
                            ok = item in (records.get(target) or {"fields": {}})["fields"].values()
                        else:
                            ok = item.startswith("placeholder")
                        result.check("C10 illustrative reference is a placeholder or an embedded record and survives decode", ok and item in json.dumps(decoded), type_name + " " + path + " " + item)

    json_index = heading_index(lines, "Paper round-trip expectations")
    fragment = None
    if json_index is not None:
        block = []
        inside = False
        for line in lines[json_index:]:
            if line.startswith("#") and block:
                break
            if line.strip() == "```json":
                inside = True
                continue
            if inside and line.strip() == "```":
                break
            if inside:
                block.append(line)
        try:
            fragment = json.loads("\n".join(block))
        except ValueError as error:
            result.check("C11 JSON fragment parses", False, str(error))
    result.check("C11 JSON fragment present", fragment is not None, "")
    if fragment is not None:
        result.check("C11 JSON encode and decode is identical", json.loads(json.dumps(fragment)) == fragment, "")
        leaves = []

        def walk(node, path):
            if isinstance(node, dict):
                for key, value in node.items():
                    child = path + "." + key if path else key
                    if path.endswith(".instance_fields"):
                        leaves.append((path, value))
                        continue
                    walk(value, child)
            elif isinstance(node, list):
                if not node or not isinstance(node[0], (dict, list)):
                    leaves.append((path, node))
                for item in node:
                    if isinstance(item, (dict, list)):
                        walk(item, path + "[]")
            else:
                leaves.append((path, node))

        walk(fragment, "")
        for path, value in leaves:
            result.check("C11 fragment path is an HF-07a CSV field", path in hf07a, path)
            for item in value if isinstance(value, list) else [value]:
                result.check("C11 fragment value is a string", isinstance(item, str), path)
        item_record = records.get("ItemDefinition") or {"fields": {}}
        recipe_record = records.get("RecipeDefinition") or {"fields": {}}
        item_id = item_record["fields"].get("id")
        recipe_id = recipe_record["fields"].get("id")
        instance_keys = {v: item_record["fields"].get(k.replace(".key", ".value_type")) for k, v in item_record["fields"].items() if re.match(r"instance_fields\[\d+\]\.key$", k)}
        checkpoint = fragment["run"]["checkpoint"]
        owned = checkpoint["equipment"]["owned"]
        equipped = checkpoint["equipment"]["equipped"]
        rewards = checkpoint["resolved_rewards"]
        recipes = fragment["profile"]["recipes"]
        result.check("C11 profile.recipes names the illustrative recipe", recipes == [recipe_id], str(recipes))
        result.check("C11 profile.recipes unique and sorted", recipes == sorted(set(recipes)), "")
        for entry in owned:
            result.check("C11 owned item_id names the illustrative item", entry["item_id"] == item_id, entry["item_id"])
            result.check("C11 instance_fields keys equal the declaration", set(entry["instance_fields"]) == set(instance_keys), str(entry["instance_fields"]))
            for key, value in entry["instance_fields"].items():
                expected = {"string": str, "id-string": str, "bool": bool}.get(instance_keys.get(key))
                result.check("C11 instance field value has its declared JSON type", expected is not None and isinstance(value, expected), key)
            result.check("C11 numeric-spelled instance_id stays a string", isinstance(entry["instance_id"], str) and entry["instance_id"] == json.loads(json.dumps(entry["instance_id"])), entry["instance_id"])
        owned_ids = [entry["instance_id"] for entry in owned]
        result.check("C11 owned sorted by instance_id", owned_ids == sorted(owned_ids), "")
        result.check("C11 equipped sorted by mount_id", [e["mount_id"] for e in equipped] == sorted(e["mount_id"] for e in equipped), "")
        for entry in equipped:
            result.check("C11 equipped instance names an owned instance", entry["instance_id"] in owned_ids, entry["instance_id"])
        result.check("C11 resolved_rewards sorted by settlement_id", [r["settlement_id"] for r in rewards] == sorted(r["settlement_id"] for r in rewards), "")
        for reward in rewards:
            result.check("C11 resolved_ids name illustrative definitions", all(i in (item_id, recipe_id) for i in reward["resolved_ids"]), str(reward["resolved_ids"]))
            result.check("C11 settlement instance_ids name owned instances", all(i in owned_ids for i in reward["instance_ids"]), str(reward["instance_ids"]))
        decode_index = None
        for index in range(json_index, len(lines)):
            if lines[index].startswith("| Path | Encoded"):
                decode_index = index
                break
        decode_rows = parse_tables(lines, decode_index) if decode_index is not None else []
        result.check("C11 decode table present", bool(decode_rows), "")
        for row in decode_rows:
            path = strip_code(row["Path"])
            node = fragment
            try:
                for part in re.findall(r"[^.\[\]]+|\[\d+\]", path):
                    node = node[int(part[1:-1])] if part.startswith("[") else node[part]
                ok = json.dumps(node) == strip_code(row["Encoded"])
            except (KeyError, IndexError, TypeError):
                ok = False
            result.check("C11 decode table row matches the fragment", ok, path)

    sp_rows = table_under(lines, "Tunable parameters") or []
    sp_ids = set()
    for row in sp_rows:
        sp_ids.add(row["ID"])
        value = row["Value at this revision"]
        source = row["Source line or question"]
        has_line = bool(re.search(r"line \d+|lines \d+", source))
        has_question = bool(QUESTION.search(source))
        result.check("C12 parameter row carries a source line or a question", has_line or has_question, row["ID"])
        if value.startswith("unset"):
            result.check("C12 unset parameter names a question", has_question, row["ID"])
        if re.search(r"\d", strip_code(value)):
            result.check("C12 numeric parameter value has a source line", has_line, row["ID"])
    for type_name, rows in field_tables.items():
        for row in rows:
            value = row["Value at this revision"]
            names = QUESTION.findall(value) or [s for s in SP_ID.findall(value) if s in sp_ids]
            result.check("C12 field value is symbolic with a question or parameter row", bool(names), type_name + " " + row["Field"] + " " + value)
            bare = re.sub(r"Q-[PE]\d{2}|SP-\d{2}", "", value)
            result.check("C12 field value carries no bare number", not re.search(r"\d", bare), type_name + " " + row["Field"])

    sources_start = heading_index(lines, "Sources")
    contract_start = heading_index(lines, "Contract")
    stated = 0
    if sources_start is not None and contract_start is not None:
        for line in lines[sources_start:contract_start]:
            link = None
            for match in re.finditer(r"\[[^\]]*\]\(([^)]+)\)|SHA256\s+`([0-9a-f]{64})`", line):
                if match.group(1):
                    raw = match.group(1)
                    target = raw.split("#")[0]
                    register_anchor = "#" in raw and target.endswith(("BACKLOG.md", "TRACKING.md"))
                    if target and not register_anchor:
                        link = target
                    continue
                stated += 1
                path = (root / "docs/tech/schemas" / link).resolve() if link else None
                actual = hashlib.sha256(path.read_bytes()).hexdigest() if path and path.exists() else None
                result.check("C13 stated dependency hash matches", actual == match.group(2), str(link))
    result.check("C13 dependency hashes stated", stated > 0, str(stated))
    return result


def replace_once(text, old, new):
    if old not in text:
        raise ValueError("mutation target absent: " + old[:60])
    return text.replace(old, new, 1)


NEGATIVE_CONTROLS = [
    ("NC1 a matrix row loses its type", lambda t: replace_once(t, "| RecipeDefinition | schema | F-08; N-026 | recipe | none | F-08; N-026 |", "| RecipeDefinition | schema | F-08 | recipe | none | F-08; N-026 |"), "C02"),
    ("NC2 a projection field is not in HF-07a", lambda t: replace_once(t, "`run.checkpoint.equipment.owned[].instance_fields`; `run.checkpoint.equipment.equipped`;", "`run.checkpoint.equipment.owned[].attuned`; `run.checkpoint.equipment.equipped`;"), "C08"),
    ("NC3 a reference target is neither a type nor an HF-06a row", lambda t: replace_once(t, "| `region_id` | String, domain ID | yes | F-05 |", "| `region_id` | String, domain ID | yes | F-99 |"), "C07"),
    ("NC4 an illustrative record loses its label", lambda t: replace_once(t, "**Illustrative, not canon.** Placeholder identifiers only; no production recipe", "Placeholder identifiers only; no production recipe"), "C06"),
    ("NC5 a content value becomes a bare number", lambda t: replace_once(t, "| F-05 | unset; Q-P07; Q-P23; Q-P25 |", "| F-05 | 5 |"), "C12"),
    ("NC6 a failing trace takes the wrong edge", lambda t: replace_once(t, "| AM.3 | missing reference | same | semantic | E09 |", "| AM.3 | missing reference | same | semantic | E05 |"), "C09"),
    ("NC7 a decoded equipped instance names no owned instance", lambda t: replace_once(t, '{ "mount_id": "placeholder.mount.a", "instance_id": "0007" }', '{ "mount_id": "placeholder.mount.a", "instance_id": "0008" }'), "C11"),
    ("NC8 the first attempt's F-02-only replacement fields are restored", lambda t: replace_once(t, [l for l in t.splitlines() if l.startswith("| `replacements[].replaces_attack_id`")][0] + "\n" + [l for l in t.splitlines() if l.startswith("| `replacements[].provides_attack_id`")][0] + "\n" + [l for l in t.splitlines() if l.startswith("| `replacements[].replaces_ability_id`")][0] + "\n" + [l for l in t.splitlines() if l.startswith("| `replacements[].provides_ability_id`")][0], "| `replacements[].replaces_action_id` | String, domain ID | yes | F-02 | SP-13 | The base action whose rows the rebuild omits while equipped (TH-08 line 178) |\n| `replacements[].provides_action_id` | String, domain ID | yes | F-02 | SP-13 | The replacing action, shown as a replacement and not an addition (PD-02 line 89) |"), "C15"),
    ("NC9 one replacement field names two families", lambda t: replace_once(t, "| `replacements[].replaces_ability_id` | String, domain ID or empty | yes | N-021 |", "| `replacements[].replaces_ability_id` | String, domain ID or empty | yes | F-02; N-021 |"), "C14"),
    ("NC10 the fixed instance-field value set is restored", lambda t: replace_once(t, [l for l in t.splitlines() if l.startswith("| SP-15 |")][0], "| SP-15 | Instance field value types | `bool`, `string`, `id-string`; no numeric type | HF-07a line 46 | DG-10 |"), "C17"),
    ("NC11 the unset-value-set admission gate is removed", lambda t: replace_once(t, [l for l in t.splitlines() if l.startswith("| DG-20 |")][0] + "\n", ""), "C17"),
    ("NC12 a stale sibling status is restored", lambda t: replace_once(t, "| F-05 | Generation policies | SC-05 | admitted at the Handoff-8 closure target; this section's original attempt did not necessarily inspect those admitted bytes |", "| F-05 | Generation policies | SC-05 | admitted after the first attempt; bytes not cited |"), "C18"),
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    root = Path(args.root).resolve()
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)

    sources = load_sources(root)
    text = (root / SECTION).read_text(encoding="utf-8")
    result = run_checks(text, root, sources)

    controls = []
    for name, mutate, expected_prefix in NEGATIVE_CONTROLS:
        mutated = run_checks(mutate(text), root, sources)
        failing = sorted(k for k, v in mutated.checks.items() if v["failed"])
        caught = any(k.startswith(expected_prefix) for k in failing)
        controls.append({"control": name, "failed_checks": failing, "caught_by_expected_check": caught})

    manifest = {
        path: hashlib.sha256((root / path).read_bytes()).hexdigest()
        for path in [SECTION, HF06A_CSV, HF06B_CSV, HF07A_CSV, HF05_MD]
    }
    ok = result.failed() == 0 and all(c["caught_by_expected_check"] for c in controls)
    report = {
        "section": SECTION,
        "checks": result.checks,
        "assertions_passed": result.passed(),
        "assertions_failed": result.failed(),
        "check_groups": len(result.checks),
        "negative_controls": controls,
        "negative_controls_caught": sum(c["caught_by_expected_check"] for c in controls),
        "verdict": "pass" if ok else "fail",
    }
    (out / "paper-check.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    (out / "source-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    for name, entry in result.checks.items():
        for failure in entry["failures"]:
            print("FAIL", name, "::", failure)
    for control in controls:
        print("NEGATIVE", control["control"], "caught" if control["caught_by_expected_check"] else "NOT CAUGHT", control["failed_checks"])
    print("paper-check", report["verdict"], "assertions passed", result.passed(), "failed", result.failed(), "check groups", len(result.checks), "negative controls caught", report["negative_controls_caught"], "of", len(controls))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
