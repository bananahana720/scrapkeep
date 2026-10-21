extends SceneTree

# 2026-10-17 (dam authored pass, Andrew's Q9 "A musical quote"): the Mind's quote at the Eye's mouth plays once per run.
# The dam's eye_mouth row, placed on flat ground with a counting publish callable:
# (a) its ride sensor publishes layer_mind_quote_spillway on the first entry and stays silent on a second, as when the
#     ball bounces inside the box or crosses back;
# (b) the same row with an ordinary ride fact still publishes on every entry;
# (c) 2026-10-18 (Andrew's "All hands"): the crest crane, crest_rail's rider, swings its jib once on the quote's first
#     entry, RIDER_SWING_DEG about its own mast, and the mast stays put; a second entry leaves it where it stopped. Built
#     through ParkRecipes.build_placed on the baked ground, so a crane the stage builder drops turns this red.
# Red before the guard: (a) counts two. Evidence limit: signal level only; no ball rolls through the Eye here.

const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const T := preload("res://tests/support/t.gd")
const ParkGraphTool := preload("res://tools/park_graph.gd")
const Terrain := preload("res://src/world/terrain.gd")
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
	_check_crane(park, mouth)
	quit(_t.verdict())


func _check_crane(park: Dictionary, _mouth: Dictionary) -> void:
	var rail: Dictionary = {}
	for row: Dictionary in park["park_rows"]:
		if row.has("rider"):
			rail = row
	_t.eq("crest_rail carries the crane", [String(rail.get("id", "")), String(rail.get("rider", {}).get("recipe", ""))], ["crest_rail", "dam_crest_crane"])
	# Through the stage's own builder, on the baked ground, as the game places it.
	var parent := Node3D.new()
	root.add_child(parent)
	var bake := ParkGraphTool.load_bake("res://assets/park/park_dam")
	var ground := Terrain._park_floor_at.bind(bake["ground"], bake["holes"], bake["under"])
	var heard: Array = []
	var rows: Node3D = ParkRecipes.build_placed(parent, park, ground, func(kind: String, _a: Vector3) -> void: heard.append(kind), false)
	var crane: Node3D = rows.get_node_or_null("Park_%s_rider" % rail["id"])
	var mouth: Node3D = rows.get_node_or_null("Park_eye_mouth")
	var jib: MeshInstance3D = crane.find_child("*_jib", true, false) if crane != null else null
	var mast: MeshInstance3D = crane.find_child("dam_crest_crane", true, false) if crane != null else null
	var at: Array = rail["rider"]["at"]
	if not _t.check("(c) the stage builder stands the crane on the crest at its rider place, with a mast and a jib", crane != null and jib != null
			and mast != null and mouth != null and crane.position.is_equal_approx(Vector3(float(at[0]), float(ground.call(float(at[0]), float(at[1]))), float(at[1])))):
		parent.free()
		return
	var tip := Vector3(0, 28.0, 34.0)
	var jib_start := jib.transform
	var mast_start := mast.transform
	var area: Area3D = mouth.find_child("Ride", true, false)
	var ball := Node3D.new()
	parent.add_child(ball)
	area.body_entered.emit(ball)
	_t.eq("(c) the quote fires once through the built stage", heard, ["layer_mind_quote_spillway"])
	var tweens := get_processed_tweens()
	_t.eq("(c) the quote's first entry starts one swing", tweens.size(), 1)
	for tween in tweens:
		tween.custom_step(ParkRecipes.RIDER_SWING_S + 0.1)
	var before := jib_start * tip
	var after := jib.transform * tip
	var turned := Vector2(before.x, before.z).angle_to(Vector2(after.x, after.z))
	_t.near("(c) the jib's tip turned %.1f degrees about the mast" % -rad_to_deg(turned), -rad_to_deg(turned), ParkRecipes.RIDER_SWING_DEG, 0.5)
	_t.check("(c) the tip kept its reach and height (a turn about the mast's axis)", is_equal_approx(Vector2(before.x, before.z).length(),
		Vector2(after.x, after.z).length()) and is_equal_approx(before.y, after.y))
	_t.check("(c) the mast stayed put", mast.transform.is_equal_approx(mast_start))
	var stopped := jib.transform
	area.body_entered.emit(ball)
	_t.check("(c) a second entry starts no swing and leaves the jib where it stopped",
		get_processed_tweens().all(func(tw: Tween) -> bool: return not tw.is_running()) and jib.transform.is_equal_approx(stopped))
	parent.free()


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
