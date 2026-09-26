extends SceneTree

const Stage := preload("res://src/stage.gd")

const SIM := 60.0
const DT := 1.0 / 90.0

# The director is pure scheduling logic, so a whole stage's worth of escalation
# can be stepped here instead of waited out in real seconds.

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
		return false

	var first_spawn := -1.0
	var sim := 0.0
	var steps := int(SIM / DT)
	for i in steps:
		sim += DT
		_stage.step_director(DT)
		if first_spawn < 0.0 and _stage.enemy_count() > 0:
			first_spawn = sim

	var spawned: int = _stage.enemy_count()
	var tier: int = _stage.director.tier()
	var cap: int = _stage.director.cap()
	var any: bool = spawned > 0
	var escalated := tier >= 1
	var capped: bool = spawned <= cap
	print("director: %d enemies alive after %.0f simulated seconds, first at %.1f s -> %s"
		% [spawned, SIM, first_spawn, "PASS" if any else "FAIL"])
	print("director: tier %d after %.0f s (rises every %.0f s) -> %s"
		% [tier, SIM, _stage.director.TIER_SECONDS, "PASS" if escalated else "FAIL"])
	print("director: alive %d within the tier cap of %d -> %s"
		% [spawned, cap, "PASS" if capped else "FAIL"])

	var ok: bool = any and escalated and capped
	print("director_test: %s" % ("PASS" if ok else "FAILED"))
	_stage.free()
	quit(0 if ok else 1)
	return true
