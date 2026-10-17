extends RefCounted

const BuildSheet := preload("res://src/build/build_sheet.gd")
const Parts := preload("res://src/build/parts.gd")
const PartDef := preload("res://src/build/part_def.gd")
const Synergies := preload("res://src/build/synergies.gd")
const PartSets := preload("res://src/build/part_sets.gd")

# SI5 stat cache (W13-INTEGRATION-3 SI5; comps/isaac/items-and-synergies.md). The build's
# derived sheet, kept between part-list changes. Each part declares the sheet categories
# it touches (PartDef.stat_touches); sync() compares, per category, the held parts that
# touch it, and refolds only the categories whose list changed. A category refold runs the
# same loop in the same order as BuildSheet.from_parts, so the result is the full
# recompute's, bit for bit (tests/stat_cache_test.gd holds that over 1,000 random builds).
# Removing a part refolds its categories without it, so a respec drops the derived bonus
# (BIBLE.md:564). A change of run tier or synergy table refolds everything, since both
# change what a part id means.

# Emitted after a sync that refolded anything, with the categories it refolded.
signal recomputed(categories: Array)

const CATEGORIES := PartDef.STAT_CATEGORIES
# The categories a synergy row can feed besides its own (transformers and dials).
const ROW_FED := ["mods", "patterns", "elements"]

# Category refolds since this cache was made, and the categories the last sync refolded.
var recomputes := 0
var last_dirty: Array = []
var _sheet: RefCounted
# The live synergy keys in from_parts order, consumed ones appended.
var _live: Array = []
var _held: Array = []
var _tier := -1
var _table = null
var _primed := false


func _init() -> void:
	_sheet = BuildSheet.new()


# The sheet for held, refolding only what changed since the last sync. Returns a copy the
# caller may adjust (build.gd adds Scrap Armor to max_hp_bonus) without touching the cache.
func sync(held: Array) -> RefCounted:
	var tier := Parts.active_tier()
	var dirty: Array = []
	if not _primed or tier != _tier or not is_same(Synergies.table, _table):
		dirty = CATEGORIES.duplicate()
	else:
		for category in CATEGORIES:
			if _touching(_held, category) != _touching(held, category):
				dirty.append(category)
	_primed = true
	_tier = tier
	_table = Synergies.table
	_held = held.duplicate()
	_sheet.parts = held.duplicate()
	last_dirty = []
	if "synergy" in dirty:
		_refold_synergy(held, dirty)
	var pending: Array = CATEGORIES.filter(func(category): return category in dirty and not category in last_dirty)
	if not pending.is_empty():
		var counted := _counted(held)
		for category in pending:
			_refold(category, counted)
	recomputes += last_dirty.size()
	if not last_dirty.is_empty():
		recomputed.emit(last_dirty.duplicate())
	return copy()


# A detached copy of the cached sheet.
func copy() -> RefCounted:
	var out: RefCounted = BuildSheet.new()
	for p in _sheet.get_property_list():
		if not p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			continue
		var value = _sheet.get(p["name"])
		out.set(p["name"], value.duplicate(true) if value is Array or value is Dictionary else value)
	return out


# The held ids, in order, whose part declares category.
static func _touching(held: Array, category: String) -> Array:
	var out: Array = []
	for part_id in held:
		var d: Resource = Parts.def(part_id)
		if d != null and category in d.stat_touches:
			out.append(part_id)
	return out


# Synergies, consumed evolutions, tag rules and sets, then their transformers and dials. A held
# Evolved part counts only while its pair is consumed, so a consumed change refolds its
# categories; a changed row set refolds the categories rows feed.
func _refold_synergy(held: Array, dirty: Array) -> void:
	var old_consumed: Array = _sheet.consumed
	var old_rows := _row_keys()
	_sheet.consumed = Synergies.consumed(held)
	var sets := Parts.tag_sets(held)
	_live = Synergies.active(held, sets)
	for key in _sheet.consumed:
		if not key in _live:
			_live.append(key)
	_sheet.synergies = _live.filter(func(key): return not key in _sheet.consumed)
	_sheet.rules = Synergies.active_rules(sets)
	_sheet.sets = PartSets.complete(held)
	_sheet.transformers = []
	_sheet.dials = {}
	for row in _rows():
		for t in row.get("transformers", []):
			if not t in _sheet.transformers:
				_sheet.transformers.append(t)
		var row_dials: Dictionary = row.get("dials", {})
		for dial in row_dials:
			_sheet.dials[dial] = _sheet.dials.get(dial, 1.0) * row_dials[dial]
	last_dirty.append("synergy")
	if old_rows != _row_keys():
		for category in ROW_FED:
			if not category in dirty:
				dirty.append(category)
	if old_consumed != _sheet.consumed:
		for part_id in held:
			var d: Resource = Parts.def(part_id)
			if d == null or d.rarity != "evolved":
				continue
			var key := Synergies.evolution_of(part_id)
			if (key in old_consumed) != (key in _sheet.consumed):
				for category in d.stat_touches:
					if not category in dirty:
						dirty.append(category)


# The row keys from_parts folds: live synergies (consumed appended), tag rules, then sets.
func _row_keys() -> Array:
	return _live + _sheet.rules + _sheet.sets.map(func(key): return PartSets.row_key(key))


# The synergy, tag-rule and set rows, in from_parts order.
func _rows() -> Array:
	var rows: Array = []
	for key in _live:
		rows.append(Synergies.ROWS[key])
	for key in _sheet.rules:
		rows.append(Synergies.TAG_RULES[key])
	for key in _sheet.sets:
		rows.append(PartSets.row(key))
	return rows


# The defs from_parts folds, in held order: an Evolved part only while consumed, and no
# copy past a linear or capped row's stack_cap.
func _counted(held: Array) -> Array:
	var out: Array = []
	var copies := {}
	for part_id in held:
		var d: Resource = Parts.def(part_id)
		if d == null:
			continue
		if d.rarity == "evolved" and not Synergies.evolution_of(part_id) in _sheet.consumed:
			continue
		copies[part_id] = copies.get(part_id, 0) + 1
		if d.stack_rule != "hyperbolic" and d.stack_cap >= 1.0 and copies[part_id] > int(d.stack_cap):
			continue
		out.append(d)
	return out


# One category from nothing, folded part by part then row by row as from_parts does.
func _refold(category: String, counted: Array) -> void:
	last_dirty.append(category)
	match category:
		"mods":
			_sheet.mods = {}
			for d in counted:
				_fold_mods(d.mods)
			for row in _rows():
				_fold_mods(row.get("mods", {}))
		"patterns":
			_sheet.patterns = {}
			for d in counted:
				_fold_patterns(d.patterns)
			for row in _rows():
				_fold_patterns(row.get("patterns", {}))
		"elements":
			_sheet.triggers = {}
			for d in counted:
				_fold_elements(d.elements)
			for row in _rows():
				_fold_elements(row.get("elements", {}))
		"cooldown":
			_sheet.cooldown_scale = 1.0
			for d in counted:
				_sheet.cooldown_scale *= d.cooldown_scale
		"magnet":
			_sheet.magnet = 1.0
			for d in counted:
				_sheet.magnet *= d.magnet
		"kill_scrap":
			_sheet.kill_scrap = 1.0
			for d in counted:
				_sheet.kill_scrap *= d.kill_scrap
		"max_hp":
			_sheet.max_hp_bonus = 0.0
			for d in counted:
				_sheet.max_hp_bonus += d.max_hp_bonus
		"punch":
			_sheet.punch = 0.0
			for d in counted:
				_sheet.punch += d.punch


func _fold_mods(part_mods: Dictionary) -> void:
	for knob in part_mods:
		_sheet.mods[knob] = _sheet.mods.get(knob, 1.0) * part_mods[knob]


func _fold_patterns(part_patterns: Dictionary) -> void:
	for pattern in part_patterns:
		_sheet.patterns[pattern] = _sheet.patterns.get(pattern, 0) + part_patterns[pattern]


func _fold_elements(part_elements: Dictionary) -> void:
	for action in part_elements:
		var list: Array = _sheet.triggers.get(action, [])
		var given = part_elements[action]
		for element in (given if given is Array else [given]):
			if not element in list:
				list.append(element)
		_sheet.triggers[action] = list
