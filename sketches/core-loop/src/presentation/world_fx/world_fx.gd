extends Node3D

const Specs := preload("res://src/presentation/world_fx/world_fx_specs.gd")
const Kit := preload("res://src/presentation/world_fx/world_fx_kit.gd")
const Anchor := preload("res://src/presentation/world_fx/world_fx_anchor.gd")
const Word := preload("res://src/presentation/world_fx/world_fx_word.gd")
const Grain := preload("res://src/presentation/world_fx/world_fx_grain.gd")
const WorldSound := preload("res://src/presentation/world_fx/world_fx_sound.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")

const RANK_SECONDS := 0.25
const BURST_POOL := 2
const RESTING := ["title", "class_select", "summary", "dead", "victory"]
const WAKE_SET := "spill_wake"
const WAKE_WORLDS := [1]
const WAKE_EVERY := 1.0 / 15.0
const WAKE_RIDE_M := 1.6
const WAKE_SPEED := 3.0
const WAKE_FULL := 16.0
const SPLASH_SPEED := 7.0
const SPLASH_DROP := 4.0
const SPLASH_COOL := 0.5
const VOICE_KEEP := 1.25
const VOICE_KEEP_M := 5.0

static var current: Node3D
static var preferred: bool:
	get:
		return Kit.reduced_motion
	set(on):
		Kit.reduced_motion = on

var world := -1
var low := false
var reduced_motion := false
var ambient: Array[GPUParticles3D] = []
var overlay: Array[GPUParticles3D] = []
var overlay_kind := ""
var resting := false
var _camera: Node3D
var _ball: Node3D
var _bursts := {}
var _next := {}
var _rank_wait := 0.0
var _relay: Node3D
var _relay_quarters := 0
var wake: Array[GPUParticles3D] = []
var wet := false
var _ctx
var _wake_wait := 0.0
var _last_ball := Vector3.INF
var _splash_cool := 0.0
var wake_sound: AudioStreamPlayer3D
var _voice_of := {}
var _wake_heard := 0.0


static func install(parent: Node, world_index: int, is_low := false, is_reduced := false) -> Node3D:
	var fx: Node3D = load("res://src/presentation/world_fx/world_fx.gd").new()
	fx.name = "WorldFx"
	fx.world = world_index
	fx.low = is_low
	fx.reduced_motion = is_reduced
	parent.add_child(fx)
	return fx


static func hook(ctx) -> Node3D:
	var fx := install(ctx.root, -1, false, preferred)
	ctx.events.stage_entered.connect(fx._on_stage_entered.bind(ctx))
	ctx.events.flow_changed.connect(fx._on_flow_changed)
	ctx.events.event_started.connect(fx._on_event_started.bind(ctx))
	ctx.events.event_progress.connect(fx._on_event_progress.bind(ctx))
	ctx.events.event_ended.connect(fx._on_event_ended.bind(ctx))
	load("res://src/presentation/graphics_preset.gd").register_dressing_host(fx)
	return fx


static func lay_overlay(kind: String) -> void:
	if is_instance_valid(current):
		current.set_overlay(kind)


static func fire(hook: String, at: Vector3, tint := Color.TRANSPARENT) -> void:
	if is_instance_valid(current):
		current.play(hook, at, tint)


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


func _ready() -> void:
	_build_ambient()
	for id in Specs.SETS[WAKE_SET]:
		wake.append(_add(id))
	var spot := Node3D.new()
	spot.name = "WakeSound"
	add_child(spot)
	wake_sound = WorldSound.voice(WAKE_SET, spot)


func _build_ambient() -> void:
	for p in ambient:
		p.queue_free()
	ambient.clear()
	var set_id: String = Specs.WORLD_SETS.get(world, "")
	for id in Specs.SETS.get(set_id, []):
		ambient.append(_add(id))
	_sync()
	_follow()


func enter_world(world_index: int) -> void:
	if world_index == world:
		return
	world = world_index
	_build_ambient()


func _on_stage_entered(stage: int, _retry: bool, ctx) -> void:
	_ctx = ctx
	WorldSound.audio = ctx.root.call("audio") if ctx.get("root") != null and ctx.root.has_method("audio") else null
	_last_ball = Vector3.INF
	set_run_seed(int(ctx.run.run_seed) if ctx.get("run") != null else 0)
	enter_world(ctx.stages.world_of(stage))
	set_overlay("")
	if is_instance_valid(_relay):
		_relay.queue_free()
		_relay = null
	bind(ctx.camera, ctx.player)
	set_resting(false)


func _on_flow_changed(state: String) -> void:
	set_resting(RESTING.has(state))
	if state in ["title", "class_select"]:
		set_run_seed(0)


func set_run_seed(seed: int) -> void:
	if seed == Grain.run_seed:
		return
	Grain.run_seed = seed
	for p in _owned():
		Grain.apply(p, seed)
	for ref in Anchor.live:
		var a = ref.get_ref()
		if a != null:
			a.set_grain(seed)
	_sync()


func _owned() -> Array[GPUParticles3D]:
	var out: Array[GPUParticles3D] = []
	out.append_array(ambient)
	out.append_array(overlay)
	out.append_array(wake)
	for id in _bursts:
		out.append_array(_bursts[id])
	return out


func set_resting(on: bool) -> void:
	resting = on
	visible = not on
	for p in ambient + overlay:
		p.emitting = not on and p.amount_ratio > 0.0
	if on:
		for p in wake:
			p.emitting = false
		wet = false
		_last_ball = Vector3.INF
		_hush_wake()
	_rank()


func _sync_dressing() -> void:
	set_quality(load("res://src/presentation/graphics_preset.gd").current == "low", reduced_motion)


func bind(camera: Node3D, ball: Node3D) -> void:
	_camera = camera
	_ball = ball
	_follow()


func set_quality(is_low: bool, is_reduced: bool) -> void:
	low = is_low
	reduced_motion = is_reduced
	_sync()


func set_overlay(kind: String) -> void:
	for p in overlay:
		p.queue_free()
	overlay.clear()
	overlay_kind = kind
	for id in Specs.OVERLAYS.get(kind, []):
		overlay.append(_add(id))
	_sync()
	_follow()


const RELAY_ID := "hold_the_relay"
const RELAY_RING_M := 24.0


static func _relay_model(ctx):
	var world = ctx.root.get("world") if ctx.root != null else null
	var director = world.get("events") if world != null else null
	if director == null or not director.has_method("offer"):
		return null
	return director.offer(RELAY_ID).get("model")


static func _relay_foot(ctx, model) -> Vector3:
	var y: float = ctx.terrain.height(model.relay.x, model.relay.y) if ctx.get("terrain") != null else 0.0
	return Vector3(model.relay.x, y, model.relay.y)


func _on_event_started(id: String, ctx) -> void:
	if id != RELAY_ID:
		return
	var model = _relay_model(ctx)
	if model == null:
		return
	if is_instance_valid(_relay):
		_relay.queue_free()
	_relay = Anchor.make("relay")
	add_child(_relay)
	_relay.global_position = _relay_foot(ctx, model)
	_relay.scale = Vector3.ONE * clampf(model.ring_radius / RELAY_RING_M, 0.25, 2.0)
	_relay.set_level(0.0, not model.inside)
	_relay_quarters = 0


func _on_event_progress(id: String, fraction: float, ctx) -> void:
	if id != RELAY_ID or not is_instance_valid(_relay):
		return
	var model = _relay_model(ctx)
	_relay.set_level(fraction, model != null and not model.inside)
	var quarters := mini(int(fraction * 4.0), 3)
	if quarters > _relay_quarters:
		_relay_quarters = quarters
		play("relay_quarter", _relay.global_position, Color.TRANSPARENT, _relay.scale.x)


func _on_event_ended(id: String, outcome: String, _ctx) -> void:
	if id != RELAY_ID or not is_instance_valid(_relay):
		return
	if outcome == "won":
		play("relay_full", _relay.global_position, Color.TRANSPARENT, _relay.scale.x)
	_relay.queue_free()
	_relay = null


func play(hook: String, at: Vector3, tint := Color.TRANSPARENT, size := 1.0) -> void:
	var row: Dictionary = Specs.HOOKS.get(hook, {})
	if row.is_empty():
		push_warning("WorldFx: no hook %s" % hook)
		return
	for id in row["effects"]:
		var p := _burst(id)
		var share := Grain.share(p, low, reduced_motion)
		if share <= 0.0:
			continue
		p.amount_ratio = share
		p.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), at)
		p.set_instance_shader_parameter(FxLibrary.TINT, tint if tint.a > 0.0 else Grain.tint(id, p.get_meta("grain", {})))
		p.restart()
		p.emitting = true
	if row["word"] != "" and not reduced_motion:
		Word.stamp(self, row["word"], at)
	if WorldSound.row(hook).get("play", "") == "once" and not resting:
		WorldSound.one_shot(hook, self, at, linear_to_db(size))


func _add(id: String) -> GPUParticles3D:
	var p := Kit.build(id)
	Grain.apply(p, Grain.run_seed)
	add_child(p)
	return p


func _burst(id: String) -> GPUParticles3D:
	if not _bursts.has(id):
		var pool: Array[GPUParticles3D] = []
		for i in BURST_POOL:
			pool.append(_add(id))
		_bursts[id] = pool
		_next[id] = 0
	var i: int = _next[id]
	_next[id] = (i + 1) % BURST_POOL
	return _bursts[id][i]


func _sync() -> void:
	for p in ambient + overlay:
		p.amount_ratio = Grain.share(p, low, reduced_motion)
		p.emitting = p.amount_ratio > 0.0 and not resting
	for ref in Anchor.live:
		var a = ref.get_ref()
		if a != null:
			a.set_quality(low, reduced_motion)


func _process(delta: float) -> void:
	_follow()
	_step_wake(delta)
	_rank_wait -= delta
	if _rank_wait <= 0.0:
		_rank_wait = RANK_SECONDS
		_rank()


func _lens() -> Node3D:
	var live := get_viewport().get_camera_3d() if is_inside_tree() else null
	if live != null:
		return live
	return _camera if is_instance_valid(_camera) else null


func _ball_place() -> Vector3:
	return _ball.shown_position() if _ball.has_method("shown_position") else _ball.global_position


func _follow() -> void:
	if _camera == null:
		return
	var lens := _lens()
	if lens == null:
		return
	var eye := lens.global_position
	var yaw := Basis(Vector3.UP, lens.global_rotation.y)
	var feet := _ball_place() if is_instance_valid(_ball) else eye
	Kit.set_clear(feet)
	for p in ambient + overlay:
		var s: Dictionary = Specs.SPECS[p.get_meta("world_fx")]
		var offset: Vector3 = s.get("offset", Vector3.ZERO)
		if s["attach"] == "ball":
			p.global_position = feet + offset
		else:
			p.global_position = eye + yaw * offset


func _rank() -> void:
	Anchor.live = Anchor.live.filter(func(r): return r.get_ref() != null)
	var lens := _lens()
	if lens == null:
		return
	var eye := lens.global_position
	var rows: Array = []
	for ref in Anchor.live:
		var a: Node3D = ref.get_ref()
		if a.is_visible_in_tree():
			rows.append([a.global_position.distance_to(eye), a])
	rows.sort_custom(func(x, y): return x[0] < y[0])
	var slots := Specs.ANCHOR_SLOTS
	var nearest := {}
	var holder_at := {}
	for row in rows:
		var a = row[1]
		var within: bool = row[0] <= a.lod_m()
		a.set_range(row[0], within and slots > 0)
		if within:
			slots -= 1
		if a.has_voice() and a.slotted and not resting:
			if not nearest.has(a.set_id):
				nearest[a.set_id] = [row[0], a]
			if _voice_of.get(a.set_id) == a:
				holder_at[a.set_id] = row[0]
	for id in nearest:
		if not holder_at.has(id) or float(holder_at[id]) > float(nearest[id][0]) * VOICE_KEEP + VOICE_KEEP_M:
			_voice_of[id] = nearest[id][1]
	for id in _voice_of.keys():
		if not nearest.has(id):
			_voice_of.erase(id)
	for ref in Anchor.live:
		var a: Node3D = ref.get_ref()
		if a.has_voice():
			a.set_voiced(_voice_of.get(a.set_id) == a)


func _step_wake(delta: float) -> void:
	_splash_cool -= delta
	_wake_wait -= delta
	if _wake_wait > 0.0:
		return
	var dt := WAKE_EVERY - _wake_wait
	_wake_wait = WAKE_EVERY
	if resting or not is_instance_valid(_ball) or _ctx == null or _ctx.get("terrain") == null or not _ctx.terrain.has_method("material_at"):
		_last_ball = Vector3.INF
		_hush_wake()
		return
	var ball := _ball_place()
	var under: Dictionary = _ctx.terrain.material_at(ball)
	var water := float(under["surface_y"]) if under.get("material", "") == "water" else NAN
	var velocity := Vector3.ZERO
	if _last_ball != Vector3.INF and dt > 0.0 and ball.distance_to(_last_ball) < 30.0:
		velocity = (ball - _last_ball) / dt
	_last_ball = ball
	steer_wake(ball, water, velocity)


func steer_wake(ball: Vector3, water: float, velocity: Vector3) -> void:
	var was := wet
	wet = WAKE_WORLDS.has(world) and not is_nan(water) and ball.y - water <= WAKE_RIDE_M
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	var speed := planar.length()
	if wet and not was and not resting and _splash_cool <= 0.0 and (speed >= SPLASH_SPEED or velocity.y <= -SPLASH_DROP):
		_splash_cool = SPLASH_COOL
		play("ball_splash", Vector3(ball.x, water, ball.z), Color.TRANSPARENT, clampf(maxf(speed, -velocity.y) / WAKE_FULL, 0.6, 1.3))
	var on := wet and speed >= WAKE_SPEED and not resting
	for p in wake:
		if on:
			p.global_transform = Transform3D(Basis.IDENTITY, Vector3(ball.x, water + 0.1, ball.z))
			var back := -planar / speed
			(p.process_material as ParticleProcessMaterial).direction = (back + Vector3.UP * 0.8).normalized()
			p.amount_ratio = Grain.share(p, low, reduced_motion) * clampf(speed / WAKE_FULL, 0.3, 1.0)
		p.emitting = on and p.amount_ratio > 0.0
	_steer_wake_sound(on, Vector3(ball.x, water, ball.z), speed)


func _steer_wake_sound(on: bool, at: Vector3, speed: float) -> void:
	if wake_sound == null:
		return
	if not on:
		_hush_wake()
		return
	var spot := wake_sound.get_parent() as Node3D
	spot.global_position = at
	WorldSound.tend(wake_sound, float(WorldSound.row(WAKE_SET)["db"]) + linear_to_db(clampf(speed / WAKE_FULL, 0.3, 1.0)))
	_wake_heard -= WAKE_EVERY
	if not wake_sound.playing:
		wake_sound.play()
		_wake_heard = 0.0
	if _wake_heard <= 0.0:
		_wake_heard = wake_sound.stream.get_length()
		WorldSound.heard(WAKE_SET, wake_sound)


func _hush_wake() -> void:
	if wake_sound != null and wake_sound.playing:
		wake_sound.stop()
