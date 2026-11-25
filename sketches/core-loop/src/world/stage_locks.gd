extends Node3D

const LockRows := preload("res://src/world/lock_rows.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const Palette := preload("res://src/core/palette.gd")
const Overtime := preload("res://src/world/overtime.gd")
const WaveCross := preload("res://src/world/wave_cross.gd")


static var active := true

const LOCK_SEQ := 900000
const LOCK_LEVEL_DOT := 0.978
const LOCK_ANY_SLOPE_SHARE := 0.75
const MIN_PACK := 2
const WALL_HEIGHT := 9.0
const WALL_RISE := 0.35
const WALL_SPRING := 60.0
const WALL_DAMP := 8.0
const WALL_SLACK := 4.0
const WALL_BOUNCE := 1.6
const WALL_ACCEL_CAP := 120.0
const CREW_RING := 0.6
const CREW_SPREAD := 0.45 * PI
const WAVE_TURN := 0.6 * PI
const REFUSE_GAP := 0.6
const COLLAR_RADIUS := 5.0
const PIP_HEIGHT := 9.0
const PIP_GAP := 2.0
const CREW_MEMBER_M := 30.0

var ctx
var row := {}
var cleared := 0
var gate_open := true
var lock_state := ""
var lock_centre := Vector3.ZERO
var lock_left := 0.0
var lock_won := false
var _packs := {}
var _crew: Array = []
var _wave := 0
var _wave_wait := -1.0
var _facing := 0.0
var _sentry_landed := false
var _sentry: WeakRef = null
var _also_done := false
var _engaged_s := -1.0
var _clock := 0.0
var _refused_at := -INF
var _wall: Node3D
var _wave_marks: Node3D
var _wall_rise := 0.0
var _collar: Node3D
var _pips: Array[MeshInstance3D] = []
var _pip_lit: StandardMaterial3D
var _pip_dark: StandardMaterial3D
var overtime: Node3D


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "StageLocks"
	ctx.flow.gate = self
	ctx.events.stage_entered.connect(_on_stage_entered)
	ctx.events.warden_engaged.connect(_on_warden_engaged)
	ctx.events.enemy_struck.connect(_on_enemy_struck)
	ctx.events.activity_done.connect(_on_activity_done)
	ctx.events.flow_changed.connect(_on_flow_changed)
	_pip_lit = Palette.unshaded(Palette.BRASS)
	_pip_dark = Palette.unshaded(Palette.CHARCOAL)
	overtime = Overtime.new()
	add_child(overtime)
	overtime.setup(ctx)


func locked() -> bool:
	return not gate_open


func has_gate() -> bool:
	return not gate_row().is_empty()


func gate_row() -> Dictionary:
	return row.get("gate", {})


func lock_row() -> Dictionary:
	return row.get("lock", {})


func packs_wanted() -> int:
	return int(gate_row().get("packs", 0))


func pips_lit() -> int:
	var total := packs_wanted()
	if total <= 0:
		return 0
	return total if gate_open else mini(cleared, total)


func lock_active() -> bool:
	return lock_state == "locked"


func yard_ahead() -> bool:
	return lock_state in ["armed", "locked"]


func crew_alive() -> Array:
	return _crew.map(func(ref: WeakRef): return ref.get_ref()).filter(func(enemy): return _alive(enemy))


func yard_fraction() -> float:
	if not lock_active():
		return 0.0
	var waves := _waves()
	var total := 0
	var down := 0
	for i in waves.size():
		var size: int = waves[i].size()
		total += size
		if i < _wave:
			down += size
		elif i == _wave:
			down += maxi(0, size - crew_alive().size())
	return clampf(float(down) / float(total), 0.0, 1.0) if total > 0 else 0.0


func yard_crew(ball: Vector3) -> Node3D:
	return _nearest(crew_alive(), ball, INF) if lock_active() else null


func foe_for(ball: Vector3, reach := INF) -> Node3D:
	if lock_active():
		return _nearest(crew_alive(), ball, reach)
	if not locked():
		return null
	var best := clamp_crew(ball, reach)
	if best != null:
		return best
	return _nearest(get_tree().get_nodes_in_group("enemy").filter(func(enemy): return enemy != ctx.flow.warden and _alive(enemy) \
			and String(enemy.get("kind")) not in ["warden", "vault", ""]), ball, reach)


func clamp_crew(ball: Vector3, reach := INF) -> Node3D:
	if not locked():
		return null
	var best: Node3D = null
	var cost := INF
	for living: Array in _open_crews():
		var foe := _nearest(living, ball, reach)
		if foe != null and _flat(foe.global_position, ball) + CREW_MEMBER_M * (living.size() - 1) < cost:
			cost = _flat(foe.global_position, ball) + CREW_MEMBER_M * (living.size() - 1)
			best = foe
	return best


func _open_crews() -> Array:
	var out := []
	for seq in _packs:
		var pack: Dictionary = _packs[seq]
		if pack["counted"] or pack["spoiled"] or pack["members"].size() < MIN_PACK:
			continue
		var living := []
		var housed := _housed(pack)
		for member: Dictionary in pack["members"]:
			var enemy = member["ref"].get_ref()
			if not (member["rider"] and housed) and not member["dead"] and _alive(enemy):
				living.append(enemy)
		if not living.is_empty():
			out.append(living)
	return out


static func _housed(pack: Dictionary) -> bool:
	return pack["members"].any(func(member: Dictionary) -> bool: return not member["rider"])


static func _nearest(pool: Array, ball: Vector3, reach: float) -> Node3D:
	var best: Node3D = null
	var near := reach
	for enemy: Node3D in pool:
		var d := _flat(enemy.global_position, ball)
		if d < near:
			near = d
			best = enemy
	return best


func objective() -> String:
	if lock_active():
		return "Yard locked: break its crew."
	if locked() and _engaged_s >= 0.0:
		return "The Warden's clamp is shut: break %d crews (%d of %d)." % [packs_wanted(), cleared, packs_wanted()]
	return ""


func note_member(enemy: Node3D, seq: int, rider := false) -> void:
	if seq < 0 or enemy == null or row.is_empty():
		return
	if not _packs.has(seq):
		_packs[seq] = {"members": [], "counted": false, "spoiled": false}
	var member := {"ref": weakref(enemy), "dead": false, "rider": rider}
	_packs[seq]["members"].append(member)
	if enemy.has_signal("died"):
		enemy.died.connect(func(_at: Vector3, _scrap: int): member["dead"] = true, CONNECT_ONE_SHOT)


func _on_stage_entered(_stage: int, _retry: bool) -> void:
	_clear()
	row = {}
	if not active or ctx.calm or ctx.stages != ParkDefs:
		return
	var map = ctx.terrain.map()
	if map == null or not "title" in map:
		return
	row = LockRows.row(String(map.title))
	gate_open = gate_row().is_empty()
	lock_state = "armed" if not lock_row().is_empty() else ""


func _clear() -> void:
	cleared = 0
	gate_open = true
	lock_state = ""
	lock_won = false
	lock_left = 0.0
	_packs.clear()
	_crew.clear()
	_sentry_landed = false
	_sentry = null
	_also_done = false
	_engaged_s = -1.0
	_refused_at = -INF
	_drop_wall()
	_drop_collar()
	overtime.clear()


func _on_warden_engaged(_stage: int) -> void:
	_engaged_s = maxf(_engaged_s, 0.0)
	if lock_active():
		_unlock(false)


func _on_flow_changed(state: String) -> void:
	if state in ["dead", "gates", "launch", "summary", "title", "victory"]:
		if lock_active():
			lock_state = "spent"
			for enemy in crew_alive():
				enemy.remove_meta("yard_crew")
			_drop_wall()
		_drop_collar()
		overtime.clear()


func _on_activity_done(id: String, _at: Vector3) -> void:
	if id in gate_row().get("also", []):
		_also_done = true


func _on_enemy_struck(enemy: Node3D, _kind: String, _force: float) -> void:
	if not locked() or enemy != ctx.flow.warden or _clock - _refused_at < REFUSE_GAP:
		return
	_refused_at = _clock
	ctx.events.world_fact.emit("warden_gate_refused", enemy.global_position)


func _physics_process(delta: float) -> void:
	if ctx == null or row.is_empty() or not ctx.flow.in_stage():
		return
	_clock += delta
	if _engaged_s >= 0.0:
		_engaged_s += delta
	_count_packs()
	_step_gate()
	_step_lock(delta)
	_dress_collar()


func _count_packs() -> void:
	for seq in _packs:
		var pack: Dictionary = _packs[seq]
		if pack["counted"] or pack["spoiled"]:
			continue
		var all_down := true
		var housed := _housed(pack)
		for member: Dictionary in pack["members"]:
			if member["rider"] and housed:
				continue
			var enemy = member["ref"].get_ref()
			if enemy != null and enemy.is_dead():
				member["dead"] = true
			if member["dead"]:
				continue
			all_down = false
			if enemy == null or not enemy.is_inside_tree():
				pack["spoiled"] = true
		if pack["spoiled"] or not all_down or pack["members"].size() < MIN_PACK:
			continue
		pack["counted"] = true
		if not gate_open:
			cleared += 1
			ctx.events.world_fact.emit("warden_gate_pip", ctx.player.ball_position())


func _step_gate() -> void:
	if gate_open:
		return
	var gate := gate_row()
	if not ctx.flow.sealed or cleared >= packs_wanted() or _also_done \
			or (_engaged_s >= 0.0 and _engaged_s >= float(gate.get("max_s", INF))):
		gate_open = true
		var at: Vector3 = ctx.flow.warden.global_position if is_instance_valid(ctx.flow.warden) else ctx.player.ball_position()
		if ctx.flow.sealed:
			ctx.events.world_fact.emit("warden_gate_opened", at)
		_drop_collar()


func _step_lock(delta: float) -> void:
	match lock_state:
		"armed":
			if _engaged_s >= 0.0 or not ctx.flow.sealed:
				lock_state = "spent"
				ctx.flow.show_start_card()
				return
			var ball: Vector3 = ctx.player.ball_position()
			var beacon: Vector3 = ctx.flow.beacon.global_position
			if not ctx.player.state.grounded:
				return
			_land_sentry(ball, beacon)
			if lock_arms(true, ctx.player.state.contact_normal.y, _flat(ball, beacon), float(lock_row().get("within_m", 0.0))):
				_lock(ball, beacon)
		"locked":
			if _engaged_s >= 0.0 or not ctx.flow.sealed:
				_unlock(false)
				return
			lock_left -= delta
			_hold_ball()
			if _wall != null and _wall_rise < 1.0:
				_wall_rise = minf(1.0, _wall_rise + delta / WALL_RISE)
				_wall.scale = Vector3(1.0, maxf(0.01, _wall_rise), 1.0)
			if lock_left <= 0.0:
				_unlock(false)
			elif crew_alive().is_empty() and _wave_wait < 0.0:
				if _wave + 1 >= _waves().size():
					_unlock(true)
				else:
					_wave_wait = float(lock_row().get("wave_gap_s", 1.5))
					_mark_wave()
					ctx.events.world_fact.emit("arena_wave", lock_centre)
			elif _wave_wait >= 0.0:
				_wave_wait -= delta
				if _wave_wait < 0.0:
					_wave += 1
					_land_wave()


static func lock_arms(grounded: bool, normal_y: float, dist: float, within_m: float) -> bool:
	if not grounded or dist > within_m:
		return false
	return normal_y >= LOCK_LEVEL_DOT or dist <= within_m * LOCK_ANY_SLOPE_SHARE


func _lock(ball: Vector3, beacon: Vector3) -> void:
	var lock := lock_row()
	var radius := float(lock.get("radius_m", 26.0))
	var toward := Vector3(beacon.x - ball.x, 0.0, beacon.z - ball.z).normalized()
	lock_centre = ball + toward * minf(float(lock.get("ahead_m", 0.0)), radius * 0.5)
	lock_centre.y = ball.y
	lock_left = float(lock.get("max_s", 60.0))
	lock_state = "locked"
	_build_wall(radius)
	_retire_sentry(radius)
	ctx.events.world_fact.emit("arena_locked", lock_centre)
	_facing = atan2(toward.z, toward.x)
	_wave = 0
	_wave_wait = -1.0
	_land_wave()


func _land_sentry(ball: Vector3, beacon: Vector3) -> void:
	var sentry: Dictionary = lock_row().get("sentry", {})
	if _sentry_landed or sentry.is_empty() or _flat(ball, beacon) > float(sentry.get("within_m", 0.0)) or not ctx.can_spawn():
		return
	_sentry_landed = true
	var toward := Vector3(beacon.x - ball.x, 0.0, beacon.z - ball.z).normalized()
	var spot := ball + toward * float(sentry.get("ahead_m", 0.0)) + toward.cross(Vector3.UP) * float(sentry.get("side_m", 0.0))
	var enemy = ctx.spawner.spawn_enemy(String(sentry["kind"]), ctx.terrain.drop_point(spot.x, spot.z, 2.4))
	if enemy is Node3D:
		_sentry = weakref(enemy)


func _retire_sentry(radius: float) -> void:
	var enemy = _sentry.get_ref() if _sentry != null else null
	_sentry = null
	if _alive(enemy) and _flat(enemy.global_position, lock_centre) > radius:
		enemy.queue_free()


func _waves() -> Array:
	return lock_row().get("waves", [])


func _land_wave() -> void:
	var kinds: Array = _waves()[_wave] if _wave < _waves().size() else []
	var seq := LOCK_SEQ + int(ctx.run.stage)
	_drop_wave_marks()
	if not ctx.can_spawn():
		return
	var spots := _wave_spots(_wave)
	for i in kinds.size():
		var enemy = ctx.spawner.spawn_enemy(String(kinds[i]), spots[i])
		if enemy is Node3D:
			enemy.set_meta("pack_seq", seq)
			enemy.set_meta("yard_crew", true)
			_crew.append(weakref(enemy))


func _wave_spots(wave: int) -> Array[Vector3]:
	var kinds: Array = _waves()[wave] if wave < _waves().size() else []
	var radius := float(lock_row().get("radius_m", 26.0))
	var facing := _facing + WAVE_TURN * wave
	var out: Array[Vector3] = []
	for i in kinds.size():
		var a := facing + (float(i) - (kinds.size() - 1) * 0.5) * CREW_SPREAD / maxf(1.0, kinds.size() - 1) * 2.0
		var spot := lock_centre + Vector3(cos(a), 0.0, sin(a)) * radius * CREW_RING
		out.append(ctx.terrain.drop_point(spot.x, spot.z, 2.4))
	return out


func _mark_wave() -> void:
	_drop_wave_marks()
	_wave_marks = WaveCross.mark(self, _wave_spots(_wave + 1), _wave_wait)


func has_wave_marks() -> bool:
	return _wave_marks != null and is_instance_valid(_wave_marks) and _wave_marks.get_child_count() > 0


func _drop_wave_marks() -> void:
	if _wave_marks != null and is_instance_valid(_wave_marks):
		_wave_marks.free()
	_wave_marks = null


func _unlock(won: bool) -> void:
	lock_state = "spent"
	lock_won = won
	for enemy in crew_alive():
		enemy.remove_meta("yard_crew")
	ctx.events.world_fact.emit("arena_unlocked", lock_centre)
	_drop_wall()
	if won and ctx.get("build") != null and ctx.build.has_method("yard_cleared"):
		ctx.build.yard_cleared(lock_centre)
	if won:
		overtime.offer(lock_centre, _facing, lock_row())
	if won and not gate_open:
		cleared += 1
		ctx.events.world_fact.emit("warden_gate_pip", ctx.player.ball_position())
	ctx.flow.show_start_card()


func _hold_ball() -> void:
	var radius := float(lock_row().get("radius_m", 26.0))
	var ball: Vector3 = ctx.player.ball_position()
	var out := Vector3(ball.x - lock_centre.x, 0.0, ball.z - lock_centre.z)
	var dist := out.length()
	if dist <= radius or dist < 0.001:
		return
	var n := out / dist
	var v: Vector3 = ctx.player.state.velocity
	var outward := v.dot(n)
	if dist > radius + WALL_SLACK and outward > 0.0:
		ctx.player.set_velocity_now(v - n * outward * WALL_BOUNCE, "arena_wall")
		return
	ctx.player.add_external_accel(-n * minf(WALL_ACCEL_CAP, WALL_SPRING * (dist - radius) + WALL_DAMP * maxf(outward, 0.0)))


const FENCE_ALPHA := 0.3


func _build_wall(radius: float) -> void:
	_drop_wall()
	_wall = Node3D.new()
	_wall.name = "ArenaLockWall"
	add_child(_wall)
	_wall.global_position = lock_centre + Vector3.DOWN * 2.0
	var shell := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = radius
	tube.bottom_radius = radius
	tube.height = WALL_HEIGHT
	tube.cap_top = false
	tube.cap_bottom = false
	tube.radial_segments = 64
	shell.mesh = tube
	shell.material_override = _fence_material()
	shell.position = Vector3.UP * WALL_HEIGHT * 0.5
	_wall.add_child(shell)
	var rim := MeshInstance3D.new()
	var band := TorusMesh.new()
	band.inner_radius = radius - 0.25
	band.outer_radius = radius + 0.25
	band.rings = 96
	rim.mesh = band
	rim.material_override = Palette.unshaded(Color(Palette.SAND, 0.55))
	rim.position = Vector3.UP * 1.3
	_wall.add_child(rim)
	_wall_rise = 0.0
	_wall.scale = Vector3(1.0, 0.01, 1.0)


static func _fence_material() -> StandardMaterial3D:
	var mat := Palette.unshaded(Color(1.0, 1.0, 1.0, 0.99))
	var ramp := Gradient.new()
	ramp.set_color(0, Color(Palette.SAND, 0.0))
	ramp.set_color(1, Color(Palette.SAND, FENCE_ALPHA))
	var texture := GradientTexture2D.new()
	texture.gradient = ramp
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	texture.width = 4
	texture.height = 64
	mat.albedo_texture = texture
	return mat


func _drop_wall() -> void:
	_drop_wave_marks()
	if _wall != null and is_instance_valid(_wall):
		_wall.queue_free()
	_wall = null


func _dress_collar() -> void:
	if gate_open or not is_instance_valid(ctx.flow.warden):
		return
	if _collar == null:
		_build_collar()
	_collar.global_position = ctx.flow.warden.global_position
	for i in _pips.size():
		_pips[i].material_override = _pip_lit if i < cleared else _pip_dark
	var pulse := 1.0 + 0.06 * sin(_clock * TAU * 0.5)
	_collar.get_child(0).scale = Vector3(pulse, 1.0, pulse)


func _build_collar() -> void:
	_collar = Node3D.new()
	_collar.name = "WardenGateCollar"
	add_child(_collar)
	var ring := MeshInstance3D.new()
	var band := TorusMesh.new()
	band.inner_radius = COLLAR_RADIUS - 0.35
	band.outer_radius = COLLAR_RADIUS + 0.35
	band.rings = 64
	ring.mesh = band
	ring.material_override = Palette.unshaded(Palette.HAZARD)
	ring.position = Vector3.UP * 1.0
	_collar.add_child(ring)
	_pips.clear()
	var count := packs_wanted()
	for i in count:
		var pip := MeshInstance3D.new()
		var plate := BoxMesh.new()
		plate.size = Vector3(1.2, 1.2, 1.2)
		pip.mesh = plate
		pip.material_override = _pip_dark
		pip.position = Vector3((float(i) - (count - 1) * 0.5) * PIP_GAP, PIP_HEIGHT, 0.0)
		pip.rotation = Vector3(0.0, 0.0, PI * 0.25)
		_collar.add_child(pip)
		_pips.append(pip)


func _drop_collar() -> void:
	if _collar != null and is_instance_valid(_collar):
		_collar.queue_free()
	_collar = null
	_pips.clear()


static func _alive(enemy) -> bool:
	return enemy != null and is_instance_valid(enemy) and enemy.is_inside_tree() and not enemy.is_dead()


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
