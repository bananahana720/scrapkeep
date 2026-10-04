extends SceneTree

const T := preload("res://tests/support/t.gd")
const Terrain := preload("res://src/world/terrain.gd")
const Contraptions := preload("res://src/world/contraptions.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const ZoneSchema := preload("res://src/world/zone_schema.gd")
const Probe := preload("res://tests/doubles/map_probe_islands.gd")

# Highdraft probe, before any Highdraft map: on this engine, (a) a fall off an island lands
# on the flat net deck, (b) a moving island carries a resting ball, (c) a contraptions
# thermal lifts the ball. Probe balls copy rigid_ball.gd's body (mass, friction, bounce,
# damping, layers, gravity) without its drive.

const GRAVITY := 26.0
const FALLS := 50
const FALL_SEED := 7
const FALL_OFFSET := 4.0
const FALL_SECONDS := 4.0
const REST_TOLERANCE := 0.3
const CARRY_SIZE := Vector3(12.0, 2.0, 12.0)
const CARRY_FROM := Vector3(-10.0, Probe.NET_H + 5.0, 60.0)
const CARRY_DISTANCE := 20.0
const CARRY_SPEED := 5.0
const CARRY_SETTLE := 1.0
const DRIFT_LIMIT := 1.0
const THERMAL_SECONDS := 3.0
const LIFT_NEEDED := 8.0
const GLIDE_ENTRY := 20.0
const GLIDE_GRAVITY := 0.30
const SIM_CAP_SECONDS := 30.0


class NoStages:
	const DEFS := []


class ProbeTerrain:
	extends Terrain

	func _init() -> void:
		super(NoStages)
		maps.append(Probe.new())
		_worlds.append(1)
		_roots.append(null)
		_heights.append(PackedFloat32Array())


class GlideKit:
	var gliding := true


var _t := T.new("probe_highdraft_lift_test")
var _scene: Node3D
var _terrain
var _contraptions
var _kit := GlideKit.new()
var _falls: Array[Dictionary] = []
# One island per carry profile, side by side on z: "constant" is the acceptance run;
# "eased" (smoothstep over the same 20 m and time) and "keep_station" (constant, plus
# contraptions.gd's barge carry accel, :180-182) are printed diagnostics only.
var _carries: Array[Dictionary] = []
var _thermal_ball: RigidBody3D
var _thermal_start := 0.0
var _thermal_peak := 0.0
# Diagnostic only: a ball entering the column from above whose kit glides by
# augments.gd's rule (:356-358: only while falling), with glide's gravity hand-back.
var _glide_ball: RigidBody3D
var _glide_kit := GlideKit.new()
var _glide_low := INF
var _ticks := 0
var _hz := 90.0
var _done := {"falls": false, "carry": false, "thermal": false}


func _initialize() -> void:
	_hz = float(Engine.physics_ticks_per_second)
	_scene = Node3D.new()
	root.add_child(_scene)
	_terrain = ProbeTerrain.new()
	_terrain.build(_scene)
	var map = _terrain.map()
	_t.check("probe map fills the ZoneSchema slots", ZoneSchema.validate(map).is_empty(), str(ZoneSchema.validate(map)))
	_build_falls()
	_build_carry()
	_build_thermal(map)


func _ball(at: Vector3) -> RigidBody3D:
	var b := RigidBody3D.new()
	b.mass = 6.0
	b.can_sleep = false
	b.continuous_cd = true
	b.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	b.linear_damp = 0.0
	b.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	b.angular_damp = 0.25
	b.gravity_scale = GRAVITY / 9.8
	var material := PhysicsMaterial.new()
	material.friction = 0.9
	material.bounce = 0.25
	b.physics_material_override = material
	b.collision_layer = 0
	b.collision_mask = 0
	b.set_collision_layer_value(2, true)
	b.set_collision_mask_value(1, true)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = Tuning.RADIUS
	shape.shape = sphere
	b.add_child(shape)
	_scene.add_child(b)
	b.position = at
	return b


func _build_falls() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = FALL_SEED
	for i in FALLS:
		var island: Vector2 = Probe.ISLANDS[i % Probe.ISLANDS.size()]
		var bearing := rng.randf_range(0.0, TAU)
		var flat := island + Vector2.from_angle(bearing) * (Probe.ISLAND_RADIUS + FALL_OFFSET)
		var at := Vector3(flat.x, Probe.NET_H + Probe.ISLAND_RISE + Tuning.RADIUS, flat.y)
		_falls.append({"ball": _ball(at), "bearing": bearing, "low": at.y})


func _build_carry() -> void:
	for i in 3:
		var from := CARRY_FROM + Vector3.BACK * 20.0 * i
		var carrier := AnimatableBody3D.new()
		carrier.sync_to_physics = true
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = CARRY_SIZE
		shape.shape = box
		carrier.add_child(shape)
		_scene.add_child(carrier)
		carrier.position = from
		var rider := _ball(from + Vector3.UP * (CARRY_SIZE.y * 0.5 + Tuning.RADIUS + 0.05))
		_carries.append({"profile": ["constant", "eased", "keep_station"][i], "carrier": carrier, "from": from,
			"rider": rider, "start": Vector3.ZERO, "last": from, "velocity": Vector3.ZERO})


func _build_thermal(map) -> void:
	_contraptions = Contraptions.new()
	_terrain.geometry_root(1).add_child(_contraptions)
	_contraptions.setup(map, _terrain.ground_callable(1), 14.0, GRAVITY)
	var at: Vector2 = Probe.THERMAL_AT
	_thermal_ball = _ball(Vector3(at.x + 1.0, Probe.NET_H + Tuning.RADIUS + 0.02, at.y))
	_thermal_start = _thermal_ball.position.y
	_thermal_peak = _thermal_start
	_glide_ball = _ball(Vector3(at.x - 1.0, Probe.NET_H + GLIDE_ENTRY, at.y))


func _physics_process(delta: float) -> bool:
	_ticks += 1
	var t := _ticks / _hz
	if t > SIM_CAP_SECONDS:
		_t.check("finished inside the sim cap", false, "sim %.2f s, unfinished %s" % [t, str(_done)])
		quit(_t.verdict())
		return true
	for f in _falls:
		f["low"] = minf(f["low"], (f["ball"] as RigidBody3D).global_position.y)
	if not _done["falls"] and t >= FALL_SECONDS:
		_done["falls"] = true
		_check_falls()
	_step_carry(delta, t)
	_step_thermal(delta, t)
	if _done.values().all(func(v): return v):
		_scene.free()
		quit(_t.verdict())
		return true
	return false


func _check_falls() -> void:
	var want := Probe.NET_H + Tuning.RADIUS
	var worst := 0.0
	var worst_bearing := 0.0
	var lowest := INF
	for f in _falls:
		var y: float = (f["ball"] as RigidBody3D).global_position.y
		if absf(y - want) > worst:
			worst = absf(y - want)
			worst_bearing = f["bearing"]
		lowest = minf(lowest, f["low"])
	_t.check("(a) %d island falls rest on the net deck" % FALLS, worst <= REST_TOLERANCE,
		"rest y vs NET_H + radius %.2f: worst miss %.3f m at bearing %.2f rad (limit %.1f)" % [want, worst, worst_bearing, REST_TOLERANCE])
	# Below NET_H means the ball's centre went through the net; the underside's landing
	# sink into the deck is printed beside it.
	_t.check("(a) no fall passes below the deck", lowest >= Probe.NET_H,
		"lowest centre y over all falls %.3f, NET_H %.1f; deepest landing sink %.3f m" % [lowest, Probe.NET_H, Probe.NET_H + Tuning.RADIUS - lowest])


func _step_carry(delta: float, t: float) -> void:
	if _done["carry"]:
		return
	var moving := t - CARRY_SETTLE
	var seconds := CARRY_DISTANCE / CARRY_SPEED
	var f := clampf(moving / seconds, 0.0, 1.0)
	for c in _carries:
		var rider: RigidBody3D = c["rider"]
		if moving <= 0.0:
			c["start"] = rider.global_position
			continue
		var share := smoothstep(0.0, 1.0, f) if c["profile"] == "eased" else f
		var at: Vector3 = c["from"] + Vector3.RIGHT * CARRY_DISTANCE * share
		(c["carrier"] as AnimatableBody3D).global_position = at
		var v: Vector3 = (at - (c["last"] as Vector3)) / delta
		var a: Vector3 = (v - (c["velocity"] as Vector3)) / delta
		c["last"] = at
		c["velocity"] = v
		if c["profile"] == "keep_station":
			rider.apply_central_force((a + (v - rider.linear_velocity) * Contraptions.KEEP_STATION) * rider.mass)
	if f < 1.0:
		return
	_done["carry"] = true
	for c in _carries:
		var start: Vector3 = c["start"]
		var expected := start + Vector3.RIGHT * CARRY_DISTANCE
		var at: Vector3 = (c["rider"] as RigidBody3D).global_position
		var drift := Vector2(at.x - expected.x, at.z - expected.z).length()
		var detail := "%s: after %.0f m at %.1f m/s: horizontal drift %.3f m, height change %.3f m (limit %.1f)" % [
			c["profile"], CARRY_DISTANCE, CARRY_SPEED, drift, at.y - start.y, DRIFT_LIMIT]
		if c["profile"] == "constant":
			_t.check("(b) moving island carries a resting ball", drift < DRIFT_LIMIT, detail)
		else:
			print("[(b) diagnostic, not a check] " + detail)


func _step_thermal(delta: float, t: float) -> void:
	if _done["thermal"]:
		return
	var b := _thermal_ball
	for fact in _contraptions.step(delta, b.global_position, b.linear_velocity, _kit, false):
		if fact["kind"] == "accel":
			b.apply_central_force(fact["accel"] * b.mass)
	_thermal_peak = maxf(_thermal_peak, b.global_position.y)
	var g := _glide_ball
	_glide_kit.gliding = g.linear_velocity.y < 0.0
	if _glide_kit.gliding:
		g.apply_central_force(Vector3.UP * GRAVITY * (1.0 - GLIDE_GRAVITY) * g.mass)
	for fact in _contraptions.step(delta, g.global_position, g.linear_velocity, _glide_kit, false):
		if fact["kind"] == "accel":
			g.apply_central_force(fact["accel"] * g.mass)
	_glide_low = minf(_glide_low, g.global_position.y)
	if t < THERMAL_SECONDS:
		return
	_done["thermal"] = true
	var gained := b.global_position.y - _thermal_start
	_t.check("(c) thermal lifts the gliding ball", gained >= LIFT_NEEDED,
		"after %.1f s: gained %.2f m, peak %.2f m above start (need %.1f)" % [THERMAL_SECONDS, gained, _thermal_peak - _thermal_start, LIFT_NEEDED])
	print("[(c) diagnostic, not a check] glide only while falling: entered %.1f m above the deck, after %.1f s at %.2f m, lowest %.2f m, vy %.2f" % [
		GLIDE_ENTRY, THERMAL_SECONDS, g.global_position.y - Probe.NET_H, _glide_low - Probe.NET_H, g.linear_velocity.y])
