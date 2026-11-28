extends RefCounted

const Augments := preload("res://src/movement/augments.gd")
const AbilityState := preload("res://src/core/ability_state.gd")

var air_draw_active := false
var air_draw_left := Augments.KEST_AIR_DRAW_MAX_S
var _wall_kick_faces := {}
var wall_aim := {}
var last_wall_kick := {}
var last_spire_vault := {}


func reset() -> void:
	air_draw_active = false
	air_draw_left = Augments.KEST_AIR_DRAW_MAX_S
	_wall_kick_faces.clear()
	wall_aim = {}
	last_wall_kick = {}
	last_spire_vault = {}


func on_fit_class() -> void:
	air_draw_active = false
	air_draw_left = Augments.KEST_AIR_DRAW_MAX_S
	_wall_kick_faces.clear()
	wall_aim = {}


func refresh_air_draw() -> void:
	air_draw_left = Augments.KEST_AIR_DRAW_MAX_S


func apply_spire_vault(player, anchor: Vector3) -> bool:
	var v: Vector3 = player.state.velocity
	v.y = maxf(v.y, Augments.KEST_SPIRE_VAULT_UP)
	player.body().set_velocity_now(v)
	air_draw_left = Augments.KEST_AIR_DRAW_MAX_S
	player.state.air_actions = maxi(player.state.air_actions, 1)
	last_spire_vault = {"anchor": anchor, "vy": v.y}
	return true


func step_air_draw(player, delta: float) -> void:
	if player.state.grounded:
		air_draw_active = false
		air_draw_left = Augments.KEST_AIR_DRAW_MAX_S
		return
	if player.kit.slamming or Augments.holding(player.kit) or player.in_set_piece():
		air_draw_active = false
		return
	var wg = player.abilities.gauge(AbilityState.WEAPON)
	var drawing: bool = (wg != null and wg.charging) or (player.abilities.selected == AbilityState.WEAPON and player.intent.fire_held)
	if drawing and air_draw_left > 0.0:
		air_draw_active = true
		air_draw_left = maxf(0.0, air_draw_left - delta)
		player.add_external_accel(Vector3.UP * player.tuning.f("gravity") * (1.0 - Augments.KEST_AIR_DRAW_GRAVITY))
	else:
		air_draw_active = false


func decay_wall_kick(delta: float) -> void:
	for k in _wall_kick_faces.keys():
		_wall_kick_faces[k] = float(_wall_kick_faces[k]) - delta
		if float(_wall_kick_faces[k]) <= 0.0:
			_wall_kick_faces.erase(k)
	wall_aim = {}


func step_wall_kick(player) -> Dictionary:
	var face := Augments.steepest_face_at(player.body().get_world_3d().direct_space_state, player.ball_position())
	if face.is_empty():
		return {}
	var key := Augments.face_key(face["point"], face["normal"])
	if float(_wall_kick_faces.get(key, 0.0)) > 0.0:
		return {}
	var n: Vector3 = (face["normal"] as Vector3).normalized()
	var look: Vector3 = -player.drive_basis.z
	var along := look - n * look.dot(n)
	var dir := (Vector3.UP * 0.78 + n * 0.48 + (along.normalized() * 0.35 if along.length_squared() > 0.01 else Vector3.ZERO)).normalized()
	var jump_spd: float = player.tuning.f("jump_speed")
	var incoming: float = player.state.velocity.length()
	var speed := minf(Augments.KEST_WALL_KICK_CAP, maxf(jump_spd * Augments.KEST_WALL_KICK_MULT, incoming * 1.15))
	var launch := dir * speed
	launch.y = maxf(launch.y, jump_spd * Augments.KEST_WALL_KICK_UP_MULT)
	wall_aim = {"point": face["point"], "normal": n, "dir": launch.normalized(), "speed": launch.length()}
	if player.state.jump_buffer <= 0.0 and not player.intent.jump_pressed:
		return {}
	player.state.jump_buffer = 0.0
	player.state.coyote = 0.0
	player.intent.jump_pressed = false
	_wall_kick_faces[key] = Augments.KEST_WALL_KICK_LOCK_S
	air_draw_left = Augments.KEST_AIR_DRAW_MAX_S
	player.body().set_velocity_now(launch)
	last_wall_kick = {"point": face["point"], "normal": n, "velocity": launch}
	return last_wall_kick
