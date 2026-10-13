extends SceneTree

# KE-FORMS: every authored park event row names a telegraph form with a WORLD_ROWS record,
# a landed record and a PARK_LAND_FACTS mapping, and the five pending forms run through the
# director (registered, telegraphed and, for the natural rows, landed).

const Director := preload("res://src/world/event_director.gd")
const Kinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const H := 0.05
const FAR := Vector3(1000.0, 1.0, 1000.0)
const PARK_DIR := "res://src/world/park"
const FIXTURE := "res://tests/fixtures/park_event_forms_pending.json"
# A floor, not an exact count (coordinator, 2026-10-13): each stage merge adds park files and rows.
const MIN_ROWS := 22
const EXPECTED_STEPPED := 6
const PENDING_FORMS := ["crust_crack", "drain_gurgle", "trestle_groan", "lightning_mark", "reactor_overload"]
const PENDING_LANDED := ["crust_crack_landed", "drain_landed", "trestle_landed", "lightning_mark_landed", "reactor_landed"]
# Hostile telegraphs take the hazard colour; the drain opens a route, so it is a ride in the sandstone colour.
const FORM_COLOUR := {"crust_crack": Palette.HAZARD, "drain_gurgle": Palette.SANDSTONE,
	"trestle_groan": Palette.HAZARD, "lightning_mark": Palette.HAZARD, "reactor_overload": Palette.HAZARD}

class Map:
	extends RefCounted
	var park := {}

var _failures := 0
var _rows: Array = []


func _initialize() -> void:
	_collect()
	_records()
	_grammar()
	_stepped()
	print("park_event_forms_test: PASS" if _failures == 0 else "park_event_forms_test: FAIL")
	quit(0 if _failures == 0 else 1)


func _collect() -> void:
	var dir := DirAccess.open(PARK_DIR)
	var names := []
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("park_") and name.ends_with(".json"):
			names.append(name)
		name = dir.get_next()
	names.sort()
	for file in names:
		for row in _load(PARK_DIR + "/" + file).get("event_rows", []):
			_rows.append({"source": file, "row": row})
	for row in _load(FIXTURE).get("event_rows", []):
		_rows.append({"source": "fixture", "row": row})


func _load(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _records() -> void:
	var checked := 0
	for entry in _rows:
		var row: Dictionary = entry.row
		var form := str(row.telegraph.form)
		var landed := str(Director.PARK_LAND_FACTS.get(form, ""))
		var has_telegraph := not Kinds.world_row(form).is_empty()
		var has_landed := landed != "" and not Kinds.world_row(landed).is_empty()
		var mapped := Director.PARK_LAND_FACTS.has(form)
		checked += 1
		_check("%s %s" % [entry.source, row.id], has_telegraph and has_landed and mapped,
			"form=%s landed=%s telegraph_record=%s landed_record=%s mapped=%s" % [form, landed, has_telegraph, has_landed, mapped])
	_check("rows checked", checked >= MIN_ROWS, "%d rows checked, at least %d" % [checked, MIN_ROWS])
	print("park_event_forms_test: rows checked %d" % checked)


func _grammar() -> void:
	# Colour from Palette, and sounds drawn only from names the existing WORLD_ROWS already use.
	var existing_sounds := {}
	for key in Kinds.WORLD_ROWS:
		if key in PENDING_FORMS or key in PENDING_LANDED:
			continue
		existing_sounds[Kinds.WORLD_ROWS[key].get("sound", "")] = true
		existing_sounds[Kinds.WORLD_ROWS[key].get("sound_next", "")] = true
	for form in PENDING_FORMS:
		var record: Dictionary = Kinds.world_row(form)
		var ok: bool = record.get("color") == FORM_COLOUR[form]
		var sounds_ok: bool = existing_sounds.has(record.get("sound", "")) and existing_sounds.has(record.get("sound_next", ""))
		_check("grammar %s" % form, ok and sounds_ok, "colour_ok=%s sounds_from_existing=%s sound=%s next=%s" % [ok, sounds_ok, record.get("sound", ""), record.get("sound_next", "")])


func _stepped() -> void:
	var fixture: Array = _load(FIXTURE).get("event_rows", [])
	for row in fixture:
		var form := str(row.telegraph.form)
		var landed := str(Director.PARK_LAND_FACTS.get(form, ""))
		var natural: bool = row.family == "natural"
		var sites := {}
		var route_ids := {}
		for id in row.route_change.closes + row.route_change.opens:
			route_ids[id] = true
		# A base route keeps the landmark reachable; the director holds any row whose route graph is unreachable.
		route_ids["main"] = true
		var routes := []
		for id in route_ids:
			routes.append({"id": id, "from": "drop_in", "to": "landmark", "via": []})
		sites[row.site] = true
		var park_rows := []
		for id in sites:
			park_rows.append({"id": id, "at": [0, 0], "y": 0.0, "size": [20, 2, 20], "yaw_deg": 0})
		var map := Map.new()
		map.park = {"map": "fixture", "event_rows": [row], "weather_rows": [], "park_rows": park_rows, "routes": routes}
		var d = Director.new(813, {}, map, 14.0, func(_x, _z): return 0.0)
		var registered := false
		for state in d._park_states:
			registered = registered or state.row.id == row.id
		var facts := []
		for i in 1200:
			var context := {"clock_tier": 4, "warden_phases": ["chunk_2"] if i == 0 else []}
			var ctx := {"clock_tier": 4, "grounded": true, "bar_s": 240.0 / 172.0, "bar_origin_s": 0.0}
			ctx.merge(context, true)
			facts.append_array(d.advance(H, FAR, Vector3.ZERO, ctx))
		var telegraphed := facts.any(func(f): return f.kind == "announced" and f.id == row.id)
		var did_land := facts.any(func(f): return f.kind == "world" and f.id == row.id and f.phase == "land" and f.fact == landed)
		var ok := registered and telegraphed and (did_land if natural else true)
		var seen := []
		for f in facts:
			if f.id == row.id:
				seen.append("%s/%s" % [f.kind, f.get("phase", "")])
		_check("stepped %s" % row.id, ok,
			"form=%s registered=%s telegraphed=%s landed=%s facts=%s" % [form, registered, telegraphed, did_land if natural else "not asserted (industrial)", seen.slice(0, 12)])
	_check("stepped rows", fixture.size() == EXPECTED_STEPPED, "%d stepped rows, expected %d" % [fixture.size(), EXPECTED_STEPPED])


func _check(label: String, ok: bool, detail: String) -> void:
	_failures += int(not ok)
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
