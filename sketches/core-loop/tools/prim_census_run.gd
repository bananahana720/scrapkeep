extends "res://tools/bot_run.gd"


const PrimCensus := preload("res://tools/prim_census.gd")
const PLANT_NAME := "PlantedStandIn"
const BARE_GATE_NAME := "PlantedBareGate"

var _pin: Array[Dictionary] = PrimCensus.load_pin()
var _listed := {}
var _planted := false
var _planted_gate := false
var _due := []
var _young := {}
var _young_frame := -1


func _physics_process(delta: float) -> bool:
	if not _due.is_empty():
		var due := _due
		_due = []
		if _settings.get("prim-plant", "0") == "1" and not _planted_gate:
			_plant_bare_gate()
		_scan(due[0], due[1])
	var out := super._physics_process(delta)
	if _game == null or _ticks % maxi(1, int(_settings.get("census-every", "30"))) != 0:
		return out
	if _settings.get("prim-plant", "0") == "1" and not _planted:
		_plant()
	_due = [_ticks, int(_game.run.stage) if _game.get("run") != null else 0]
	_listen(true)
	return out


func _listen(on: bool) -> void:
	if on and not node_added.is_connected(_on_node_added):
		node_added.connect(_on_node_added)
	elif not on and node_added.is_connected(_on_node_added):
		node_added.disconnect(_on_node_added)
		_young.clear()


func _on_node_added(node: Node) -> void:
	if not node is GeometryInstance3D:
		return
	var frame := Engine.get_process_frames()
	if frame != _young_frame:
		_young.clear()
		_young_frame = frame
	_young[node.get_instance_id()] = true


func _settling(node: Node) -> bool:
	return node != null and _young_frame == Engine.get_process_frames() and _young.has(node.get_instance_id())


func _scan(tick: int, stage: int) -> void:
	var settling := false
	for row in PrimCensus.new().scan(root, tick, stage):
		if _listed.has(row.key):
			continue
		if _settling(root.get_node_or_null(NodePath(row.path))):
			settling = true
			continue
		_listed[row.key] = true
		var p := PrimCensus.pin_for(row, _pin)
		var verdict := "NEW" if p.is_empty() else ("code" if p.kind == "code" else "%s:%s" % [p.kind, p.row])
		print("PRIM\t%d\t%d\t%s\t%s\t%s\t%s\t%s" % [row.tick, row.stage, verdict, row.owner, row.mesh, row.shape, row.path])
	if settling and _due.is_empty():
		_due = [tick, stage]
	_listen(not _due.is_empty())


func _plant() -> void:
	var activities := root.find_child("Activities", true, false)
	if activities == null:
		return
	for child in activities.get_children():
		if String(child.name).begins_with("Activity_") and child is Node3D:
			var plant := MeshInstance3D.new()
			plant.name = PLANT_NAME
			plant.mesh = BoxMesh.new()
			child.add_child(plant)
			_planted = true
			return


func _plant_bare_gate() -> void:
	var gates := root.find_child("RewardGates", true, false)
	if gates == null or not gates.has_method("is_open") or not gates.is_open():
		return
	var gate := Node3D.new()
	gate.name = BARE_GATE_NAME
	gate.position = Vector3(0.0, -50.0, 0.0)
	gates.add_child(gate)
	var post := MeshInstance3D.new()
	post.mesh = BoxMesh.new()
	gate.add_child(post)
	_planted_gate = true
