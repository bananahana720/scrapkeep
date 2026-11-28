extends Node

const Tuning := preload("res://src/movement/tuning.gd")
const Redline := preload("res://src/combat/redline.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const EventJuice := preload("res://src/presentation/event_juice.gd")
const Rows := preload("res://src/presentation/rows.gd")
const DamageNumbers := preload("res://src/presentation/damage_numbers.gd")
const NUMBER_LIFT := 1.6
const SimClock := preload("res://src/core/sim_clock.gd")
const Parts := preload("res://src/build/parts.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const Palette := preload("res://src/core/palette.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Contact := preload("res://src/movement/contact.gd")
const Augments := preload("res://src/movement/augments.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")


const SettingsStore := preload("res://src/ui/settings_store.gd")
const REDUCED_FLASH: float = SettingsStore.REDUCED_FLASH
const SHAKE_CAP := 0.5
const IMPACT_ZOOM_FRAMES := 2
const IMPACT_ZOOM_S := 2.0 / 60.0
const IMPACT_ZOOM_CAP := 5.0
const IMPACT_ZOOM := {
	"heavy": -3.2,
	"crit": -2.4,
	"harpoon_bit": -2.2,
	"boss_weak_point_hit": -3.8,
	"enemy_rebounded": -2.8,
}
const STRIKE_STOP_FACTS := ["enemy_struck", "boss_weak_point_hit", "multi_kill", "harpoon_bit", "posture_changed",
	"posture_break", "boss_defeated", "piece_shattered", "test", "comfort"]
const STOP_FLOOR_MS := 4.0
const STOP_TRIM_FLOOR_MS := 8.0
const BITE_STOP_MS := 40.0
const CONTACT_KINDS := ["ram", "stomp", "slam"]
const THROW_LO := 11.0
const THROW_STOP_MS := [22.0, 58.0]
const THROW_SHAKE := [0.2, 0.5]
const SHATTER_WEIGHT := {3: ["hit", 0.0], 4: ["heavy", 0.0], 5: ["heavy", 30.0]}
const MAX_BURSTS := 6
const SHELL_PER_CLASS := 0.0
const SHELL_RATE := 9.0
const PULSE_SPEED := 9.0
const PULSE_MAX := 0.22
const SHELL_SWING := 0.15

const SPRING := 420.0
const DAMPING := 17.0
const MAX_SQUASH := 0.45
const SPRING_STEP := 1.0 / 120.0
const MAX_SPRING_STEPS := 64

const RUMBLE := {
	"near_miss": {"weak": 0.6, "strong": 0.0, "ms": 60},
	"harpoon_bit": {"weak": 0.35, "strong": 0.1, "ms": 50},
	"ram": {"weak": 0.25, "strong": 0.55, "ms": 100},
	"slammed": {"weak": 0.2, "strong": 0.75, "ms": 150},
	"landed": {"weak": 0.0, "strong": 0.4, "ms": 80},
	"carved": {"weak": 0.35, "strong": 0.15, "ms": 70},
	"bumped": {"weak": 0.2, "strong": 0.6, "ms": 90},
	"player_hit": {"weak": 0.45, "strong": 0.7, "ms": 170},
	"multi_kill": {"weak": 0.4, "strong": 0.3, "ms": 90},
	"boss_weak_point_hit": {"weak": 0.5, "strong": 0.65, "ms": 120},
	"posture_changed": {"weak": 0.35, "strong": 0.8, "ms": 180},
	"posture_break": {"weak": 0.45, "strong": 1.0, "ms": 260},
	"boss_defeated": {"weak": 0.5, "strong": 1.0, "ms": 400},
	"piece_shattered": {"weak": 0.3, "strong": 0.55, "ms": 90},
	"heft_class_changed": {"weak": 0.15, "strong": 0.5, "ms": 220},
	"beacon_unsealed": {"weak": 0.3, "strong": 0.85, "ms": 320},
	"heat_skim": {"weak": 0.6, "strong": 0.0, "ms": 60},
	"heat_redline": {"weak": 0.25, "strong": 0.0, "ms": Redline.COOK_OFF_S * 1000.0},
	"heat_blast": {"weak": 0.4, "strong": 1.0, "ms": 180},
	"shot_called": {"weak": 0.0, "strong": 0.5, "ms": 80},
	"call_met": {"weak": 0.0, "strong": 1.0, "ms": 250},
}
const RUMBLE_FLOOR := 0.05
const CARVE_PITCH_SPEED := 14.0

var ctx
var player
var camera
var audio
var vfx
var hook_log: Array = []
var hit_stop_log: Array = []
var hit_stop_sink: Callable
var resolve_of: Callable
var plating_of: Callable
var number_sink: Callable
var shell := 1.0
var stop_scale := 1.0
var shake_scale := 1.0
var multi_log: Array = []
var rumble_log: Array = []
const RUMBLE_LOG_CAP := 512
const LOG_CAP := 2048

var _squash := 0.0
var _squash_velocity := 0.0
var _axis := Vector3.UP
var _plant_t := -1.0
var _pylon_parts := {}
var _pylon_transform := Transform3D.IDENTITY
var _ghosts: Array = []
var _shell_velocity := 0.0
var _heft_class := 1
var _stops: Array = []
var _hits: Array = []
var _kills: Array = []
var _blasts: Array = []
var _weighed: Array = []
var _posture_seen := {}
var _flush_queued := false
var _multi_size := 0
var _multi_last := -100000
var _rumble_until := -1
var _rumble_weak := 0.0
var _rumble_strong := 0.0
var _rumble_fact := ""


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "Juice"
	player = ctx.player
	camera = ctx.camera
	player.builtin_squash = false
	hit_stop_sink = ctx.hit_stop
	var events = ctx.events
	events.landed.connect(_on_landed)
	events.slammed.connect(_on_slammed)
	events.jumped.connect(_on_jumped)
	events.dashed.connect(_on_dashed)
	events.boosted.connect(_on_boosted)
	events.launched.connect(_on_launched)
	events.mounted.connect(_on_mounted)
	events.dismounted.connect(_on_dismounted)
	events.enemy_struck.connect(_on_enemy_struck)
	events.enemy_killed.connect(_on_killed)
	events.scrap_collected.connect(_on_scrap)
	events.player_hit.connect(_on_player_hit)
	events.shot_fired.connect(_on_shot)
	events.stage_entered.connect(func(_stage: int, _retry: bool): _reset())
	for signal_name in ["stage_content_cleared", "boss_arena_entered"]:
		if events.has_signal(signal_name):
			var argc := SignalWire.arg_count(events, signal_name)
			events.connect(signal_name, _reset.unbind(argc) if argc > 0 else _reset)
	events.run_started.connect(func(_class_id: String): _heft_class = 1)
	_wire_loop_rumble(events)
	events.world_fact.connect(func(kind: String, at: Vector3):
		if camera != null and kind == "arena_locked":
			camera.set_lock(at)
		elif camera != null and kind == "arena_unlocked":
			camera.set_lock(null))
	events.flow_changed.connect(func(state: String):
		if camera != null and state in ["gates", "launch", "summary", "title", "victory"]:
			camera.set_lock(null))
	if ctx.spawner != null and ctx.spawner.has_method("resolve"):
		resolve_of = Callable(ctx.spawner, "resolve")
	if ctx.spawner != null and ctx.spawner.has_method("plating_of"):
		plating_of = Callable(ctx.spawner, "plating_of")
	var charges = ctx.spawner.get("sticky") if ctx.spawner != null else null
	if charges != null and charges.has_signal("stuck"):
		charges.stuck.connect(_on_stuck)
	wire_optional()


func wire_optional() -> void:
	var events = ctx.events
	SignalWire.listen(events, "beacon_unsealed", _on_unsealed)
	SignalWire.listen(events, "heft_class_changed", _on_heft_class)
	SignalWire.listen(events, "heft_class_dropped", _on_heft_class)
	SignalWire.listen(events, "boss_weak_point_hit", _on_weak_point)
	SignalWire.listen(events, "enemy_rebounded", _on_rebounded)
	SignalWire.listen(events, "near_miss", _on_near_miss)
	SignalWire.listen(events, "scrap_lost", _on_scrap_lost)
	SignalWire.listen(events, "sticky_detonated", _on_detonated)
	SignalWire.listen(events, "rocket_jumped", _on_rocket_jumped)
	SignalWire.listen(events, "part_gained", _on_part)
	SignalWire.listen(events, "core_gained", _on_core)
	SignalWire.listen(events, "quick_break", _on_quick_break)
	SignalWire.listen(events, "harpoon_bit", _on_harpoon_bit)
	SignalWire.listen(events, "carved", _on_carved)
	SignalWire.listen(events, "bumped", _on_bumped)
	SignalWire.listen(events, "enemy_walled", _on_walled)
	SignalWire.listen(events, "posture_changed", _on_posture)
	SignalWire.listen(events, "boss_defeated", _on_boss_defeated)


func _on_harpoon_bit(_enemy: Node3D, _at: Vector3) -> void:
	request_hit_stop(BITE_STOP_MS / 1000.0, "harpoon_bit")
	impact_zoom("harpoon_bit")
	rumble("harpoon_bit")


func _on_carved(_at: Vector3, seconds: float, speed: float) -> void:
	var share := clampf(seconds / 1.2, 0.4, 1.0)
	if audio != null:
		audio.play("carved", lerpf(-4.0, 0.0, share), clampf(speed / CARVE_PITCH_SPEED, 0.85, 1.25))
	rumble("carved", share)


static func collision_share(row: Dictionary, speed: float) -> float:
	return clampf((speed - float(row["min_speed"])) / (float(row["full_speed"]) - float(row["min_speed"])), 0.0, 1.0)


static func _span(pair: Array, share: float) -> float:
	return lerpf(float(pair[0]), float(pair[1]), share)


func _on_bumped(at: Vector3, normal: Vector3, speed: float) -> void:
	var row := EventJuice.juice("bumped")
	var share := collision_share(row, speed)
	squash(lerpf(0.12, float(row["squash"]), share), normal)
	_camera("kick", "bumped", -normal, float(row["kick"]) * share)
	if audio != null:
		audio.play("bumped", _span(row["db"], share), _span(row["pitch"], share))
	if vfx != null:
		vfx.play_fx("bumped", at, Color.TRANSPARENT, "", normal)
	if share >= float(row["shake_from"]):
		request_shake(float(row["shake"]) * share, 0.18, "bumped")
	rumble("bumped", maxf(share, 0.35))


func _on_walled(_enemy: Node3D, at: Vector3, normal: Vector3, speed: float) -> void:
	var row := EventJuice.juice("enemy_walled")
	var share := collision_share(row, speed)
	if audio != null:
		audio.play("enemy_walled", _span(row["db"], share), _span(row["pitch"], share))
	if vfx != null:
		vfx.play_fx("enemy_walled", at, Color.TRANSPARENT, "", normal)
	if player != null and at.distance_to(player.shown_position()) <= float(row["near_m"]):
		request_shake(float(row["shake"]) * share, 0.15, "enemy_walled")


func on_prop_kicked(at: Vector3, mode: String, speed: float, tags: Array) -> void:
	var row: Dictionary = EventJuice.juice("prop_kicked")[mode]
	var share := clampf((speed - 4.0) / 26.0, 0.0, 1.0)
	var metal := "machine" in tags or "sign" in tags
	var sound := String(row["metal"] if metal else row["sound"])
	if audio != null and sound != "":
		audio.play("prop_kicked", float(row["db"]) + 4.0 * share, _span(row["pitch"], share), "SFX", sound)
	if vfx != null:
		vfx.burst("dust", at - Vector3.UP * 0.4, EventKinds.color("landed"), int(row["dust"]))


func _reset() -> void:
	if ctx.run.has_method("heft_class"):
		_heft_class = int(ctx.run.heft_class())
	if camera != null:
		camera.set_lock(null)
	_squash = 0.0
	_squash_velocity = 0.0
	_plant_t = -1.0
	_hits.clear()
	_kills.clear()
	_blasts.clear()
	_weighed.clear()
	_posture_seen.clear()
	_multi_size = 0
	for ghost in _ghosts:
		if is_instance_valid(ghost["node"]):
			ghost["node"].queue_free()
	_ghosts.clear()


func set_comfort(id: String, level: float) -> void:
	level = clampf(level, 0.0, 1.0)
	match id:
		"shake":
			shake_scale = level
			if camera != null:
				camera.motion_scale = level
		"hitstop":
			stop_scale = level


func set_reduced_motion(on: bool) -> void:
	if camera != null:
		camera.reduced_motion = on
	if vfx != null and vfx.edge != null:
		vfx.edge.flash_scale = REDUCED_FLASH if on else 1.0


func comfort(id: String) -> float:
	return shake_scale if id == "shake" else stop_scale


func squash(amount: float, axis: Vector3) -> void:
	_squash = clampf(amount, -MAX_SQUASH, MAX_SQUASH)
	_squash_velocity = 0.0
	if axis.length_squared() > 0.01:
		_axis = axis.normalized()


func pulse(amount: float) -> void:
	var room := clampf(1.0 - signf(amount) * (shell - shell_target()) / SHELL_SWING, 0.0, 1.0)
	_shell_velocity = clampf(_shell_velocity + amount * room * PULSE_SPEED, -PULSE_MAX * PULSE_SPEED, PULSE_MAX * PULSE_SPEED)


func _on_landed(impact: float) -> void:
	squash(clampf(impact / 26.0, 0.0, 0.42), player.state.contact_normal)
	rumble("landed", clampf((impact - 10.0) / 16.0, 0.0, 1.0))
	if impact > 18.0:
		_camera("kick", "landed", Vector3.DOWN, impact * 0.012)


func _on_jumped(air: bool) -> void:
	squash(-0.22 if air else -0.28, Vector3.UP)


func _on_slammed(_at: Vector3, strength: float, _flatness: float) -> void:
	if strength < 0.05:
		return
	squash(0.3 + 0.2 * minf(strength, 1.0), player.state.contact_normal)
	rumble("slammed", minf(strength, 1.0))
	_camera("kick", "slammed", Vector3.DOWN, 0.35 + 0.35 * minf(strength, 1.5))
	_camera("punch_fov", "slammed", Vector3.ZERO, -4.0 * minf(strength, 1.5), 0.25)


func _process(delta: float) -> void:
	if player == null:
		return
	step_springs(delta)
	var juice: Node3D = player.juice_node()
	var basis := _axis_scale(_axis, _squash)
	var flat: Vector3 = player.planar_velocity()
	if flat.length() > 1.0:
		basis = _axis_scale(flat.normalized(), -0.1 * player.speed_fraction()) * basis
	juice.basis = basis.scaled(Vector3.ONE * shell)
	var ground: Vector3 = player.state.contact_normal if player.state.grounded else Vector3.UP
	juice.position = -_axis * Tuning.RADIUS * clampf(_squash, -0.3, MAX_SQUASH) * 0.9 * shell + ground * Tuning.RADIUS * (shell - 1.0)
	var mount: Node3D = player.pod_mount() if player.has_method("pod_mount") else null
	if mount != null:
		mount.position = juice.position
	_animate_pylon(delta)
	if vfx != null and audio != null:
		vfx.set_chain(audio.kill_streak.length if audio.kill_streak.live(Time.get_ticks_msec()) else 0, audio.kill_streak.rung)


func step_springs(delta: float) -> void:
	var steps := clampi(ceili(delta / SPRING_STEP), 1, MAX_SPRING_STEPS)
	var h := delta / float(steps)
	var target := shell_target()
	for _i in steps:
		var accel := -SPRING * _squash - DAMPING * _squash_velocity
		_squash_velocity += accel * h
		_squash += _squash_velocity * h
		var shell_accel := SHELL_RATE * SHELL_RATE * (target - shell) - 2.0 * 0.45 * SHELL_RATE * _shell_velocity
		_shell_velocity += shell_accel * h
		shell += _shell_velocity * h


static func _axis_scale(axis: Vector3, amount: float) -> Basis:
	var up := axis.normalized()
	var right := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	right = (right - up * right.dot(up)).normalized()
	var align := Basis(right, up, right.cross(up))
	var side := 1.0 + amount * 0.5
	return align * Basis.from_scale(Vector3(side, 1.0 - amount, side)) * align.transposed()


func squash_amount() -> float:
	return _squash


func _on_dashed(direction: Vector3) -> void:
	_camera("punch_fov", "dashed", direction, 7.0, 0.3)
	squash(-0.18, direction)


func _on_boosted(direction: Vector3) -> void:
	_camera("punch_fov", "boosted", direction, 5.0, 0.3)
	squash(-0.14, direction)


func _on_launched(velocity: Vector3) -> void:
	_camera("punch_fov", "launched", velocity, 16.0, 1.0)
	_camera("kick", "launched", -velocity, 0.6)
	squash(-0.3, velocity)


func _on_dismounted(velocity: Vector3) -> void:
	_eject_ghost()
	if velocity.length() < 1.0:
		return
	_camera("punch_fov", "dismounted", velocity, clampf(4.0 + velocity.length() * 0.2, 4.0, 10.0), 0.35)
	squash(-0.25, velocity)


func _on_enemy_struck(enemy: Node3D, kind: String, force: float) -> void:
	var result := {"dealt": force, "punch": force, "full": true, "part": "", "plating": 0.0}
	if resolve_of.is_valid() and is_instance_valid(enemy):
		result = resolve_of.call(enemy, kind, force)
	if not bool(result.get("full", true)):
		return
	var at: Vector3 = player.shown_position()
	if is_instance_valid(enemy) and enemy.is_inside_tree():
		at = enemy.global_position
	var dealt := float(result.get("dealt", force))
	var key := str(enemy.get_instance_id()) if is_instance_valid(enemy) else ""
	var absorbed := bool(result.get("absorbed", false))
	if kind == "synergy":
		if not absorbed:
			_raise_number(key, dealt, at, kind, false)
		return
	var body_plating := float(plating_of.call(enemy)) if plating_of.is_valid() and is_instance_valid(enemy) else -INF
	var crit := DamageNumbers.is_crit(result, body_plating)
	var impact := EventKinds.impact(_impact_key(enemy, kind))
	_hits.append({"at": at + Vector3.UP * 0.6, "contact": _contact_point(enemy, at + Vector3.UP * 0.6), "damage": dealt, "crit": crit, "heavy": impact["stop"] == "heavy", "kind": kind,
		"stop": impact["stop"] != "none", "shake": float(impact["shake"]), "key": key, "world": at, "throw": _throw_of(kind, force), "absorbed": absorbed})
	_queue_flush()


func _raise_number(key: String, dealt: float, at: Vector3, kind: String, crit: bool) -> void:
	if number_sink.is_valid():
		number_sink.call(key, dealt, at + Vector3.UP * NUMBER_LIFT, DamageNumbers.type_of_kind(kind), "player", crit)


func _contact_point(enemy: Node3D, centre: Vector3) -> Vector3:
	var to_ball: Vector3 = player.shown_position() - centre
	var reach := minf(float(enemy.get("radius")) if is_instance_valid(enemy) and enemy.get("radius") != null else 0.0, to_ball.length() * 0.5)
	return centre + to_ball.normalized() * reach


func _impact_key(enemy: Node3D, kind: String) -> String:
	var last = ctx.spawner.get("last_impact") if ctx != null and ctx.spawner != null else null
	if last is Dictionary and not last.is_empty() and is_instance_valid(enemy) and int(last.get("enemy", 0)) == enemy.get_instance_id():
		return String(last["key"])
	return kind


func _throw_of(kind: String, force: float) -> float:
	if not kind in CONTACT_KINDS:
		return -1.0
	var heft := 1.0
	if ctx != null and ctx.spawner != null and ctx.spawner.has_method("heft"):
		heft = float(ctx.spawner.heft())
	if kind == "slam":
		return minf(force * Contact.heft_knock(heft), maxf(force, Contact.KNOCK_CEILING))
	return Contact.ram_knock(Augments.RAM_KNOCK, force, heft)


static func throw_share(throw: float) -> float:
	return clampf((throw - THROW_LO) / (Contact.KNOCK_CEILING - THROW_LO), 0.0, 1.0)


static func throw_stop_ms(throw: float, crit := false) -> float:
	var ms := lerpf(THROW_STOP_MS[0], THROW_STOP_MS[1], throw_share(throw))
	if crit:
		ms *= float(EventJuice.juice("enemy_struck")["crit"]["stop_mult"])
	return minf(ms, EventJuice.SPINE_CAP_MS)


func _queue_flush() -> void:
	if not _flush_queued:
		_flush_queued = true
		flush.call_deferred()


func flush() -> void:
	_flush_queued = false
	var caught := _hits.filter(func(h: Dictionary): return h["kind"] == "sticky").size()
	var b_row := EventJuice.juice("sticky_detonated")
	if _blasts.any(func(b: Array): return b[1]):
		for hit in _hits:
			if hit["kind"] == "sticky":
				hit["crit"] = true
	for blast in _blasts:
		_camera("punch_fov", "sticky_detonated", Vector3.ZERO,
			minf(float(b_row["punch_fov"]) + float(b_row["punch_per_enemy"]) * caught, float(b_row["punch_cap"])), 0.3)
	_blasts.clear()
	var landed := _flush_weighed()
	var struck := _flush_hits()
	var shake := maxf(float(landed["shake"]), float(struck["shake"]))
	if camera != null and shake > 0.0:
		request_shake(shake, 0.3 if float(landed["shake"]) > float(struck["shake"]) else 0.2, String(landed["fact"]) if float(landed["shake"]) > float(struck["shake"]) else "enemy_struck")
	var stop := maxf(float(landed["stop"]), float(struck["stop"]))
	if stop > 0.0:
		request_hit_stop(stop / 1000.0, String(landed["fact"]) if float(landed["stop"]) > float(struck["stop"]) else "enemy_struck")
	_flush_kills()


func _flush_weighed() -> Dictionary:
	var out := {"stop": 0.0, "shake": 0.0, "fact": ""}
	var kick := 0.0
	var kick_fact := ""
	var fov := 0.0
	var fov_fact := ""
	var rumble_strength := 0.0
	var rumble_fact := ""
	for record in _weighed:
		var fact := String(record["fact"])
		var rec_kick := float(record["kick"])
		if rec_kick > kick:
			kick = rec_kick
			kick_fact = fact
		var rec_fov := float(record["punch_fov"])
		if absf(rec_fov) > absf(fov):
			fov = rec_fov
			fov_fact = fact
		var rec_rumble := maxf(float(record["strength"]), 0.35)
		if rec_rumble > rumble_strength:
			rumble_strength = rec_rumble
			rumble_fact = fact
		if float(record["stop_ms"]) > float(out["stop"]):
			out["stop"] = float(record["stop_ms"])
			out["fact"] = fact
		out["shake"] = maxf(float(out["shake"]), float(record["shake"]))
		if out["fact"] == "":
			out["fact"] = fact
	if kick > 0.0:
		_camera("kick", kick_fact, Vector3.DOWN, kick)
	if not is_zero_approx(fov):
		_camera("punch_fov", fov_fact, Vector3.ZERO, fov, 0.35)
	if rumble_strength > 0.0:
		rumble(rumble_fact, rumble_strength)
	_weighed.clear()
	return out


func _flush_hits() -> Dictionary:
	if _hits.is_empty():
		return {"stop": 0.0, "shake": 0.0}
	var row := EventJuice.juice("enemy_struck")
	var stop := 0.0
	var shake := 0.0
	var heavy := false
	var crit := false
	var contact := Vector3.ZERO
	for i in _hits.size():
		var hit: Dictionary = _hits[i]
		var throw := float(hit.get("throw", -1.0))
		if hit["stop"]:
			stop = maxf(stop, maxf(EventJuice.stop_ms_for(hit["damage"], hit["crit"], hit["heavy"]), throw_stop_ms(throw, hit["crit"]) if throw >= 0.0 else 0.0))
			if hit["crit"]:
				shake = maxf(shake, float(row["crit"]["shake"]))
		shake = maxf(shake, maxf(hit["shake"], lerpf(THROW_SHAKE[0], THROW_SHAKE[1], throw_share(throw)) if throw >= 0.0 else 0.0))
		crit = crit or hit["crit"]
		if hit["heavy"]:
			heavy = true
			contact = hit["at"]
		if vfx != null and i < MAX_BURSTS:
			vfx.play_fx("enemy_struck", hit["contact"], DamageNumbers.effect_colour(DamageNumbers.type_of_kind(hit["kind"]), "player", hit["crit"]), "crit" if hit["crit"] else "")
		if not hit.get("absorbed", false):
			_raise_number(hit["key"], hit["damage"], hit["world"], hit["kind"], hit["crit"])
	if stop > 0.0:
		stop += EventJuice.STOP_PER_EXTRA_HIT_MS * mini(_hits.size() - 1, 5)
	if crit and audio != null:
		audio.play("enemy_struck", 0.0, 1.0, "SFX", String(row["crit"]["sound"]))
	if crit and not heavy and stop > 0.0:
		impact_zoom("crit")
	if heavy:
		_thump(contact, float(row["heavy"]["kick"]), int(row["heavy"]["dust"]), "enemy_struck")
		var throw_max := 0.0
		for hit in _hits:
			throw_max = maxf(throw_max, float(hit.get("throw", -1.0)))
		rumble("ram", lerpf(0.45, 1.0, throw_share(throw_max)))
	_hits.clear()
	return {"stop": stop, "shake": shake}


func _thump(at: Vector3, kick: float, dust: int, fact: String) -> void:
	var travel: Vector3 = player.planar_velocity()
	var along: Vector3 = travel.normalized() if travel.length() > 0.5 else (at - player.shown_position()).normalized()
	_camera("kick", fact, along, kick)
	impact_zoom("enemy_rebounded" if fact == "enemy_rebounded" else "heavy")
	squash(0.28, along)
	if vfx != null:
		vfx.burst("dust", at - Vector3.UP * 0.5, EventKinds.color("landed"), dust)


func _on_rebounded(enemy: Node3D, _speed: float) -> void:
	var row := EventJuice.juice("enemy_rebounded")
	var at: Vector3 = enemy.global_position if is_instance_valid(enemy) and enemy.is_inside_tree() else player.shown_position()
	_thump(at, float(row["kick"]), int(row["dust"]), "enemy_rebounded")
	if camera != null:
		request_shake(float(row["shake"]), 0.2, "enemy_rebounded")


func _on_weak_point(_point_id: String) -> void:
	_camera("kick", "boss_weak_point_hit", Vector3.DOWN, 0.25)
	impact_zoom("boss_weak_point_hit")
	rumble("boss_weak_point_hit")
	request_hit_stop(EventJuice.stop_ms_for(30.0, true) / 1000.0, "boss_weak_point_hit")


func _on_posture(enemy: Node3D, _posture: float, staggered: bool) -> void:
	if not is_instance_valid(enemy):
		return
	var id := enemy.get_instance_id()
	var seen: Array = _posture_seen.get(id, [false, BossPosture.CHUNKS])
	var chunks: int = int(enemy.chunks_left()) if enemy.has_method("chunks_left") else int(seen[1])
	_posture_seen[id] = [staggered, chunks]
	var lost := maxi(int(seen[1]) - chunks, 0)
	var at: Vector3 = enemy.global_position if enemy.is_inside_tree() else player.shown_position()
	if lost > 0 and chunks <= 0:
		weigh("posture_break", {"staggered": true}, at)
	elif staggered and not bool(seen[0]):
		weigh("posture_changed", {"staggered": true, "chunks_lost": lost}, at)
	elif lost > 0:
		weigh("posture_changed", {"chunks_lost": lost}, at)


func _on_boss_defeated() -> void:
	weigh("boss_defeated", {}, player.shown_position() if player != null else Vector3.ZERO)


func on_piece_shattered(tier: int, at: Vector3) -> void:
	var record := shatter_weight(tier)
	if record.is_empty():
		return
	record["at"] = at
	_weighed.append(record)
	_queue_flush()


static func shatter_weight(tier: int) -> Dictionary:
	if not SHATTER_WEIGHT.has(tier):
		return {}
	var key := String(SHATTER_WEIGHT[tier][0])
	var profile: Dictionary = Rows.WEIGHT[key]
	var stop := float(profile["stop_ms"]) if not profile["stop_ms"] is String else EventJuice.stop_ms_for(float(SHATTER_WEIGHT[tier][1]), false, profile["stop_ms"] == "heavy")
	return {"fact": "piece_shattered", "weight": key, "strength": 1.0, "stop_ms": stop, "shake": float(profile["shake"]),
		"kick": float(profile["kick"]), "punch_fov": float(profile["punch_fov"])}


func weigh(fact: String, args: Dictionary, at: Vector3) -> Dictionary:
	var record := Rows.weigh(fact, args)
	record["at"] = at
	_weighed.append(record)
	_queue_flush()
	return record


func _on_unsealed(_stage: int) -> void:
	var row := EventJuice.juice("beacon_unsealed")
	_camera("punch_fov", "beacon_unsealed", Vector3.ZERO, float(row["punch_fov"]), 0.6)
	rumble("beacon_unsealed")
	request_hit_stop(0.0, "beacon_unsealed")


func _on_killed(_kind: String, at: Vector3, _value: int) -> void:
	_kills.append(at)
	_queue_flush()


func _flush_kills() -> void:
	if _kills.is_empty():
		return
	var row := EventJuice.juice("enemy_killed")
	if vfx != null:
		for at in _kills:
			vfx.kill_pop(at)
	var now := SimClock.msec()
	var before := _multi_size if now - _multi_last <= int(row["multi_ms"]) else 0
	_multi_size = before + _kills.size()
	_multi_last = now
	_kills.clear()
	for mark in [2, 4, 8]:
		if before < mark and _multi_size >= mark:
			_log_push(multi_log, [mark, now])
			request_hit_stop(float(row["multi_stop_ms"]) / 1000.0, "multi_kill")
			rumble("multi_kill", minf(0.5 + mark / 8.0, 1.0))
			_camera("punch_fov", "multi_kill", Vector3.ZERO, -2.0 - mark * 0.5, 0.3)
			if audio != null:
				audio.play("enemy_killed", 2.0, 1.0, "SFX", "kill_pop")
			if vfx != null:
				vfx.glyph("enemy_killed", player.shown_position(), 1.0, 3.0 + mark, 0.35, Vector3.UP, "ring")


func _on_scrap(_amount: int, _at: Vector3, _total: int) -> void:
	var row := EventJuice.juice("scrap_collected")
	var rung: int = audio.scrap_streak.rung if audio != null else 0
	pulse(minf(float(row["pulse"]) * (1.0 + 0.2 * rung), float(row["pulse_cap"])))


func _on_scrap_lost(_amount: int, _at: Vector3, _total: int, _cause: String) -> void:
	pulse(float(EventJuice.juice("scrap_lost")["pulse"]))
	squash(0.3, Vector3.UP)


func _on_part(part_id: String, _source: String) -> void:
	if vfx == null:
		return
	var row := EventJuice.juice("part_gained")
	vfx.burst("fountain", player.shown_position() + Vector3.UP * 0.8, part_tint(part_id), int(row["fountain"]))
	pulse(0.12)


static func part_tint(part_id: String) -> Color:
	var def: Resource = Parts.def(part_id)
	if def == null:
		return EventKinds.color("part_gained")
	var rung := ItemGen.resolve_rarity(String(def.rarity))
	var tint: Color = Palette.SANDSTONE if rung in ["", "common"] else RewardGates.rarity_color(rung)
	return EventJuice.juice("part_gained")["element"].get(String(def.element), tint)


func _on_core(_source: String, at: Vector3, _count: int) -> void:
	if vfx != null:
		vfx.burst("fountain", at + Vector3.UP * 0.6, EventKinds.color("core_gained"), int(EventJuice.juice("core_gained")["fountain"]))


func _on_quick_break(_stage: int, _seconds: float, at: Vector3) -> void:
	pulse(0.12)
	if vfx != null:
		var row := EventJuice.juice("quick_break")
		vfx.burst("fountain", at + Vector3.UP * float(row["rise"]), EventKinds.color("quick_break"), int(row["fountain"]))


func _on_near_miss(_kind: String, at: Vector3) -> void:
	var row := EventJuice.juice("near_miss")
	request_hit_stop(0.0, "near_miss")
	_camera("punch_fov", "near_miss", Vector3.ZERO, float(row["punch_fov"]), 0.25)
	rumble("near_miss")
	if vfx != null:
		var travel: Vector3 = player.planar_velocity()
		vfx.glyph("near_miss", at + Vector3.UP * 1.8, 0.6, 1.4, 0.35, travel if travel.length() > 0.5 else Vector3.ZERO, "", Color(0, 0, 0, 0), "P2")
		vfx.glyph("near_miss", at, 1.0, 4.0, 0.3, Vector3.UP, "ring", Color(0, 0, 0, 0), "P2")


func _on_player_hit(amount: float, source: String) -> void:
	var row := EventJuice.juice("player_hit")
	_log_push(hook_log, ["edge_flash", "player_hit"])
	squash(float(row["squash"]), Vector3.ZERO)
	rumble("player_hit", clampf(0.5 + amount / 30.0, 0.5, 1.0))
	var team := DamageNumbers.team_of_source(source)
	if number_sink.is_valid():
		number_sink.call("player", amount, player.shown_position() + Vector3.UP * 1.4, "kinetic", team, false)
	if vfx == null:
		return
	var from = null
	var last: Dictionary = ctx.spawner.get("last_player_hit") if ctx.spawner != null and ctx.spawner.get("last_player_hit") != null else {}
	if not last.is_empty() and Engine.get_physics_frames() - int(last.get("frame", -100)) <= 2:
		from = last["from"]
	vfx.edge_flash(_screen_direction(from), DamageNumbers.effect_colour("kinetic", team), float(row["edge_alpha"]) * clampf(0.6 + amount / 25.0, 0.6, 1.0), float(row["edge_s"]))


func _screen_direction(from) -> Vector2:
	if from == null or camera == null or camera.cam == null:
		return Vector2.ZERO
	var local: Vector3 = camera.cam.global_basis.inverse() * ((from as Vector3) - camera.cam.global_position)
	var flat := Vector2(local.x, -local.y if local.z < 0.0 else local.z)
	return flat.normalized() if flat.length() > 0.01 else Vector2.ZERO


func _on_shot(weapon_id: String, from: Vector3, to: Vector3) -> void:
	var row := EventJuice.juice("shot_fired")
	var feel: Dictionary = row["weapons"].get(weapon_id, {})
	var aim := (to - from)
	if aim.length() < 0.01:
		return
	aim = aim.normalized()
	if float(feel.get("kick", 0.0)) > 0.0:
		_camera("kick", "shot_fired", -aim, float(feel["kick"]))
	if float(feel.get("recoil", 0.0)) > absf(_squash):
		squash(float(feel["recoil"]), aim)
	if weapon_id == "sticky_charge" and audio != null:
		var throw: Dictionary = row["throw"]
		audio.play("shot_fired", float(throw["db"]), float(throw["pitch"]), "SFX", String(throw["sound"]))


func _on_stuck(at: Vector3) -> void:
	var stick: Dictionary = EventJuice.juice("shot_fired")["stick"]
	if audio != null:
		audio.play("shot_fired", -2.0, float(stick["pitch"]), "SFX", String(stick["sound"]))
	if vfx != null:
		vfx.play_fx("sticky_stuck", at, EventKinds.color("sticky_detonated"))


func _on_detonated(at: Vector3, crit: bool) -> void:
	var row := EventJuice.juice("sticky_detonated")
	var color := EventKinds.color("sticky_detonated")
	_blasts.append([at, crit])
	_queue_flush()
	if camera != null:
		request_shake(float(row["shake"]), 0.25, "sticky_detonated")
	if vfx != null:
		vfx.glyph("sticky_detonated", at + Vector3.UP * 0.8, 1.0, 4.0, 0.18, Vector3.ZERO, "flash")
		vfx.glyph("sticky_detonated", at + Vector3.UP * 0.2, 1.0, 9.0, 0.4, Vector3.UP, "ring")
		vfx.burst("debris", at + Vector3.UP * 0.4, color, int(row["debris"]))
		vfx.burst("dust", at, EventKinds.color("landed"), int(row["dust"]))
	var away: Vector3 = player.shown_position() - at
	if away.length() < float(row["near_m"]):
		var dir := away.normalized() if away.length() > 0.1 else Vector3.UP
		_camera("kick", "sticky_detonated", dir, float(row["near_kick"]))
		squash(0.3, dir)


func _on_rocket_jumped(_at: Vector3, _speed: float) -> void:
	var row := EventJuice.juice("rocket_jumped")
	_camera("kick", "rocket_jumped", Vector3.DOWN, float(row["kick"]))
	_camera("punch_fov", "rocket_jumped", Vector3.UP, float(row["punch_fov"]), 0.5)
	squash(-float(row["squash"]), Vector3.UP)


func _on_heft_class(heft_class: int, _heft: float) -> void:
	if heft_class > _heft_class:
		squash(0.32, Vector3.UP)
		rumble("heft_class_changed")
		_log_push(hook_log, ["class_up", "heft_class_changed"])
	_heft_class = heft_class


func shell_target() -> float:
	return 1.0 + SHELL_PER_CLASS * (_heft_class - 1)


static func _log_push(log_arr: Array, entry: Variant, cap := LOG_CAP) -> void:
	if log_arr.size() >= cap:
		log_arr.pop_front()
	log_arr.append(entry)


func _camera(hook: String, fact: String, direction: Vector3, amount: float, time := 0.3) -> void:
	_log_push(hook_log, [hook, fact])
	if camera == null:
		return
	match hook:
		"punch_fov":
			camera.punch_fov(amount, time)
		"kick":
			camera.kick(direction, amount)


func rumble(fact: String, share := 1.0) -> void:
	var row: Dictionary = RUMBLE.get(fact, {})
	if row.is_empty():
		return
	var scale := clampf(share, 0.0, 1.0) * shake_scale
	var weak := float(row["weak"]) * scale
	var strong := float(row["strong"]) * scale
	var seconds := float(row["ms"]) / 1000.0
	var now := Time.get_ticks_msec()
	var running := now < _rumble_until
	if rumble_log.size() >= RUMBLE_LOG_CAP:
		rumble_log.pop_front()
	var in_play: bool = ctx == null or ctx.flow == null or ctx.flow.in_play()
	if not in_play or maxf(weak, strong) < RUMBLE_FLOOR or (running and weak <= _rumble_weak and strong <= _rumble_strong):
		rumble_log.append([fact, weak, strong, seconds, false])
		return
	_rumble_weak = weak
	_rumble_strong = strong
	_rumble_until = now + int(row["ms"])
	_rumble_fact = fact
	rumble_log.append([fact, weak, strong, seconds, true])
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, weak, strong, seconds)


func rumbling() -> String:
	return _rumble_fact if Time.get_ticks_msec() < _rumble_until else ""


func _stop_rumble(fact: String) -> void:
	if _rumble_fact != fact or Time.get_ticks_msec() >= _rumble_until:
		return
	_rumble_until = 0
	_rumble_weak = 0.0
	_rumble_strong = 0.0
	_rumble_fact = ""
	for device in Input.get_connected_joypads():
		Input.stop_joy_vibration(device)


func _wire_loop_rumble(events) -> void:
	var redline = player.get("redline")
	if redline != null:
		redline.skimmed.connect(func(_at: Vector3): rumble("heat_skim"))
		redline.redlined.connect(func(): rumble("heat_redline"))
		redline.detonated.connect(func(_at: Vector3, _force: float): rumble("heat_blast"))
		redline.cooked_off.connect(func(_at: Vector3, _force: float): rumble("heat_blast"))
		redline.changed.connect(func(_value: float, band: int):
			if band < 3:
				_stop_rumble("heat_redline"))
	events.world_fact.connect(func(kind: String, _at: Vector3):
		if kind == "shot_called" or kind == "call_met":
			rumble(kind))


func impact_zoom(fact: String, scale := 1.0) -> float:
	var amount := clampf(float(IMPACT_ZOOM.get(fact, 0.0)) * clampf(scale, 0.0, 1.5), -IMPACT_ZOOM_CAP, IMPACT_ZOOM_CAP)
	if is_zero_approx(amount):
		return 0.0
	_camera("punch_fov", fact, Vector3.ZERO, amount, IMPACT_ZOOM_S)
	return amount


func effective_shake_cap() -> float:
	var cap := SHAKE_CAP
	if camera != null and camera.has_method("active_profiles"):
		var profiles = camera.get("PROFILES")
		if profiles is Dictionary:
			for row in camera.active_profiles():
				if profiles.has(row):
					cap = minf(cap, float(profiles[row].get("shake_cap", cap)))
	return cap


func request_shake(amount: float, time: float, _fact: String) -> void:
	if camera == null:
		return
	camera.shake(minf(amount, effective_shake_cap()), time)


func request_hit_stop(seconds: float, fact: String) -> void:
	var now := SimClock.msec()
	if not STRIKE_STOP_FACTS.has(fact):
		_log_push(hit_stop_log, [seconds, 0.0, fact, now])
		return
	var wanted := minf(seconds * 1000.0, EventJuice.SPINE_CAP_MS) * stop_scale
	_stops = _stops.filter(func(stop: Array): return now - int(stop[0]) < 1000)
	var spent := 0.0
	var recent := 0.0
	for stop in _stops:
		spent += float(stop[1])
		if now - int(stop[0]) < EventJuice.STOP_WINDOW_MS:
			recent += float(stop[1])
	var sent := minf(wanted, minf(EventJuice.STOP_BUDGET_MS - spent, EventJuice.STOP_WINDOW_BUDGET_MS - recent))
	var spaced := _stops.is_empty() or now - int(_stops.back()[0]) - float(_stops.back()[1]) >= EventJuice.STOP_GAP_MS
	var in_play: bool = ctx == null or ctx.flow == null or ctx.flow.in_play()
	if not in_play or not spaced or wanted < STOP_FLOOR_MS or sent < minf(wanted, STOP_TRIM_FLOOR_MS):
		_log_push(hit_stop_log, [seconds, 0.0, fact, now])
		return
	_stops.append([now, sent])
	_log_push(hit_stop_log, [seconds, sent / 1000.0, fact, now])
	_log_push(hook_log, ["hit_stop", fact])
	if hit_stop_sink.is_valid():
		hit_stop_sink.call(sent / 1000.0)


func reset_stops() -> void:
	_stops.clear()


func _on_mounted(_at: Vector3, banked_speed: float) -> void:
	_plant_t = 0.0
	_camera("punch_fov", "mounted", Vector3.ZERO, -3.0, 0.2)
	squash(0.25 + minf(banked_speed / 60.0, 0.15), player.kit.mount_normal)


func _pylon() -> Dictionary:
	if not _pylon_parts.is_empty():
		return _pylon_parts
	var pylon: Node3D = player.pylon_node()
	if pylon == null:
		return {}
	for child in pylon.get_children():
		if child is MeshInstance3D and child.mesh is CylinderMesh:
			var part := "post" if (child.mesh as CylinderMesh).height > 0.5 else "plate"
			_pylon_parts[part] = {"node": child, "rest": child.transform, "height": (child.mesh as CylinderMesh).height}
	return _pylon_parts


func _animate_pylon(delta: float) -> void:
	var parts := _pylon()
	if parts.is_empty():
		return
	var pylon: Node3D = player.pylon_node()
	if pylon.visible:
		_pylon_transform = pylon.global_transform
	for ghost in _ghosts.duplicate():
		ghost["t"] += delta / 0.16
		var node: Node3D = ghost["node"]
		if ghost["t"] >= 1.0:
			node.queue_free()
			_ghosts.erase(ghost)
			continue
		var s := 1.0 - ease(ghost["t"], 0.4)
		node.scale = Vector3(1.0, maxf(0.01, s), 1.0)
	if _plant_t < 0.0:
		return
	_plant_t += delta
	var t := clampf(_plant_t / 0.16, 0.0, 1.0)
	var drive := 1.0 + 0.12 * sin(t * PI) if t > 0.45 else lerpf(0.15, 1.12, t / 0.45)
	if parts.has("post"):
		var post: Dictionary = parts["post"]
		var node: MeshInstance3D = post["node"]
		var rest: Transform3D = post["rest"]
		node.transform = Transform3D(rest.basis.scaled(Vector3(1.0, drive, 1.0)), Vector3(rest.origin.x, post["height"] * 0.5 * drive, rest.origin.z))
	if parts.has("plate"):
		var plate: Dictionary = parts["plate"]
		var flare := lerpf(1.7, 1.0, ease(t, 0.3))
		(plate["node"] as MeshInstance3D).transform = Transform3D(plate["rest"].basis.scaled(Vector3(flare, 1.0, flare)), plate["rest"].origin)
	if t >= 1.0:
		_plant_t = -1.0
		_restore_pylon()


func _restore_pylon() -> void:
	for part in _pylon_parts.values():
		(part["node"] as Node3D).transform = part["rest"]


func _eject_ghost() -> void:
	var parts := _pylon()
	_plant_t = -1.0
	_restore_pylon()
	if not parts.has("post") or ctx.root == null:
		return
	var source: MeshInstance3D = parts["post"]["node"]
	var holder := Node3D.new()
	holder.name = "PylonEject"
	ctx.root.add_child(holder)
	holder.global_transform = _pylon_transform
	var ghost := MeshInstance3D.new()
	ghost.mesh = source.mesh
	ghost.material_override = source.material_override
	ghost.transform = parts["post"]["rest"]
	holder.add_child(ghost)
	_ghosts.append({"node": holder, "t": 0.0})
