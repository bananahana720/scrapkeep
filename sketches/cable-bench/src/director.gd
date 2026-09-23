extends Node3D

const Layout := preload("res://src/layout.gd")
const Rules := preload("res://src/rules.gd")
const Foe := preload("res://src/foe.gd")
const Lobber := preload("res://src/lobber.gd")

const MIN_RANGE := 42.0
const MAX_RANGE := 74.0
const EDGE := 168.0

signal spawned(foe: Node3D)

var run
var target
var camera
var rng := RandomNumberGenerator.new()

var _clock := 0.0
var _total := 0


func setup(run_ref, target_ref, camera_ref, seed_value: int) -> void:
	run = run_ref
	target = target_ref
	camera = camera_ref
	rng.seed = seed_value
	_clock = 3.0


func total_spawned() -> int:
	return _total


func live_count() -> int:
	return get_tree().get_nodes_in_group("foe").size() if is_inside_tree() else 0


func _physics_process(delta: float) -> void:
	tick(delta)


# Split out so a test can run a minute of stage time in one frame.
func tick(delta: float) -> void:
	if run == null or not run.live():
		return
	_clock -= delta
	if _clock > 0.0:
		return
	var tier: int = run.tier()
	_clock = Rules.spawn_interval(tier, run.charging())
	if live_count() >= Rules.spawn_budget(tier, run.charging()):
		return
	spawn("lobber" if rng.randf() < Rules.lobber_share(tier) else "chaser")


func spawn(kind: String, at = null) -> Node3D:
	var foe: Node3D = Lobber.new() if kind == "lobber" else Foe.new()
	foe.name = "%s_%d" % [kind, _total]
	add_child(foe)
	foe.setup(kind, target, run, run.tier())
	foe.global_position = at if at != null else _spawn_point()
	_total += 1
	spawned.emit(foe)
	return foe


func spike_miniboss() -> Node3D:
	return spawn("miniboss")


# Off-screen near the player: prefer a ring position behind the camera, and never
# place a foe outside the terrain or inside a rock face.
func _spawn_point() -> Vector3:
	var centre: Vector3 = target.ball_position() if target != null else Vector3.ZERO
	var forward: Vector3 = -camera.global_transform.basis.z if camera != null else Vector3.FORWARD
	var best := Vector3.ZERO
	var best_score := -10.0
	for attempt in 10:
		var angle := rng.randf_range(-PI, PI)
		var radius := rng.randf_range(MIN_RANGE, MAX_RANGE)
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * radius
		var x := clampf(centre.x + offset.x, -EDGE, EDGE)
		var z := clampf(centre.z + offset.z, -EDGE, EDGE)
		var ground := Layout.height(x, z)
		# A point far below the player is down a cliff face, not behind them.
		var drop := absf(ground - centre.y)
		var behind := -offset.normalized().dot(Vector3(forward.x, 0.0, forward.z).normalized())
		var score := behind - drop * 0.08
		if score > best_score:
			best_score = score
			best = Vector3(x, ground + 2.2, z)
	return best
