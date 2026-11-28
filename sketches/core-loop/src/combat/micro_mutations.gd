extends Node

const AbilityState := preload("res://src/core/ability_state.gd")
const BallRules := preload("res://src/movement/ball_rules.gd")
const Bolts := preload("res://src/combat/bolts.gd")
const Groups := preload("res://src/core/groups.gd")
const OrbitalSatellites := preload("res://src/combat/orbital_satellites.gd")
const Palette := preload("res://src/core/palette.gd")
const Parts := preload("res://src/build/parts.gd")
const Synergies := preload("res://src/build/synergies.gd")
const WeaponDriver := preload("res://src/combat/weapon_driver.gd")

var ctx
var combat
var _air_steer_surge_left := 0.0
var air_dash_bat_left := 0.0
var _boost_active_left := 0.0
var _cadence_window_extended := false
var _cadence_extended_weapon := ""
var _prev_window_state := WeaponDriver.WINDOW_IDLE
var _pendulum_zapped := {}
var _pendulum_swing_charged := false
var _pendulum_swing_origin := Vector3.INF
var _thermobaric_pins := {}
var _pulled_recent := {}
var _gravity_ledger_ready_at := -INF
var last_micro_mutation := {}
var last_cross_synergy := {}
var _micro_counts := {}
var _cross_counts := {}


func setup(ctx_ref, combat_ref) -> void:
	ctx = ctx_ref
	combat = combat_ref
	name = "MicroMutations"


func reset(clear_counts := false) -> void:
	_air_steer_surge_left = 0.0
	air_dash_bat_left = 0.0
	_boost_active_left = 0.0
	_cadence_window_extended = false
	_cadence_extended_weapon = ""
	_prev_window_state = WeaponDriver.WINDOW_IDLE
	_pendulum_zapped.clear()
	_pendulum_swing_charged = false
	_pendulum_swing_origin = Vector3.INF
	_thermobaric_pins.clear()
	_pulled_recent.clear()
	_gravity_ledger_ready_at = -INF
	if clear_counts:
		last_micro_mutation = {}
		last_cross_synergy = {}
		_micro_counts.clear()
		_cross_counts.clear()
	assert(_pendulum_zapped.is_empty() and _thermobaric_pins.is_empty() and _pulled_recent.is_empty())


func on_enemy_died(id: int) -> void:
	_pendulum_zapped.erase(id)
	_pulled_recent.erase(id)


func drop_cadence_extension() -> void:
	_cadence_window_extended = false
	_cadence_extended_weapon = ""


func has_micro_mutation(part_id: String) -> bool:
	if ctx == null:
		return false
	var build = ctx.build
	var fx = build.get("effects") if build != null else null
	if fx != null and fx.has_method("has_micro_mutation") and fx.has_micro_mutation(part_id):
		return true
	return ctx.run != null and Parts.has_micro_mutation(ctx.run.parts, part_id)


func micro_row(part_id: String) -> Dictionary:
	var build = ctx.build if ctx != null else null
	var fx = build.get("effects") if build != null else null
	if fx != null and fx.has_method("micro_mutation"):
		var row: Dictionary = fx.micro_mutation(part_id)
		if not row.is_empty():
			return row
	return Parts.micro_mutation(part_id)


func has_cross_synergy(id: String, extra := {}) -> bool:
	if ctx == null:
		return false
	var context: Dictionary = combat.synergy_context(extra)
	var build = ctx.build
	var fx = build.get("effects") if build != null else null
	if fx != null and fx.has_method("has_cross_synergy") and fx.has_cross_synergy(id, context):
		return true
	if ctx.run == null:
		return false
	return Synergies.cross_system_awake(id, ctx.run.parts, OrbitalSatellites.part_synergy_info, context)


func micro_mutation_count(part_id: String) -> int:
	return int(_micro_counts.get(part_id, 0))


func cross_synergy_count(id: String) -> int:
	return int(_cross_counts.get(id, 0))


func air_steer_surge_left() -> float:
	return _air_steer_surge_left


func cadence_window_extended() -> bool:
	return _cadence_window_extended


static func extended_window(base: Vector2, extend_frac: float) -> Vector2:
	if base.y <= base.x or extend_frac <= 0.0:
		return base
	return Vector2(base.x, base.y + (base.y - base.x) * extend_frac)


func note_micro(part_id: String, details := {}) -> void:
	_micro_counts[part_id] = int(_micro_counts.get(part_id, 0)) + 1
	var entry := details.duplicate()
	entry["part_id"] = part_id
	entry["at_clock"] = combat.clock_now()
	last_micro_mutation = entry


func note_cross(id: String, details := {}) -> void:
	_cross_counts[id] = int(_cross_counts.get(id, 0)) + 1
	var entry := details.duplicate()
	entry["id"] = id
	entry["at_clock"] = combat.clock_now()
	last_cross_synergy = entry


func stamp_ricochet_canyon(rec: Dictionary, rc_row: Dictionary) -> void:
	rec["extra_bounces"] = clampi(int(rc_row.get("extra_bounces", 2)), 0, Bolts.MAX_EXTRA_BOUNCES)
	rec["ricochet_home"] = true
	rec["ricochet_home_reach"] = float(rc_row.get("home_reach_m", Bolts.RICOCHET_HOME_REACH))
	rec["ricochet_home_turn"] = float(rc_row.get("home_turn", Bolts.RICOCHET_HOME_TURN))


func step_micro_mutations(delta: float) -> void:
	if has_micro_mutation("tread_plating") and ctx.player.state.carving:
		var bonus := float(micro_row("tread_plating").get("rate_bonus", 0.25))
		var refund_s := delta * bonus
		if ctx.player.abilities != null:
			ctx.player.abilities.refund(AbilityState.MOVEMENT, refund_s)
		if ctx.player.state.boost_cooldown > 0.0:
			ctx.player.state.boost_cooldown = maxf(0.0, ctx.player.state.boost_cooldown - refund_s)
		note_micro("tread_plating", {"refund_s": refund_s})
	if _air_steer_surge_left > 0.0:
		_air_steer_surge_left = maxf(0.0, _air_steer_surge_left - delta)
		if not ctx.player.state.grounded and has_micro_mutation("long_spool"):
			var wish := _air_steer_wish()
			if wish.length_squared() > 0.0001:
				var mult := float(micro_row("long_spool").get("steer_mult", 1.65))
				var extra_accel: float = ctx.player.tuning.f("drive_accel") * ctx.player.tuning.f("air_control") * maxf(0.0, mult - 1.0)
				ctx.player.add_external_accel(wish * extra_accel)
	if air_dash_bat_left > 0.0:
		air_dash_bat_left = maxf(0.0, air_dash_bat_left - delta)
	if _boost_active_left > 0.0:
		_boost_active_left = maxf(0.0, _boost_active_left - delta)


func _air_steer_wish() -> Vector3:
	var intent = ctx.player.intent
	if intent == null or intent.move.length_squared() < 0.02:
		return Vector3.ZERO
	var drive_basis: Basis = ctx.camera.drive_basis() if ctx.camera != null and ctx.camera.has_method("drive_basis") else Basis.IDENTITY
	return BallRules.wish_direction(intent, drive_basis, ctx.player.state)


func clear_pendulum() -> void:
	_pendulum_zapped.clear()
	_pendulum_swing_charged = false
	_pendulum_swing_origin = Vector3.INF


func on_grapple_released() -> void:
	if not ctx.flow.in_play() or not has_micro_mutation("long_spool"):
		return
	var dur := float(micro_row("long_spool").get("duration_s", 0.4))
	_air_steer_surge_left = maxf(_air_steer_surge_left, dur)
	note_micro("long_spool", {"duration_s": dur})


func on_dashed_micro(_dir: Vector3) -> void:
	if not ctx.flow.in_play():
		return
	if has_micro_mutation("dash_vane") and not ctx.player.state.grounded:
		air_dash_bat_left = maxf(air_dash_bat_left, float(micro_row("dash_vane").get("window_s", 0.28)))
	if has_micro_mutation("boost_coil"):
		_boost_active_left = maxf(_boost_active_left, float(micro_row("boost_coil").get("window_s", 0.5)))


func on_boosted_micro(_dir: Vector3) -> void:
	if not ctx.flow.in_play():
		return
	if has_micro_mutation("boost_coil"):
		_boost_active_left = maxf(_boost_active_left, float(micro_row("boost_coil").get("window_s", 0.5)))


func step_cadence_micro(weapon: String, p: Resource, shots: Array) -> void:
	var wsnap: Dictionary = combat.weapon_driver.state_snapshot()
	var cur_state := String(wsnap.get("window", WeaponDriver.WINDOW_IDLE))
	var skilled_hit: bool = cur_state == WeaponDriver.WINDOW_HIT and _prev_window_state != WeaponDriver.WINDOW_HIT
	if not skilled_hit:
		for shot in shots:
			var kind := String(shot.get("kind", ""))
			if bool(shot.get("overclock_skilled", false)) or kind in [WeaponDriver.SHOT_SNAP, WeaponDriver.SHOT_BEAT_3, WeaponDriver.SHOT_STAMP, WeaponDriver.SHOT_RAIL]:
				skilled_hit = true
				break
	if skilled_hit and has_micro_mutation("loose_trigger") and p != null and p.window_s.y > p.window_s.x:
		var extend_frac := float(micro_row("loose_trigger").get("window_extend", 0.25))
		var widened: Resource = p.copy()
		widened.window_s = extended_window(p.window_s, extend_frac)
		combat.weapon_driver.sync_pattern(weapon, widened)
		_cadence_window_extended = true
		_cadence_extended_weapon = weapon
		note_micro("loose_trigger", {"weapon": weapon, "base": p.window_s, "extended": widened.window_s})
	elif _cadence_window_extended:
		var missed: bool = cur_state == WeaponDriver.WINDOW_SPENT and _prev_window_state != WeaponDriver.WINDOW_SPENT
		var swapped: bool = weapon != _cadence_extended_weapon
		if (missed or swapped or not has_micro_mutation("loose_trigger")) and p != null:
			_cadence_window_extended = false
			_cadence_extended_weapon = ""
			combat.weapon_driver.sync_pattern(weapon, p)
	_prev_window_state = cur_state


func on_world_fact_w47(kind: String, at: Vector3) -> void:
	if kind != "piece_shattered" or not ctx.flow.in_play():
		return
	if has_micro_mutation("boost_coil") and (_boost_active_left > 0.0 or ctx.player.kit.sprinting):
		var share := float(micro_row("boost_coil").get("cd_refresh", 0.5))
		var full_boost: float = ctx.player.tuning.boost_cooldown()
		if ctx.player.state.boost_cooldown > 0.0:
			ctx.player.state.boost_cooldown = maxf(0.0, ctx.player.state.boost_cooldown - full_boost * share)
		if ctx.player.abilities != null:
			var mv_cd: float = ctx.player.abilities.cooldown_of(AbilityState.MOVEMENT)
			if mv_cd > 0.0:
				ctx.player.abilities.refund(AbilityState.MOVEMENT, mv_cd * share)
		_boost_active_left = 0.0
		note_micro("boost_coil", {"at": at, "refresh_share": share})
	if has_cross_synergy("demolition_derby"):
		var row := Synergies.cross_system_row("demolition_derby")
		var radius := float(row.get("radius_m", 12.0))
		var dmg: float = maxf(float(row.get("damage_base", 24.0)), combat.weapon_hit()) * combat.heft()
		var knock := float(row.get("knock", 10.0))
		combat.effects.shockwave(at, radius, row.get("color", Palette.AMBER))
		var hits := 0
		for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
			if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
				continue
			var reach: float = enemy.global_position.distance_to(at)
			if reach > radius:
				continue
			var scale := clampf(1.0 - reach / (radius * 1.25), 0.35, 1.0)
			combat.deal_hit(enemy, combat.SYNERGY, dmg * scale, enemy.global_position - at, knock, "", "item_proc", "proc")
			hits += 1
		ctx.player.state.boost_cooldown = 0.0
		if ctx.player.abilities != null:
			ctx.player.abilities.grant(AbilityState.MOVEMENT)
		note_cross("demolition_derby", {"at": at, "radius": radius, "hits": hits})


func step_cross_synergies(_delta: float, enemies: Array) -> void:
	_step_pendulum_tesla(enemies)
	_step_thermobaric_pins(enemies)


func _step_pendulum_tesla(enemies: Array) -> void:
	var kit = ctx.player.kit
	if not kit.hooked:
		if not _pendulum_zapped.is_empty():
			_pendulum_zapped.clear()
		_pendulum_swing_charged = false
		_pendulum_swing_origin = Vector3.INF
		return
	if not has_cross_synergy("pendulum_tesla"):
		return
	var row := Synergies.cross_system_row("pendulum_tesla")
	var a: Vector3 = ctx.player.ball_position()
	var b: Vector3 = kit.anchor
	if not _pendulum_swing_origin.is_finite():
		_pendulum_swing_origin = a
	if a.distance_squared_to(b) < 0.25:
		return
	var width := float(row.get("cable_width_m", 1.8))
	var dmg := maxf(float(row.get("damage_base", 18.0)), combat.weapon_hit() * 0.85)
	var color: Color = row.get("color", Palette.ARC)
	var zapped_now := 0
	for enemy in enemies:
		if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		var id: int = enemy.get_instance_id()
		if _pendulum_zapped.has(id):
			continue
		var closest := Geometry3D.get_closest_point_to_segment(enemy.global_position, a, b)
		if closest.distance_to(enemy.global_position) > width + combat.hull_radius(enemy):
			continue
		_pendulum_zapped[id] = true
		combat.effects.arc(closest, enemy.global_position + Vector3.UP * 0.5, color)
		combat.deal_hit(enemy, combat.SYNERGY, dmg, enemy.global_position - closest, 3.0, "", "item_proc", "proc")
		zapped_now += 1
	var swept_far: bool = a.distance_to(_pendulum_swing_origin) >= 3.0
	if not _pendulum_swing_charged and (zapped_now > 0 or swept_far):
		_pendulum_swing_charged = true
		var share := float(row.get("special_charge_share", 0.15))
		var abilities = ctx.player.abilities
		if abilities != null:
			var sp_cd: float = abilities.cooldown_of(AbilityState.SPECIAL)
			if sp_cd > 0.0:
				combat.refund_special(abilities, sp_cd * share)
			else:
				combat.grant_special(abilities)
		note_cross("pendulum_tesla", {"zapped": zapped_now, "special_share": share})
	elif zapped_now > 0:
		note_cross("pendulum_tesla", {"zapped": zapped_now})


func on_thermobaric_slammed(at: Vector3, strength: float, _flatness: float) -> void:
	if strength < 0.05 or not ctx.flow.in_play() or not has_cross_synergy("thermobaric_dunk"):
		return
	var row := Synergies.cross_system_row("thermobaric_dunk")
	var launch_r := float(row.get("launch_radius_m", 10.0))
	var nearby: Array = []
	var has_heated := false
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		if enemy.global_position.distance_to(at) > launch_r:
			continue
		nearby.append(enemy)
		if combat.heated(enemy):
			has_heated = true
	if not has_heated:
		return
	var launch_speed := float(row.get("launch_speed", 14.0))
	var det_r := float(row.get("detonate_radius_m", 6.5))
	var det_dmg: float = float(row.get("detonate_damage", 28.0)) * combat.heft()
	var timeout_s := float(row.get("pin_timeout_s", 1.6))
	var color: Color = row.get("color", Palette.RUST)
	var launched := 0
	for enemy in nearby:
		if combat.fights_posture(enemy) or combat.target_class_of(enemy) == "boss":
			continue
		var id: int = enemy.get_instance_id()
		if _thermobaric_pins.has(id):
			continue
		var away: Vector3 = enemy.global_position - at
		away.y = 0.0
		var dir := (away.normalized() * 0.55 + Vector3.UP * 1.4).normalized()
		if enemy.has_method("knock"):
			var weight = enemy.get("weight")
			enemy.knock(dir, launch_speed * (float(weight) if weight != null else 1.0))
		_thermobaric_pins[id] = {
			"enemy": enemy,
			"start_y": enemy.global_position.y,
			"peak_y": enemy.global_position.y,
			"airborne": false,
			"launched_at": combat.clock_now(),
			"until": combat.clock_now() + timeout_s,
			"radius": det_r,
			"damage": det_dmg,
			"color": color,
			"last_pos": enemy.global_position,
		}
		launched += 1
	if launched > 0:
		combat.effects.ring(at, launch_r, color)
		note_cross("thermobaric_dunk", {"stage": "launch", "launched": launched, "at": at})


func _step_thermobaric_pins(enemies: Array) -> void:
	if _thermobaric_pins.is_empty():
		return
	for id in _thermobaric_pins.keys():
		var pin: Dictionary = _thermobaric_pins[id]
		var enemy = pin["enemy"]
		var valid: bool = is_instance_valid(enemy) and not (enemy.has_method("is_dead") and enemy.is_dead())
		var pos: Vector3 = enemy.global_position if valid else Vector3(pin["last_pos"])
		pin["last_pos"] = pos
		var elapsed: float = combat.clock_now() - float(pin["launched_at"])
		if valid:
			pin["peak_y"] = maxf(float(pin["peak_y"]), pos.y)
			if pos.y > float(pin["start_y"]) + 0.35 or elapsed >= 0.12:
				pin["airborne"] = true
		var impacted: bool = not valid or combat.clock_now() >= float(pin["until"])
		if not impacted and bool(pin["airborne"]) and elapsed >= 0.12:
			if enemy is CharacterBody3D and enemy.is_on_floor():
				impacted = true
			elif pos.y <= float(pin["start_y"]) + 0.15 and float(pin["peak_y"]) > float(pin["start_y"]) + 0.35:
				impacted = true
		if not impacted:
			continue
		_thermobaric_pins.erase(id)
		var det_r := float(pin["radius"])
		var det_dmg := float(pin["damage"])
		var color: Color = pin["color"]
		combat.effects.shockwave(pos, det_r, color)
		var hits := 0
		for other in enemies:
			if not is_instance_valid(other) or (other.has_method("is_dead") and other.is_dead()):
				continue
			if other.global_position.distance_to(pos) > det_r:
				continue
			combat.deal_hit(other, combat.SYNERGY, det_dmg, other.global_position - pos, 8.0, "", "item_proc", "proc")
			hits += 1
		note_cross("thermobaric_dunk", {"stage": "detonate", "at": pos, "hits": hits})


func check_gravity_ledger(centre: Vector3, pulled_enemies: Array) -> void:
	if not ctx.flow.in_play() or not has_cross_synergy("gravity_ledger"):
		return
	for e in pulled_enemies:
		if is_instance_valid(e) and not (e.has_method("is_dead") and e.is_dead()):
			_pulled_recent[e.get_instance_id()] = combat.clock_now()
	for id in _pulled_recent.keys():
		if combat.clock_now() - float(_pulled_recent[id]) > 0.6:
			_pulled_recent.erase(id)
	if combat.clock_now() < _gravity_ledger_ready_at:
		return
	var row := Synergies.cross_system_row("gravity_ledger")
	var cluster_r := float(row.get("cluster_radius_m", 5.5))
	var cluster: Array = []
	for id in _pulled_recent.keys():
		var e = instance_from_id(int(id))
		if not is_instance_valid(e) or (e.has_method("is_dead") and e.is_dead()):
			_pulled_recent.erase(id)
			continue
		if e.global_position.distance_to(centre) <= cluster_r:
			cluster.append(e)
	if cluster.size() < 2:
		return
	_gravity_ledger_ready_at = combat.clock_now() + float(row.get("cooldown_s", 0.35))
	var mid := Vector3.ZERO
	for e in cluster:
		mid += e.global_position
	mid /= float(cluster.size())
	var dmg: float = float(row.get("crush_damage", 22.0)) * combat.heft()
	var color: Color = row.get("color", Palette.VERDIGRIS)
	combat.effects.ring(mid, cluster_r * 0.6, color)
	for e in cluster:
		if is_instance_valid(e) and not e.is_dead():
			combat.deal_hit(e, combat.SYNERGY, dmg, mid - e.global_position, 6.0, "", "item_proc", "proc")
	var cogs := int(row.get("cog_count", 3))
	if ctx.build != null and ctx.build.get("scrap") != null and ctx.build.scrap.has_method("drop_cogs") \
			and (ctx.flow == null or ctx.flow.in_stage()):
		ctx.build.scrap.drop_cogs(mid, cogs)
	note_cross("gravity_ledger", {"at": mid, "crushed": cluster.size(), "cogs": cogs})


func on_consumable_used(consumable_id: String, at := Vector3.INF) -> Dictionary:
	if ctx == null or ctx.flow == null or not ctx.flow.in_play():
		return {}
	if combat.actives == null or combat.actives.active_id == "":
		return {}
	if not has_cross_synergy("catalyst_cartridge", {"has_consumable": true, "has_active": true}):
		return {}
	var row := Synergies.cross_system_row("catalyst_cartridge")
	var gain := float(row.get("active_charge_gain", 0.40))
	var radius := float(row.get("burst_radius_m", 8.0))
	var pos: Vector3 = at if at.is_finite() else ctx.player.ball_position()
	combat.actives.recharge(gain)
	var active_row: Dictionary = combat.actives.row_of(combat.actives.active_id)
	var ring_color: Color = active_row.get("color", row.get("color", Palette.SAND))
	combat.effects.ring(pos, radius, ring_color)
	var result := {
		"fired": true,
		"consumable_id": consumable_id,
		"active_id": combat.actives.active_id,
		"charge_gain": gain,
		"radius": radius,
		"at": pos,
	}
	note_cross("catalyst_cartridge", result)
	return result
