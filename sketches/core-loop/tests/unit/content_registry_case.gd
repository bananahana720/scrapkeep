extends RefCounted

# T5 rule: registered content is well formed, resolves references, is selectable,
# meets its admission floor, and matches a typed golden hash. Each bad-row fixture
# must fail its named rule; deleting any registered table must fail minimum_rows.
const Registry := preload("res://src/core/content_registry.gd")
const FIXTURES := "res://tests/fixtures/content_registry/"
const TABLE_COUNT := 27
# These two content pins exclude the stage table; unrelated registry pins stay canonical.
const CONTENT_HASHES := {
	"lore_rows.ROWS": "5d8ad2b4450a20aadfa841794e5370ed26f93ec06cb06b8228da11cd6df61882",
	"music_rows.ROWS": "6ae91061fe62a58b8935f508c4b253ffc8c8bb1cbe2d9167eddbb7c3c3126329",
}


func run(t) -> void:
	var tables := Registry.snapshot()
	for name in CONTENT_HASHES:
		t.eq("assigned content pin " + name, Registry.digest(tables[name]), CONTENT_HASHES[name])
		t.eq("canonical content pin " + name, Registry.GOLDEN_HASHES[name], CONTENT_HASHES[name])
	t.eq("content registry has all assigned tables", tables.size(), TABLE_COUNT)
	t.eq("registration matches loaded tables", _sorted(Registry.TABLES.keys()), _sorted(tables.keys()))
	t.eq("golden pins match registration", _sorted(Registry.GOLDEN_HASHES.keys()), _sorted(tables.keys()))
	t.eq("unchanged registered content validates", Registry.validate(tables), [])
	for name in tables:
		t.check("golden digest " + name, Registry.digest(tables[name]) == Registry.GOLDEN_HASHES[name], Registry.digest(tables[name]))
	var fixture_files := []
	for rule in Registry.RULES:
		fixture_files.append(rule + ".json")
	t.eq("one fixture file per validator rule", _sorted(Array(DirAccess.get_files_at(FIXTURES))), _sorted(fixture_files))
	for rule in Registry.RULES:
		var fixture = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + rule + ".json"))
		if not t.check("fixture loads " + rule, fixture is Dictionary and fixture.get("rule") == rule and fixture.get("cases") is Array):
			continue
		t.check("fixture contains bad rows " + rule, not fixture.cases.is_empty())
		var covered := []
		for index in fixture.cases.size():
			var edit: Dictionary = fixture.cases[index]
			var changed := tables.duplicate(false)
			changed[edit.table] = tables[edit.table].duplicate(true)
			if edit.op == "drop_category":
				changed["event_kinds.CODEX_CATEGORIES"] = tables["event_kinds.CODEX_CATEGORIES"].duplicate(true)
			_mutate(changed, edit)
			var issues := Registry.validate_table(edit.table, changed[edit.table], changed, rule == "golden_hash")
			var matched: Array = issues.filter(func(issue): return issue.rule == rule)
			t.check("fixture %s/%d %s" % [rule, index, edit.table], not matched.is_empty(), str(matched))
			if rule == "golden_hash":
				t.eq("valid content change fails only its hash " + edit.table, issues.filter(func(issue): return issue.rule != "golden_hash"), [])
			covered.append(edit.table)
		if rule in ["minimum_rows", "well_formed", "references", "golden_hash"]:
			t.eq("fixture covers every table " + rule, _sorted(_unique(covered)), _sorted(tables.keys()))
	t.eq("fixtures leave source snapshots unchanged", Registry.validate(Registry.snapshot()), [])
	_hash_rules(t)
	_missing_tables(t, tables)
	_cross_references(t, tables)


func _sorted(values: Array) -> Array:
	var out := values.duplicate()
	out.sort()
	return out


func _unique(values: Array) -> Array:
	var out := []
	for value in values:
		if not out.has(value):
			out.append(value)
	return out


# Fixture edits run on a deep copy. A node-array adapter keeps full and world-one
# nodes under the same fixture rules as dictionary rows and ordered lore rows.
func _mutate(tables: Dictionary, edit: Dictionary) -> void:
	var rows = tables[edit.table]
	var trees: bool = Registry.TABLES[edit.table].kind in ["trees", "world_one_trees"]
	var pilot = rows.keys()[0] if trees else ""
	var list = rows[pilot] if trees else rows
	var key = 0 if list is Array else list.keys()[0]
	match edit.op:
		"empty":
			rows.clear()
		"empty_tree":
			rows[pilot].clear()
		"bad_row":
			list[key] = "not a row"
		"erase_field":
			list[key].erase(Registry.TABLES[edit.table].schema.keys()[0])
		"missing_parent":
			list[0].id = ""
		"duplicate":
			list.append(list[0].duplicate(true))
		"set", "extra_field":
			var value = edit.value
			# JSON numbers are floats; preserve the field's existing integer type.
			if list[key].get(edit.field) is int and value is float:
				value = int(value)
			list[key][edit.field] = value
		"set_bounds":
			list[key].need = "kills"
			list[key].min = 10
			list[key].max = 1
		"rename":
			if list is Array:
				list[key].id = edit.value
			else:
				list[edit.value] = list[key]
				list.erase(key)
		"erase":
			rows.erase(edit.id)
		"extra_node":
			var node: Dictionary = list[0].duplicate(true)
			node.id = "fixture_orphan"
			list.append(node)
		"drop_category":
			tables["event_kinds.CODEX_CATEGORIES"].erase("enemy")


func _hash_rules(t) -> void:
	t.eq("hash ignores dictionary insertion order", Registry.digest({"a": 1, "b": {"x": 2, "y": 3}}), Registry.digest({"b": {"y": 3, "x": 2}, "a": 1}))
	t.check("hash retains array order", Registry.digest([1, 2]) != Registry.digest([2, 1]))
	t.check("hash retains number types", Registry.digest(1) != Registry.digest(1.0))
	t.check("hash retains full color precision", Registry.digest(Color(0.123456, 0, 0)) != Registry.digest(Color(0.123457, 0, 0)))
	t.check("hash retains nested fields", Registry.digest({"a": {"b": 1}}) != Registry.digest({"a": {"b": 2}}))
	t.eq("hash handles malformed mixed key types", Registry.digest({"a": 1, 2: "b"}), Registry.digest({2: "b", "a": 1}))


func _missing_tables(t, tables: Dictionary) -> void:
	for name in tables:
		var changed := tables.duplicate(false)
		changed.erase(name)
		# Avoid repeating the 81,920-state objective chooser sweep for unrelated table-absence checks;
		# objectives.ROWS itself is checked below and in the full validate() calls.
		if name != "objectives.ROWS":
			changed["objectives.ROWS"] = {}
		var issues := Registry.validate(changed, false)
		t.check("absent table fails minimum " + name, issues.any(func(issue): return issue.table == name and issue.rule == "minimum_rows"))
	var changed := tables.duplicate(false)
	changed["unknown.ROWS"] = {}
	t.check("unregistered tables are refused", Registry.validate(changed, false).any(func(issue): return issue.table == "unknown.ROWS" and issue.rule == "well_formed"))


func _cross_references(t, tables: Dictionary) -> void:
	var changed := tables.duplicate(false)
	changed["event_kinds.REACTIONS"] = tables["event_kinds.REACTIONS"].duplicate(true)
	changed["event_kinds.REACTIONS"].erase("flinch")
	var issues := Registry.validate_table("event_kinds.IMPACT", changed["event_kinds.IMPACT"], changed, false)
	t.check("impact resolves against supplied reaction table", issues.any(func(issue): return issue.rule == "references"))
	changed = tables.duplicate(false)
	changed["item_gen.RARITY"] = tables["item_gen.RARITY"].duplicate(true)
	changed["item_gen.RARITY"].erase("common")
	issues = Registry.validate_table("parts.rows", changed["parts.rows"], changed, false)
	t.check("parts resolve against supplied rarity table", issues.any(func(issue): return issue.rule == "references"))
	changed = tables.duplicate(false)
	changed["cosmetics.ROWS"] = tables["cosmetics.ROWS"].duplicate(true)
	changed["cosmetics.ROWS"].erase("paint_any_night")
	issues = Registry.validate_table("achievements.ROWS", changed["achievements.ROWS"], changed, false)
	t.check("achievements resolve against supplied cosmetic table", issues.any(func(issue): return issue.rule == "references"))
