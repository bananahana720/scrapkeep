extends SceneTree

# Rule (design-v3/park/LANDMARK-CARDS.md port note P4, fact 5): the dam, the flume and the sinkhole give their Warden
# the three hardpoints their landmark GLB carries as hp_0 to hp_2 empties. The spec's "hardpoint_offsets" are offsets
# from the Warden body in world axes; the body stands exactly on landmark.warden.anchor (warden.gd setup), so each
# offset is the empty's world position (the landmark row's transform applied to the GLB empty) minus the anchor.
# The pit, the islands and the crown give none, and keep warden.gd's three body offsets.
# What each card claims of the two flank hardpoints (hp_1, hp_2):
# - dam (card 1): about 28 m from the beacon at ground level, in 3D, inside the rope range (Tuning rope_range, 45 m).
#   Measured at the y datum (28.4 m); on the baked ground at the beacon (1.05 m lower) it is 29.3 m, still inside the rope.
# - flume (card 2): the channel cheeks, 5 m either side of the channel axis (flat offset from the body) and 4 m up.
# - sinkhole (card 4): the ring_post_e and ring_post_w rows' world x/z in park_sinkhole.json.
# The dam's piers sit 20 m apart, inside the reactor's 24 m sheet.

const T := preload("res://tests/support/t.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const Warden := preload("res://src/combat/warden.gd")
const WardenReactor := preload("res://src/combat/warden_reactor.gd")
const ParkGraphTool := preload("res://tools/park_graph.gd")
const Terrain := preload("res://src/world/terrain.gd")
const Tuning := preload("res://src/movement/tuning.gd")

const WITH_OFFSETS := ["park_dam", "park_flume", "park_sinkhole"]
const WITHOUT_OFFSETS := ["park_pit", "park_islands", "park_crown"]
const EMPTIES := ["hp_0", "hp_1", "hp_2"]
const TOLERANCE_M := 0.05
const DAM_BEACON_M := 28.0
const DAM_BEACON_TOLERANCE_M := 1.0
const FLUME_CHEEK_OUT_M := 5.0
const FLUME_CHEEK_UP_M := 4.0

var t := T.new("park_warden_hardpoints_test")


# Whether `offset` puts the hardpoint on `empty_world` for a body at `body`, within `tolerance`.
static func offset_matches(offset: Vector3, body: Vector3, empty_world: Vector3, tolerance: float) -> bool:
	return (body + offset).distance_to(empty_world) <= tolerance


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var rope := Tuning.new().f("rope_range")
	t.near("rope range is the cards' 45 m", rope, 45.0)
	for map_id: String in WITH_OFFSETS:
		_park(map_id, rope)
	for map_id: String in WITHOUT_OFFSETS:
		var park := _load(map_id)
		var spec: Dictionary = park["landmark"]["warden"]
		t.check("%s carries no hardpoint_offsets" % map_id, not spec.has("hardpoint_offsets"))
		t.eq("%s keeps the three body offsets" % map_id, Warden.hardpoints_for(spec), Warden.HARDPOINTS)
	_control()
	quit(t.verdict())


func _load(map_id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/%s.json" % map_id))


func _park(map_id: String, rope: float) -> void:
	var park := _load(map_id)
	var mark: Dictionary = park["landmark"]
	var spec: Dictionary = mark["warden"]
	var a: Array = spec["anchor"]
	var body := Vector3(a[0], a[1], a[2])
	var offsets := Warden.hardpoints_for(spec)
	t.eq("%s spec yields three hardpoints" % map_id, offsets.size(), 3)
	var row := ParkRecipes.landmark_row(park)
	var xf := ParkRecipes.row_transform(row)
	var scene: Node3D = (load("res://assets/models/park/%s.glb" % String(mark["recipe"])) as PackedScene).instantiate()
	root.add_child(scene)
	var anchor_empty := scene.find_child("warden_anchor", true, false) as Node3D
	t.check("%s GLB carries warden_anchor" % map_id, anchor_empty != null)
	if anchor_empty != null:
		t.near("%s warden_anchor lands on the spec anchor" % map_id, (xf * anchor_empty.global_transform.origin).distance_to(body), 0.0, TOLERANCE_M)
	var hardpoints: Array[Vector3] = []
	for i in EMPTIES.size():
		var empty := scene.find_child(EMPTIES[i], true, false) as Node3D
		if not t.check("%s GLB carries %s" % [map_id, EMPTIES[i]], empty != null) or offsets.size() <= i:
			continue
		var world: Vector3 = xf * empty.global_transform.origin
		var offset: Vector3 = offsets[i]
		t.check("%s %s offset %s is its empty (world %s) minus the body" % [map_id, EMPTIES[i], offset, world],
			offset_matches(offset, body, world, TOLERANCE_M))
		hardpoints.append(body + offset)
	scene.queue_free()
	if hardpoints.size() == 3:
		match map_id:
			"park_dam":
				var bake := ParkGraphTool.load_bake("res://assets/park/park_dam")
				var ground := float(Terrain._park_floor_at(float(mark["beacon"][0]), float(mark["beacon"][1]), bake["ground"], bake["holes"], bake["under"]))
				# The card measures from the beacon at the landmark's y datum (0); the baked ground there is 1.05 m lower,
				# which puts the piers 29.3 m away. Both are checked: the card's 28 m at the datum, the rope on the baked ground.
				var datum := Vector3(float(mark["beacon"][0]), ParkRecipes.landmark_datum(mark), float(mark["beacon"][1]))
				var baked := Vector3(datum.x, ground, datum.z)
				for i in [1, 2]:
					t.near("park_dam hp_%d 3D distance to the beacon at the datum (card: about 28 m)" % i, hardpoints[i].distance_to(datum), DAM_BEACON_M, DAM_BEACON_TOLERANCE_M)
					var d := hardpoints[i].distance_to(baked)
					t.check("park_dam hp_%d within rope range of the beacon on the baked ground (%.2f)" % [i, ground], d < rope, "%.2f m of %.0f" % [d, rope])
			"park_flume":
				for i in [1, 2]:
					var off: Vector3 = offsets[i]
					t.near("park_flume hp_%d flat offset" % i, Vector2(off.x, off.z).length(), FLUME_CHEEK_OUT_M, TOLERANCE_M)
					t.near("park_flume hp_%d is 4 m up" % i, off.y, FLUME_CHEEK_UP_M, TOLERANCE_M)
			"park_sinkhole":
				var posts := {}
				for prow: Dictionary in park["park_rows"]:
					if String(prow["id"]).begins_with("ring_post_"):
						posts[String(prow["id"])] = prow
				for pair in [[1, "ring_post_e"], [2, "ring_post_w"]]:
					var ok: bool = posts.has(pair[1])
					t.check("park_sinkhole has %s" % pair[1], ok)
					if ok:
						var at: Array = posts[pair[1]]["at"]
						var flat := Vector2(hardpoints[pair[0]].x - float(at[0]), hardpoints[pair[0]].z - float(at[1])).length()
						t.near("park_sinkhole hp_%d sits on %s" % [pair[0], pair[1]], flat, 0.0, TOLERANCE_M)
	if map_id == "park_dam" and hardpoints.size() == 3:
		var apart := hardpoints[1].distance_to(hardpoints[2])
		t.near("park_dam piers sit 20 m apart", apart, 20.0, TOLERANCE_M)
		t.near("park_dam piers stand level with the relic", hardpoints[1].y, body.y, TOLERANCE_M)
		t.check("park_dam piers sit inside the %.0f m sheet" % WardenReactor.SHEET_WIDTH,
			absf(hardpoints[1].x - body.x) <= WardenReactor.SHEET_WIDTH * 0.5 and absf(hardpoints[2].x - body.x) <= WardenReactor.SHEET_WIDTH * 0.5)


# Planted control: a wrong offset must fail the comparison, and the right one pass it.
func _control() -> void:
	var body := Vector3(0.0, 22.0, 590.0)
	var empty := Vector3(-10.0, 22.0, 590.0)
	t.check("control: the right offset matches", offset_matches(Vector3(-10.0, 0.0, 0.0), body, empty, TOLERANCE_M))
	t.check("control: a wrong offset fails", not offset_matches(Vector3(10.0, 0.0, 0.0), body, empty, TOLERANCE_M))
	t.check("control: a slightly wrong offset fails", not offset_matches(Vector3(-10.0, 0.1, 0.0), body, empty, TOLERANCE_M))
