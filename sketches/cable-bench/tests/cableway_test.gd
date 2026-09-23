extends SceneTree

const Stage := preload("res://src/stage.gd")

const TICK := 1.0 / 60.0
const LIMIT := 900

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

	var cableway = _stage.cableways[0]
	# Drive it by hand so the sweep is deterministic instead of frame-rate luck.
	cableway.set_physics_process(false)
	var start: float = cableway.progress()
	var victim: Node3D = _stage.director.spawn("chaser", cableway.path_point(0.5))
	victim.set_physics_process(false)
	var at: Vector3 = victim.global_position

	var hits := []
	cableway.struck.connect(func(body): hits.append(body))
	var ticks := 0
	while ticks < LIMIT and hits.is_empty():
		cableway.tick(TICK)
		ticks += 1

	var moved: bool = absf(cableway.progress() - start) > 0.0001
	var knocked: Vector3 = victim.knock_velocity() if is_instance_valid(victim) else Vector3.ZERO
	var hit: bool = not hits.is_empty()
	print("[cableway] load advanced along its path after %d ticks: %.3f -> %.3f -> %s"
		% [ticks, start, cableway.progress(), "PASS" if moved else "FAIL"])
	print("[cableway] load reached the body at %s -> %s" % [at, "PASS" if hit else "FAIL"])
	print("[cableway] knockback on that body: %.1f m/s -> %s"
		% [knocked.length(), "PASS" if knocked.length() > 1.0 else "FAIL"])
	var ok: bool = moved and hit and knocked.length() > 1.0
	print("cableway_test: %s" % ("PASS" if ok else "FAIL"))
	_stage.free()
	quit(0 if ok else 1)
	return true
