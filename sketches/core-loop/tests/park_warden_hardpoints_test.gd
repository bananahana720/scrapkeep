extends SceneTree

# Rule (design-v3/park/LANDMARK-CARDS.md port note P4, fact 5): the dam, the flume and the sinkhole give their Warden
# the three hardpoints their landmark GLB carries as hp_0 to hp_2 empties. The spec's "hardpoint_offsets" are offsets
# from the Warden body in world axes; the body stands exactly on landmark.warden.anchor (warden.gd setup), so each
# offset is the empty's world position (the landmark row's transform applied to the GLB empty) minus the anchor.
# The pit, the islands and the crown give none, and keep warden.gd's three body offsets.
# Rope: every hardpoint is within the rope range (Tuning rope_range, 45 m) of the landmark beacon, measured flat
# (the beacon is a map point with no height), except the sinkhole's two ring posts, which the card puts at (+-20, 3, 5)
# from the nest: 47.4 m flat from the beacon centre, so they are checked against the engage ring's edge (reach_m)
# and pinned at the measured distance. The dam's piers sit 20 m apart, inside the reactor's 24 m sheet.

const T := preload("res://tests/support/t.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const Warden := preload("res://src/combat/warden.gd")
const WardenReactor := preload("res://src/combat/warden_reactor.gd")
const Tuning := preload("res://src/movement/tuning.gd")

const WITH_OFFSETS := ["park_dam", "park_flume", "park_sinkhole"]
const WITHOUT_OFFSETS := ["park_pit", "park_islands", "park_crown"]
const EMPTIES := ["hp_0", "hp_1", "hp_2"]
const TOLERANCE_M := 0.05
const SINKHOLE_BEACON_FLAT_M := 47.4
const SINKHOLE_BEACON_PIN_M := 0.1

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
	var beacon := Vector3(float(mark["beacon"][0]), 0.0, float(mark["beacon"][1]))
	var reach := float(mark["reach_m"])
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
	for i in hardpoints.size():
		var flat := Vector2(hardpoints[i].x - beacon.x, hardpoints[i].z - beacon.z).length()
		if map_id == "park_sinkhole" and i > 0:
			t.near("%s hp_%d flat distance to the beacon centre (pinned)" % [map_id, i], flat, SINKHOLE_BEACON_FLAT_M, SINKHOLE_BEACON_PIN_M)
			t.check("%s hp_%d within rope range of the engage ring's edge" % [map_id, i], flat - reach <= rope, "%.1f m" % (flat - reach))
		else:
			t.check("%s hp_%d within rope range of the beacon" % [map_id, i], flat <= rope, "%.1f m of %.0f" % [flat, rope])
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
