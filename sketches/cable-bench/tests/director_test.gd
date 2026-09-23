extends SceneTree

const Stage := preload("res://src/stage.gd")
const Rules := preload("res://src/rules.gd")
const Layout := preload("res://src/layout.gd")

const STEP := 0.1
const SIMULATED := 60.0

var _stage
var _started := false


func _initialize() -> void:
	_stage = Stage.new()
	_stage.test_mode = true
	root.add_child(_stage)


func _process(_delta: float) -> bool:
	if not _started:
		if _stage.director == null:
			return false
		_started = true
		return false

	var director = _stage.director
	director.set_physics_process(false)
	var steps := int(SIMULATED / STEP)
	for i in steps:
		_stage.run.stage_time += STEP
		director.tick(STEP)

	var spawned: int = director.total_spawned()
	var on_map := true
	var far := 0.0
	for foe in get_nodes_in_group("foe"):
		var at: Vector3 = foe.global_position
		far = maxf(far, at.distance_to(_stage.player.ball_position()))
		if absf(at.x) > Layout.HALF or absf(at.z) > Layout.HALF:
			on_map = false
	print("[director] %.0f simulated seconds reached tier %d, spawned %d foes (needs >= 1) -> %s"
		% [SIMULATED, _stage.run.tier(), spawned, "PASS" if spawned >= 1 else "FAIL"])
	print("[director] furthest spawn from the player: %.1f m (ring is %.0f-%.0f m), all on the map -> %s"
		% [far, director.MIN_RANGE, director.MAX_RANGE, "PASS" if on_map else "FAIL"])
	var tiers_rise: bool = Rules.tier_of(0.0) == 1 and Rules.tier_of(Rules.TIER_SECONDS + 0.1) == 2
	print("[director] the tier clock ticks every %.0fs -> %s"
		% [Rules.TIER_SECONDS, "PASS" if tiers_rise else "FAIL"])
	var ok: bool = spawned >= 1 and on_map and tiers_rise
	print("director_test: %s" % ("PASS" if ok else "FAIL"))
	_stage.free()
	quit(0 if ok else 1)
	return true
