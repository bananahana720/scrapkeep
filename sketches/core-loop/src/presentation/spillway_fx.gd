extends Node3D

const Specs := preload("res://src/presentation/world_fx/world_fx_specs.gd")
const Anchor := preload("res://src/presentation/world_fx/world_fx_anchor.gd")
const ParkSites := preload("res://src/presentation/park_sites.gd")

# The Spillway parks' anchored effects (WORLD-FX.md, Specs.SPILL_PLACES): the powerhouse's steam, the
# weir's falls, the dam's spray curtain and the penstock tower's vent. Row sets stand at once; landmark
# sets wait for the park's rows to finish building (the landmark is placed last, over several frames),
# then stand in the landmark node's frame, so they move with it. Visual only; WorldFx ranks them into
# its anchor slots like any other anchor, so the live-particle ceiling holds.
const SEEK_EVERY := 0.25
# park_recipes.gd Placer.Phase.READY.
const PLACER_READY := 3

var stage_root: Node3D
var landmark_kind := ""
var placed: Array[Node3D] = []
var _rows: Node
var _wait := 0.0


# Hangs the park's effects under parent (the park's SpillwayScenery). sites reads the park's rows and ground.
static func place(parent: Node3D, stage_root_ref: Node3D, map, sites: ParkSites) -> Node3D:
	var fx: Node3D = load("res://src/presentation/spillway_fx.gd").new()
	fx.name = "SpillwayFx"
	fx.stage_root = stage_root_ref
	fx.landmark_kind = String(map.park.get("landmark", {}).get("kind", ""))
	parent.add_child(fx)
	var rows := {}
	for row in map.park["park_rows"]:
		rows[String(row["id"])] = row
	for place in Specs.SPILL_PLACES:
		for id in place.get("rows", []):
			if rows.has(id):
				fx._stand(place, rows[id], sites)
	fx.set_process(fx._landmark_place() != {})
	return fx


func _stand(place: Dictionary, row: Dictionary, sites: ParkSites) -> void:
	var f := ParkSites.frame(row)
	var at: Vector2 = f["at"]
	if place.get("foot", false):
		at += f["run"] * float(f["half_length"])
	var base := float(row["y"]) if row.get("y") != null else sites.height(at)
	var top := base + (0.0 if place.get("foot", false) else float(row["size"][1]))
	var a := Anchor.make(String(place["set"]))
	a.name = "WorldFx_%s_%s" % [place["set"], row["id"]]
	# The sets' directions point down +Z: turn +Z along the row's run.
	a.transform = Transform3D(Basis(Vector3.UP, ParkSites.yaw_toward(-f["run"])), Vector3(at.x, top + float(place.get("lift", 0.0)), at.y))
	add_child(a)
	placed.append(a)


func _landmark_place() -> Dictionary:
	for place in Specs.SPILL_PLACES:
		if String(place.get("landmark", "")) == landmark_kind and landmark_kind != "":
			return place
	return {}


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = SEEK_EVERY
	if _rows == null:
		_rows = stage_root.find_child("ParkRows", true, false) if is_instance_valid(stage_root) else null
		if _rows == null:
			return
	var landmark = _rows.get("landmark")
	if landmark is Node3D and is_instance_valid(landmark):
		set_process(false)
		stand_on_landmark(landmark)
	elif int(_rows.get("phase")) == PLACER_READY:
		# Built with no landmark (a proxy-free stand-in failed): nothing to stand on.
		set_process(false)


# Stands the park's landmark set in the landmark node's frame: at the mean of the named GLB nodes when
# all exist (the dam's gate leaves), else at the row's `local` point; then `offset`.
func stand_on_landmark(landmark: Node3D) -> Node3D:
	var place := _landmark_place()
	if place.is_empty():
		return null
	var local: Vector3 = place["local"]
	var nodes: Array = place.get("nodes", [])
	var found := nodes.map(func(n): return landmark.get_node_or_null(String(n))).filter(func(n): return n is Node3D)
	if not nodes.is_empty() and found.size() == nodes.size():
		local = Vector3.ZERO
		for n: Node3D in found:
			local += n.position
		local /= float(found.size())
	var a := Anchor.make(String(place["set"]))
	a.position = local + (place["offset"] as Vector3)
	landmark.add_child(a)
	placed.append(a)
	return a
