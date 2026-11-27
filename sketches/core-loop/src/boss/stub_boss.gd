extends Node

const Warden := preload("res://src/combat/warden.gd")
const Roster := preload("res://src/combat/roster.gd")
const Arena := preload("res://src/boss/arena.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
const CodexEntries := preload("res://src/boss/codex_entries.gd")
const WeakPoints := preload("res://src/boss/weak_points.gd")
const WeakPart := preload("res://src/boss/weak_part.gd")
const Augments := preload("res://src/movement/augments.gd")
const EnemyBossCraft := preload("res://src/presentation/craft/enemy_boss_craft.gd")
const Palette := preload("res://src/core/palette.gd")

enum { IDLE, FIGHT, DEFEATED }
const PAD_RADIUS := 36.0
const PAD_THICK := 2.0
const ENTRY_R := 26.0
const ENTRY_LIFT := 2.0
const RESCUE_DEPTH := 10.0
const FALLBACK_SPEC := {"plating": 120.0, "hp": 1200.0}

var ctx
var state := IDLE
var clock := 0.0
var pad: StaticBody3D
var warden: Node3D
var _posture_seen: Array = []
var _phase_started := 0.0
var _phase_open_at := 0.0
var _chunks_lost_seen := 0
var _entry_monster := false
var hold_s := 0.0
var hold_bound_s := 0.0
var _hold_capped := false
var weak = WeakPoints.off()
var _weak_opened: Array = []
var _part_nodes := {}
var _touching := {}
var _paying := ""
var _paid_frame := -1
var _reel_frame := {}


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "StubBoss"
	ctx.events.stage_entered.connect(func(_stage: int, _retry: bool): exit_arena())
	ctx.events.run_started.connect(func(_class_id: String): exit_arena())
	ctx.events.flow_changed.connect(func(flow_state: String):
		if flow_state in ["title", "class_select", "summary"]:
			exit_arena())


func active() -> bool:
	return state == FIGHT


func enter_arena(entry_velocity: Vector3) -> void:
	exit_arena()
	var center := Arena.place(ctx.terrain, ctx.run.stage)
	_build_pad(center)
	warden = Warden.new()
	ctx.root.add_child(warden)
	warden.global_position = center
	warden.setup(ctx.player, self, ctx.root, Callable(ctx.flow, "in_play"), 1.0, _warden_spec())
	warden.died.connect(_on_warden_died)
	warden.set_meta("plate_name", String(_row().get("name", "Warden")))
	_posture_seen = _posture_signature()
	state = FIGHT
	clock = 0.0
	_phase_started = 0.0
	_phase_open_at = 0.0
	_chunks_lost_seen = 0
	hold_s = 0.0
	hold_bound_s = 0.0
	_hold_capped = false
	latch_monster()
	_weak_opened.clear()
	var parts := _weak_parts()
	weak = WeakPoints.new(parts) if _weak_dial_on() and not parts.is_empty() else WeakPoints.off()
	_reel_frame.clear()
	_touching.clear()
	_paying = ""
	_paid_frame = -1
	if weak.active() and ctx.player.has_signal("struck") and not ctx.player.struck.is_connected(_on_player_struck):
		ctx.player.struck.connect(_on_player_struck)
	_place_ball(center, entry_velocity)
	ctx.flow.boss_active = true
	ctx.flow.boss_plating = live_plating()
	ctx.events.boss_arena_entered.emit()


func exit_arena() -> void:
	_free_parts()
	if is_instance_valid(warden):
		warden.queue_free()
	warden = null
	if is_instance_valid(pad):
		pad.collision_layer = 0
		pad.queue_free()
	pad = null
	if state != DEFEATED:
		state = IDLE


func _physics_process(delta: float) -> void:
	if active():
		clock += delta
		weak.step(clock)
		if weak.active():
			_step_parts()
		_hold_update()
		_hold_meter(delta)
		ctx.flow.boss_plating = live_plating()
		_publish_posture()


func _hold_boss() -> String:
	return ""


func _weak_parts() -> Array:
	return []


func _part_reachable(_id: String) -> bool:
	return true


func _removed_families() -> Array:
	return weak.removed_families()


func _weak_dial_on() -> bool:
	return _hold_boss() != "" and ChallengeDials.value(_hold_boss() + ".weak_points") >= 0.5


func _weak_wanted() -> bool:
	return _weak_dial_on() and not _weak_parts().is_empty()


func _open_weak(id: String, quiet := false) -> bool:
	var opened: bool = weak.open(id, clock)
	if opened:
		_weak_opened.erase(id)
		_weak_opened.append(id)
		_sync_part(id)
		if not quiet:
			ctx.events.weak_point_opened.emit(id, _weak_position(id), weak.open_seconds)
	return opened


func _weak_position(id: String) -> Vector3:
	var part = _part_nodes.get(id)
	if is_instance_valid(part):
		return part.global_position
	return warden.global_position if is_instance_valid(warden) else Vector3.ZERO


func weak_open() -> Array:
	return _weak_opened.filter(func(id): return weak.state(id) == WeakPoints.OPEN)


func weak_part(id: String) -> Node3D:
	var part = _part_nodes.get(id)
	return part if is_instance_valid(part) else null


func _weak_point_for(part: String, _kind: String) -> String:
	return part if part != "" and weak.has(part) else ""


func _brace_scale(_kind: String) -> float:
	return 1.0


func _weak_judge(result: Dictionary, part := "", kind := "") -> Dictionary:
	if not weak.active():
		return result
	var frame := Engine.get_physics_frames()
	var out := result.duplicate()
	if _paying == "" and frame == _paid_frame and bool(result.get("contact", false)):
		out["gain"] = 0.0
		return out
	var id: String = _paying if _paying != "" else _weak_point_for(part, kind)
	var reel := bool(result.get("reel", false))
	if reel and id != "" and int(_reel_frame.get(id, -1)) == frame:
		reel = false
	var hit := {"point": id, "reel": reel, "punch": float(result.get("punch", 0.0)), "gain": float(result.get("gain", 0.0))}
	var answer: Dictionary = weak.judge(hit)
	weak.apply(answer, clock)
	var scale := float(answer["gain_scale"])
	if scale >= 1.0:
		if reel and id != "":
			_reel_frame[id] = frame
		scale *= _brace_scale(kind)
	if float(answer["damage"]) > 0.0 or bool(answer["broke"]):
		ctx.events.boss_weak_point_hit.emit(id)
		_sync_part(id)
	out["gain"] = float(result.get("gain", 0.0)) * scale
	return out


func _add_part(id: String, at: Vector3, facing: Vector3) -> Node3D:
	var part := WeakPart.new()
	part.setup(id, facing)
	ctx.root.add_child(part)
	part.global_position = at
	if Vector2(facing.x, facing.z).length() > 0.01:
		part.look_at(at + Vector3(facing.x, 0.0, facing.z), Vector3.UP)
	part.set_state(weak.state(id))
	_part_nodes[id] = part
	return part


func _free_parts() -> void:
	for id in _part_nodes.keys():
		_free_part(id)
	_part_nodes.clear()
	_touching.clear()
	if ctx != null and ctx.player != null and ctx.player.has_signal("struck") and ctx.player.struck.is_connected(_on_player_struck):
		ctx.player.struck.disconnect(_on_player_struck)


func _free_part(id: String) -> void:
	var part = _part_nodes.get(id)
	_part_nodes.erase(id)
	_touching.erase(id)
	if is_instance_valid(part):
		if ctx.player.kit.anchor_body == part:
			ctx.player.release_grapple()
		part.collision_layer = 0
		if part.get_parent() != null:
			part.get_parent().remove_child(part)
		part.queue_free()


func _sync_part(id: String) -> void:
	var part = _part_nodes.get(id)
	if not is_instance_valid(part):
		return
	var now: int = weak.state(id)
	if part.state == now:
		return
	part.set_state(now)
	var kit = ctx.player.kit
	if now != WeakPoints.OPEN and kit.hooked and kit.anchor_body == part and kit.line_state != Augments.LINE_SMASH:
		ctx.player.release_grapple()


func _step_parts() -> void:
	var ball: Vector3 = ctx.player.ball_position()
	for id in _part_nodes.keys():
		var part = _part_nodes[id]
		if not is_instance_valid(part):
			_part_nodes.erase(id)
			continue
		_sync_part(id)
		var near: bool = weak.state(id) != WeakPoints.BROKEN and _part_reachable(id) and ball.distance_to(part.global_position) <= WeakPart.REACH \
				and (weak.state(id) == WeakPoints.OPEN or (ctx.player.kit.hooked and ctx.player.kit.anchor_body == part))
		if near and not bool(_touching.get(id, false)) and ctx.player.has_method("touch_body"):
			ctx.player.touch_body(part)
		_touching[id] = near


func _on_player_struck(enemy: Node3D, kind: String, force: float) -> void:
	if state != FIGHT or not is_instance_valid(warden) or not is_instance_valid(enemy) or warden.staggered() \
			or ctx.spawner == null or not ctx.spawner.has_method("strike"):
		return
	var id := ""
	for key in _part_nodes:
		if _part_nodes[key] == enemy:
			id = key
	if id == "":
		return
	var landing = ctx.player.smash_landing
	_paying = id
	if landing == enemy:
		ctx.player.smash_landing = warden
	ctx.spawner.strike(warden, kind, force, id)
	ctx.player.smash_landing = landing
	_paying = ""
	_paid_frame = Engine.get_physics_frames()


func _hold_minimums() -> Array:
	return []


func _hold_update() -> void:
	if _hold_boss() == "" or not is_instance_valid(warden):
		return
	var lost: int = BossPosture.CHUNKS - warden.chunks_left()
	if lost > _chunks_lost_seen:
		_chunks_lost_seen = lost
		var minimums := _hold_minimums()
		var minimum := 0.0
		if warden.chunks_left() > 0 and not minimums.is_empty():
			minimum = float(minimums[clampi(lost - 1, 0, minimums.size() - 1)]) * ChallengeDials.by_phase(_hold_boss() + ".phase_min_by_phase", lost)
		_phase_open_at = maxf(clock, _phase_started + minimum)
		_phase_started = _phase_open_at


func _hold_meter(delta: float) -> void:
	if not hold_active() or not is_instance_valid(warden):
		_hold_capped = false
		return
	hold_s += delta
	_hold_capped = _hold_capped or warden.posture() >= Warden.HOLD_CAP - 0.001
	if _hold_capped:
		hold_bound_s += delta


func hold_capped() -> bool:
	return hold_active() and is_instance_valid(warden) and warden.posture() >= Warden.HOLD_CAP - 0.001


func hold_left() -> float:
	return maxf(0.0, _phase_open_at - clock) if hold_active() else 0.0


func latch_monster() -> void:
	_entry_monster = is_instance_valid(warden) and warden.monster_build()


func hold_active() -> bool:
	_hold_update()
	return clock < _phase_open_at and not _entry_monster


func shown_chunks_left() -> int:
	return warden.chunks_left() + (1 if hold_active() else 0)


func _publish_posture() -> void:
	if not is_instance_valid(warden) or not warden.has_method("posture"):
		return
	var now := _posture_signature()
	if now == _posture_seen:
		return
	var opened: bool = warden.staggered() and not _posture_seen[1]
	_posture_seen = now
	ctx.events.posture_changed.emit(warden, warden.posture(), warden.staggered())
	if opened:
		ctx.events.weak_point_opened.emit(warden.family_point(), warden.family_point_at(), BossPosture.STAGGER_SECONDS)


func _posture_signature() -> Array:
	if not is_instance_valid(warden) or not warden.has_method("posture"):
		return [0, false, BossPosture.CHUNKS, false]
	return [floori(warden.posture()), warden.staggered(), warden.chunks_left(), warden.chunk_cracked()]


func _row() -> Dictionary:
	return ctx.flow.boss_row(ctx.stages.world_of(ctx.run.stage))


func _warden_spec() -> Dictionary:
	var spec: Dictionary = FALLBACK_SPEC.duplicate()
	if ctx.spawner != null and ctx.spawner.has_method("warden_spec"):
		spec = ctx.spawner.warden_spec(ctx.run.stage).duplicate()
	spec["stage"] = ctx.run.stage
	spec["fight"] = "posture"
	spec["lesson"] = "plate"
	spec["family"] = Roster.REACTOR
	spec["reach"] = PAD_RADIUS
	if _hold_boss() != "":
		spec["posture_hold"] = Callable(self, "hold_active")
		spec["weak_judge"] = Callable(self, "_weak_judge")
		if _weak_wanted():
			spec["weak_judge_all"] = true
	spec["heft"] = func() -> float: return float(ctx.run.heft()) if ctx != null and ctx.run != null else 0.0
	return spec


func _build_pad(center: Vector3) -> void:
	pad = StaticBody3D.new()
	pad.name = "StubBossPad"
	pad.collision_layer = 1
	pad.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = PAD_RADIUS
	cylinder.height = PAD_THICK
	shape.shape = cylinder
	pad.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.name = "PadDeckMesh"
	var pad_mesh := EnemyBossCraft.waking_arena_pad(PAD_RADIUS, PAD_THICK)
	if pad_mesh.get_surface_count() > 0 and pad_mesh.surface_get_material(0) == null:
		var fallback_mat := StandardMaterial3D.new()
		fallback_mat.resource_name = "waking_pad_fallback"
		fallback_mat.albedo_color = Color("cfd4d6")
		fallback_mat.roughness = 0.72
		fallback_mat.metallic = 0.16
		Palette.surface_grain(fallback_mat)
		pad_mesh.surface_set_material(0, fallback_mat)
	mesh.mesh = pad_mesh
	pad.add_child(mesh)
	ctx.root.add_child(pad)
	pad.global_position = center - Vector3.UP * PAD_THICK * 0.5


func _place_ball(center: Vector3, entry_velocity: Vector3) -> void:
	var at := center + Vector3(0.0, ENTRY_LIFT, ENTRY_R)
	var heading := Vector3.FORWARD
	var flat := maxf(Vector2(entry_velocity.x, entry_velocity.z).length(), ctx.tuning.f("cruise"))
	ctx.player.reset_to(at, heading * flat)
	if ctx.camera != null and ctx.camera.has_method("snap"):
		ctx.camera.snap(heading)


func _on_warden_died(_at: Vector3, _scrap: int) -> void:
	if state != FIGHT:
		return
	_free_parts()
	state = DEFEATED
	warden = null
	ctx.flow.boss_active = false
	ctx.events.boss_defeated.emit()


func _discover(id: String, at: Vector3) -> void:
	if ctx.codex != null and ctx.codex.has_method("mark_discovered"):
		ctx.codex.mark_discovered(id, at)


func _top() -> float:
	return pad.global_position.y + PAD_THICK * 0.5 if is_instance_valid(pad) else -INF


func height(x: float, z: float) -> float:
	return ground_height_at(Vector3(x, 0.0, z))


func drop_point(x: float, z: float, clearance := 1.8) -> Vector3:
	return Vector3(x, height(x, z) + clearance, z)


func ground_height_at(point: Vector3) -> float:
	if is_instance_valid(pad):
		return _top()
	if ctx.terrain != null and ctx.terrain.has_method("height"):
		return ctx.terrain.height(point.x, point.z)
	return point.y


func floor_y() -> float:
	return _top() - RESCUE_DEPTH


func rescue_point(near = null) -> Vector3:
	var from: Vector3 = near if near is Vector3 else ctx.player.ball_position()
	if not is_instance_valid(pad):
		return from
	var center := pad.global_position
	var flat := Vector2(from.x - center.x, from.z - center.z)
	flat = flat.normalized() * ENTRY_R if flat.length() > 0.01 else Vector2(0.0, ENTRY_R)
	return Vector3(center.x + flat.x, _top() + ENTRY_LIFT, center.z + flat.y)


func live_plating() -> float:
	if not is_instance_valid(warden) or warden.staggered():
		return 0.0
	return warden.plating_now()


func music_state() -> Dictionary:
	if not active() or not is_instance_valid(warden):
		return {}
	return {
		"in_phase": 1.0 if warden.staggered() else clampf(warden.posture() / 100.0, 0.0, 1.0),
		"held": false,
		"phase_seconds": 0.0,
	}


func objective_text() -> String:
	var row := _row()
	var who := String(row.get("name", "the boss"))
	match state:
		DEFEATED:
			return String(row.get("victory", "%s is down." % who))
		FIGHT:
			if is_instance_valid(warden) and warden.staggered():
				return "%s is staggered: hit its open core." % who
			var chunks: int = warden.chunks_left() if is_instance_valid(warden) else 0
			return "Fill %s's bar to stagger it. %d chunks left." % [who, chunks]
	return ""
