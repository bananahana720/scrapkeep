extends RefCounted

const BuildSheet := preload("res://src/build/build_sheet.gd")
const Parts := preload("res://src/build/parts.gd")
const PartDef := preload("res://src/build/part_def.gd")
const Synergies := preload("res://src/build/synergies.gd")


signal recomputed(categories: Array)

const CATEGORIES := PartDef.STAT_CATEGORIES
const ROW_FED := ["mods", "patterns", "elements"]

var recomputes := 0
var last_dirty: Array = []
var _sheet: RefCounted
var _live: Array = []
var _held: Array = []
var _tier := -1
var _table = null
var _primed := false


func _init() -> void:
	_sheet = BuildSheet.new()


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
	var before: Array = _held
	_held = held.duplicate()
	_sheet.parts = held.duplicate()
	last_dirty = []
	if "synergy" in dirty:
		_refold_synergy(held, dirty, before)
	var pending: Array = CATEGORIES.filter(func(category): return category in dirty and not category in last_dirty)
	if not pending.is_empty():
		var counted := _counted(held)
		for category in pending:
			_refold(category, counted)
	recomputes += last_dirty.size()
	if not last_dirty.is_empty():
		recomputed.emit(last_dirty.duplicate())
	return copy()


func copy() -> RefCounted:
	var out: RefCounted = BuildSheet.new()
	for p in _sheet.get_property_list():
		if not p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			continue
		var value = _sheet.get(p["name"])
		out.set(p["name"], value.duplicate(true) if value is Array or value is Dictionary else value)
	return out


static func _touching(held: Array, category: String) -> Array:
	var out: Array = []
	for part_id in held:
		var d: Resource = Parts.def(part_id)
		if d != null and category in d.stat_touches:
			out.append(part_id)
	return out


func _refold_synergy(held: Array, dirty: Array, before: Array) -> void:
	var old_rows: Array = _live.duplicate()
	var old_evolved := _evolved_live(before)
	_live = Synergies.active(Parts.maker_counts(held))
	_sheet.synergies = _live.duplicate()
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
	if old_rows != _live:
		for category in ROW_FED:
			if not category in dirty:
				dirty.append(category)
	var now_evolved := _evolved_live(held)
	for part_id in Synergies.EVOLUTIONS:
		if (part_id in old_evolved) != (part_id in now_evolved) and part_id in held:
			for category in Parts.def(part_id).stat_touches:
				if not category in dirty:
					dirty.append(category)


static func _evolved_live(held: Array) -> Array:
	return Synergies.EVOLUTIONS.keys().filter(func(part_id): return part_id in held and Synergies.evolution_live(part_id, held))


func _rows() -> Array:
	return _live.map(func(key): return Synergies.ROWS[key])


func _counted(held: Array) -> Array:
	var out: Array = []
	var copies := {}
	for part_id in held:
		var d: Resource = Parts.def(part_id)
		if d == null:
			continue
		if not Synergies.evolution_live(part_id, held):
			continue
		copies[part_id] = copies.get(part_id, 0) + 1
		if not d.levels.is_empty():
			if copies[part_id] > 1:
				continue
			d = Parts.def_at(part_id, Parts.level_of(part_id, held))
		elif d.stack_rule != "hyperbolic" and d.stack_cap >= 1.0 and copies[part_id] > int(d.stack_cap):
			continue
		out.append(d)
	return out


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
