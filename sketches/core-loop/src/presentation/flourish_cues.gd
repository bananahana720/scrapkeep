extends Node

const FlourishRows := preload("res://src/presentation/flourish_rows.gd")
const Requisition := preload("res://src/boss/requisition.gd")
const BossModel := preload("res://src/boss/boss_model.gd")
const Palette := preload("res://src/core/palette.gd")


const HOLD_CAP := 2.0
const RISE_OUT := 16.0
const RISE_UP := 12.0
const EJECT_UP := 11.0
const EJECT_OUT := 30.0
const EJECT_TURNS := 1.5
const EJECT_SLOW := 0.75

var ctx
var player
var _played_this_run := {}
var _earned_in_fight := {}
var _world_beaten := {}
var _clear_due := ""
var _chain: Array[String] = []
var _victory_ids := {}
var _chain_from := ""
var _playing := {}
var _world := []
var _slow := {}


func setup(ctx_ref, player_ref) -> void:
	ctx = ctx_ref
	player = player_ref
	name = "FlourishCues"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	var events = ctx.events
	events.run_started.connect(func(_class_id: String):
		_played_this_run.clear()
		_world_beaten.clear()
		_drop_clear()
		_chain.clear())
	events.boss_arena_entered.connect(_on_arena_entered)
	events.boss_phase_changed.connect(_on_phase)
	events.boss_defeated.connect(_on_boss_defeated)
	events.world_entered.connect(_on_world_entered)
	events.beacon_unsealed.connect(_on_beacon_unsealed)
	events.stage_entered.connect(_on_stage_entered)
	events.warden_engaged.connect(_on_warden_engaged)
	events.achievement_earned.connect(func(id: String): _earned_in_fight[id] = true)
	events.flow_changed.connect(_on_flow_changed)
	if player != null and player.has_signal("finished"):
		player.finished.connect(_on_finished)
	if ctx.flow != null and "victory_plan" in ctx.flow:
		ctx.flow.victory_plan = plan_victory


func _boss_id() -> String:
	var row: Dictionary = ctx.flow.boss_row(ctx.stages.world_of(ctx.run.stage))
	return String(row.get("kind", ""))


func _on_arena_entered() -> void:
	_earned_in_fight.clear()
	for id in matching("arrival", _boss_id()):
		if _played_this_run.has(id):
			continue
		_played_this_run[id] = true
		_play(id)


func names_boss() -> bool:
	return matching("arrival", _boss_id()).any(func(id): return player != null and player.reading(id))


func _on_phase(phase: int, _name: String) -> void:
	for id in matching("phase", _boss_id()):
		if phase in FlourishRows.row(id).get("phases", []):
			_play(id)


func plan_victory() -> Dictionary:
	var boss := _boss_id()
	var routs := matching("rout", boss)
	if routs.is_empty():
		return {"hold": 0.0, "veil": 0.0}
	var rout := routs[0]
	_chain.clear()
	_victory_ids = {rout: true}
	_chain_from = rout
	for id in matching("sign_on", boss):
		if _earned_in_fight.has(String(FlourishRows.row(id).get("earned", ""))):
			_chain.append(id)
			_victory_ids[id] = true
	var base: float = ctx.flow.VICTORY_SECONDS
	var veil := length_of(rout)
	var total := veil
	for id in _chain:
		total += length_of(id)
	var hold := clampf(total - base, 0.0, HOLD_CAP)
	var start := 0.0
	var paid := {}
	for id in [rout] + _chain:
		var end := start + length_of(id)
		paid[id] = clampf(minf(end, base + hold) - maxf(start, base), 0.0, hold)
		start = end
	if player != null:
		player.stop_all()
	_play(rout, paid[rout])
	for id in _chain:
		_playing[id] = {"held": paid[id]}
	return {"hold": hold, "veil": veil}


static func matching(on: String, boss: String) -> Array[String]:
	var out: Array[String] = []
	for id in FlourishRows.ROWS:
		var row: Dictionary = FlourishRows.ROWS[id]
		if String(row.get("on", "")) == on and String(row.get("boss", "")) == boss:
			out.append(String(id))
	return out


static func matching_world(on: String, world: int) -> Array[String]:
	var out: Array[String] = []
	for id in FlourishRows.ROWS:
		var row: Dictionary = FlourishRows.ROWS[id]
		if String(row.get("on", "")) == on and int(row.get("world_id", 0)) == world:
			out.append(String(id))
	return out


static func world_beats(id: String, short: bool) -> Array:
	var world = FlourishRows.row(id).get("world", {})
	return world.get("short" if short else "full", []) if world is Dictionary else []


func length_of(id: String) -> float:
	return FlourishRows.length(id, _short(id))


func _short(id: String) -> bool:
	var profile = ctx.get("profile")
	return profile != null and profile.is_seen(FlourishRows.SEEN_PREFIX + id)


func _play(id: String, held := 0.0) -> void:
	var full := not _short(id)
	if player == null or not player.play(id, _seed(), _anchors()):
		return
	_playing[id] = {"held": held, "full": full}
	for beat in world_beats(id, not full):
		_world_beat(id, beat)


func _seed() -> int:
	return int(ctx.run.run_seed) if ctx.run != null else 0


func _anchors() -> Dictionary:
	var out := {}
	var boss = ctx.get("boss")
	if boss != null:
		for key in ["ship", "scooter", "arena", "warden", "pad"]:
			var node = boss.get(key)
			if node is Node3D and is_instance_valid(node):
				out[key] = node
		if out.has("ship"):
			out["ship_body"] = out.ship.model if out.ship.get("model") is Node3D else out.ship
		if out.has("warden") and not out.has("boss_body"):
			out["boss_body"] = out.warden
		if out.has("pad") and not out.has("arena"):
			out["arena"] = out.pad
	if ctx.player != null and ctx.player.has_method("body"):
		out["ball"] = ctx.player.body()
	return out


func _on_boss_defeated() -> void:
	if ctx.run != null and ctx.stages != null:
		_world_beaten[ctx.stages.world_of(int(ctx.run.stage))] = true


func _on_world_entered(world: int) -> void:
	var cleared_world := world - 1
	if not _world_beaten.get(cleared_world, false):
		return
	var rows := matching_world("world_clear", cleared_world)
	if rows.is_empty():
		return
	_world_beaten.erase(cleared_world)
	var id := rows[0]
	if _played_this_run.has(id):
		return
	_drop_clear()
	_clear_due = id
	var busy = ctx.get("screen_busy")
	if busy != null:
		busy.request(_clear_due, true)
	set_process(true)
	_ask_clear()


func _on_beacon_unsealed(stage: int) -> void:
	if ctx.stages == null or not ctx.stages.is_world_last(stage):
		return
	var world: int = ctx.stages.world_of(stage)
	for id in matching_world("stage_clear", world):
		if _played_this_run.has(id):
			continue
		_played_this_run[id] = true
		_play(id)


func _on_stage_entered(_stage: int, retry: bool) -> void:
	if retry:
		_drop_clear()


func _on_warden_engaged(_stage: int) -> void:
	if _clear_due != "":
		_drop_clear()
	if player != null and player.playing:
		var on := String(FlourishRows.row(player.id).get("on", ""))
		if on in ["world_clear", "stage_clear"]:
			player.stop_all()


func _ask_clear() -> void:
	if _clear_due == "":
		return
	var hud = ctx.root.get("hud") if ctx.root != null else null
	var busy = ctx.get("screen_busy")
	if hud != null and hud.launch_card.showing():
		if busy != null:
			busy.ready(_clear_due)
		return
	if busy != null and not busy.may_show(_clear_due, 0.0):
		return
	var id := _clear_due
	_clear_due = ""
	if _slow.is_empty():
		set_process(false)
	_played_this_run[id] = true
	if player == null or not player.play(id, _seed(), _anchors()):
		if busy != null:
			busy.done(id)
	else:
		_playing[id] = {"held": 0.0, "full": not _short(id), "busy": true}


func _drop_clear() -> void:
	if _clear_due == "":
		return
	var id := _clear_due
	_clear_due = ""
	var busy = ctx.get("screen_busy") if ctx != null else null
	if busy != null:
		busy.done(id)
	if _slow.is_empty():
		set_process(false)


func _on_finished(id: String, skipped: bool) -> void:
	if not _playing.has(id):
		return
	var info: Dictionary = _playing.get(id, {})
	_playing.erase(id)
	if bool(info.get("busy", false)) and ctx.get("screen_busy") != null:
		ctx.screen_busy.done(id)
	if String(_slow.get("id", "")) == id:
		_end_slow()
	var held := float(info.get("held", 0.0))
	if skipped and _victory_ids.has(id):
		var owed := held
		for later in _chain:
			owed += float(_playing.get(later, {}).get("held", 0.0))
			_playing.erase(later)
		_chain.clear()
		_victory_ids.clear()
		if ctx.flow != null and ctx.flow.has_method("cut_victory"):
			ctx.flow.cut_victory(owed)
		held = 0.0
	if not player.played.is_empty() and String(player.played.back().get("id", "")) == id:
		player.played.back()["held"] = snappedf(held, 0.01)
	elif skipped:
		held = 0.0
	if not skipped and id == _chain_from and not _chain.is_empty():
		var next: String = _chain.pop_front()
		_chain_from = next
		_play(next, float(_playing.get(next, {}).get("held", 0.0)))


func _on_flow_changed(state: String) -> void:
	if state in ["title", "class_select", "summary", "dead"]:
		_drop_clear()
		_chain.clear()
		_victory_ids.clear()
		_chain_from = ""
		for active_id in _playing.keys():
			if bool(_playing[active_id].get("busy", false)) and ctx.get("screen_busy") != null:
				ctx.screen_busy.done(active_id)
		_playing.clear()
		_end_slow()
		for node in _world:
			if is_instance_valid(node):
				node.queue_free()
		_world.clear()


func _reduced_motion() -> bool:
	return ctx.camera != null and bool(ctx.camera.get("reduced_motion"))


func _world_beat(id: String, beat: Dictionary) -> void:
	if _reduced_motion():
		return
	match String(beat.get("kind", "")):
		"slow":
			_slow_for(id, float(beat.get("at", 0.0)), float(beat.get("for", 0.0)), float(beat.get("scale", 1.0)))
		"rise":
			_rise(float(beat.get("at", 0.0)), float(beat.get("seconds", 1.0)))
		"eject":
			_eject(float(beat.get("at", 0.0)), float(beat.get("seconds", 1.6)))
		"glance":
			_glance(String(beat.get("anchor", "ship")), float(beat.get("seconds", 0.9)), float(beat.get("at", 0.0)), id)


func _glance(anchor: String, seconds: float, at := 0.0, id := "") -> void:
	if ctx.camera == null or not ctx.camera.has_method("glance_at"):
		return
	if not _hands_on():
		return
	var subject = _anchors().get(anchor)
	if not subject is Node3D:
		return
	if at <= 0.0:
		ctx.camera.glance_at(subject, seconds)
		return
	get_tree().create_timer(at, false).timeout.connect(func():
		if _playing.has(id) and not _reduced_motion() and is_instance_valid(subject) and subject.is_inside_tree() and ctx.camera != null:
			ctx.camera.glance_at(subject, seconds))


func _hands_on() -> bool:
	return ctx.root != null and not bool(ctx.root.get("bot_driven"))


func _slow_for(id: String, at: float, seconds: float, scale: float) -> void:
	if not _hands_on() or seconds <= 0.0 or ctx.root == null or not ctx.root.has_method("slow_motion"):
		return
	_slow = {"id": id, "from": at, "to": at + seconds, "scale": scale}
	set_process(true)


func _process(_delta: float) -> void:
	if _clear_due != "":
		_ask_clear()
	if _slow.is_empty():
		if _clear_due == "":
			set_process(false)
		return
	if not player.has(String(_slow.id)):
		_end_slow()
		return
	var on: bool = not get_tree().paused and player.in_window(String(_slow.id), float(_slow.from), float(_slow.to))
	ctx.root.slow_motion(float(_slow.scale) if on else 1.0)


func _end_slow() -> void:
	if _slow.is_empty():
		return
	_slow = {}
	if _clear_due == "":
		set_process(false)
	ctx.root.slow_motion(1.0)


func _rise(at: float, seconds: float) -> void:
	var boss = ctx.get("boss")
	var ship = boss.get("ship") if boss != null else null
	var arena = boss.get("arena") if boss != null else null
	if not (ship is Node3D) or not is_instance_valid(ship) or ship.get("model") == null or not (arena is Node3D):
		return
	var model: Node3D = ship.model
	var tween := model.create_tween()
	tween.tween_interval(at)
	tween.tween_method(func(f: float):
		if not is_instance_valid(model) or not is_instance_valid(ship) or not is_instance_valid(arena):
			return
		var out := Vector3(ship.global_position.x - arena.global_position.x, 0.0, ship.global_position.z - arena.global_position.z).normalized()
		var e := 1.0 - pow(1.0 - f, 3.0)
		var offset := out * RISE_OUT * (1.0 - e) + Vector3.UP * (RISE_UP * (1.0 - e) + 4.0 * sin(PI * e) * (1.0 - e))
		model.position = ship.global_basis.inverse() * offset, 0.0, 1.0, seconds)
	tween.tween_callback(func():
		if is_instance_valid(model):
			model.position = Vector3.ZERO)


func _eject(at: float, seconds: float) -> void:
	var boss = ctx.get("boss")
	var arena = boss.get("arena") if boss != null else null
	var scooter = boss.get("scooter") if boss != null else null
	if not (arena is Node3D) or not is_instance_valid(arena):
		return
	var from: Vector3 = scooter.global_position if scooter is Node3D and is_instance_valid(scooter) else ctx.player.shown_position()
	var prop := Node3D.new()
	prop.name = "RoutScooter"
	arena.add_child(prop)
	_world.append(prop)
	Requisition.dress_scooter(prop)
	if prop.get_child_count() == 0:
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(2.0, 1.0, 2.8)
		box.mesh = mesh
		box.material_override = Palette.solid(Palette.BRASS, 0.8)
		prop.add_child(box)
	prop.global_position = from
	prop.visible = false
	var view = get_viewport().get_camera_3d() if is_inside_tree() else null
	var out: Vector3 = -view.global_basis.z if view != null else from - arena.global_position
	out.y = 0.0
	out = out.normalized() if out.length() > 0.01 else Vector3.FORWARD
	var tween := prop.create_tween()
	tween.tween_interval(at)
	tween.tween_callback(func():
		if is_instance_valid(prop):
			prop.visible = true)
	tween.tween_method(func(t: float):
		if not is_instance_valid(prop):
			return
		var f := slow_mo(t)
		prop.global_position = from + out * EJECT_OUT * f + Vector3.UP * EJECT_UP * 4.0 * f * (1.0 - f)
		prop.rotation = Vector3(TAU * EJECT_TURNS * f, 0.0, PI * 0.5 * f), 0.0, 1.0, seconds)
	tween.tween_callback(func():
		if is_instance_valid(prop):
			prop.queue_free())


static func slow_mo(t: float) -> float:
	return t + EJECT_SLOW * sin(TAU * t) / TAU
