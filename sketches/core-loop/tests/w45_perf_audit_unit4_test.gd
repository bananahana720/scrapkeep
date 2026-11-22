extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Effects := preload("res://src/combat/effects.gd")
const WindupRows := preload("res://src/presentation/windup_rows.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const AimReticle := preload("res://src/ui/aim_reticle.gd")
const Augments := preload("res://src/movement/augments.gd")
const EdgeMarkers := preload("res://src/ui/edge_markers.gd")
const Hud := preload("res://src/ui/hud.gd")
const Companion := preload("res://src/core/companion.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const ScrapField := preload("res://src/build/scrap_field.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("w45_perf_audit_unit4_test")
var _game


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _physics(count: int) -> void:
	for i in count:
		await physics_frame


func _run() -> void:
	_check_effects()
	_check_windup_rows()
	_check_companion_writes()
	_check_scrap_field()
	await _check_reticle()
	await _check_edge_markers()
	await _check_live_combat_and_vfx()
	quit(_t.verdict())


func _check_effects() -> void:
	var fx := Effects.new()
	root.add_child(fx)
	fx.setup()
	_t.check("effects: sleeps after setup", not fx.is_processing())

	fx.arc(Vector3.ZERO, Vector3.FORWARD, Color.WHITE)
	_t.check("effects: arc wakes process", fx.is_processing() and fx.live_mark_count() == 1)
	fx._process(Effects.ARC_LIFE + 0.05)
	_t.check("effects: sleeps after arc ages out", not fx.is_processing() and fx.live_mark_count() == 0 and fx._mesh.get_surface_count() == 0)

	fx.ring(Vector3.ZERO, 3.0, Color.WHITE)
	_t.check("effects: ring wakes process", fx.is_processing())
	fx.clear()
	_t.check("effects: clear puts process back to sleep", not fx.is_processing() and fx.live_mark_count() == 0)

	fx.spark(Vector3.ZERO, Color.WHITE)
	_t.check("effects: spark wakes process", fx.is_processing())
	fx._process(Effects.SPARK_LIFE + 0.05)
	_t.check("effects: sleeps after spark ages out", not fx.is_processing())

	fx.beam(Vector3.ZERO, Vector3.RIGHT, Color.WHITE, 0.2)
	_t.check("effects: beam wakes process", fx.is_processing())
	fx._process(0.25)
	_t.check("effects: sleeps after beam ages out", not fx.is_processing())

	fx.frost_flash(Vector3.ZERO)
	_t.check("effects: flair wakes process", fx.is_processing())
	fx._process(Effects.PAYOFF_LIFE + 0.5)
	_t.check("effects: sleeps after flair ages out", not fx.is_processing())

	fx.free()


func _check_windup_rows() -> void:
	_t.check("windup_rows: warden and swarm_remnant have state facts",
		WindupRows.has_state_facts("warden") and WindupRows.has_state_facts("swarm_remnant"))
	_t.check("windup_rows: ordinary kinds have no state facts",
		not WindupRows.has_state_facts("chaser") and not WindupRows.has_state_facts("lobber")
			and not WindupRows.has_state_facts("miniboss") and not WindupRows.has_state_facts(""))


class _HudRun:
	var companion := {}


class _HudGame:
	var run := _HudRun.new()

	func audio():
		return null


func _escape_doc(ready: bool) -> Dictionary:
	var m := Companion.new()
	m.acquire("escape_vent")
	m.acquire("ram_prow")
	m.assemble(["escape_vent", "ram_prow"])
	if not ready:
		m.spend_escape()
	return m.to_dict()


func _check_companion_writes() -> void:
	var hud := Hud.new()
	var game := _HudGame.new()
	hud.game = game
	var pip := TextureRect.new()
	hud._companion = pip

	game.run.companion = _escape_doc(true)
	hud._step_companion(true)
	_t.check("hud companion: initial ready sets texture and modulate",
		pip.texture != null and pip.modulate == EventKinds.UI_ROWS["companion_ready"]["color"])
	var sentinel := Color(0.11, 0.22, 0.33, 1.0)
	pip.modulate = sentinel
	hud._step_companion(true)
	_t.eq("hud companion: unchanged state skips redundant property writes", pip.modulate, sentinel)

	game.run.companion = _escape_doc(false)
	hud._step_companion(true)
	_t.eq("hud companion: transition to spent updates modulate", pip.modulate, EventKinds.UI_ROWS["companion_spent"]["color"])

	pip.free()
	hud.free()


func _check_scrap_field() -> void:
	var field := ScrapField.new()
	field.setup()
	root.add_child(field)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var far := Vector3(ScrapField.SPIN_RANGE + 100.0, 0.0, 0.0)
	field.drop(far, 2, rng)
	field.drop_recovery(null, far, Vector3.FORWARD, 5, 1, rng)
	field._add(Vector3(0.0, 0.0, 1.0))
	field._add(Vector3(0.0, 0.0, 4.0))
	field._add(Vector3(0.0, 0.0, 40.0))

	var spin_item: MeshInstance3D = field._items[field._items.size() - 1]
	var far_item: MeshInstance3D = field._items[0]
	var far_rot := far_item.rotation
	var spin_rot := spin_item.rotation

	var taken := field.step(Vector3.ZERO, 0.0, 0.1)
	_t.eq("scrap_field: immediate pickup collected", taken.size(), 1)
	_t.check("scrap_field: far pickup skipped without rotating", far_item.rotation == far_rot)
	_t.check("scrap_field: near pickup inside SPIN_RANGE rotates", not spin_item.rotation.is_equal_approx(spin_rot))
	_t.check("scrap_field: magnet catches pickup inside reach", field._caught.size() == 1)

	var caught_item: MeshInstance3D = field._caught.keys()[0]
	caught_item.global_position = Vector3(ScrapField.SPIN_RANGE + 50.0, 0.0, 0.0)
	var before_pull := caught_item.global_position
	field.step(Vector3.ZERO, 0.0, 0.1)
	_t.check("scrap_field: caught pickup still homes even past SPIN_RANGE", caught_item.global_position.x < before_pull.x)

	var expired := 0
	for i in 6:
		field.step(Vector3.ZERO, 0.0, ScrapField.RECOVERY_LIFE / 4.0)
		expired += field.expired_values.size()
	_t.eq("scrap_field: distant recovery cluster still expires", expired, 1)
	field.free()


class _Kit:
	var aim := {"state": Augments.AIM_NONE}
	var hooked := false
	var rewind_left := 0.0
	var grapple := true

	func on(key: String) -> bool:
		return grapple and key == Augments.GRAPPLE


class _Tuning:
	func harpoon_rewind() -> float:
		return 1.0


class _Player:
	var kit := _Kit.new()
	var tuning := _Tuning.new()
	var at := Vector3.ZERO
	var reach := 30.0

	func shown_position() -> Vector3:
		return at

	func grapple_range() -> float:
		return reach


class _CountedReticle extends AimReticle:
	var casts := 0
	var cover_calls := 0

	func _out_of_range(aim: Dictionary) -> bool:
		casts += 1
		return super(aim)

	func cover(centre: Vector2) -> float:
		cover_calls += 1
		return super(centre)


class _DrawCounter:
	var n := 0

	func hit() -> void:
		n += 1


func _check_reticle() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.position = Vector3(0.0, 1.0, 0.0)
	var wall := StaticBody3D.new()
	wall.collision_layer = Augments.WORLD_MASK
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 40.0, 1.0)
	shape.shape = box
	wall.add_child(shape)
	world.add_child(wall)
	wall.position = Vector3(0.0, 0.0, -60.0)

	var player := _Player.new()
	var reticle := _CountedReticle.new()
	reticle.visible = false
	root.add_child(reticle)
	reticle.setup(player, cam)
	var draws := _DrawCounter.new()
	reticle.draw.connect(draws.hit)
	reticle._on_line_state("dry_fire", null, Vector3.ZERO, "")
	await _physics(3)
	await _frames(5)
	_t.eq("reticle: hidden reticle casts no rays", reticle.casts, 0)
	_t.eq("reticle: hidden reticle queues no redraws", draws.n, 0)
	_t.check("reticle: hidden reticle still steps shake timer", reticle._shake_left < AimReticle.DRY_SHAKE_TIME)

	reticle._shake_left = 0.0
	reticle.visible = true
	await _frames(3)
	var cover_before := reticle.cover_calls
	reticle.gauge = 0.5
	await _frames(1)
	_t.eq("reticle: _process and _draw compute cover once, not twice", reticle.cover_calls - cover_before, 1)

	player.kit.aim = {"state": Augments.AIM_BODY, "point": Vector3(0.0, 1.0, -10.0)}
	player.kit.hooked = true
	await _frames(2)
	var d0 := draws.n
	player.kit.aim["point"] = Vector3(2.0, 1.0, -10.0)
	cam.fov = 80.0
	await _frames(2)
	_t.eq("reticle: hooked dot ignores brackets snap point and fov changes", draws.n - d0, 0)

	player.kit.hooked = false
	await _frames(2)
	d0 = draws.n
	cam.fov = 95.0
	await _frames(2)
	_t.check("reticle: unhooked brackets redraw on camera fov change", draws.n > d0)

	reticle.set_process(false)
	player.kit.aim = {"state": Augments.AIM_NONE}
	await _frames(1)
	var c0 := reticle.casts
	var cov0 := reticle.cover_calls
	reticle.queue_redraw()
	await _frames(1)
	_t.check("reticle: direct _draw without _process still computes out-of-range and cover",
		reticle.casts == c0 + 1 and reticle.cover_calls == cov0 + 1)

	reticle.queue_free()
	world.queue_free()
	await _frames(1)


class _Map:
	var contraptions: Array

	func _init(rows: Array) -> void:
		contraptions = rows


class _Ground:
	var calls := 0
	var ridge := false

	func height(_x: float, z: float) -> float:
		calls += 1
		return 60.0 if ridge and z < -20.0 and z > -40.0 else 0.0


class _Terrain:
	var ground := _Ground.new()
	var current: _Map
	var stage := 1
	var overlays: Array[String] = []

	func map() -> RefCounted:
		return current

	func height(x: float, z: float) -> float:
		return ground.height(x, z)


class _Doors:
	var valves: Array = []
	var walls: Array = []


class _World:
	var terrain := _Terrain.new()
	var contraptions := {1: _Doors.new()}


class _Flow:
	func in_play() -> bool:
		return true


class _CameraRig:
	var cam: Camera3D


class _MarkerGame:
	var world := _World.new()
	var player := _Player.new()
	var flow := _Flow.new()
	var camera := _CameraRig.new()


func _check_edge_markers() -> void:
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0.0, 3.0, 0.0)
	var game := _MarkerGame.new()
	game.camera.cam = cam
	var valve := {"kind": "valve", "id": "v1", "at": Vector2(0.0, -95.0), "door": {"at": Vector2(0.0, -100.0)}}
	game.world.terrain.current = _Map.new([valve])
	var markers := EdgeMarkers.new()
	markers.game = game
	var ground: _Ground = game.world.terrain.ground
	var size := Vector2(1920.0, 1080.0)

	_t.check("edge_markers: undiscovered pocket targets return empty with zero terrain reads",
		markers._pocket_targets_now().is_empty() and ground.calls == 0)

	markers.note_pockets(size)
	_t.eq("edge_markers: door discovered", markers.discovered.size(), 1)
	ground.calls = 0
	var first := markers._pocket_targets_now()
	var first_reads := ground.calls
	ground.calls = 0
	for i in 5:
		markers._pocket_targets_now()
	_t.check("edge_markers: stationary pocket targets hit cache with zero terrain reads",
		first.size() == 1 and first_reads > 10 and ground.calls == 0,
		"first %d reads, cached %d reads" % [first_reads, ground.calls])

	game.player.at = Vector3(0.0, 0.0, EdgeMarkers.POCKET_STILL_M * 0.5)
	markers._pocket_targets_now()
	_t.eq("edge_markers: movement below POCKET_STILL_M stays cached", ground.calls, 0)

	game.world.terrain.overlays.append("slide_before")
	markers._pocket_targets_now()
	_t.check("edge_markers: overlay addition invalidates pocket target cache", ground.calls > 0)

	ground.calls = 0
	game.world.terrain.overlays.erase("slide_before")
	game.world.terrain.overlays.append("slide_after")
	markers._pocket_targets_now()
	_t.check("edge_markers: same-size overlay swap invalidates pocket target cache", ground.calls > 0)

	ground.calls = 0
	markers.discovered.clear()
	markers.note_pockets(size)
	ground.calls = 0
	markers.discovered.clear()
	game.world.terrain.overlays.clear()
	markers.note_pockets(size)
	_t.check("edge_markers: overlay change invalidates note_pockets still check", ground.calls > 0)

	markers._reset_pocket_caches()
	_t.check("edge_markers: reset clears both ball caches",
		markers._pockets_ball == Vector3.INF and markers._targets_ball == Vector3.INF)

	markers.free()
	cam.queue_free()
	await _frames(1)


class _DuckCarrier extends Node3D:
	var knocks := 1
	var velocity := Vector3(12.0, 0.0, 0.0)
	var radius := 1.0
	var speed := 12.0

	func is_dead() -> bool:
		return false

	func knock(_dir: Vector3, _force: float) -> void:
		pass

	func _knocked_speed() -> float:
		return speed


func _check_live_combat_and_vfx() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.ctx.rng.seed = 11
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	await _physics(3)
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()

	var sparkles_shadow_off := true
	for p: CPUParticles3D in _game.presentation.vfx._sparkles:
		if p.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			sparkles_shadow_off = false
	_t.check("vfx: all sparkle emitters disable shadow casting",
		not _game.presentation.vfx._sparkles.is_empty() and sparkles_shadow_off)

	var spawn: Vector3 = _game.player.ball_position() + Vector3(15.0, 0.0, 0.0)
	var lobber = _game.combat.spawn_enemy("lobber", _game.ctx.terrain.drop_point(spawn.x, spawn.z, 2.1))
	for i in 90:
		if lobber.is_on_floor():
			break
		await _physics(1)
	lobber.set_physics_process(false)
	lobber.hp = 100000.0
	lobber._clock = 0.0
	lobber._show_charge(0.0)
	_t.check("lobber: initial zero charge sets muzzle at rest and parts at rest",
		lobber._muzzle_at_rest and not lobber._parts_off_rest
			and is_equal_approx(lobber._muzzle_material.emission_energy_multiplier, 0.8)
			and lobber._muzzle.scale == Vector3.ONE)
	var sentinel_scale := Vector3(1.23, 1.23, 1.23)
	lobber._muzzle.scale = sentinel_scale
	lobber._show_charge(0.0)
	_t.eq("lobber: idle zero charge skips redundant muzzle writes", lobber._muzzle.scale, sentinel_scale)

	lobber._show_charge(0.5)
	_t.check("lobber: active charge clears rest flags and poses parts",
		not lobber._muzzle_at_rest and lobber._parts_off_rest and lobber._barrel.transform != lobber._barrel_rest)
	lobber._show_charge(0.0)
	_t.check("lobber: returning to zero charge restores muzzle and parts to rest",
		lobber._muzzle_at_rest and not lobber._parts_off_rest
			and lobber._muzzle.scale == Vector3.ONE
			and lobber._cart.transform == lobber._cart_rest and lobber._barrel.transform == lobber._barrel_rest)

	lobber.shots = 1
	lobber._clock = 0.1
	lobber._show_charge(0.0)
	_t.check("lobber: recovery window poses cart and barrel",
		lobber._parts_off_rest and lobber._barrel.transform != lobber._barrel_rest)
	lobber._clock = lobber.POSE_RECOVERY + 0.05
	lobber._show_charge(0.0)
	_t.check("lobber: leaving recovery restores exact rest transforms",
		not lobber._parts_off_rest and lobber._cart.transform == lobber._cart_rest and lobber._barrel.transform == lobber._barrel_rest)

	lobber._show_charge(0.8)
	lobber._die()
	_t.check("lobber: _die restores rest transforms cleanly",
		not lobber._parts_off_rest and lobber._cart.transform == lobber._cart_rest and lobber._barrel.transform == lobber._barrel_rest)
	await _physics(1)

	var chaser = _game.combat.spawn_enemy("chaser", _game.ctx.terrain.drop_point(spawn.x, spawn.z, 1.6))
	chaser.set_physics_process(false)
	_t.eq("enemy: zero knock speed returns 0.0", chaser._knocked_speed(), 0.0)
	chaser._knock = Vector3(3.0, 9.0, 4.0)
	_t.near("enemy: horizontal knock speed ignores y", chaser._knocked_speed(), 5.0)
	chaser._knock = Vector3.ZERO

	var scatter := EnemyMotion.scatter(chaser, "chaser", Vector3.FORWARD)
	var debris_meshes := scatter.find_children("*", "MeshInstance3D", true, false)
	var debris_shadow_off := debris_meshes.all(func(m: MeshInstance3D) -> bool:
		return m.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_t.check("enemy_motion: death debris pieces disable shadow casting",
		not debris_meshes.is_empty() and debris_shadow_off)
	scatter.free()

	var combat = _game.combat
	combat._pinned.clear()
	var pins_before: int = combat.pins
	combat._pin_step([chaser])
	_t.check("combat _pin_step: still enemy keeps _pinned empty", combat._pinned.is_empty() and combat.pins == pins_before)

	var victim = _game.combat.spawn_enemy("chaser", _game.ctx.terrain.drop_point(spawn.x + 2.0, spawn.z, 1.6))
	victim.set_physics_process(false)
	chaser._knock = Vector3(12.0, 0.0, 0.0)
	chaser.velocity = Vector3.ZERO
	combat._pin_step([chaser, victim])
	_t.eq("combat _pin_step: zero velocity heading skips inner victim loop", combat.pins, pins_before)

	chaser.velocity = Vector3(12.0, 0.0, 0.0)
	combat._pin_step([chaser, victim])
	_t.check("combat _pin_step: active enemy carrier pins victim and records key",
		combat.pins == pins_before + 1 and combat._pinned.size() == 1)

	var duck := _DuckCarrier.new()
	root.add_child(duck)
	duck.global_position = victim.global_position - Vector3(2.0, 0.0, 0.0)
	combat._pin_step([duck, victim])
	_t.eq("combat _pin_step: duck-typed carrier still pins victim", combat.pins, pins_before + 2)
	duck.free()

	combat._clock += 3.5
	combat._pin_step([])
	_t.check("combat _pin_step: expired pin keys are evicted", combat._pinned.is_empty())

	chaser.free()
	victim.free()
	_game.free()
