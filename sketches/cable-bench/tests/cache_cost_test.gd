extends SceneTree

const Stage := preload("res://src/stage.gd")
const Rules := preload("res://src/rules.gd")

var _stage
var _started := false


func _initialize() -> void:
	_stage = Stage.new()
	_stage.test_mode = true
	root.add_child(_stage)


func _process(_delta: float) -> bool:
	if not _started:
		if _stage.run == null:
			return false
		_started = true
		return false

	var rising := true
	var previous := 0
	var curve := []
	for tier in range(1, 9):
		var cost: int = Rules.cache_cost(tier)
		curve.append("t%d:%d" % [tier, cost])
		if cost <= previous:
			rising = false
		previous = cost
	print("[cache] cost curve %s -> %s" % [" ".join(curve), "PASS" if rising else "FAIL"])

	# The same rise has to reach a real cache in the stage, not just the formula.
	var cache = _stage.caches[0]
	_stage.run.stage_time = 0.0
	var early: int = cache.cost()
	_stage.run.stage_time = Rules.TIER_SECONDS * 4.0 + 1.0
	var late: int = cache.cost()
	var wired: bool = late > early and early == Rules.cache_cost(1) and late == Rules.cache_cost(5)
	print("[cache] a live cache charges %d at tier 1 and %d at tier %d -> %s"
		% [early, late, _stage.run.tier(), "PASS" if wired else "FAIL"])

	var ok: bool = rising and wired
	print("cache_cost_test: %s" % ("PASS" if ok else "FAIL"))
	_stage.free()
	quit(0 if ok else 1)
	return true
