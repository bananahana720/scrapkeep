extends SceneTree

const Stage := preload("res://src/stage.gd")
const Terrain := preload("res://src/terrain.gd")
const FloodCycle := preload("res://src/flood_cycle.gd")

const DT := 1.0 / 90.0

# The flood is the stage's clock and the only thing that uncovers the secret, so
# one stepped cycle has to reach every phase and leave the hatch open.

var _stage
var _started := false


func _initialize() -> void:
	_stage = Stage.new()
	_stage.test_mode = true
	root.add_child(_stage)


func _process(_delta: float) -> bool:
	if not _started:
		if _stage.player == null:
			return false
		_started = true
		_stage.director.paused = true
		return false

	var cycle = _stage.flood.cycle
	var secret = _stage._secret
	var hidden_at_start: bool = not secret.revealed
	var seen := {}
	var peak := -99.0
	var steps := int((cycle.cycle_seconds() + 2.0) / DT)
	for i in steps:
		cycle.advance(DT)
		seen[cycle.phase] = true
		peak = maxf(peak, cycle.depth(Terrain.FLOOD_DEPTH))

	var all_phases: bool = seen.size() == FloodCycle.DURATIONS.size()
	var flooded: bool = peak >= Terrain.FLOOD_DEPTH - 0.01
	var end_depth: float = cycle.depth(Terrain.FLOOD_DEPTH)
	var drained: bool = end_depth < 0.0
	var revealed_flag: bool = cycle.hatch_revealed()

	# Drive one stage tick so the reveal goes through the real path, not the flag.
	_stage._physics_process(DT)
	var opened: bool = secret.revealed

	# Standing on the drained basin floor: the parked plane is below it, so this
	# must read as dry even though it is the lowest point on the stage.
	var dry_point := Terrain.at(Terrain.HATCH, 1.0)
	var dry_accel: Vector3 = _stage.flood.external_accel(dry_point, Vector3(0.0, 0.0, 14.0))
	cycle.phase = FloodCycle.HIGH
	cycle.elapsed = 0.0
	_stage.flood.step(0.0)
	var wet_point := Vector3(Terrain.BASIN_CENTRE.x, _stage.flood.surface_y() - 1.0, Terrain.BASIN_CENTRE.y)
	var wet_accel: Vector3 = _stage.flood.external_accel(wet_point, Vector3(0.0, 0.0, 14.0))
	var drags: bool = wet_accel.z < -1.0 and dry_accel == Vector3.ZERO

	print("flood: %d of %d phases reached in one %.0f s cycle -> %s"
		% [seen.size(), FloodCycle.DURATIONS.size(), cycle.cycle_seconds(), "PASS" if all_phases else "FAIL"])
	print("flood: peak depth %.2f m then drained to %.2f m -> %s"
		% [peak, end_depth, "PASS" if flooded and drained else "FAIL"])
	print("flood: hatch flagged %s and the secret cache is visible %s -> %s"
		% [revealed_flag, opened, "PASS" if hidden_at_start and revealed_flag and opened else "FAIL"])
	print("flood: submerged ball gets %.2f m/s^2 along its travel, dry ball gets none -> %s"
		% [wet_accel.z, "PASS" if drags else "FAIL"])

	var ok: bool = all_phases and flooded and drained and hidden_at_start and revealed_flag and opened and drags
	print("flood_test: %s" % ("PASS" if ok else "FAILED"))
	_stage.free()
	quit(0 if ok else 1)
	return true
