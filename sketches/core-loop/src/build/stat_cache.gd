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
		var counted := BuildSheet.counted_defs(held)
		var rows := _rows()
		for category in pending:
			last_dirty.append(category)
			_sheet.refold_category(category, counted, rows)
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
	_sheet.refold_category("synergy", [], _rows())
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
