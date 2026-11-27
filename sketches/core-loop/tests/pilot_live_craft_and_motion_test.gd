extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const AttackBudget := preload("res://src/combat/attack_budget.gd")
const Dispatcher := preload("res://src/combat/dispatcher.gd")
const Recipes := preload("res://src/world/park/park_recipes.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const WeaponRigFx := preload("res://src/presentation/weapon_rig_fx.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("pilot_live_craft_and_motion_test")
var _game


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _boot() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	while _game.flow == null:
		await process_frame
	await _frames(4)
	_game.ctx.calm = true
	_game.ctx.rng.seed = 11
	_game.player.source = Intent.Scripted.new()


func _primitive_meshes(scope: Node) -> Array:
	var out := []
	for node in scope.find_children("*", "MeshInstance3D", true, false):
		if (node as MeshInstance3D).mesh is PrimitiveMesh:
			out.append(node.name)
	return out


func _check_camp_floor_and_turntable() -> void:
	var screens = _game.screens
	_game._screen_key(KEY_K)
	await _frames(3)
	var hub = _game.camp_hub
	_t.check("camp walk entered", screens.walk_live() and hub.walking)
	var ground: Node3D = hub.root.get_node_or_null("CampGround")
	var disc := ground.get_node_or_null("SandstoneDisc") as MeshInstance3D if ground != null else null
	var shape: CollisionShape3D = null
	if ground != null:
		for child in ground.get_children():
			if child is CollisionShape3D and (child as CollisionShape3D).shape is CylinderShape3D:
				shape = child
				break
	_t.check("SandstoneDisc and its cylinder collider exist", disc != null and shape != null)
	if disc != null and shape != null:
		var top: float = disc.position.y + disc.mesh.get_aabb().end.y
		_t.check("SandstoneDisc top sits below the plaza apron at y = 0 (no coplanar overlap)",
			top < -Recipes.SURFACE_LAYER_M * 2.0, "top=%.4f" % top)
		_t.near("Camp ground collider keeps its walking floor at y = 0", shape.position.y + (shape.shape as CylinderShape3D).height * 0.5, 0.0, 0.0001)

	var customize = screens._camp.customize
	customize.reduced_motion = true
	customize._open_from_camp()
	await _frames(3)
	_t.check("customize page opened from the lockers", customize.visible)
	var prims := _primitive_meshes(customize)
	_t.eq("CustomizePage holds zero PrimitiveMesh instances", prims, [])
	var pedestal := customize.find_child("TurntablePedestal", true, false) as MeshInstance3D
	_t.check("Customize turntable is a sculpted ArrayMesh pedestal", pedestal != null and pedestal.mesh is ArrayMesh and pedestal.material_override is ShaderMaterial)
	customize.close()
	await _frames(2)
	_game._screen_key(KEY_K)
	await _frames(2)


func _check_live_pilot() -> void:
	var rec: Dictionary = _game.presentation.hero_assets.shell_of(_game.player)
	var pilot = rec.get("pilot")
	_t.check("live run seats an animated pilot", pilot != null and is_instance_valid(pilot))
	if pilot == null:
		return
	var gear: Array = (pilot as Node).find_children("CraftGear_*", "BoneAttachment3D", true, false)
	_t.check("live pilot wears CraftGear_* pieces", gear.size() >= 2, str(gear.map(func(n): return n.name)))
	var live = rec.get("liveliness")
	_t.check("live pilot carries PilotLiveliness", live != null and is_instance_valid(live))
	if live == null:
		return
	UiTokens.reduced_motion = false
	live.reset_state()
	_game.ctx.events.player_hit.emit(5.0, "test")
	var kicked: float = absf(float(live.get("_recoil_vel")))
	await _frames(3)
	_t.check("events.player_hit kicks the live pilot's recoil", kicked > 0.5 and absf(float(live.snapshot().recoil)) > 0.0, "vel=%.3f recoil=%.4f" % [kicked, float(live.snapshot().recoil)])
	live.reset_state()
	_t.eq("shot_fired and boss_defeated reach the live pilot", [_game.presentation.hero_assets.pilot_impulse("shot_fired"), _game.presentation.hero_assets.pilot_impulse("boss_defeated")], [1, 1])
	live.reset_state()
	UiTokens.reduced_motion = true
	_game.ctx.events.player_hit.emit(5.0, "test")
	_t.near("Less motion holds the pilot still on a hit", float(live.get("_recoil_vel")), 0.0, 0.0001)
	UiTokens.reduced_motion = false
	live.reset_state()


func _spin_per_second(rig: Node3D, reduced: bool) -> float:
	UiTokens.reduced_motion = reduced
	await _frames(6)
	var start: float = rig.spin_angle()
	var elapsed := 0.0
	for i in 30:
		await process_frame
		elapsed += root.get_process_delta_time()
	return (rig.spin_angle() - start) / maxf(elapsed, 0.0001)


func _check_weapon_rig_motion() -> void:
	var rec: Dictionary = _game.presentation.hero_assets.shell_of(_game.player)
	var pod = rec.get("pod")
	var ring: Node3D = (pod as Node3D).get_node_or_null("WeaponRing") if pod != null else null
	var rig: Node3D = WeaponRigFx.ensure_on(ring)
	_t.check("live ball's weapon ring carries a WeaponRigFx", rig != null)
	if rig == null:
		return
	var full: float = await _spin_per_second(rig, false)
	var calm: float = await _spin_per_second(rig, true)
	UiTokens.reduced_motion = false
	_t.check("Less motion slows WeaponRigFx spin to about %.2fx" % WeaponRigFx.REDUCED_RECOIL_SCALE,
		full > 0.0 and calm / full > WeaponRigFx.REDUCED_RECOIL_SCALE - 0.12 and calm / full < WeaponRigFx.REDUCED_RECOIL_SCALE + 0.12,
		"full=%.3f calm=%.3f ratio=%.3f" % [full, calm, calm / maxf(full, 0.0001)])
	_game.run.parts.append("hot_rivets")
	await _frames(3)
	var carriage := rig.get_node_or_null("RecoilCarriage") as Node3D
	_t.check("a kinetic part dresses the WeaponRigFx with a recoil carriage", carriage != null, str(rig.active_mods()))
	if carriage != null:
		var ratios := []
		for reduced in [true, false]:
			UiTokens.reduced_motion = reduced
			rig.on_shot_fired("plain", 1.0)
			await process_frame
			ratios.append(carriage.position.z / maxf(rig.recoil_offset(), 0.0001))
		UiTokens.reduced_motion = false
		_t.check("Less motion scales WeaponRigFx recoil to %.2fx" % WeaponRigFx.REDUCED_RECOIL_SCALE,
			absf(ratios[0] - WeaponRigFx.REDUCED_RECOIL_SCALE) < 0.01 and absf(ratios[1] - 1.0) < 0.01, str(ratios))
	_game.run.parts.erase("hot_rivets")
	await _frames(2)


func _check_flush_pod_scale() -> void:
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()
	if root.has_meta(AttackBudget.LAST_META):
		root.remove_meta(AttackBudget.LAST_META)
	var spawn: Vector3 = _game.ctx.terrain.spawn_point(1)
	var ball: Vector3 = _game.ctx.terrain.drop_point(spawn.x, spawn.z, 1.05)
	_game.player.reset_to(ball)
	var at := Vector3(ball.x + 14.0, 0.0, ball.z + 4.0)
	at.y = _game.ctx.terrain.height(at.x, at.z)
	var rig: Node3D = _game.combat.spawn_enemy("dispatcher", at)
	rig._rest = 0.0
	rig.ignored_seconds = Dispatcher.FLUSH_IGNORE_S + 0.5
	var flushed := []
	rig.cargo_flushed.connect(func(pod: Node3D): flushed.append(pod))
	await _physics(6)
	_t.check("dispatcher commits an Express Cargo Flush", rig._flush_active)
	await _physics(int(ceil((Dispatcher.FLUSH_SIREN + 0.25) * Engine.physics_ticks_per_second)))
	_t.eq("flush pod launched", flushed.size(), 1)
	var pod := rig.get("_pod") as Node3D
	_t.check("flush pod in flight", pod != null and is_instance_valid(pod))
	if pod != null and is_instance_valid(pod):
		var scale: Vector3 = pod.global_basis.get_scale()
		_t.check("flush pod keeps its 1.4x scale in flight", scale.is_equal_approx(Vector3.ONE * 1.4), str(scale))
	rig.free()


func _run() -> void:
	await _boot()
	await _check_camp_floor_and_turntable()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	await _physics(6)
	await _frames(4)
	await _check_live_pilot()
	await _check_weapon_rig_motion()
	await _check_flush_pod_scale()
	UiTokens.reduced_motion = false
	_game.free()
	quit(_t.verdict())
