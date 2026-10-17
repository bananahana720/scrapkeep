extends SceneTree

const ParkSchema := preload("res://src/world/park/park_schema.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const T := preload("res://tests/support/t.gd")

# The crown's place layers (stage 6 page sections 11 and 17; journey board gap 9): a park row's music_layer is
# published by its ride sensor beside its ride fact, and a group row with no recipe (the hoodoo forest) gets a sensor
# that publishes the layer alone. The toppled route's layer waits for the strike's runtime swap: on the unswapped
# spire_top_ramp its sensor sat on the main line and played before any strike (bot audit, 2026-10-17). The crown ramp's
# layer waits too: the ramp sits inside the Warden's bowl, the ball re-crossed it mid-fight, and each layer change moved
# the on-bar telegraphs (skipper stage 6 seed 2 broke the Warden at fight tick 14410 instead of 6262). The ball entering is driven by emitting the sensor's
# body_entered by hand; whether the music thread's render plays is not checked here.

const CROWN := "res://src/world/park/park_crown.json"
const LAYERS := {"hoodoo_forest": "layer_crown_hoodoos", "alcove_ledge": "layer_crown_alcove"}

var _t := T.new("park_music_layers_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var read := ParkSchema.load_park(CROWN)
	_t.eq("the crown loads", read["errors"], [])
	var park: Dictionary = read["data"]
	var rows := {}
	for row in park["park_rows"]:
		rows[row["id"]] = row
	for id in LAYERS:
		_t.eq("%s names its layer" % id, String(rows[id].get("music_layer", "")), LAYERS[id])
		_t.check("%s's layer is a WORLD_ROWS kind" % id, EventKinds.WORLD_ROWS.has(LAYERS[id]), LAYERS[id])
	_t.eq("the layer-only rows are the recipe-less ones", ParkRecipes.layer_rows(park).map(func(r): return r["id"]),
		["hoodoo_forest"])
	_t.check("the unswapped spire top ramp carries no layer yet", not rows["spire_top_ramp"].has("music_layer"), "")
	_t.check("the in-arena crown ramp carries no layer", not rows["crown_ramp"].has("music_layer"), "")

	var parent := Node3D.new()
	root.add_child(parent)
	var ball := Node3D.new()
	parent.add_child(ball)
	var heard: Array = []
	var publish := func(fact: String, _at: Vector3) -> void: heard.append(fact)

	var forest := ParkRecipes.place_layer(rows["hoodoo_forest"], parent, Callable(), publish)
	(forest.get_node("Ride") as Area3D).body_entered.emit(ball)
	_t.eq("the forest's sensor publishes its layer alone, not the members' grapple fact", heard, ["layer_crown_hoodoos"])
	_t.eq("the forest's sensor places no view and no collider", forest.get_child_count(), 1)

	heard.clear()
	var ledge := Node3D.new()
	parent.add_child(ledge)
	ParkRecipes._sensor(ledge, rows["alcove_ledge"], publish)
	(ledge.get_node("Ride") as Area3D).body_entered.emit(ball)
	_t.eq("a placed row's sensor publishes its ride fact then its layer", heard, ["ride_ledge", "layer_crown_alcove"])

	heard.clear()
	var plain := Node3D.new()
	parent.add_child(plain)
	ParkRecipes._sensor(plain, rows["turnstone"], publish)
	(plain.get_node("Ride") as Area3D).body_entered.emit(ball)
	_t.eq("a row with no layer publishes its ride fact only", heard, ["ride_bowl"])
	parent.free()
	quit(_t.verdict())
