extends SceneTree

# Dig probe (ALPHA-PLAN P1): a raised overlay floor drops with the ball on it. The ball
# settles on the overlay and agrees with terrain.height; the overlay is erased and its
# collider follows it the cave-in way (a finished body parked, map_gorge.gd apply_swap);
# the ball reaches the lower floor within 120 physics frames and agrees again.
# Evidence limit: headless physics on a probe map; no camera or feel claim.

const Terrain := preload("res://src/world/terrain.gd")
const ProbeMap := preload("res://tests/doubles/map_probe_floors.gd")
const ZoneSchema := preload("res://src/world/zone_schema.gd")
const Tuning := preload("res://src/movement/tuning.gd")

const TOLERANCE := 0.3
const DROP_FRAMES := 120
const SETTLE_FRAMES := 120


# Terrain takes only registered maps (terrain.gd _init), so this one fills its own row.
class ProbeTerrain extends "res://src/world/terrain.gd":
	func _init() -> void:
		super({"DEFS": []})
		maps.append(ProbeMap.new())
		_worlds.append(1)
		_roots.append(null)
		_heights.append(PackedFloat32Array())


var _failures := 0


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	_run()


func _run() -> void:
	var m = ProbeMap.new()
	_check("probe map is ZoneSchema-valid", ZoneSchema.validate(m).is_empty(), str(ZoneSchema.validate(m)))
	var world := Node3D.new()
	root.add_child(world)
	var terrain := ProbeTerrain.new()
	terrain.build(world)
	terrain.use(1)
	var probe = terrain.map()

	# The player's body as rigid_ball.gd sets it up: radius, no sleep (a sleeping body
	# stays hovering when the floor under it is parked), material and gravity.
	var radius: float = Tuning.RADIUS
	var ball := RigidBody3D.new()
	ball.can_sleep = false
	var material := PhysicsMaterial.new()
	material.friction = 0.9
	material.bounce = 0.25
	ball.physics_material_override = material
	ball.gravity_scale = Tuning.new().f("gravity") / 9.8
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	ball.add_child(shape)
	ball.position = Vector3(0.0, ProbeMap.RAISE + radius + 2.0, 0.0)
	world.add_child(ball)
	for i in SETTLE_FRAMES:
		await physics_frame

	var at := ball.global_position
	var upper := terrain.height(at.x, at.z)
	var gap_before := at.y - radius - upper
	_check("rests on the overlay", absf(gap_before) <= TOLERANCE and upper > ProbeMap.FLOOR_Y + 1.0,
		"y %.3f, radius %.2f, terrain.height %.3f, gap %.3f" % [at.y, radius, upper, gap_before])

	terrain.overlays.erase("probe_floor")
	probe.refresh(terrain.overlays)
	var reached := -1
	var gap := INF
	for frame in range(1, DROP_FRAMES + 1):
		await physics_frame
		at = ball.global_position
		gap = at.y - radius - terrain.height(at.x, at.z)
		if reached < 0 and absf(gap) <= TOLERANCE:
			reached = frame
	var lower := terrain.height(at.x, at.z)
	_check("reaches the lower floor within %d frames" % DROP_FRAMES, reached > 0 and lower < upper - 1.0,
		"first agreeing frame %d, terrain.height %.3f (was %.3f)" % [reached, lower, upper])
	_check("agrees with the lower floor at frame %d" % DROP_FRAMES, absf(gap) <= TOLERANCE,
		"y %.3f, terrain.height %.3f, gap %.3f, speed %.3f" % [at.y, lower, gap, ball.linear_velocity.length()])

	print("probe_dig_floor_drop_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	world.free()
	quit(0 if _failures == 0 else 1)
