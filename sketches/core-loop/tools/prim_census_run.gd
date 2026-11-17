extends "res://tools/bot_run.gd"

# The primitive census over a bot run: tools/bot_run.gd (same flags) plus a scan every
# --census-every ticks (default 30) that prints one tab-separated line for each primitive surface
# first drawn (tools/prim_census.gd says what counts and how the pin judges it):
#   PRIM <tick> <stage> <verdict> <owner> <mesh> <shape> <path>
# verdict is "code", "stand-in:<BACKLOG row>" or "NEW" (no pin row covers it: the test fails on it).
# The world 1 pass the test runs, and the one to run before and after a stand-in row:
#   godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/prim_census_run.gd -- \
#     --out=artifacts/local/prim --table=park --policy=skipper --pilot=pylon_engineer --seeds=40317 --until=2
# --prim-plant=1 (the test's control) hangs a BoxMesh named PlantedStandIn on the first park
# activity it finds; the census must call it NEW.

const PrimCensus := preload("res://tools/prim_census.gd")
const PLANT_NAME := "PlantedStandIn"

var _census := PrimCensus.new()
var _pin: Array[Dictionary] = PrimCensus.load_pin()
var _planted := false
var _due := []


func _physics_process(delta: float) -> bool:
	# The scan a tick asked for runs at the start of the next one, when everything that tick built and
	# queued has run. A deferred scan was not enough: this step runs before the game's nodes, so the scan
	# was queued ahead of the dressing a node queues in the same tick (hero_assets dresses a reward gate
	# by call_deferred from node_added), and a gate built on a scan tick was listed bare (wave 43 gate).
	if not _due.is_empty():
		_scan(_due[0], _due[1])
		_due = []
	var out := super._physics_process(delta)
	if _game == null or _ticks % maxi(1, int(_settings.get("census-every", "30"))) != 0:
		return out
	if _settings.get("prim-plant", "0") == "1" and not _planted:
		_plant()
	_due = [_ticks, int(_game.run.stage) if _game.get("run") != null else 0]
	return out


func _scan(tick: int, stage: int) -> void:
	for row in _census.scan(root, tick, stage):
		var p := PrimCensus.pin_for(row, _pin)
		var verdict := "NEW" if p.is_empty() else ("code" if p.kind == "code" else "%s:%s" % [p.kind, p.row])
		print("PRIM\t%d\t%d\t%s\t%s\t%s\t%s\t%s" % [row.tick, row.stage, verdict, row.owner, row.mesh, row.shape, row.path])


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
