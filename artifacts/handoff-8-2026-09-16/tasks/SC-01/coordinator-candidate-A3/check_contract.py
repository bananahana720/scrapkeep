#!/usr/bin/env python3
"""Paper check for docs/tech/schemas/SC-01.md.

Usage: python3 check_contract.py --root <repository-root> --out <directory>
Writes paper-check.json and source-manifest.json into --out. Exit 0 when every
assertion passes and every negative control fails as intended, 1 otherwise,
2 on an internal error.
"""

import argparse
import copy
import csv
import hashlib
import json
import os
import re
import sys

DOC = "docs/tech/schemas/SC-01.md"
HEADINGS = [
    "Sources",
    "Contract",
    "Scenarios",
    "Unresolved questions",
    "Re-verification triggers",
    "Procedure performed",
    "Evidence limits",
]
TYPE_SUBHEADINGS = ["fields", "identity and version", "references", "diagnostics", "illustrative record"]
ILLUSTRATIVE_LABEL = "Illustrative, not canon."
PLACEHOLDER = re.compile(r"^unset:(Q-[PE]\d\d)(\+Q-[PE]\d\d)*$")
QID = re.compile(r"Q-[PE]\d\d")
ID_GRAMMAR = re.compile(r"^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$")
KEY_GRAMMAR = re.compile(r"^[a-z][a-z0-9_]*$")
TOKENS = {"T1": "character", "T3": "slot", "T4": "tree"}
ROLES = ["weapon", "main_hero_skill", "mobility", "ultimate"]
ACCESS = {"weapon": "run_start", "main_hero_skill": "world_one", "mobility": "run_start", "ultimate": "world_one"}
TARGET_CLASSES = {"player", "device", "companion"}
INITIAL_ONLY_EDGES = {"E08", "E09", "E10"}
REPLACEMENT_ONLY_EDGES = {"E11", "E12", "E13", "E14", "E15"}


def sha256(path):
    with open(path, "rb") as handle:
        return hashlib.sha256(handle.read()).hexdigest()


def read_csv(path):
    with open(path, newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def strip_ticks(text):
    return text.replace("`", "").strip()


class Doc:
    def __init__(self, text):
        self.text = text
        self.lines = text.split("\n")

    def heading_index(self, heading):
        for index, line in enumerate(self.lines):
            if line.strip() == heading:
                return index
        return None

    def block_after(self, heading):
        start = self.heading_index(heading)
        if start is None:
            return None
        end = len(self.lines)
        level = len(heading.split(" ")[0])
        for index in range(start + 1, len(self.lines)):
            match = re.match(r"^(#+) ", self.lines[index])
            if match and not self.in_fence(index) and len(match.group(1)) <= max(level, 4):
                end = index
                break
        return self.lines[start + 1:end]

    def in_fence(self, target):
        fenced = False
        for index in range(target):
            if self.lines[index].startswith("```"):
                fenced = not fenced
        return fenced

    def table(self, heading):
        block = self.block_after(heading)
        if block is None:
            return None
        rows = []
        started = False
        for line in block:
            if line.startswith("|"):
                started = True
                rows.append([cell.strip() for cell in line.strip().strip("|").split("|")])
            elif started:
                break
        if len(rows) < 2:
            return None
        header = rows[0]
        return [dict(zip(header, row)) for row in rows[2:] if len(row) == len(header)], header, rows[2:]

    def json_after(self, heading):
        block = self.block_after(heading)
        if block is None:
            return None, False
        labelled = False
        collecting = False
        body = []
        for line in block:
            if collecting:
                if line.startswith("```"):
                    return json.loads("\n".join(body)), labelled
                body.append(line)
            elif line.startswith("```json"):
                collecting = True
            elif line.startswith(ILLUSTRATIVE_LABEL):
                labelled = True
        return None, labelled

    def level2(self):
        result = []
        fenced = False
        for line in self.lines:
            if line.startswith("```"):
                fenced = not fenced
            if not fenced and re.match(r"^## ", line):
                result.append(line[3:].strip())
        return result


class Report:
    def __init__(self):
        self.results = []

    def check(self, category, name, ok, detail=""):
        self.results.append({"category": category, "name": name, "ok": bool(ok), "detail": detail})

    def failures(self):
        return [result for result in self.results if not result["ok"]]



def is_placeholder(value):
    return isinstance(value, str) and value.startswith("unset:")


def placeholders(value, path=""):
    if is_placeholder(value):
        yield path
    elif isinstance(value, dict):
        for key, child in value.items():
            yield from placeholders(child, f"{path}.{key}" if path else key)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from placeholders(child, f"{path}[{index}]")


def all_strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for child in value.values():
            yield from all_strings(child)
    elif isinstance(value, list):
        for child in value:
            yield from all_strings(child)


def validate(candidate, registered):
    """Return (gate, findings). Findings are (name, location)."""
    structural = []
    definitions = [("T1", d) for d in candidate["characters"]] + [("T3", d) for d in candidate["slots"]] + [("T4", d) for d in candidate["trees"]]

    seen = {}
    for type_id, definition in definitions:
        identifier = definition.get("id")
        if isinstance(identifier, str) and identifier.split(".")[0] == "example":
            structural.append(("reserved_example_id", f"{identifier} id"))
        elif not (isinstance(identifier, str) and ID_GRAMMAR.match(identifier) and identifier.split(".")[0] == TOKENS[type_id]):
            structural.append(("id_grammar", f"{identifier} id"))
        if identifier in seen:
            structural.append(("duplicate_id", f"{identifier} id"))
        seen[identifier] = True
        version = definition.get("schema_version")
        if not (isinstance(version, int) and not isinstance(version, bool) and version == 1):
            structural.append(("schema_version_unsupported", f"{identifier} schema_version"))
        for text in all_strings(definition):
            if text.startswith("unset:"):
                ids = QID.findall(text)
                if not PLACEHOLDER.match(text) or any(q not in registered for q in ids):
                    structural.append(("placeholder_form", f"{identifier}"))

    def need(definition, key, ok, identifier, path=None):
        if key not in definition or not ok(definition[key]):
            structural.append(("field_missing_or_mistyped", f"{identifier} {path or key}"))
            return False
        return True

    ref_ok = lambda v: isinstance(v, str)
    nullable_ref = lambda v: v is None or isinstance(v, str)
    shape = lambda v: v is None or isinstance(v, str)

    for character in candidate["characters"]:
        cid = character.get("id")
        for key in ["culture_ref"]:
            if key in character and not shape(character[key]):
                structural.append(("reference_shape", f"{cid} {key}"))
            elif not need(character, key, nullable_ref, cid):
                pass
        for key in ["visual_refs", "narrative_refs"]:
            if need(character, key, lambda v: isinstance(v, list), cid):
                for index, entry in enumerate(character[key]):
                    if not isinstance(entry, str):
                        structural.append(("reference_shape", f"{cid} {key}[{index}]"))
        need(character, "base_extent", lambda v: v is not None, cid)
        if need(character, "kit", lambda v: isinstance(v, dict) and isinstance(v.get("slots"), list), cid):
            bindings = character["kit"]["slots"]
            if len(bindings) != 4:
                structural.append(("kit_slot_count", f"{cid} kit.slots"))
            for binding in bindings:
                for key in ["slot_ref", "tree_ref", "ability_ref"]:
                    if key not in binding:
                        structural.append(("field_missing_or_mistyped", f"{cid} kit.slots[slot_ref={binding.get('slot_ref')}].{key}"))
                    elif not ref_ok(binding[key]):
                        structural.append(("reference_shape", f"{cid} kit.slots[slot_ref={binding.get('slot_ref')}].{key}"))
            slot_refs = [b.get("slot_ref") for b in bindings]
            tree_refs = [b.get("tree_ref") for b in bindings if not is_placeholder(b.get("tree_ref"))]
            if len(set(slot_refs)) != len(slot_refs):
                structural.append(("kit_slot_duplicate", f"{cid} kit.slots"))
            if len(set(tree_refs)) != len(tree_refs):
                structural.append(("kit_tree_duplicate", f"{cid} kit.slots"))
            if all(isinstance(s, str) for s in slot_refs) and slot_refs != sorted(slot_refs):
                structural.append(("kit_order", f"{cid} kit.slots"))

    for slot in candidate["slots"]:
        sid = slot.get("id")
        need(slot, "role", lambda v: v in ROLES, sid)
        need(slot, "access", lambda v: v in ("run_start", "world_one"), sid)

    for tree in candidate["trees"]:
        tid = tree.get("id")
        if not (need(tree, "nodes", lambda v: isinstance(v, list), tid) and need(tree, "edges", lambda v: isinstance(v, list), tid) and need(tree, "root_key", lambda v: isinstance(v, str), tid)):
            continue
        keys = []
        for node in tree["nodes"]:
            key = node.get("key")
            if not (isinstance(key, str) and KEY_GRAMMAR.match(key)):
                structural.append(("node_key_grammar", f"{tid} nodes[key={key}]"))
            keys.append(key)
            if "effects" not in node or not (isinstance(node["effects"], list) or is_placeholder(node["effects"])):
                structural.append(("field_missing_or_mistyped", f"{tid} nodes[key={key}].effects"))
            elif isinstance(node["effects"], list):
                for index, effect in enumerate(node["effects"]):
                    for field in ["behavior_id", "target_classes", "ability_ref", "attack_ref", "attribute_key"]:
                        if field not in effect:
                            structural.append(("field_missing_or_mistyped", f"{tid} nodes[key={key}].effects[{index}].{field}"))
                    if sum(effect.get(f) is not None for f in ("ability_ref", "attack_ref", "attribute_key")) != 1:
                        structural.append(("effect_modifies_one", f"{tid} nodes[key={key}].effects[{index}]"))
                    classes = effect.get("target_classes")
                    if not (isinstance(classes, list) and classes and len(set(classes)) == len(classes) and all(c in TARGET_CLASSES or is_placeholder(c) for c in classes)):
                        structural.append(("effect_target_class", f"{tid} nodes[key={key}].effects[{index}]"))
                    elif not any(is_placeholder(c) for c in classes):
                        if effect.get("ability_ref") is not None and classes != ["player"]:
                            structural.append(("effect_family_target", f"{tid} nodes[key={key}].effects[{index}]"))
                        if effect.get("attack_ref") is not None and not all(c in ("device", "companion") for c in classes):
                            structural.append(("effect_family_target", f"{tid} nodes[key={key}].effects[{index}]"))
            for field in ["construction_ref", "cost"]:
                if field not in node or node[field] is None:
                    structural.append(("field_missing_or_mistyped", f"{tid} nodes[key={key}].{field}"))
        if len(set(keys)) != len(keys):
            structural.append(("node_key_duplicate", f"{tid} nodes"))
        keyset = set(keys)
        edges = tree["edges"]
        if len(keys) != 15:
            structural.append(("tree_node_count", f"{tid} nodes"))
        if len(edges) != 14:
            structural.append(("tree_edge_count", f"{tid} edges"))
        valid_edges = []
        for index, edge in enumerate(edges):
            if edge.get("parent_key") not in keyset or edge.get("child_key") not in keyset:
                structural.append(("edge_unknown_key", f"{tid} edges[{index}]"))
            else:
                valid_edges.append((edge["parent_key"], edge["child_key"]))
        if tree["root_key"] not in keyset:
            structural.append(("edge_unknown_key", f"{tid} root_key"))
        children = {}
        parents = {}
        for parent, child in valid_edges:
            children.setdefault(parent, []).append(child)
            parents.setdefault(child, []).append(parent)
        roots = [k for k in keys if k not in parents]
        if len(roots) != 1 or roots[0] != tree["root_key"]:
            structural.append(("tree_root", f"{tid} root_key"))
        for key in keys:
            if key in children and len(children[key]) != 2:
                structural.append(("tree_children", f"{tid} nodes[key={key}]"))
        if len([k for k in keys if k not in children]) != 8:
            structural.append(("tree_endpoint_count", f"{tid} nodes"))
        if any(len(p) > 1 for p in parents.values()):
            structural.append(("tree_reconvergence", f"{tid} edges"))
        depth = {}
        root = tree["root_key"]
        frontier = [root] if root in keyset else []
        if frontier:
            depth[root] = 0
        cycle = False
        while frontier:
            node = frontier.pop()
            for child in children.get(node, []):
                if child in depth:
                    cycle = True
                    continue
                depth[child] = depth[node] + 1
                frontier.append(child)
        if cycle and not any(("tree_reconvergence", f"{tid} edges") == f for f in structural):
            structural.append(("tree_reconvergence", f"{tid} edges"))
        if len(depth) != len(keyset):
            structural.append(("tree_connectivity", f"{tid} nodes"))
        endpoints = [k for k in keys if k not in children and k in depth]
        if any(depth[k] != 3 for k in endpoints):
            structural.append(("tree_depth", f"{tid} nodes"))

    if structural:
        return "structural", structural

    semantic = []
    for type_id, definition in definitions:
        for path in placeholders(definition):
            semantic.append(("unresolved_product_value", f"{definition['id']} {path}"))
    families = {d["id"]: "slot" for d in candidate["slots"]}
    families.update({d["id"]: "tree" for d in candidate["trees"]})
    families.update({d["id"]: "character" for d in candidate["characters"]})
    families.update(candidate.get("dependencies", {}))

    def resolve(value, family, referrer, nullable=False):
        if value is None and nullable:
            return
        if is_placeholder(value):
            return
        if value not in families:
            semantic.append(("missing_id", referrer))
        elif families[value] != family:
            semantic.append(("wrong_family", referrer))

    slot_roles = {d["id"]: d["role"] for d in candidate["slots"]}
    bound = {}
    for character in candidate["characters"]:
        cid = character["id"]
        resolve(character["culture_ref"], "N-056", f"{cid} culture_ref", nullable=True)
        for index, value in enumerate(character["visual_refs"]):
            resolve(value, "N-045", f"{cid} visual_refs[{index}]")
        for index, value in enumerate(character["narrative_refs"]):
            resolve(value, "N-012", f"{cid} narrative_refs[{index}]")
        roles = set()
        for binding in character["kit"]["slots"]:
            prefix = f"{cid} kit.slots[slot_ref={binding['slot_ref']}]"
            resolve(binding["slot_ref"], "slot", f"{prefix}.slot_ref")
            resolve(binding["tree_ref"], "tree", f"{prefix}.tree_ref")
            resolve(binding["ability_ref"], "N-021", f"{prefix}.ability_ref")
            if binding["slot_ref"] in slot_roles:
                roles.add(slot_roles[binding["slot_ref"]])
            if not is_placeholder(binding["tree_ref"]):
                bound.setdefault(binding["tree_ref"], []).append(prefix)
        if len(roles) != 4 and all(b["slot_ref"] in slot_roles for b in character["kit"]["slots"]):
            semantic.append(("kit_slot_roles", f"{cid} kit.slots"))
    for tree_ref, prefixes in bound.items():
        if len(prefixes) > 1:
            semantic.append(("tree_bound_twice", f"{tree_ref}"))
    if len(candidate["slots"]) != 4 or sorted(slot_roles.values()) != sorted(ROLES):
        semantic.append(("slot_catalogue_roles", "slots"))
    for slot in candidate["slots"]:
        if ACCESS[slot["role"]] != slot["access"]:
            semantic.append(("slot_access_rule", f"{slot['id']} access"))
    for tree in candidate["trees"]:
        tid = tree["id"]
        for node in tree["nodes"]:
            base = f"{tid} nodes[key={node['key']}]"
            if isinstance(node["effects"], list):
                for index, effect in enumerate(node["effects"]):
                    resolve(effect["ability_ref"], "N-021", f"{base}.effects[{index}].ability_ref", nullable=True)
                    resolve(effect["attack_ref"], "F-02", f"{base}.effects[{index}].attack_ref", nullable=True)
                    if isinstance(effect["target_classes"], list) and any(c in ("device", "companion") for c in effect["target_classes"]):
                        semantic.append(("node_target_unset", f"{base}.effects[{index}].target_classes"))
            resolve(node["construction_ref"], "N-046", f"{base}.construction_ref")
    return ("semantic", semantic) if semantic else ("admitted", [])


def outcome_state(gate, candidate_kind):
    if gate == "admitted":
        return "admitted"
    return "draft" if candidate_kind == "initial" else "rejected-reload"


def validate_saved(save, candidate):
    findings = []
    characters = {d["id"]: d for d in candidate["characters"]}
    slots = {d["id"]: d for d in candidate["slots"]}
    trees = {d["id"]: d for d in candidate["trees"]}
    cid = save["run"]["start"]["character_id"]
    if cid not in characters:
        findings.append(("saved_character", "run.start.character_id"))
        return findings
    bindings = {b["slot_ref"]: b["tree_ref"] for b in characters[cid]["kit"]["slots"]}
    entries = save["run"]["checkpoint"]["build"]["slots"]
    ids = [e["slot_id"] for e in entries]
    if any(i not in slots for i in ids) or len(set(ids)) != len(ids) or ids != sorted(ids):
        findings.append(("saved_slot", "run.checkpoint.build.slots"))
    for entry in entries:
        tree_id = entry["tree_id"]
        keys = entry["node_keys"]
        if tree_id is not None and (tree_id not in trees or bindings.get(entry["slot_id"]) != tree_id):
            findings.append(("saved_tree_binding", f"slot {entry['slot_id']}"))
        if tree_id is None:
            if keys:
                findings.append(("saved_prefix", f"slot {entry['slot_id']}"))
        elif tree_id in trees:
            tree = trees[tree_id]
            parent = {e["child_key"]: e["parent_key"] for e in tree["edges"]}
            ok = len(keys) <= 4 and (not keys or keys[0] == tree["root_key"])
            ok = ok and all(parent.get(keys[i]) == keys[i - 1] for i in range(1, len(keys)))
            if not ok:
                findings.append(("saved_prefix", f"slot {entry['slot_id']}"))
        if not entry["unlocked"] and keys:
            findings.append(("saved_locked_selection", f"slot {entry['slot_id']}"))
        if entry["slot_id"] in slots and slots[entry["slot_id"]]["access"] == "run_start" and not entry["unlocked"]:
            findings.append(("saved_run_start_access", f"slot {entry['slot_id']}"))
    return findings



def resolved_fixture(records):
    t1, t3, t4 = records["T1"], records["T3"], records["T4"]
    slots = []
    for index, role in enumerate(ROLES, start=1):
        slot = copy.deepcopy(t3)
        slot.update({"id": f"slot.s{index}", "role": role, "access": ACCESS[role]})
        slots.append(slot)
    trees = []
    for index in range(1, 5):
        tree = copy.deepcopy(t4)
        tree["id"] = f"tree.t{index}"
        for node in tree["nodes"]:
            for effect in node["effects"]:
                effect.update({"behavior_id": "behavior_b1", "target_classes": ["player"], "ability_ref": f"n021.a{index}"})
            node["construction_ref"] = "n046.v1"
            node["cost"] = "resolved"
        trees.append(tree)
    character = copy.deepcopy(t1)
    character.update({"id": "character.c1", "culture_ref": "n056.g1", "visual_refs": ["n045.v1"], "narrative_refs": ["n012.d1"], "base_extent": "resolved"})
    character["kit"]["slots"] = [
        {"slot_ref": f"slot.s{i}", "tree_ref": f"tree.t{i}", "ability_ref": f"n021.a{i}"} for i in range(1, 5)
    ]
    dependencies = {f"n021.a{i}": "N-021" for i in range(1, 5)}
    dependencies.update({"f02.x1": "F-02", "n045.v1": "N-045", "n046.v1": "N-046", "n012.d1": "N-012", "n056.g1": "N-056"})
    return {"characters": [character], "slots": slots, "trees": trees, "dependencies": dependencies}


def resolved_save():
    return {"run": {"start": {"character_id": "character.c1"}, "checkpoint": {"build": {"slots": [
        {"slot_id": "slot.s1", "unlocked": True, "tree_id": "tree.t1", "node_keys": ["k0", "k1"]},
        {"slot_id": "slot.s2", "unlocked": False, "tree_id": None, "node_keys": []},
        {"slot_id": "slot.s3", "unlocked": True, "tree_id": None, "node_keys": []},
        {"slot_id": "slot.s4", "unlocked": False, "tree_id": None, "node_keys": []},
    ]}}}}


def mutation(name):
    def edit_tree(candidate, fn):
        fn(candidate["trees"][0])
    table = {
        "id_grammar": lambda c: c["characters"][0].update(id="char.c1"),
        "reserved_example_id": lambda c: c["characters"][0].update(id="example.character.c1"),
        "duplicate_id": lambda c: c["trees"][1].update(id="tree.t1"),
        "schema_version_unsupported": lambda c: c["slots"][0].update(schema_version=2),
        "field_missing_or_mistyped": lambda c: c["characters"][0].pop("base_extent"),
        "reference_shape": lambda c: c["characters"][0].update(culture_ref=7),
        "placeholder_form": lambda c: c["characters"][0].update(base_extent="unset:Q-X99"),
        "unresolved_product_value": lambda c: c["characters"][0].update(base_extent="unset:Q-P22"),
        "missing_id": lambda c: c["characters"][0]["kit"]["slots"][1].update(tree_ref="tree.t9"),
        "wrong_family": lambda c: c["characters"][0]["kit"]["slots"][0].update(ability_ref="n046.v1"),
        "kit_slot_count": lambda c: c["characters"][0]["kit"]["slots"].pop(),
        "kit_slot_duplicate": lambda c: c["characters"][0]["kit"]["slots"][3].update(slot_ref="slot.s3"),
        "kit_tree_duplicate": lambda c: c["characters"][0]["kit"]["slots"][1].update(tree_ref="tree.t1"),
        "kit_order": lambda c: c["characters"][0]["kit"]["slots"].reverse(),
        "kit_slot_roles": lambda c: c["slots"][1].update(role="weapon", access="run_start"),
        "tree_bound_twice": lambda c: c["characters"].append(dict(copy.deepcopy(c["characters"][0]), id="character.c2")),
        "slot_catalogue_roles": lambda c: c["slots"].append(dict(copy.deepcopy(c["slots"][3]), id="slot.s5")),
        "slot_access_rule": lambda c: c["slots"][0].update(access="world_one"),
        "tree_node_count": lambda c: edit_tree(c, lambda t: t["nodes"].append(dict(copy.deepcopy(t["nodes"][0]), key="k15"))),
        "tree_edge_count": lambda c: edit_tree(c, lambda t: t["edges"].pop()),
        "tree_root": lambda c: edit_tree(c, lambda t: t.update(root_key="k1")),
        "tree_children": lambda c: edit_tree(c, lambda t: t["edges"][4].update(parent_key="k1")),
        "tree_endpoint_count": lambda c: edit_tree(c, lambda t: t["edges"][13].update(parent_key="k13")),
        "tree_reconvergence": lambda c: edit_tree(c, lambda t: t["edges"].append({"parent_key": "k1", "child_key": "k5"})),
        "tree_connectivity": lambda c: edit_tree(c, lambda t: t["edges"][1].update(parent_key="k5")),
        "tree_depth": lambda c: edit_tree(c, lambda t: [t["edges"][6].update(parent_key="k14"), t["edges"][7].update(parent_key="k14")]),
        "edge_unknown_key": lambda c: edit_tree(c, lambda t: t["edges"][13].update(child_key="k99")),
        "node_key_grammar": lambda c: edit_tree(c, lambda t: t["nodes"][7].update(key="K7")),
        "node_key_duplicate": lambda c: edit_tree(c, lambda t: t["nodes"][8].update(key="k7")),
        "effect_modifies_one": lambda c: edit_tree(c, lambda t: t["nodes"][0]["effects"][0].update(ability_ref=None)),
        "effect_family_target": lambda c: edit_tree(c, lambda t: t["nodes"][0]["effects"][0].update(target_classes=["device"])),
        "node_target_unset": lambda c: edit_tree(c, lambda t: t["nodes"][0]["effects"][0].update(target_classes=["device"], ability_ref=None, attack_ref="f02.x1")),
        "effect_target_class": lambda c: edit_tree(c, lambda t: t["nodes"][0]["effects"][0].update(target_classes=["enemy"])),
    }
    return table.get(name)


SAVE_MUTATIONS = {
    "saved_character": lambda s: s["run"]["start"].update(character_id="character.c9"),
    "saved_slot": lambda s: s["run"]["checkpoint"]["build"]["slots"].reverse(),
    "saved_tree_binding": lambda s: s["run"]["checkpoint"]["build"]["slots"][0].update(tree_id="tree.t2"),
    "saved_prefix": lambda s: s["run"]["checkpoint"]["build"]["slots"][0].update(node_keys=["k0", "k5"]),
    "saved_locked_selection": lambda s: s["run"]["checkpoint"]["build"]["slots"][3].update(node_keys=["k0"], tree_id="tree.t4"),
    "saved_run_start_access": lambda s: s["run"]["checkpoint"]["build"]["slots"][0].update(unlocked=False, tree_id=None, node_keys=[]),
}



def flatten_encode(value):
    """A line-oriented notation distinct from JSON: one `path = literal` per leaf."""
    lines = []

    def walk(node, path):
        if isinstance(node, dict):
            lines.append(f"{path} = {{}}")
            for key, child in node.items():
                walk(child, f"{path}.{key}")
        elif isinstance(node, list):
            lines.append(f"{path} = []")
            for index, child in enumerate(node):
                walk(child, f"{path}[{index}]")
        else:
            lines.append(f"{path} = {json.dumps(node)}")

    walk(value, "$")
    return "\n".join(lines)


def flatten_decode(text):
    root = {"$": None}
    for line in text.split("\n"):
        path, literal = line.split(" = ", 1)
        value = {} if literal == "{}" else [] if literal == "[]" else json.loads(literal)
        tokens = re.findall(r"\$|\.([^.\[]+)|\[(\d+)\]", path)
        container = root
        key = "$"
        for index, (name, position) in enumerate(tokens[1:], start=1):
            container = container[key] if isinstance(container, dict) else container[key]
            key = name if name else int(position)
        if isinstance(key, int):
            container.append(value)
        else:
            container[key] = value
    return root["$"]


def lossy_encode(value):
    def drop(node):
        if isinstance(node, dict):
            return {k: drop(v) for k, v in node.items() if v is not None}
        if isinstance(node, list):
            return [drop(v) for v in node]
        return node
    return flatten_encode(drop(value))


def reversing_encode(value):
    def flip(node):
        if isinstance(node, dict):
            return {k: flip(v) for k, v in node.items()}
        if isinstance(node, list):
            return [flip(v) for v in reversed(node)]
        return node
    return flatten_encode(flip(value))


def strict_equal(left, right):
    if type(left) is not type(right):
        return False
    if isinstance(left, dict):
        return list(left.keys()) == list(right.keys()) and all(strict_equal(left[k], right[k]) for k in left)
    if isinstance(left, list):
        return len(left) == len(right) and all(strict_equal(a, b) for a, b in zip(left, right))
    return left == right



def run_checks(root, doc_text, encode=flatten_encode):
    report = Report()
    doc = Doc(doc_text)
    doc_dir = os.path.join(root, os.path.dirname(DOC))
    sections = os.path.join(root, "docs/tech/sections")
    hf06a = read_csv(os.path.join(sections, "HF-06a-schema-inventory.csv"))
    hf06b = {row["row_id"]: row for row in read_csv(os.path.join(sections, "HF-06b-persistence-projection.csv"))}
    hf07a = {row["field"]: row for row in read_csv(os.path.join(sections, "HF-07a-save-envelope.csv"))}
    rows_by_id = {row["row_id"]: row for row in hf06a}
    with open(os.path.join(root, "BACKLOG.md"), encoding="utf-8") as handle:
        registered = set(q.upper() for q in re.findall(r'<a id="(q-[pe]\d\d)"></a>', handle.read()))

    report.check("C01-headings", "seven headings in order", doc.level2() == HEADINGS, str(doc.level2()))

    in_sources = False
    stated = 0
    for line in doc.lines:
        if line.startswith("## "):
            in_sources = line.strip() == "## Sources"
            continue
        if in_sources and line.startswith("- "):
            link = None
            for token in re.finditer(r"SHA256\s+`([0-9a-f]{64})`|\[[^\]]*\]\(([^)]+)\)", line):
                if token.group(2):
                    target = token.group(2).split("#")[0]
                    if target and not target.endswith(("BACKLOG.md", "TRACKING.md")) or (target and "#" not in token.group(2)):
                        link = target
                elif link:
                    stated += 1
                    actual = sha256(os.path.normpath(os.path.join(doc_dir, link)))
                    report.check("C02-hashes", f"hash {link}", actual == token.group(1), actual)
    report.check("C02-hashes", "at least one stated hash", stated > 0, str(stated))

    types_table = doc.table("### What this contract fixes")
    types = {row["Type"]: row for row in types_table[0]} if types_table else {}
    allocation = doc.table("### Row allocation")
    family = [row for row in hf06a if row["producing_card"] == "SC-01"]
    report.check("C03-rows", "type table present", bool(types), str(list(types)))
    alloc_rows = allocation[0] if allocation else []
    ids = [row["Row"] for row in alloc_rows]
    report.check("C03-rows", "every SC-01 row allocated exactly once", sorted(ids) == sorted(r["row_id"] for r in family) and len(ids) == len(set(ids)), str(ids))
    md_rationale = {}
    with open(os.path.join(sections, "HF-06a-schema-inventory.md"), encoding="utf-8") as handle:
        for line in handle:
            match = re.match(r"^\| (F-\d{2}|N-\d{3}) \|", line)
            if match and match.group(1) not in md_rationale:
                md_rationale[match.group(1)] = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", line.rstrip().rstrip("|").split("|")[-1]).strip()
    phrases = {}
    for type_id, row in types.items():
        phrases[type_id] = re.findall(r"`([^`]+)`", row.get("Rationale phrases", ""))
        report.check("C03-rows", f"{type_id} declares at least one rationale phrase", bool(phrases[type_id]), row.get("Rationale phrases", ""))

    def named_types(text):
        return sorted(t for t, found in phrases.items() if any(p.lower() in text.lower() for p in found))

    for row in alloc_rows:
        source = rows_by_id.get(row["Row"])
        report.check("C03-rows", f"{row['Row']} subject and treatment match HF-06a", bool(source) and source["subject"] == row["Subject"] and source["treatment"] == row["Treatment"], row["Subject"])
        declared = sorted(t.strip() for t in row["Types"].split(";"))
        report.check("C03-rows", f"{row['Row']} types are known", all(t in types for t in declared), row["Types"])
        csv_named = named_types(source["scope_and_rationale"]) if source else []
        md_named = named_types(md_rationale.get(row["Row"], ""))
        report.check("C03-rows", f"{row['Row']} types equal the types its CSV rationale names", declared == csv_named, f"declared {declared} csv {csv_named}")
        report.check("C03-rows", f"{row['Row']} types equal the types its Markdown rationale names", declared == md_named, f"declared {declared} md {md_named}")
    for type_id in types:
        carried = [r["Row"] for r in alloc_rows if type_id in [t.strip() for t in r["Types"].split(";")]]
        report.check("C03-rows", f"{type_id} has at least one row", bool(carried), type_id)
        declared_rows = sorted(r.strip() for r in types[type_id].get("HF-06a rows", "").split(";"))
        report.check("C03-rows", f"{type_id} type table rows equal its allocation", declared_rows == sorted(carried), f"{declared_rows} vs {sorted(carried)}")

    records = {}
    field_tables = {}
    for type_id in types:
        for sub in TYPE_SUBHEADINGS:
            block = doc.block_after(f"#### {type_id} {sub}")
            report.check("C04-types", f"{type_id} {sub} present and nonempty", block is not None and any(line.strip() for line in block), sub)
        fields = doc.table(f"#### {type_id} fields")
        ok = bool(fields) and fields[1] == ["Field", "Type", "Required", "Content value", "Rule"] and len(fields[0]) > 0 and all(r["Type"] for r in fields[0])
        report.check("C04-types", f"{type_id} fields typed", ok, str(fields[1] if fields else None))
        field_tables[type_id] = fields[0] if fields else []
        diagnostics = doc.table(f"#### {type_id} diagnostics")
        report.check("C04-types", f"{type_id} diagnostics name a rule and diagnostic", bool(diagnostics) and all(r.get("Rule") and r.get("Diagnostic") for r in diagnostics[0]) and len(diagnostics[0]) > 0, "")
        record, labelled = doc.json_after(f"#### {type_id} illustrative record")
        report.check("C04-types", f"{type_id} one labelled illustrative record", record is not None and labelled, "")
        records[type_id] = record

    def field_names(type_id, prefix):
        names = []
        for row in field_tables.get(type_id, []):
            name = strip_ticks(row["Field"])
            if prefix == "" and "." not in name and "[" not in name:
                names.append(name)
            elif prefix and name.startswith(prefix) and "." not in name[len(prefix):]:
                names.append(name[len(prefix):])
        return names

    nested = {"T2": [("slots", "slots[].")], "T4": [("edges", "edges[].")], "T5": [("effects", "effects[].")]}
    for type_id, record in records.items():
        if not isinstance(record, dict):
            continue
        report.check("C05-record-fields", f"{type_id} record keys equal field table", sorted(record.keys()) == sorted(field_names(type_id, "")), f"{sorted(record.keys())} vs {sorted(field_names(type_id, ''))}")
        for key, prefix in nested.get(type_id, []):
            expected = sorted(field_names(type_id, prefix))
            ok = isinstance(record.get(key), list) and all(sorted(e.keys()) == expected for e in record[key])
            report.check("C05-record-fields", f"{type_id} {key} element keys equal field table", ok, str(expected))
    if all(isinstance(records.get(t), dict) for t in ("T1", "T2", "T4", "T5")):
        report.check("C05-record-fields", "T1 kit equals the T2 record", strict_equal(records["T1"]["kit"], records["T2"]), "")
        report.check("C05-record-fields", "T4 node k7 equals the T5 record", any(strict_equal(n, records["T5"]) for n in records["T4"]["nodes"]), "")

    for type_id in types:
        refs = doc.table(f"#### {type_id} references")
        for row in (refs[0] if refs else []):
            target = strip_ticks(row["Target"])
            if target == "none":
                ok = strip_ticks(row["Field"]) == "none"
            elif target.startswith("row "):
                foreign = rows_by_id.get(target[4:])
                ok = bool(foreign) and foreign["producing_card"] != "SC-01"
            else:
                ok = target in types
            report.check("C06-references", f"{type_id} {row['Field']} target {target}", ok, target)
            family_tokens = re.findall(r"`(ability|attack)`", row.get("Expected family", ""))
            if type_id in ("T2", "T5") and target.startswith("row "):
                report.check("C06-references", f"{type_id} {row['Field']} names at most one action family", len(family_tokens) <= 1, row.get("Expected family", ""))
            if type_id == "T2" and target.startswith("row "):
                report.check("C06-references", f"kit {row['Field']} expects ability on N-021", family_tokens == ["ability"] and target == "row N-021", row.get("Expected family", ""))
    node_refs = {strip_ticks(r["Field"]): r for r in (doc.table("#### T5 references") or [[]])[0]}
    expected_node = {"effects[].ability_ref": ("row N-021", "ability"), "effects[].attack_ref": ("row F-02", "attack")}
    for field, (row_id, family) in expected_node.items():
        row = node_refs.get(field)
        ok = bool(row) and strip_ticks(row["Target"]) == row_id and re.findall(r"`(ability|attack)`", row["Expected family"]) == [family]
        report.check("C06-references", f"node {field} expects {family} on {row_id}", ok, str(row))
    for type_id in ("T4", "T5"):
        record = records.get(type_id)
        nodes = record["nodes"] if type_id == "T4" and isinstance(record, dict) else [record] if isinstance(record, dict) else []
        for node in nodes:
            for effect in node.get("effects", []) if isinstance(node.get("effects"), list) else []:
                classes = effect.get("target_classes") if isinstance(effect.get("target_classes"), list) else []
                device = any(c in ("device", "companion") for c in classes)
                ok = not (device and effect.get("ability_ref") is not None) and not ("player" in classes and effect.get("attack_ref") is not None)
                report.check("C06-references", f"{type_id} illustrative node {node.get('key')} effect family follows its target class", ok, str(classes))
    foreign = doc.table("### Foreign references")
    for row in (foreign[0] if foreign else []):
        source = rows_by_id.get(row["Row"])
        report.check("C06-references", f"foreign {row['Row']} producing card", bool(source) and source["producing_card"] == row["Producing card"] and row["Producing card"] != "SC-01", row["Producing card"])

    save = doc.table("### Save treatment")
    save_rows = save[0] if save else []
    report.check("C07-save", "save rows equal allocation rows", sorted(r["Row"] for r in save_rows) == sorted(ids), "")
    alloc_types = {r["Row"]: r["Types"] for r in alloc_rows}
    field_phrases = {"run.checkpoint.build.slots[].node_keys": "node keys"}

    def credited_rows(field):
        named = re.findall(r"\b(?:F-\d{2}|N-\d{3})\b", re.sub(r"HF-\d+[a-z]? line \d+", "", hf07a[field]["source"]))
        if named:
            return set(named)
        phrase = field_phrases.get(field)
        return {r for r, row in hf06b.items() if phrase and phrase in row["rationale"]}

    run_fields = [f for f in hf07a if f.startswith("run.checkpoint.build") or f.startswith("run.start.character_id")]
    for row in save_rows:
        source = hf06b.get(row["Row"], {})
        report.check("C07-save", f"{row['Row']} save column and case match HF-06b", source.get("save_column") == row["Save column"] and source.get("rationale_case") == row["Case"], f"{source.get('save_column')}/{source.get('rationale_case')}")
        report.check("C07-save", f"{row['Row']} types match allocation", alloc_types.get(row["Row"]) == row["Types"], row["Types"])
        cell = row["Projection or exclusion"]
        if row["Save column"] == "json-projection":
            paths = re.findall(r"`([^`]+)`", cell)
            groups = set(source.get("save_projection", "").split("; "))
            ok = bool(paths) and all(p in hf07a and hf07a[p]["projection_group"] in groups | {"container"} for p in paths) and any(hf07a.get(p, {}).get("projection_group") in groups for p in paths)
            report.check("C07-save", f"{row['Row']} projection fields in HF-07a with matching group", ok, str(paths))
            expected = sorted(f for f in run_fields if row["Row"] in credited_rows(f))
            report.check("C07-save", f"{row['Row']} lists exactly the fields HF-07a and HF-06b credit to it", sorted(p for p in paths if p in hf07a) == expected and all(p in hf07a for p in paths), f"listed {sorted(paths)} credited {expected}")
        else:
            report.check("C07-save", f"{row['Row']} explicit exclusion", cell.startswith("Excluded."), cell)

    with open(os.path.join(sections, "HF-05-content-admission.md"), encoding="utf-8") as handle:
        edges = {m.group(1): (m.group(2).strip(), m.group(3).strip()) for m in re.finditer(r"^\| (E\d\d) \| ([^|]+) \| ([^|]+) \|", handle.read(), re.M)}
    report.check("C08-traces", "HF-05 edges E01 to E16 parsed", len(edges) == 16, str(len(edges)))
    outcomes = doc.table("### Scenario outcomes")
    outcome_rows = {r["Scenario"]: r for r in (outcomes[0] if outcomes else [])}
    scenario_headings = {"AV": "### AV: a valid candidate", "AM": "### AM: a missing reference", "AI": "### AI: an invalid record", "AX": "### AX: the illustrative records submitted as a candidate"}
    for scenario, heading in scenario_headings.items():
        steps = doc.table(heading)
        outcome = outcome_rows.get(scenario)
        report.check("C08-traces", f"{scenario} has steps and an outcome row", bool(steps) and bool(outcome), "")
        if not steps or not outcome:
            continue
        last = {}
        ok = True
        detail = []
        for step in steps[0]:
            edge = step["Edge"]
            if edge not in edges or edges[edge] != (step["From"], step["To"]):
                ok = False
                detail.append(f"{step['Step']} edge mismatch")
            if step["Subject"] in last and last[step["Subject"]] != step["From"]:
                ok = False
                detail.append(f"{step['Step']} discontinuity")
            if step["Subject"].startswith("candidate"):
                if outcome["Candidate"] == "initial" and edge in REPLACEMENT_ONLY_EDGES or outcome["Candidate"] == "replacement" and edge in INITIAL_ONLY_EDGES:
                    ok = False
                    detail.append(f"{step['Step']} edge {edge} wrong candidate kind")
            last[step["Subject"]] = step["To"]
            if step["Class"] != "F-LIFECYCLE":
                ok = False
                detail.append(f"{step['Step']} class")
        candidate_final = [v for k, v in last.items() if k.startswith("candidate")]
        ok = ok and candidate_final == [outcome["Final state"]]
        report.check("C08-traces", f"{scenario} edges, continuity and final state", ok, "; ".join(detail) or str(candidate_final))

    rule_names = {}
    for heading in ["### Shared admission rules"] + [f"#### {t} diagnostics" for t in types] + ["#### Load boundary rules"]:
        table = doc.table(heading)
        for row in (table[0] if table else []):
            names = re.findall(r"`([a-z_]+)`", row.get("Name", ""))
            if re.match(r"^S[AML]-\d\d$", row["Rule"]):
                rule_names.setdefault(row["Rule"], set()).update(names)
    report.check("C09-model", "rule vocabulary parsed", len(rule_names) >= 20, str(len(rule_names)))
    if all(isinstance(records.get(t), dict) for t in ("T1", "T3", "T4")):
        base = resolved_fixture(records)
        fixtures = {
            "AV": base,
            "AM": copy.deepcopy(base),
            "AI": copy.deepcopy(base),
            "AX": {"characters": [copy.deepcopy(records["T1"])], "slots": [copy.deepcopy(records["T3"])], "trees": [copy.deepcopy(records["T4"])], "dependencies": {}},
        }
        mutation("missing_id")(fixtures["AM"])
        mutation("tree_children")(fixtures["AI"])
        for scenario, candidate in fixtures.items():
            outcome = outcome_rows.get(scenario)
            if not outcome:
                continue
            gate, findings = validate(candidate, registered)
            state = outcome_state(gate, outcome["Candidate"])
            names = sorted(set(f[0] for f in findings)) or ["none"]
            locations = sorted(f[1] for f in findings) or ["none"]
            expected_locations = sorted(part.strip() for part in outcome["Location or referrer"].split(";"))
            ok = state == outcome["Final state"] and names == [outcome["Code or rule"]] and locations == expected_locations
            diagnostic = "none" if gate == "admitted" else ("ContentReferenceFailure" if names[0] in ("missing_id", "wrong_family", "missing_revision", "incompatible_revision", "ambiguous_revision") else "ContentAdmissionFailure")
            ok = ok and diagnostic == outcome["Diagnostic"]
            report.check("C09-model", f"{scenario} model outcome equals the outcome table", ok, f"{state} {names} {locations}")
        base_findings = validate(base, registered)[1]
        for rule_id, names in sorted(rule_names.items()):
            if rule_id.startswith("SL"):
                continue
            targets = sorted(names) if rule_id != "SM-02" else ["missing_id", "wrong_family"]
            for name in targets:
                mutate = mutation(name)
                if mutate is None:
                    report.check("C09-model", f"{rule_id} {name} has a model fixture", False, name)
                    continue
                candidate = copy.deepcopy(base)
                mutate(candidate)
                fired = name in [f[0] for f in validate(candidate, registered)[1]]
                report.check("C09-model", f"{rule_id} {name} fires on its mutation and not on the valid fixture", fired and name not in [f[0] for f in base_findings], name)
        save_ok = validate_saved(resolved_save(), base)
        report.check("C09-model", "valid saved selection passes the load rules", save_ok == [], str(save_ok))
        for rule_id, names in sorted(rule_names.items()):
            if not rule_id.startswith("SL"):
                continue
            for name in names:
                saved = resolved_save()
                SAVE_MUTATIONS[name](saved)
                report.check("C09-model", f"{rule_id} {name} fires on its saved mutation", name in [f[0] for f in validate_saved(saved, base)], name)

    def declared_paths(type_id, prefix=""):
        paths = []
        for row in field_tables.get(type_id, []):
            name = prefix + strip_ticks(row["Field"])
            paths.append(name)
            embedded = re.search(r"(array of )?(T[25]) record", row["Type"])
            if embedded:
                paths += declared_paths(embedded.group(2), name + ("[]." if embedded.group(1) else "."))
        return paths

    def reference_paths(type_id, prefix=""):
        found = []
        table = doc.table(f"#### {type_id} references")
        for row in (table[0] if table else []):
            target = strip_ticks(row["Target"])
            if target in ("T2", "T5"):
                nested_prefix = prefix + strip_ticks(row["Field"]).rstrip("[]") + ("[]." if row["Field"].strip("`").endswith("[]") else ".")
                found += reference_paths(target, nested_prefix)
            elif target != "none":
                found += [prefix + name for name in re.findall(r"`([^`]+)`", row["Field"])]
        return found

    def values_at(value, path):
        current = [("", value)]
        for token in path.split("."):
            iterate = token.endswith("[]")
            key = token[:-2] if iterate else token
            following = []
            for where, node in current:
                if not isinstance(node, dict) or key not in node:
                    following.append((f"{where}.{key}", KeyError))
                    continue
                child = node[key]
                if iterate and isinstance(child, list):
                    following += [(f"{where}.{key}[{i}]", item) for i, item in enumerate(child)]
                else:
                    following.append((f"{where}.{key}", child))
            current = following
        return current

    def same_shape(left, right):
        if left is KeyError or right is KeyError or type(left) is not type(right):
            return False
        if isinstance(left, dict):
            return sorted(left) == sorted(right)
        if isinstance(left, list):
            return len(left) == len(right) and all(type(a) is type(b) and (isinstance(a, (dict, list)) or a == b) for a, b in zip(left, right))
        return left == right

    def leaf_paths(value, path=""):
        if isinstance(value, dict):
            return [p for key, child in value.items() for p in leaf_paths(child, f"{path}.{key}" if path else key)]
        if isinstance(value, list) and value and isinstance(value[0], dict):
            return [p for child in value for p in leaf_paths(child, f"{path}[]")]
        return [path]

    for type_id, record in records.items():
        if record is None:
            continue
        decoded = flatten_decode(encode(record))
        declared = declared_paths(type_id)
        undeclared = sorted(set(p for p in leaf_paths(record) if p not in declared))
        report.check("C10-roundtrip", f"{type_id} every illustrative field is declared in the field tables", not undeclared, str(undeclared))
        broken = [path for path in declared if not all(same_shape(a[1], b[1]) and a[0] == b[0] for a, b in zip(values_at(record, path), values_at(decoded, path))) or len(values_at(record, path)) != len(values_at(decoded, path))]
        report.check("C10-roundtrip", f"{type_id} every declared field keeps its value and type after encode and decode", not broken, str(broken))
        refs = reference_paths(type_id)
        lost = [path for path in refs if values_at(record, path) != values_at(decoded, path)]
        report.check("C10-roundtrip", f"{type_id} every declared reference keeps its ID on the same field", bool(refs) or type_id == "T3", str(refs))
        report.check("C10-roundtrip", f"{type_id} declared references preserved", not lost, str(lost))
    excerpt, labelled = doc.json_after("### RT: the illustrative records round-trip")
    report.check("C10-roundtrip", "save excerpt present and labelled", excerpt is not None and labelled, "")
    if excerpt is not None:
        first = json.dumps(excerpt, separators=(",", ":"))
        second = json.dumps(json.loads(first), separators=(",", ":"))
        report.check("C10-roundtrip", "save excerpt serialise, parse, serialise is byte-identical", first == second and strict_equal(excerpt, json.loads(first)), "")
        leaves = []

        def walk(node, path):
            if isinstance(node, dict):
                for key, child in node.items():
                    walk(child, f"{path}.{key}" if path else key)
            elif isinstance(node, list) and node and isinstance(node[0], dict):
                for child in node:
                    walk(child, f"{path}[]")
            else:
                leaves.append((path, node))
        walk(excerpt, "")
        report.check("C10-roundtrip", "every save excerpt leaf is an HF-07a path", all(p in hf07a for p, _ in leaves), str([p for p, _ in leaves if p not in hf07a]))
        ids_are_strings = all(isinstance(v, str) for p, v in leaves if hf07a.get(p, {}).get("type") == "id-string")
        keys_are_strings = all(isinstance(k, str) for p, v in leaves if p.endswith("node_keys") for k in v)
        report.check("C10-roundtrip", "saved IDs and node keys are strings", ids_are_strings and keys_are_strings, "")

    for type_id, rows in field_tables.items():
        for row in rows:
            value = row["Content value"]
            ok = value == "structural" or (PLACEHOLDER.match(value) and all(q in registered for q in QID.findall(value)))
            report.check("C11-symbolic", f"{type_id} {row['Field']} content value structural or placeholder", ok, value)
    params = doc.table("### Tunable parameters")
    sourced_numbers = set()
    for row in (params[0] if params else []):
        value = row["Value at this base"]
        source = row["Source line or question"]
        if value == "unset":
            ok = bool(QID.findall(source)) and all(q in registered for q in QID.findall(source))
        else:
            ok = bool(re.search(r"\blines?\b", source))
            sourced_numbers.update(re.findall(r"\b\d+\b", value))
        report.check("C11-symbolic", f"{row['ID']} sourced or unset with a registered question", ok, f"{value} / {source}")
    in_fence = False
    stray = []
    for line in doc.lines:
        if line.startswith("```"):
            in_fence = not in_fence
        for token in re.findall(r"unset:[A-Za-z0-9+\-]+", line):
            if not PLACEHOLDER.match(token) or any(q not in registered for q in QID.findall(token)):
                stray.append(token)
    report.check("C11-symbolic", "every placeholder in the document names registered questions", not stray, str(stray))
    for type_id, record in records.items():
        for text in all_strings(record or {}):
            ok = not text.startswith("unset:") or (PLACEHOLDER.match(text) and all(q in registered for q in QID.findall(text)))
            if not ok:
                report.check("C11-symbolic", f"{type_id} illustrative placeholder form", False, text)
    number_headings = ["### Identity, version and placeholder rules", "### Shared admission rules"] + [f"#### {t} {s}" for t in types for s in ("fields", "diagnostics")]
    unsourced = []
    for heading in number_headings:
        table = doc.table(heading)
        for row in (table[0] if table else []):
            for column, cell in row.items():
                if column == "Source":
                    continue
                text = re.sub(r"`[^`]*`", "", cell)
                text = re.sub(r"\blines? \d+( to \d+)?(, \d+)*", "", text)
                text = re.sub(r"\b[A-Za-z]+-[A-Za-z]*\d+\b", "", text)
                text = re.sub(r"\b(T|E|k|RA-|RS-|QO-|Seam )\d+\b", "", text)
                text = re.sub(r"<[^>]*>", "", text)
                unsourced += [n for n in re.findall(r"\b\d+\b", text) if n not in sourced_numbers]
    report.check("C11-symbolic", "every numeral in rule and field tables is a sourced parameter value", not unsourced, str(unsourced))

    return report


def negative_controls(root, text):
    controls = []

    def expect(name, category, mutated_text, encode=flatten_encode):
        report = run_checks(root, mutated_text, encode)
        failed = [r for r in report.failures() if r["category"] == category]
        controls.append({"control": name, "category": category, "failed_as_intended": bool(failed), "failures": len(failed), "changed": mutated_text != text or encode is not flatten_encode})

    def replace_once(old, new):
        assert old in text, old
        return text.replace(old, new, 1)

    expect("NC1 drop row N-013 from the allocation", "C03-rows", replace_once("| N-013 | 5.1 Shared baseline and class roles | embedded-record |", "| N-099 | 5.1 Shared baseline and class roles | embedded-record |"))
    expect("NC2 F-03 save column changed", "C07-save", replace_once("| F-03 | T4; T5 | json-projection | projection |", "| F-03 | T4; T5 | immutable-by-id | projection |"))
    expect("NC3 reference to a row outside HF-06a", "C06-references", replace_once("| `culture_ref` | row N-056 |", "| `culture_ref` | row X-99 |"))
    expect("NC4 a placeholder replaced by a number", "C11-symbolic", replace_once("| `base_extent` | placeholder | yes | unset:Q-P22 |", "| `base_extent` | placeholder | yes | 1.5 |"))
    expect("NC5 a lossy codec that drops nulls", "C10-roundtrip", text, lossy_encode)
    expect("NC6 AM outcome code changed", "C09-model", replace_once("| AM | replacement | rejected-reload | ContentReferenceFailure | missing_id |", "| AM | replacement | rejected-reload | ContentReferenceFailure | wrong_family |"))
    expect("NC7 a projected field HF-07a does not carry", "C07-save", replace_once("`run.checkpoint.build.slots[].slot_id`, `run.checkpoint.build.slots[].unlocked`,", "`run.checkpoint.build.slots[].slot_id`, `run.checkpoint.build.slots[].tier`,"))
    expect("NC8 illustrative label removed from T3", "C04-types", replace_once("Illustrative, not canon. The role and access values", "The role and access values"))
    expect("NC9 a replacement edge in an initial trace", "C08-traces", replace_once("| AI.2 | candidate C | E08 | imported | draft |", "| AI.2 | candidate C | E11 | imported | rejected-reload |"))
    expect("NC10 N-024 allocated to the slot type alone, as attempt 1 did", "C03-rows", replace_once("| N-024 | Four slots and milestone progression | schema | T3; T4; T5 |", "| N-024 | Four slots and milestone progression | schema | T3 |"))
    expect("NC11 the kit ability reference retargeted to attacks", "C06-references", replace_once("| `slots[].ability_ref` | row N-021 | `ability`", "| `slots[].ability_ref` | row F-02 | `attack`"))
    expect("NC12 slot_id credited to F-03 instead of N-024", "C07-save", replace_once("| F-03 | T4; T5 | json-projection | projection | `run.checkpoint.build`,", "| F-03 | T4; T5 | json-projection | projection | `run.checkpoint.build.slots[].slot_id`, `run.checkpoint.build`,"))
    expect("NC13 a codec that reverses arrays", "C10-roundtrip", text, reversing_encode)
    expect("NC14 an illustrative field the field table does not declare", "C10-roundtrip", replace_once('  "access": "run_start"\n}', '  "access": "run_start",\n  "label": "example"\n}'))
    expect("NC15 a device-target effect naming an ability", "C06-references", replace_once('{"key": "k7", "effects": [{"behavior_id": "unset:Q-P11", "target_classes": ["unset:Q-P11+Q-P15"]', '{"key": "k7", "effects": [{"behavior_id": "unset:Q-P11", "target_classes": ["device"]'))
    expect("NC16 one node reference field naming two families", "C06-references", replace_once("| `effects[].ability_ref` | row N-021 | `ability` (HF-06a row N-021) |", "| `effects[].ability_ref` | row N-021 | `ability` or `attack` (HF-06a row N-021) |"))
    return controls


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    root = os.path.abspath(args.root)
    os.makedirs(args.out, exist_ok=True)
    with open(os.path.join(root, DOC), encoding="utf-8") as handle:
        text = handle.read()
    report = run_checks(root, text)
    controls = negative_controls(root, text)
    categories = {}
    for result in report.results:
        bucket = categories.setdefault(result["category"], {"passed": 0, "failed": 0})
        bucket["passed" if result["ok"] else "failed"] += 1
    controls_ok = all(c["failed_as_intended"] and c["changed"] for c in controls)
    summary = {
        "document": DOC,
        "document_sha256": sha256(os.path.join(root, DOC)),
        "assertions": len(report.results),
        "passed": len(report.results) - len(report.failures()),
        "failed": len(report.failures()),
        "categories": categories,
        "failures": report.failures(),
        "negative_controls": controls,
        "negative_controls_failed_as_intended": sum(1 for c in controls if c["failed_as_intended"]),
        "verdict": "pass" if not report.failures() and controls_ok and len(controls) >= 3 else "fail",
    }
    manifest = {path: sha256(os.path.join(root, path)) for path in [
        DOC,
        "docs/tech/sections/HF-05-content-admission.md",
        "docs/tech/sections/HF-06a-schema-inventory.csv",
        "docs/tech/sections/HF-06b-persistence-projection.csv",
        "docs/tech/sections/HF-07a-save-envelope.csv",
        "BACKLOG.md",
    ]}
    manifest["checker"] = sha256(os.path.abspath(__file__))
    with open(os.path.join(args.out, "paper-check.json"), "w", encoding="utf-8") as handle:
        json.dump(summary, handle, indent=2)
    with open(os.path.join(args.out, "source-manifest.json"), "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)
    print(f"paper-check {summary['verdict']}: {summary['passed']} passed, {summary['failed']} failed, {summary['negative_controls_failed_as_intended']}/{len(controls)} negative controls failed as intended")
    for failure in report.failures():
        print(f"FAIL {failure['category']} {failure['name']}: {failure['detail']}")
    for control in controls:
        if not control["failed_as_intended"]:
            print(f"CONTROL DID NOT FAIL {control['control']}")
    return 0 if summary["verdict"] == "pass" else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:  # noqa: BLE001
        import traceback
        traceback.print_exc()
        print(f"paper-check internal error: {error}")
        sys.exit(2)
