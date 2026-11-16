extends Node3D

const Activities := preload("res://src/world/activities.gd")
const DamageFamilies := preload("res://src/combat/damage_families.gd")
const Palette := preload("res://src/core/palette.gd")
const LoopTally := preload("res://src/core/loop_tally.gd")
const WaveCross := preload("res://src/world/wave_cross.gd")

# Reservoir (docs/design/loops.md Spec 2; Andrew approved the top three loops on 11 Nov 2026
# 18:42Z and asked for them before the sitting): a keeper's gamble on a won yard. Behind
# `--overtime=on` (off by default), on a lock row that names an `overtime` block (the dam yard).
#
# - The bell. A won yard lights a keeper's bell beside it. A ram at the cracked-face bar
#   (Activities.RAM_MIN_PER_CRUISE x cruise) rings it: one overtime wave lands on the yard's ring
#   (the row's last wave plus one plated brute) and the pot and the reservoir both rise a notch.
#   Three rings at most; it rings while a wave still stands. Nobody makes you (ruling ci).
# - The pot. A net on a post across the yard. A ram cashes it (build.gd overtime_paid) and no more
#   overtime comes; a wave still standing stays.
# - The sluice. A wheel upstream. A ram opens it: SLUICE_WARN_S of whistle, then a sheet of water
#   runs across the yard along the row's flow, longer for every notch. Machines in it are carried
#   and soaked (enemy.gd soak: wet, so arc hits them at the wet row); the ball in it is carried at
#   FLOOD_CARRY x cruise. An arc hit on a soaked machine jumps once to every soaked machine within
#   ARC_JUMP_M. One sluice a yard.
#
# Blockout: the bell, the net and the wheel are code-built shapes with no collider (a ram is a
# touch at speed), so no park file changes; art and colliders come after the sitting.

const MAX_RINGS := 3
const PROP_SIDE_M := 9.0
const SLUICE_UP_M := 14.0
const TOUCH_M := 2.9
const TOUCH_GAP_S := 0.8
const SLUICE_WARN_S := 4.0
const FLOOD_S := [2.0, 3.0, 5.0, 7.0]
const FLOOD_CARRY := 1.4
const FLOOD_ACCEL := 4.0
const FLOOD_KNOCK := 9.0
const FLOOD_KNOCK_GAP_S := 0.25
const WET_S := 8.0
const ARC_JUMP_M := 8.0
const ARC_JUMP_SHARE := 0.6
const ELITE_KIND := "plated_brute"
const OVERTIME_SEQ := 910000
const WAVE_CROSS_HOLD_S := 1.5
const WATER_ALPHA := 0.45
const WARN_ALPHA := 0.15

var ctx
var state := ""
var rings := 0
var centre := Vector3.ZERO
var radius := 26.0
var flow_dir := Vector3.FORWARD
var sluice := ""
var sluice_left := 0.0
var flood_left := 0.0
var cashed := false
var _row := {}
var _facing := 0.0
var _touched := {}
var _clock := 0.0
var _knock_wait := 0.0
var _crew: Array = []
var _soaked: Array = []
var _conducting := false
var _props: Node3D
var _bell: Node3D
var _pot: MeshInstance3D
var _wheel: Node3D
var _water: MeshInstance3D
var _water_mat: StandardMaterial3D
var _pot_next: MeshInstance3D
var _bands: Array[MeshInstance3D] = []

signal changed(state: String, rings: int)


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "Overtime"
	ctx.events.enemy_struck.connect(_on_enemy_struck)
	set_physics_process(false)


func enabled() -> bool:
	return ctx != null and ctx.player != null and ctx.player.get("tuning") != null \
		and ctx.player.tuning.option("overtime") == "on"


# The yard at `at` was won (stage_locks.gd _unlock). `facing` is the yard's heading toward the
# beacon; `lock` its lock row.
func offer(at: Vector3, facing: float, lock: Dictionary) -> void:
	clear()
	_row = lock.get("overtime", {}).duplicate()
	if _row.is_empty() or not enabled():
		return
	_row["waves"] = lock.get("waves", [])
	centre = at
	_facing = facing
	radius = float(lock.get("radius_m", 26.0))
	var flow: Array = _row.get("flow", [])
	flow_dir = Vector3(float(flow[0]), 0.0, float(flow[2])).normalized() if flow.size() == 3 \
		else Vector3(cos(facing), 0.0, sin(facing))
	state = "offered"
	rings = 0
	sluice = "ready"
	set_physics_process(true)
	_build_props()
	ctx.events.world_fact.emit("overtime_offered", _bell.global_position)
	changed.emit(state, rings)


func clear() -> void:
	state = ""
	rings = 0
	sluice = ""
	sluice_left = 0.0
	flood_left = 0.0
	cashed = false
	_touched.clear()
	_crew.clear()
	_soaked.clear()
	if _props != null:
		_props.queue_free()
	_props = null
	_water = null
	_pot_next = null
	_bands.clear()
	set_physics_process(false)


# What the pot pays now: {panels, rares, cores}.
static func pot_for(count: int) -> Dictionary:
	return {"panels": 1 if count >= 1 else 0, "rares": (1 if count >= 2 else 0) + (1 if count >= 3 else 0),
		"cores": 1 if count >= 3 else 0}


func ring() -> bool:
	if state != "offered" or rings >= MAX_RINGS:
		return false
	rings += 1
	LoopTally.note(ctx.run, "overtime")
	ctx.events.world_fact.emit("overtime_rung", _bell.global_position)
	_land_wave()
	_dress_pot()
	changed.emit(state, rings)
	return true


# The pot pays what the rings put in it; an empty pot has nothing to cash.
func cash() -> bool:
	if state != "offered" or rings <= 0:
		return false
	state = "spent"
	cashed = true
	if ctx.get("build") != null and ctx.build.has_method("overtime_paid"):
		ctx.build.overtime_paid(_pot.global_position, rings)
	ctx.events.world_fact.emit("overtime_paid", _pot.global_position)
	if _pot != null:
		_pot.visible = false
	if _pot_next != null:
		_pot_next.visible = false
	changed.emit(state, rings)
	return true


func open_sluice() -> bool:
	if sluice != "ready" or _wheel == null:
		return false
	sluice = "warning"
	sluice_left = SLUICE_WARN_S
	ctx.events.world_fact.emit("sluice_warning", _wheel.global_position)
	_show_water(true)
	return true


# Where a prop stands ("bell", "pot" or "sluice"), or Vector3.INF when the yard offers none.
func prop_at(id: String) -> Vector3:
	var node: Node3D = {"bell": _bell, "pot": _pot, "sluice": _wheel}.get(id)
	return node.global_position if _props != null and node != null and is_instance_valid(node) else Vector3.INF


# What the sheet shows: "" (nothing), "warning" (a pale ring on the ground) or "flooding".
func water_shown() -> String:
	if _water == null or not _water.visible:
		return ""
	return "flooding" if sluice == "flooding" else "warning"


func crew_alive() -> Array:
	return _crew.map(func(ref: WeakRef): return ref.get_ref()).filter(func(e): return _alive(e))


func _physics_process(delta: float) -> void:
	if state == "" or ctx == null or ctx.player == null:
		return
	_clock += delta
	_step_touches()
	_step_sluice(delta)


func _step_touches() -> void:
	var ball: Vector3 = ctx.player.ball_position()
	var speed: float = ctx.player.planar_velocity().length()
	if speed < Activities.RAM_MIN_PER_CRUISE * float(ctx.player.tuning.tier_cruise()):
		return
	for prop in [_bell, _pot, _wheel]:
		if prop == null or not prop.visible or _flat(ball, prop.global_position) > TOUCH_M:
			continue
		if _clock - float(_touched.get(prop.name, -INF)) < TOUCH_GAP_S:
			continue
		_touched[prop.name] = _clock
		if prop == _bell:
			ring()
		elif prop == _pot:
			cash()
		else:
			open_sluice()


func _step_sluice(delta: float) -> void:
	match sluice:
		"warning":
			sluice_left -= delta
			if sluice_left <= 0.0:
				sluice = "flooding"
				flood_left = float(FLOOD_S[clampi(rings, 0, FLOOD_S.size() - 1)])
				_knock_wait = 0.0
				ctx.events.world_fact.emit("sluice_open", centre)
				_show_water(true)
		"flooding":
			flood_left -= delta
			_carry(delta)
			if flood_left <= 0.0:
				sluice = "spent"
				_show_water(false)


# The sheet carries the ball toward FLOOD_CARRY x cruise along the flow, and knocks and soaks
# every machine in the yard on a short beat.
func _carry(delta: float) -> void:
	var ball: Vector3 = ctx.player.ball_position()
	if _flat(ball, centre) <= radius:
		var along: float = ctx.player.planar_velocity().dot(flow_dir)
		var want: float = FLOOD_CARRY * float(ctx.player.tuning.tier_cruise())
		if along < want:
			ctx.player.add_external_accel(flow_dir * (want - along) * FLOOD_ACCEL)
	_knock_wait -= delta
	if _knock_wait > 0.0:
		return
	_knock_wait = FLOOD_KNOCK_GAP_S
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not _alive(enemy) or _flat(enemy.global_position, centre) > radius:
			continue
		enemy.knock(flow_dir, FLOOD_KNOCK)
		if enemy.has_method("soak"):
			enemy.soak(WET_S)
			if not _soaked.any(func(ref: WeakRef): return ref.get_ref() == enemy):
				_soaked.append(weakref(enemy))


# An arc hit on a soaked machine jumps once to every other soaked machine within ARC_JUMP_M,
# at ARC_JUMP_SHARE of its force. The jumps are struck while _conducting, so they never jump again.
func _on_enemy_struck(enemy: Node3D, kind: String, force: float) -> void:
	if _conducting or state == "" or DamageFamilies.family(kind) != DamageFamilies.ARC:
		return
	if not is_instance_valid(enemy) or not enemy.has_method("wet") or not enemy.wet():
		return
	var targets: Array = []
	for ref in _soaked:
		var other = ref.get_ref()
		if other != enemy and _alive(other) and other.wet() and other.global_position.distance_to(enemy.global_position) <= ARC_JUMP_M:
			targets.append(other)
	if targets.is_empty():
		return
	_conducting = true
	for other in targets:
		ctx.spawner.strike(other, kind, force * ARC_JUMP_SHARE)
	_conducting = false


func _land_wave() -> void:
	if not ctx.can_spawn():
		return
	var waves: Array = _row_waves()
	var kinds: Array = (waves[waves.size() - 1] as Array).duplicate() if not waves.is_empty() else []
	kinds.append(ELITE_KIND)
	var ball: Vector3 = ctx.player.ball_position()
	var away := atan2(centre.z - ball.z, centre.x - ball.x)
	var drops: Array[Vector3] = []
	for i in kinds.size():
		var a := away + (float(i) - (kinds.size() - 1) * 0.5) * 0.5
		var spot := centre + Vector3(cos(a), 0.0, sin(a)) * radius * 0.6
		drops.append(ctx.terrain.drop_point(spot.x, spot.z, 2.4))
		var enemy = ctx.spawner.spawn_enemy(String(kinds[i]), drops[i])
		if enemy is Node3D:
			enemy.set_meta("pack_seq", OVERTIME_SEQ + rings)
			# The pot pays for the crew, as the yard does (ruling af): no panel roll per kill.
			enemy.set_meta("yard_crew", true)
			_crew.append(weakref(enemy))
	# The whistle sounds as the crew lands here, so its cross holds at the drop spots for a beat.
	WaveCross.mark(self, drops, 0.0, WAVE_CROSS_HOLD_S)
	ctx.events.world_fact.emit("arena_wave", centre)


func _row_waves() -> Array:
	return _row.get("waves", [])


func _alive(enemy) -> bool:
	return enemy != null and is_instance_valid(enemy) and not (enemy.has_method("is_dead") and enemy.is_dead())


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- Blockout props -------------------------------------------------------------------------

func _build_props() -> void:
	_props = Node3D.new()
	_props.name = "OvertimeProps"
	add_child(_props)
	var side := Vector3(cos(_facing + PI * 0.5), 0.0, sin(_facing + PI * 0.5))
	_bell = _post("Bell", centre + side * PROP_SIDE_M, Palette.BRASS)
	var dome := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.5
	cone.bottom_radius = 1.1
	cone.height = 1.4
	dome.mesh = cone
	dome.material_override = Palette.unshaded(Palette.BRASS)
	dome.position = Vector3.UP * 3.6
	_bell.add_child(dome)
	# The bell's price: one brass band a ring left, struck off as it rings.
	for i in MAX_RINGS:
		var band := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.28
		torus.outer_radius = 0.42
		band.mesh = torus
		band.material_override = Palette.unshaded(Palette.BRASS)
		band.position = Vector3.UP * (0.8 + 0.6 * i)
		_bell.add_child(band)
		_bands.append(band)
	var pot_post := _post("PotPost", centre - side * PROP_SIDE_M, Palette.SANDSTONE)
	_pot = MeshInstance3D.new()
	_pot.name = "Pot"
	var net := SphereMesh.new()
	net.radius = 0.7
	net.height = 1.4
	_pot.mesh = net
	_pot.material_override = Palette.unshaded(Palette.SAND)
	_pot.position = Vector3.UP * 3.4
	pot_post.add_child(_pot)
	# What the next ring would make the pot: a pale shell round it.
	_pot_next = MeshInstance3D.new()
	_pot_next.mesh = net
	var ghost := Palette.unshaded(Color(Palette.SAND, 0.25))
	ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pot_next.material_override = ghost
	_pot_next.position = _pot.position
	pot_post.add_child(_pot_next)
	_wheel = _post("Sluice", centre - flow_dir * SLUICE_UP_M, Palette.CHARCOAL)
	var wheel := MeshInstance3D.new()
	var rim := TorusMesh.new()
	rim.inner_radius = 0.9
	rim.outer_radius = 1.2
	wheel.mesh = rim
	wheel.material_override = Palette.unshaded(Palette.HAZARD)
	wheel.position = Vector3.UP * 3.0
	wheel.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	_wheel.add_child(wheel)
	# The sheet is the circle it acts in (_carry): the same radius, drawn pale through the warning.
	_water = MeshInstance3D.new()
	_water.name = "SluiceWater"
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.08
	_water.mesh = disc
	_water_mat = Palette.unshaded(Color(Palette.water_tone(), WATER_ALPHA))
	_water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water.material_override = _water_mat
	_water.position = centre + Vector3.UP * 0.5
	_water.visible = false
	_props.add_child(_water)
	_dress_pot()


func _post(id: String, at: Vector3, color: Color) -> Node3D:
	var node := Node3D.new()
	node.name = id
	_props.add_child(node)
	node.global_position = ctx.terrain.drop_point(at.x, at.z, 0.0)
	var post := MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.2
	shaft.bottom_radius = 0.25
	shaft.height = 3.0
	post.mesh = shaft
	post.material_override = Palette.unshaded(color)
	post.position = Vector3.UP * 1.5
	node.add_child(post)
	return node


# The pot swells with each ring, so the stake reads from across the yard.
func _dress_pot() -> void:
	if _pot != null:
		_pot.scale = Vector3.ONE * (1.0 + 0.45 * rings)
	if _pot_next != null:
		_pot_next.visible = rings < MAX_RINGS
		_pot_next.scale = Vector3.ONE * (1.0 + 0.45 * (rings + 1))
	for i in _bands.size():
		_bands[i].visible = i < MAX_RINGS - rings


func _show_water(on: bool) -> void:
	if _water == null:
		return
	_water.visible = on
	_water_mat.albedo_color.a = WATER_ALPHA if sluice == "flooding" else WARN_ALPHA
