extends RefCounted

const Cosmetics := preload("res://src/core/cosmetics.gd")
const Items := preload("res://src/build/items.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Palette := preload("res://src/core/palette.gd")
const SourceScan := preload("res://tests/support/source_scan.gd")
const FORBIDDEN := "\\bNode\\b|[Pp]rofile|res://src/(movement|combat|build|world|boss)"
const CUT := "(?s:func %s\\(.*?)(?=^\\S)"

# The cosmetics table is looks only: every row keeps to the allowed keys, none carries an
# item stat key, no tint is a hostile hue, and each rule is shown able to fail.

const STAT_LITERALS := ["mods", "punch", "charges"]
# An item row may carry its own display name (Scrap Bulk, wave 35). A name is not a stat, and cosmetics have names too.
const ITEM_DISPLAY_KEYS := ["name"]


func _pilots() -> Array:
	var ids: Array = []
	for def in ClassDef.all():
		ids.append(def.id)
	return ids


func _stat_keys() -> Array:
	var keys: Array = STAT_LITERALS.duplicate()
	for id in Items.TABLE:
		var item: Dictionary = Items.TABLE[id]
		for key in item:
			if not keys.has(key) and not ITEM_DISPLAY_KEYS.has(key):
				keys.append(key)
		for nested in ["mods", "charges", "patterns"]:
			if item.get(nested) is Dictionary:
				for key in item[nested]:
					if not keys.has(key):
						keys.append(key)
	return keys


func _bad(t, label: String, rows: Dictionary, id: String, rule: String) -> void:
	var problems := Cosmetics.validate(rows, _pilots())
	var named := false
	for p in problems:
		if p.begins_with(id + ":") and p.contains(rule):
			named = true
	t.check(label, named, "problems %s (need one naming %s and %s)" % [problems, id, rule])


func _good() -> Dictionary:
	return {"paint_ok": {"slot": "paint", "pilot": "", "name": "Ok", "starter": true, "tint": Color("336699")}}


func _with(extra: Dictionary) -> Dictionary:
	var r: Dictionary = _good()["paint_ok"].duplicate()
	for key in extra:
		if extra[key] == null:
			r.erase(key)
		else:
			r[key] = extra[key]
	var rows := {"paint_ok": r}
	# The table-level PENDING_ART check wants each pending id to be a row; reuse the real rows.
	for pending in Cosmetics.PENDING_ART:
		rows[pending] = Cosmetics.ROWS[pending]
	for i in range(Cosmetics.MIN_ROWS - 1):
		rows["pad_%d" % i] = {"slot": "paint", "pilot": "", "name": "Pad", "starter": false, "tint": Color("669933")}
	return rows


func run(t) -> void:
	var rows := Cosmetics.ROWS
	var problems := Cosmetics.validate(rows, _pilots())
	t.check("the real table validates clean", problems.is_empty(), "problems %s" % [problems])
	t.check("the table has at least 6 rows", rows.size() >= 6, "%d rows" % rows.size())

	var stats := _stat_keys()
	var carried: Array = []
	for id in rows:
		for key in rows[id]:
			if stats.has(key):
				carried.append("%s.%s" % [id, key])
	t.check("no real row carries a stat key", carried.is_empty(), "stat keys on %s" % [carried])
	var overlap: Array = []
	for key in Cosmetics.ALLOWED:
		if stats.has(key):
			overlap.append(key)
	t.check("no allowed key is an item stat key", overlap.is_empty(), "overlap %s" % [overlap])

	var hostile: Array = []
	var starters := 0
	for id in rows:
		var r: Dictionary = rows[id]
		if r.has("tint") and (r["tint"] == Palette.HAZARD or Cosmetics.is_hostile(r["tint"])):
			hostile.append(id)
		if r["slot"] == "paint" and r["starter"]:
			starters += 1
	t.check("no real tint is a hostile hue", hostile.is_empty(), "hostile tints on %s" % [hostile])
	t.check("at least one starter paint exists", starters >= 1, "%d starter paints" % starters)
	# The eight slots are the P-R7 customization scaffold: outfit, shell, companion_skin and bay_decor join the four approved ones.
	t.eq("cosmetic slots are paint plus the three P-R7 slots", Cosmetics.SLOTS, ["paint", "trail", "decal", "companion_paint", "outfit", "shell", "companion_skin", "bay_decor"])
	var bare: Array = []
	for pilot in _pilots():
		var owned := false
		for id in rows:
			var r: Dictionary = rows[id]
			if r["pilot"] == pilot and r["slot"] == "paint" and r["starter"] == true:
				owned = true
		if not owned:
			bare.append(pilot)
	t.check("every pilot has its own starter paint", bare.is_empty(), "no starter paint of their own: %s" % [bare])
	t.check("for_slot offers a pilot its own and any-pilot paints", Cosmetics.for_slot("paint", "runner_gunner").has("paint_rivet_moss") and Cosmetics.for_slot("paint", "runner_gunner").has("paint_any_salt") and not Cosmetics.for_slot("paint", "runner_gunner").has("paint_kest_plum"),
		"got %s" % [Cosmetics.for_slot("paint", "runner_gunner")])

	t.check("fixture control: a good row validates clean", Cosmetics.validate(_with({}), _pilots()).is_empty(), "problems %s" % [Cosmetics.validate(_with({}), _pilots())])
	_bad(t, "bad: a mods key is refused", _with({"mods": {"cruise": 1.5}}), "paint_ok", "not allowed")
	_bad(t, "bad: a punch key is refused", _with({"punch": 3.0}), "paint_ok", "not allowed")
	_bad(t, "bad: a hostile tint is refused", _with({"tint": Palette.HAZARD}), "paint_ok", "hostile")
	_bad(t, "bad: a near-hostile tint is refused", _with({"tint": Color("fb5a3a")}), "paint_ok", "hostile")
	_bad(t, "bad: an unknown slot is refused", _with({"slot": "aura"}), "paint_ok", "slot")
	_bad(t, "bad: an unknown pilot is refused", _with({"pilot": "nobody"}), "paint_ok", "pilot")
	_bad(t, "bad: a mesh key is refused", _with({"mesh": "res://x.tres"}), "paint_ok", "not allowed")
	_bad(t, "bad: a row without a tint is refused", _with({"tint": null}), "paint_ok", "needs a tint")
	_bad(t, "bad: a trail slot is refused", _with({"slot": "trail"}), "paint_ok", "slot")
	_bad(t, "bad: a table without a starter paint is refused", _with({"starter": false}), "table", "starter paint")
	_bad(t, "bad: a short table is refused", _good(), "table", "at least 6 rows")

	t.eq("fixture control: the purity pattern finds a planted Node", SourceScan.search(t, "var n: Node\n", FORBIDDEN).size(), 1)
	t.eq("fixture control: the cut takes one whole function", SourceScan.search(t, "func a():\n\tvar n: Node\n\nconst B := 1\n", SourceScan.DECLARATION + CUT % "a").map(func(m: RegExMatch) -> String: return m.get_string()), ["func a():\n\tvar n: Node\n\n"])
	_purity(t, "res://src/core/cosmetics.gd", "resolve")


func _purity(t, path: String, allowed: String) -> void:
	var source := SourceScan.text(t, path)
	var cut := SourceScan.search(t, source, SourceScan.DECLARATION + CUT % allowed)
	t.eq("%s holds one %s" % [path.get_file(), allowed], cut.size(), 1)
	var rest := source.replace(cut[0].get_string(), "") if cut.size() == 1 else source
	var hits := SourceScan.search(t, rest, FORBIDDEN)
	t.check("%s references no node, profile or stat module outside %s, which instantiates a delivered scene to check it" % [path.get_file(), allowed], hits.is_empty() and rest != "", "found %s" % [hits.map(func(m: RegExMatch) -> String: return m.get_string())])
