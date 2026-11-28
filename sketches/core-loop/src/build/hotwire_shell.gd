extends RefCounted

const HotwireRules := preload("res://src/build/hotwire_rules.gd")
const Parts := preload("res://src/build/parts.gd")
const RunState := preload("res://src/core/run_state.gd")

const SHELL_SCRAP_PER_HP := 5.0
const SHELL_AIR_FACTOR := 0.75
const RIVETED_SHELL := "riveted_shell"
const RIVETED_ARMOUR := HotwireRules.RIVETED_ARMOUR
const RIVETED_AIR_FACTOR := HotwireRules.RIVETED_AIR_FACTOR
const SHELL_VAULT_WINDOW := 2.0
const SHELL_AIR_FACTOR_VAULT := 1.25
const SHELL_AIR_FACTOR_SPRINT := 1.0

var shell_window := 0.0
var _air_seen := 0.0
var _air_rest := 0.0
var _sprint_seen := false
var _glide_seen := false
var _id := ""
var state := ""
var spent := false
var _world := 1
var _tread_recovery := 0.0
var _tread_frame := -1
var _tread_kind := ""
var _tread_hits: Array[Dictionary] = []
var tread_fires := 0


func reset_run() -> void:
	shell_window = 0.0
	_air_seen = 0.0
	_air_rest = 0.0
	_id = ""
	state = ""
	spent = false
	_world = 1
	_tread_recovery = 0.0
	_tread_frame = -1
	_tread_hits = []
	tread_fires = 0


func shell_fitted(build) -> bool:
	return build.ctx != null and build.ctx.tuning != null and build.ctx.tuning.option("hotwire_shell") == "on"


func shell_held(build) -> bool:
	return shell_fitted(build) and build.ctx.run != null and RIVETED_SHELL in build.ctx.run.parts


func shell_rest_factor(build) -> float:
	if not shell_fitted(build):
		return 1.0
	return SHELL_AIR_FACTOR * (RIVETED_AIR_FACTOR if shell_held(build) else 1.0)


func shell_air_factor(build) -> float:
	if not shell_fitted(build):
		return 1.0
	var factor := shell_rest_factor(build)
	if shell_window > 0.0 and face_runner_s4(build):
		factor = maxf(factor, SHELL_AIR_FACTOR_VAULT)
	if sprinting(build) and second_wind_r6(build):
		factor = maxf(factor, SHELL_AIR_FACTOR_SPRINT)
	if gliding(build) and smoke_trail_k5(build):
		factor = maxf(factor, SHELL_AIR_FACTOR_VAULT)
	return factor


func second_wind_r6(build) -> bool:
	var tree = build.ctx.player.tree if build.ctx != null and build.ctx.player != null else null
	return tree != null and tree.world_one and "r_second_wind" in tree.picks


func smoke_trail_k5(build) -> bool:
	var tree = build.ctx.player.tree if build.ctx != null and build.ctx.player != null else null
	return tree != null and tree.world_one and "k_smoke_trail" in tree.picks


func gliding(build) -> bool:
	return build.ctx != null and build.ctx.player != null and build.ctx.player.kit != null and build.ctx.player.kit.gliding


func sprinting(build) -> bool:
	return build.ctx != null and build.ctx.player != null and build.ctx.player.kit != null and build.ctx.player.kit.sprinting


func face_runner_s4(build) -> bool:
	var tree = build.ctx.player.tree if build.ctx != null and build.ctx.player != null else null
	return tree != null and tree.world_one and "s_face_runner" in tree.picks


func open_shell_window(build) -> void:
	if not shell_fitted(build) or not face_runner_s4(build):
		return
	shell_window = SHELL_VAULT_WINDOW
	refresh_air_mod(build)


func refresh_air_mod(build) -> void:
	build.ctx.tuning.set_mod("air_control", build.sheet.mod("air_control") * shell_air_factor(build))
	note_air_factor(build)


func note_air_factor(build) -> void:
	if not shell_fitted(build):
		_air_seen = 0.0
		_air_rest = 0.0
		return
	var factor := shell_air_factor(build)
	var rest := shell_rest_factor(build)
	var before := _air_seen
	var rest_before := _air_rest
	_air_seen = factor
	_air_rest = rest
	if before > 0.0 and not is_equal_approx(before, factor) and is_equal_approx(rest_before, rest):
		build.emit_shell_air_changed(factor, factor > rest)


func shell_scrap_per_hp(build) -> float:
	if not shell_fitted(build):
		return RunState.SCRAP_PER_HP
	return SHELL_SCRAP_PER_HP / (RIVETED_ARMOUR if shell_held(build) else 1.0)


func apply_shell(build) -> void:
	build.ctx.run.scrap_per_hp = shell_scrap_per_hp(build)
	if shell_fitted(build):
		build.ctx.tuning.set_mod("air_control", build.ctx.tuning.mod("air_control") * shell_air_factor(build))
	note_air_factor(build)


func on_warden_broken(build, _stage: int) -> void:
	var world := maxi(build.ctx.run.world, 1)
	if world != _world:
		_world = world
		spent = false
		_id = ""
		state = ""
	if spent:
		return
	spent = true
	save(build)
	var ids := Parts.hotwire_offer(build.ctx.run.armor_mode, build.ctx.run.parts, build.ctx.run.world)
	if ids.is_empty():
		return
	_id = ids[0]
	state = "fit"
	save(build)
	to_open_gates(build)


func to_open_gates(build) -> void:
	if build.gates.is_open() and not _id in build.gates.offers.map(func(offer): return offer["part_id"]):
		var ids: Array = build.gates.offers.map(func(offer): return offer["part_id"])
		ids.append(_id)
		build.ctx.events.reward_offered.emit(build.gates.open(ids, build.ctx.player.ball_position(), build.heading_dir(), build.ctx.run.parts))


func save(build) -> void:
	if build.ctx != null and build.ctx.run != null:
		build.ctx.run.extra["hotwire"] = {"id": _id, "state": state, "spent": spent, "world": _world}


func restore(build, retry := false) -> void:
	if build.ctx == null or build.ctx.run == null:
		return
	if retry and not build.ctx.run.extra.has("hotwire"):
		_id = ""
		state = ""
		spent = false
		_world = 1
		return
	if (spent and not retry) or not build.ctx.run.extra.has("hotwire"):
		return
	var saved: Dictionary = build.ctx.run.extra["hotwire"]
	_id = String(saved.get("id", ""))
	state = String(saved.get("state", ""))
	spent = bool(saved.get("spent", false))
	_world = int(saved.get("world", 1))
	if state == "open":
		state = "fit"
		save(build)


func pending() -> Dictionary:
	return {"part_id": _id, "state": state}


func gate_ids(build) -> Array:
	if state == "fit" and not _id in build.ctx.run.parts:
		return [_id]
	return []


func tread_fitted(build) -> bool:
	return build.ctx != null and build.ctx.run != null and build.ctx.tuning != null \
		and HotwireRules.fitted(build.ctx.run.parts, build.ctx.tuning.option("hotwire_tread"))


func on_tread_struck(build, enemy: Node3D, kind: String, force: float) -> void:
	if build.in_own_strikes() or not tread_fitted(build) or not is_instance_valid(enemy):
		return
	var frame := Engine.get_physics_frames()
	if frame != _tread_frame or kind != _tread_kind:
		var speed: float = build.ctx.player.planar_velocity().length()
		if not HotwireRules.eligible(kind, _tread_recovery, speed, build.ctx.tuning.f("cruise"), build.ctx.run.mass):
			return
		_tread_frame = frame
		_tread_kind = kind
		_tread_recovery = HotwireRules.RECOVERY
		tread_fires += 1
	var punch: float = build.ctx.spawner.punch_of(kind, force) if build.ctx.spawner != null and build.ctx.spawner.has_method("punch_of") else force
	_tread_hits.append({"enemy": enemy, "damage": HotwireRules.bonus_damage(punch)})


func step(build, delta: float) -> void:
	if shell_window > 0.0:
		shell_window -= delta
		if shell_window <= 0.0:
			shell_window = 0.0
			refresh_air_mod(build)
	var sprinting_now := sprinting(build)
	if sprinting_now != _sprint_seen:
		_sprint_seen = sprinting_now
		if shell_fitted(build):
			refresh_air_mod(build)
	var gliding_now := gliding(build)
	if gliding_now != _glide_seen:
		_glide_seen = gliding_now
		if shell_fitted(build):
			refresh_air_mod(build)
	_tread_recovery = maxf(0.0, _tread_recovery - delta)
	var hits := _tread_hits
	_tread_hits = []
	build.begin_own_strikes()
	for hit in hits:
		if is_instance_valid(hit["enemy"]):
			build.strike_enemy(hit["enemy"], build.SYNERGY_KIND, hit["damage"])
	build.end_own_strikes()
