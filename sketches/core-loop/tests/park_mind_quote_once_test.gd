extends SceneTree

# 2026-10-17 (dam authored pass, Andrew's Q9 "A musical quote"): the Mind's quote at the Eye's mouth plays once per run.
# The dam's eye_mouth row, placed on flat ground with a counting publish callable:
# (a) its ride sensor publishes layer_mind_quote_spillway on the first entry and stays silent on a second, as when the
#     ball bounces inside the box or crosses back;
# (b) the same row with an ordinary ride fact still publishes on every entry.
# Red before the guard: (a) counts two. Evidence limit: signal level only; no ball rolls through the Eye here.

const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const T := preload("res://tests/support/t.gd")
const PARK := "res://src/world/park/park_dam.json"
const QUOTE := "layer_mind_quote_spillway"

var _t := T.new("park_mind_quote_once_test")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var park: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PARK))
	var mouth: Dictionary = {}
	for row: Dictionary in park["park_rows"]:
		if row["id"] == "eye_mouth":
			mouth = row
	_t.eq("eye_mouth publishes the quote", String(mouth.get("ride_fact", "")), QUOTE)
	_t.eq("(a) the quote plays once over two entries", _entries(mouth, 2), [QUOTE])
	var plain := mouth.duplicate()
	plain["ride_fact"] = "ride_drop"
	_t.eq("(b) an ordinary ride fact publishes on each entry", _entries(plain, 2), ["ride_drop", "ride_drop"])
	quit(_t.verdict())


func _entries(row: Dictionary, times: int) -> Array:
	var heard: Array = []
	var parent := Node3D.new()
	root.add_child(parent)
	var node := ParkRecipes.place(row, parent, func(_x: float, _z: float) -> float: return 0.0,
		func(kind: String, _at: Vector3) -> void: heard.append(kind))
	var ball := Node3D.new()
	parent.add_child(ball)
	var area: Area3D = node.find_child("Ride", true, false) if node != null else null
	_t.check("%s has a ride sensor" % row["ride_fact"], area != null)
	if area != null:
		for i in times:
			area.body_entered.emit(ball)
	parent.free()
	return heard
