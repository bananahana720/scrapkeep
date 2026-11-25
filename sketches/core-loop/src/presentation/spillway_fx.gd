extends Node3D

const Specs := preload("res://src/presentation/world_fx/world_fx_specs.gd")
const Anchor := preload("res://src/presentation/world_fx/world_fx_anchor.gd")
const ParkSites := preload("res://src/presentation/park_sites.gd")

const SEEK_EVERY := 0.25
const PLACER_READY := 3

var stage_root: Node3D
var landmark_kind := ""
var placed: Array[Node3D] = []
var _rows: Node
var _wait := 0.0


static func place(parent: Node3D, stage_root_ref: Node3D, map, sites: ParkSites) -> Node3D:
	var fx: Node3D = load("res://src/presentation/spillway_fx.gd").new()
	fx.name = "SpillwayFx"
	fx.stage_root = stage_root_ref
	fx.landmark_kind = String(map.park.get("landmark", {}).get("kind", ""))
	parent.add_child(fx)
	var rows := {}
	for row in map.park["park_rows"]:
		rows[String(row["id"])] = row
	for row_place in Specs.SPILL_PLACES:
		for id in row_place.get("rows", []):
			if rows.has(id):
				fx._stand(row_place, rows[id], sites)
	fx.set_process(fx._landmark_place() != {})
	return fx


func _stand(spot: Dictionary, row: Dictionary, sites: ParkSites) -> void:
	var f := ParkSites.frame(row)
	var at: Vector2 = f["at"]
	if spot.get("foot", false):
		at += f["run"] * float(f["half_length"])
	var base := float(row["y"]) if row.get("y") != null else sites.height(at)
	var top := base + (0.0 if spot.get("foot", false) else float(row["size"][1]))
	var a := Anchor.make(String(spot["set"]))
	a.name = "WorldFx_%s_%s" % [spot["set"], row["id"]]
	a.transform = Transform3D(Basis(Vector3.UP, ParkSites.yaw_toward(-f["run"])), Vector3(at.x, top + float(spot.get("lift", 0.0)), at.y))
	add_child(a)
	placed.append(a)


func _landmark_place() -> Dictionary:
	for spot in Specs.SPILL_PLACES:
		if String(spot.get("landmark", "")) == landmark_kind and landmark_kind != "":
			return spot
	return {}


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = SEEK_EVERY
	if not is_instance_valid(_rows):
		_rows = stage_root.get_node_or_null("ParkRows") if is_instance_valid(stage_root) else null
		if _rows == null:
			return
	var landmark = _rows.get("landmark")
	if landmark is Node3D and is_instance_valid(landmark):
		set_process(false)
		stand_on_landmark(landmark)
	elif int(_rows.get("phase")) == PLACER_READY:
		set_process(false)


func stand_on_landmark(landmark: Node3D) -> Node3D:
	var spot := _landmark_place()
	if spot.is_empty():
		return null
	var local: Vector3 = spot["local"]
	var nodes: Array = spot.get("nodes", [])
	var found := nodes.map(func(n): return landmark.get_node_or_null(String(n))).filter(func(n): return n is Node3D)
	if not nodes.is_empty() and found.size() == nodes.size():
		local = Vector3.ZERO
		for n: Node3D in found:
			local += n.position
		local /= float(found.size())
	var a := Anchor.make(String(spot["set"]))
	a.position = local + (spot["offset"] as Vector3)
	landmark.add_child(a)
	placed.append(a)
	return a
