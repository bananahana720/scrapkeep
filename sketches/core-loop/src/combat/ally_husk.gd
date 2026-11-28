extends Node

const Palette := preload("res://src/core/palette.gd")
const Roster := preload("res://src/combat/roster.gd")
const EnemyBase := preload("res://src/combat/enemy.gd")
const AttackBudget := preload("res://src/combat/attack_budget.gd")
const AllyHuskLook := preload("res://src/presentation/ally_husk_look.gd")
const DamageDoor := preload("res://src/combat/damage_door.gd")
const ActiveBase := preload("res://src/combat/actives/active_base.gd")

const GROUP := "ally_husk"
const WRECK_SECONDS := 6.0
const SHIFT_SECONDS := 12.0
const DAMAGE_SHARE := 0.60
const ELITE_DAMAGE_MULT := 1.35
const ORDINARY_SEAT_COST := 1
const ELITE_SEAT_COST := 2
const HEFT_SEAT_CAPS := [2, 2, 3, 3, 4]
const OVERCLOCK_SPEED_MULT := 1.5
const OVERCLOCK_RATE_MULT := 1.5
const OVERCLOCK_SECONDS := 3.0
const OVERCLOCK_PASS_RADIUS := 7.5
const SURGE_WINDOW_SECONDS := 0.55
const CHARGE_SECONDS := 3.5
const CHARGE_SPEED_MULT := 1.45
const SEVERANCE_RADIUS := 5.5
const SEVERANCE_DAMAGE := 28.0
const SEVERANCE_RAM_RADIUS := 2.6
const SEVERANCE_RAM_MIN_SPEED := 12.0
const SEVERANCE_RAM_GRACE := 0.35
const LINK_HUSK_RADIUS := 5.5
const ATTACK_SEARCH_RADIUS := 34.0
const TAKEOVER_WARN_SECONDS := 1.0
const TAKEOVER_NODE_RADIUS := 1.6
const TAKEOVER_OVERCHARGE_SECONDS := 5.0
const TAKEOVER_OVERCHARGE_DAMAGE_MULT := 1.6
const TAKEOVER_STUN_SECONDS := 2.0
const TAKEOVER_COLOR := Palette.HAZARD

const PROFILES := {
	"chaser": {
		"base_damage": 9.0, "speed": 7.2, "range": 9.5, "warn": 0.55, "live": 0.25, "rest": 0.95,
		"zone_shape": "lane", "zone_length": 9.5, "zone_width": 2.8, "at_target": false,
		"radius": 1.0, "half_height": 1.5,
	},
	"plated_brute": {
		"base_damage": 12.0, "speed": 5.4, "range": 6.2, "warn": 0.70, "live": 0.20, "rest": 1.35,
		"zone_shape": "ring", "zone_radius": 5.2, "at_target": false,
		"radius": 1.3, "half_height": 1.1,
	},
	"lobber": {
		"base_damage": 12.0, "speed": 4.2, "range": 18.0, "warn": 0.75, "live": 0.20, "rest": 1.50,
		"zone_shape": "ring", "zone_radius": 4.0, "at_target": true,
		"radius": 1.3, "half_height": 2.0,
	},
	"boom_tender": {
		"base_damage": 10.0, "speed": 5.8, "range": 8.4, "warn": 0.65, "live": 0.25, "rest": 1.20,
		"zone_shape": "lane", "zone_length": 8.4, "zone_width": 3.0, "at_target": false,
		"radius": 1.3, "half_height": 1.3,
	},
	"burrower": {
		"base_damage": 10.0, "speed": 6.8, "range": 14.0, "warn": 0.70, "live": 0.25, "rest": 1.25,
		"zone_shape": "ring", "zone_radius": 3.0, "at_target": true,
		"radius": 0.9, "half_height": 1.1,
	},
	"drill_crew": {
		"base_damage": 11.0, "speed": 4.5, "range": 16.0, "warn": 0.75, "live": 0.30, "rest": 1.45,
		"zone_shape": "lane", "zone_length": 14.0, "zone_width": 2.8, "at_target": false,
		"radius": 1.2, "half_height": 1.2,
	},
	"lamp_swarm": {
		"base_damage": 9.0, "speed": 5.5, "range": 15.0, "warn": 0.70, "live": 0.30, "rest": 1.30,
		"zone_shape": "lane", "zone_length": 14.0, "zone_width": 2.8, "at_target": false,
		"radius": 1.0, "half_height": 1.4,
	},
	"prop_crew": {
		"base_damage": 12.0, "speed": 4.8, "range": 8.0, "warn": 0.75, "live": 0.25, "rest": 1.35,
		"zone_shape": "ring", "zone_radius": 5.0, "at_target": false,
		"radius": 1.1, "half_height": 1.3,
	},
	"pit_jaw": {
		"base_damage": 10.0, "speed": 4.6, "range": 14.0, "warn": 0.70, "live": 0.25, "rest": 1.35,
		"zone_shape": "ring", "zone_radius": 3.2, "at_target": true,
		"radius": 1.1, "half_height": 0.9,
	},
	"line_cutter": {
		"base_damage": 10.0, "speed": 6.2, "range": 16.0, "warn": 0.70, "live": 0.25, "rest": 1.30,
		"zone_shape": "lane", "zone_length": 14.0, "zone_width": 2.8, "at_target": false,
		"radius": 0.8, "half_height": 1.1,
	},
	"kite_drone": {
		"base_damage": 10.0, "speed": 6.8, "range": 16.0, "warn": 0.75, "live": 0.25, "rest": 1.35,
		"zone_shape": "ring", "zone_radius": 3.2, "at_target": true,
		"radius": 0.8, "half_height": 1.1,
	},
	"ballast_heavy": {
		"base_damage": 13.0, "speed": 4.4, "range": 7.0, "warn": 0.80, "live": 0.25, "rest": 1.45,
		"zone_shape": "ring", "zone_radius": 5.0, "at_target": false,
		"radius": 1.2, "half_height": 1.3,
	},
	"gap_net": {
		"base_damage": 10.0, "speed": 4.0, "range": 15.0, "warn": 0.75, "live": 0.30, "rest": 1.40,
		"zone_shape": "lane", "zone_length": 12.0, "zone_width": 3.0, "at_target": false,
		"radius": 0.9, "half_height": 1.2,
	},
}

const DEFAULT_PROFILE := {
	"base_damage": 10.0, "speed": 6.2, "range": 7.0, "warn": 0.60, "live": 0.20, "rest": 1.15,
	"zone_shape": "ring", "zone_radius": 4.2, "at_target": false,
	"radius": 1.0, "half_height": 1.2,
}

var ctx
var combat

var wrecks: Array = []
var husks: Array = []
var last_severance := {}
var last_counter_hack := {}
var raises_total := 0
var severance_total := 0
var strikes_total := 0
var takeovers_started := 0
var takeovers_interrupted := 0
var takeovers_completed := 0

var _surge_window := 0.0


class HuskUnit extends Node3D:
	var kind := "chaser"
	var elite := false
	var seat_cost := 1
	var damage := 5.4
	var move_speed := 7.2
	var attack_range := 9.5
	var warn_s := 0.55
	var live_s := 0.25
	var rest_s := 0.95
	var zone_shape := "lane"
	var zone_length := 9.5
	var zone_width := 2.8
	var zone_radius := 4.2
	var zone_at_target := false
	var body_radius := 1.0
	var half_height := 1.5
	var world_root: Node3D

	var shift_left := 12.0
	var age := 0.0
	var overclock_left := 0.0
	var overcharged := false
	var overcharge_left := 0.0
	var charge_left := 0.0
	var charge_target := Vector3.ZERO
	var shot_bits := 0

	var takeover_active := false
	var takeover_source: Node = null
	var takeover_elapsed := 0.0
	var takeover_duration := 1.0
	var takeover_node_pos := Vector3.ZERO
	var takeover_color := Palette.HAZARD
	var takeover_visual: Node3D = null

	var state := "chase"
	var phase_t := 0.0
	var rest_left := 0.0
	var struck_this_phase := false
	var lunge_dir := Vector3.FORWARD
	var lunge_origin := Vector3.ZERO

	var look: Dictionary = {}
	var zone: AllyHuskLook.AllyZone = null


	func is_overclocked() -> bool:
		return overclock_left > 0.0 or overcharge_left > 0.0


	func is_overcharged() -> bool:
		return overcharge_left > 0.0


	func effective_damage() -> float:
		return damage * (TAKEOVER_OVERCHARGE_DAMAGE_MULT if overcharge_left > 0.0 else 1.0)


	func speed_mult() -> float:
		var m := 1.0
		if is_overclocked():
			m *= OVERCLOCK_SPEED_MULT
		if charge_left > 0.0:
			m *= CHARGE_SPEED_MULT
		return m


	func rate_mult() -> float:
		return OVERCLOCK_RATE_MULT if is_overclocked() else 1.0


	func clear_zone() -> void:
		if zone != null and is_instance_valid(zone):
			if zone.get_parent() != null:
				zone.get_parent().remove_child(zone)
			zone.queue_free()
		zone = null


	func clear_takeover() -> void:
		takeover_active = false
		takeover_source = null
		takeover_elapsed = 0.0
		if takeover_visual != null and is_instance_valid(takeover_visual):
			if takeover_visual.get_parent() != null:
				takeover_visual.get_parent().remove_child(takeover_visual)
			takeover_visual.queue_free()
		takeover_visual = null


func setup(ctx_ref, combat_ref) -> void:
	ctx = ctx_ref
	combat = combat_ref
	name = "AllyHusks"
	if ctx != null and ctx.events != null and ctx.events.has_signal("shot_fired"):
		if not ctx.events.shot_fired.is_connected(_on_shot_fired):
			ctx.events.shot_fired.connect(_on_shot_fired)


static func can_leave_husk(enemy_kind: String, ringed_out := false, is_spectator := false) -> bool:
	if ringed_out or is_spectator:
		return false
	if not EnemyBase.is_ordinary_kind(enemy_kind):
		return false
	return Roster.has(enemy_kind) and Roster.faction_of(enemy_kind) == Roster.FLEET


static func seat_cap_for(heft_class: int, extra_seats := 0) -> int:
	var idx := clampi(heft_class - 1, 0, HEFT_SEAT_CAPS.size() - 1)
	return int(HEFT_SEAT_CAPS[idx]) + maxi(0, extra_seats)


static func profile_for(enemy_kind: String) -> Dictionary:
	return PROFILES.get(enemy_kind, DEFAULT_PROFILE)


func seat_cap() -> int:
	var hc := 1
	if ctx != null and ctx.run != null and ctx.run.has_method("heft_class"):
		hc = int(ctx.run.heft_class())
	var extra: int = combat.ghost_shift_extra_seats() if combat != null and combat.has_method("ghost_shift_extra_seats") else 0
	return seat_cap_for(hc, extra)


func seats_used() -> int:
	var total := 0
	for h in husks:
		if is_instance_valid(h):
			total += int(h.seat_cost)
	return total


func active_count() -> int:
	var n := 0
	for h in husks:
		if is_instance_valid(h):
			n += 1
	return n


func record_wreck(enemy: Node3D) -> Dictionary:
	if enemy == null or not is_instance_valid(enemy) or ctx == null or ctx.root == null:
		return {}
	if enemy.has_method("is_fleet_husk_eligible"):
		if not enemy.is_fleet_husk_eligible():
			return {}
	else:
		var k := String(enemy.get("kind")) if enemy.get("kind") != null else ""
		var ro := bool(enemy.get("ringed_out")) if enemy.get("ringed_out") != null else false
		if not can_leave_husk(k, ro, enemy.is_in_group("spectator")):
			return {}
	var kind := String(enemy.get("kind"))
	var elite := bool(enemy.get_meta("elite_pack", false)) or enemy.has_meta("elite_affix")
	var pos := _ground_point(enemy.global_position)
	var prof := profile_for(kind)
	var radius := ActiveBase.enemy_girth(enemy, float(prof["radius"]))
	var hh := float(enemy.get("half_height")) if enemy.get("half_height") != null else float(prof["half_height"])
	var marker := AllyHuskLook.build_wreck_marker(ctx.root, pos, radius, elite)
	var entry := {
		"kind": kind,
		"at": pos,
		"elite": elite,
		"radius": radius,
		"half_height": hh,
		"left": WRECK_SECONDS,
		"marker": marker,
	}
	wrecks.append(entry)
	return entry


func raise_in_radius(at: Vector3, radius: float) -> Array:
	if wrecks.is_empty():
		return []
	var raised: Array = []
	var kept: Array = []
	for w in wrecks:
		var flat_d := Vector2(float((w["at"] as Vector3).x) - at.x, float((w["at"] as Vector3).z) - at.z).length()
		if flat_d <= radius:
			var unit := _raise_wreck(w)
			if unit != null:
				raised.append(unit)
			else:
				kept.append(w)
		else:
			kept.append(w)
	wrecks = kept
	return raised


func raise_drive_by(at: Vector3, radius := LINK_HUSK_RADIUS) -> Array:
	return raise_in_radius(at, radius)


func refresh_all_shifts() -> int:
	var count := 0
	for h in husks:
		if not is_instance_valid(h):
			continue
		h.shift_left = SHIFT_SECONDS
		count += 1
		if combat != null and combat.effects != null:
			combat.effects.ring(h.global_position, maxf(1.8, h.body_radius * 1.8), Palette.AMBER)
	return count


func start_surge_overclock() -> int:
	_surge_window = maxf(_surge_window, SURGE_WINDOW_SECONDS)
	return _apply_pass_by_overclock()


func command_charge(at: Vector3) -> int:
	var target_pt := _ground_point(at)
	var count := 0
	for h in husks:
		if not is_instance_valid(h):
			continue
		h.charge_target = target_pt
		h.charge_left = CHARGE_SECONDS
		count += 1
		if combat != null and combat.effects != null:
			combat.effects.arc(h.global_position + Vector3.UP * 1.4, target_pt + Vector3.UP * 0.6, Palette.AMBER)
	return count


func step(delta: float, enemies: Array) -> void:
	if ctx == null or ctx.root == null:
		return
	if not wrecks.is_empty():
		var live_wrecks: Array = []
		for w in wrecks:
			w["left"] = float(w["left"]) - delta
			if float(w["left"]) <= 0.0:
				_free_marker(w)
			else:
				live_wrecks.append(w)
		wrecks = live_wrecks

	if _surge_window > 0.0:
		_surge_window = maxf(0.0, _surge_window - delta)
		_apply_pass_by_overclock()

	if husks.is_empty():
		return
	var hc := 1
	if ctx.run != null and ctx.run.has_method("heft_class"):
		hc = int(ctx.run.heft_class())
	var has_severance: bool = combat != null and combat.has_method("ghost_shift_has_severance") and combat.ghost_shift_has_severance()
	var ball_pos: Vector3 = ctx.player.ball_position() if ctx.player != null else Vector3.INF
	var ball_speed: float = ctx.player.planar_velocity().length() if ctx.player != null else 0.0

	var kept: Array = []
	for h in husks:
		if not is_instance_valid(h):
			continue
		h.age += delta
		h.shift_left -= delta
		h.overclock_left = maxf(0.0, h.overclock_left - delta)
		h.overcharge_left = maxf(0.0, h.overcharge_left - delta)
		if h.overcharge_left <= 0.0:
			h.overcharged = false
		h.charge_left = maxf(0.0, h.charge_left - delta)

		if h.takeover_active:
			if _step_takeover(h, delta, ball_pos):
				_free_husk(h)
				continue

		if h.shift_left <= 0.0:
			if has_severance:
				_severance_blast(h, enemies, "shift_end")
			_free_husk(h)
			continue

		if has_severance and h.age >= SEVERANCE_RAM_GRACE and ball_speed >= SEVERANCE_RAM_MIN_SPEED:
			var flat_ball := Vector2(ball_pos.x - h.global_position.x, ball_pos.z - h.global_position.z).length()
			if flat_ball <= SEVERANCE_RAM_RADIUS:
				_severance_blast(h, enemies, "ram")
				_free_husk(h)
				continue

		_step_husk_ai(h, delta, enemies, hc)
		AllyHuskLook.update_husk_look(h.look, clampf(h.shift_left / SHIFT_SECONDS, 0.0, 1.0), h.is_overclocked(), delta)
		kept.append(h)
	husks = kept


func _raise_wreck(w: Dictionary) -> HuskUnit:
	var elite := bool(w.get("elite", false))
	var cost := ELITE_SEAT_COST if elite else ORDINARY_SEAT_COST
	var cap := seat_cap()
	if cost > cap:
		return null
	while seats_used() + cost > cap and not husks.is_empty():
		var oldest: HuskUnit = husks.pop_front()
		_free_husk(oldest)
	_free_marker(w)

	var kind := String(w.get("kind", "chaser"))
	var prof := profile_for(kind)
	var unit := HuskUnit.new()
	unit.name = "AllyHusk_%s_%d" % [kind, raises_total]
	unit.kind = kind
	unit.elite = elite
	unit.seat_cost = cost
	unit.damage = float(prof["base_damage"]) * DAMAGE_SHARE * (ELITE_DAMAGE_MULT if elite else 1.0)
	unit.move_speed = float(prof["speed"])
	unit.attack_range = float(prof["range"])
	unit.warn_s = float(prof["warn"])
	unit.live_s = float(prof["live"])
	unit.rest_s = float(prof["rest"])
	unit.zone_shape = String(prof["zone_shape"])
	unit.zone_length = float(prof.get("zone_length", 9.0))
	unit.zone_width = float(prof.get("zone_width", 2.8))
	unit.zone_radius = float(prof.get("zone_radius", 4.2))
	unit.zone_at_target = bool(prof.get("at_target", false))
	unit.body_radius = float(w.get("radius", prof["radius"]))
	unit.half_height = float(w.get("half_height", prof["half_height"]))
	unit.shift_left = SHIFT_SECONDS
	unit.world_root = ctx.root
	if combat != null and combat.has_method("ghost_shift_inherits_bits") and combat.ghost_shift_inherits_bits():
		unit.shot_bits = int(combat.shot_bits())

	var at: Vector3 = _ground_point(w["at"])
	unit.position = at
	ctx.root.add_child(unit)
	unit.add_to_group(GROUP)
	unit.look = AllyHuskLook.attach_husk_look(unit, kind, unit.body_radius, unit.half_height, elite)
	husks.append(unit)
	raises_total += 1

	if combat != null and combat.effects != null:
		combat.effects.ring(at, maxf(1.8, unit.body_radius * 1.6), Palette.AMBER)
		combat.effects.spark(at + Vector3.UP * 1.3, Palette.AMBER)
	return unit


func _apply_pass_by_overclock() -> int:
	if ctx == null or ctx.player == null:
		return 0
	var ball: Vector3 = ctx.player.ball_position()
	var hit := 0
	for h in husks:
		if not is_instance_valid(h):
			continue
		var d := Vector2(ball.x - h.global_position.x, ball.z - h.global_position.z).length()
		if d <= OVERCLOCK_PASS_RADIUS:
			var was: bool = h.is_overclocked()
			h.overclock_left = maxf(h.overclock_left, OVERCLOCK_SECONDS)
			if not was and combat != null and combat.effects != null:
				combat.effects.spark(h.global_position + Vector3.UP * 1.8, Palette.AMBER)
			hit += 1
	return hit


func _step_husk_ai(h: HuskUnit, delta: float, enemies: Array, heft_class: int) -> void:
	var rate := h.rate_mult()
	var spd := h.move_speed * h.speed_mult()
	match h.state:
		"chase":
			h.rest_left = maxf(0.0, h.rest_left - delta * rate)
			var foe := _pick_target(h, enemies)
			var goal := Vector3.INF
			var dist_to_foe := INF
			if foe != null:
				goal = foe.global_position
				dist_to_foe = Vector2(goal.x - h.global_position.x, goal.z - h.global_position.z).length()
			elif h.charge_left > 0.0:
				goal = h.charge_target
			elif ctx.player != null:
				var ball: Vector3 = ctx.player.ball_position()
				if Vector2(ball.x - h.global_position.x, ball.z - h.global_position.z).length() > 8.0:
					goal = ball
			if goal.is_finite():
				var flat := Vector3(goal.x - h.global_position.x, 0.0, goal.z - h.global_position.z)
				var d := flat.length()
				if d > 0.15:
					var dir := flat / d
					_face_dir(h, dir, delta)
					if foe == null or dist_to_foe > maxf(2.2, h.attack_range * 0.65):
						var step_pos := h.global_position + dir * minf(spd * delta, d)
						h.global_position = _ground_point(step_pos)
			if foe != null and dist_to_foe <= h.attack_range and h.rest_left <= 0.0:
				if AttackBudget.ask_ally(h, heft_class):
					_begin_warn(h, foe)
			else:
				AttackBudget.withdraw_ally(h)
		"warn":
			h.phase_t += delta * rate
			var p := clampf(h.phase_t / maxf(0.05, h.warn_s), 0.0, 1.0)
			if h.zone != null and is_instance_valid(h.zone):
				h.zone.set_progress(p)
			if h.phase_t >= h.warn_s:
				h.state = "strike"
				h.phase_t = 0.0
				h.struck_this_phase = false
		"strike":
			h.phase_t += delta * rate
			if h.zone_shape == "lane":
				var frac := clampf(h.phase_t / maxf(0.05, h.live_s), 0.0, 1.0)
				var along := h.lunge_origin + h.lunge_dir * (h.zone_length * 0.72 * frac)
				h.global_position = _ground_point(along)
			if not h.struck_this_phase:
				h.struck_this_phase = true
				_resolve_husk_strike(h, enemies)
			if h.phase_t >= h.live_s:
				h.clear_zone()
				AttackBudget.release_ally(h)
				h.state = "recover"
				h.phase_t = 0.0
				h.rest_left = h.rest_s
		"recover":
			h.rest_left = maxf(0.0, h.rest_left - delta * rate)
			if h.rest_left <= 0.0:
				h.state = "chase"


func _begin_warn(h: HuskUnit, foe: Node3D) -> void:
	h.clear_zone()
	h.state = "warn"
	h.phase_t = 0.0
	var to := Vector3(foe.global_position.x - h.global_position.x, 0.0, foe.global_position.z - h.global_position.z)
	var heading := to.normalized() if to.length_squared() > 0.0001 else Vector3.FORWARD
	_face_dir(h, heading, 1.0)
	h.lunge_dir = heading
	h.lunge_origin = h.global_position
	var terrain = combat.ground if combat != null else null
	if h.zone_shape == "lane":
		h.zone = AllyHuskLook.create_lane_zone(ctx.root, h.global_position, heading, h.zone_length, h.zone_width, terrain)
	else:
		var centre := _ground_point(foe.global_position) if h.zone_at_target else h.global_position
		h.zone = AllyHuskLook.create_ring_zone(ctx.root, centre, h.zone_radius, terrain)
	h.zone.set_progress(0.0)


func _resolve_husk_strike(h: HuskUnit, enemies: Array) -> void:
	if h.zone == null or not is_instance_valid(h.zone) or combat == null:
		return
	var origin: Vector3 = h.zone.center
	var bits := h.shot_bits
	if bits == 0 and combat.has_method("ghost_shift_inherits_bits") and combat.ghost_shift_inherits_bits():
		bits = int(combat.shot_bits())
	for enemy in enemies:
		if not is_instance_valid(enemy) or DamageDoor.dead(enemy):
			continue
		if not h.zone.contains(enemy.global_position):
			continue
		combat.ally_husk_hit(h, enemy, h.effective_damage(), origin, bits)
		strikes_total += 1
	if combat.effects != null:
		combat.effects.ring(origin, h.zone_radius if h.zone_shape == "ring" else h.zone_width, Palette.AMBER)


func _severance_blast(h: HuskUnit, enemies: Array, cause: String) -> void:
	if combat == null:
		return
	var at := h.global_position
	var dmg := SEVERANCE_DAMAGE * float(combat.heft())
	var bits := h.shot_bits
	if bits == 0 and combat.has_method("ghost_shift_inherits_bits") and combat.ghost_shift_inherits_bits():
		bits = int(combat.shot_bits())
	var hits := 0
	for enemy in enemies:
		if not is_instance_valid(enemy) or DamageDoor.dead(enemy):
			continue
		if Vector2(enemy.global_position.x - at.x, enemy.global_position.z - at.z).length() > SEVERANCE_RADIUS:
			continue
		combat.ally_husk_hit(h, enemy, dmg, at, bits)
		hits += 1
	severance_total += 1
	last_severance = {"at": at, "cause": cause, "hits": hits, "damage": dmg, "color": Palette.AMBER}
	if combat.effects != null:
		combat.effects.shockwave(at, SEVERANCE_RADIUS, Palette.AMBER)
		combat.effects.ring(at, SEVERANCE_RADIUS, Palette.AMBER)
		combat.effects.spark(at + Vector3.UP * 1.2, Palette.AMBER)


func _pick_target(h: HuskUnit, enemies: Array) -> Node3D:
	var best: Node3D = null
	var best_score := INF
	for enemy in enemies:
		if not is_instance_valid(enemy) or DamageDoor.dead(enemy):
			continue
		var d := Vector2(enemy.global_position.x - h.global_position.x, enemy.global_position.z - h.global_position.z).length()
		if d > ATTACK_SEARCH_RADIUS:
			continue
		var score := d
		if h.charge_left > 0.0:
			var dc := Vector2(enemy.global_position.x - h.charge_target.x, enemy.global_position.z - h.charge_target.z).length()
			score = dc * 0.8 + d * 0.2
		if score < best_score:
			best_score = score
			best = enemy
	return best


func _face_dir(h: HuskUnit, dir: Vector3, delta: float) -> void:
	var want_yaw := atan2(-dir.x, -dir.z)
	if delta >= 0.99:
		h.rotation.y = want_yaw
	else:
		h.rotation.y = lerp_angle(h.rotation.y, want_yaw, minf(1.0, delta * 10.0))


func _ground_point(at: Vector3) -> Vector3:
	if combat != null and combat.has_method("floor_at"):
		return combat.floor_at(at + Vector3.UP * 2.0)
	if combat != null and combat.ground != null:
		if combat.ground.has_method("height_at"):
			return Vector3(at.x, float(combat.ground.height_at(at)), at.z)
		if combat.ground.has_method("height"):
			return Vector3(at.x, float(combat.ground.height(at.x, at.z)), at.z)
	return at


func _free_marker(w: Dictionary) -> void:
	var m = w.get("marker")
	if m != null and is_instance_valid(m):
		if m.get_parent() != null:
			m.get_parent().remove_child(m)
		m.queue_free()
	w["marker"] = null


func _free_husk(h: HuskUnit) -> void:
	if h == null or not is_instance_valid(h):
		return
	h.clear_takeover()
	h.clear_zone()
	AttackBudget.withdraw_ally(h)
	AttackBudget.release_ally(h)
	if h.is_in_group(GROUP):
		h.remove_from_group(GROUP)
	if h.get_parent() != null:
		h.get_parent().remove_child(h)
	h.queue_free()


func first_takeover_target(origin: Vector3, max_range := 26.0) -> HuskUnit:
	var best: HuskUnit = null
	var best_d := max_range
	for h in husks:
		if not is_instance_valid(h) or h.takeover_active:
			continue
		var d := Vector2(h.global_position.x - origin.x, h.global_position.z - origin.z).length()
		if d <= best_d:
			best_d = d
			best = h
	return best


func begin_takeover(h: HuskUnit, source: Node, duration := TAKEOVER_WARN_SECONDS) -> bool:
	assert(TAKEOVER_COLOR == Palette.HAZARD)
	if h == null or not is_instance_valid(h) or h.takeover_active or not husks.has(h):
		return false
	if source == null or not is_instance_valid(source):
		return false
	h.clear_takeover()
	h.takeover_active = true
	h.takeover_source = source
	h.takeover_elapsed = 0.0
	h.takeover_duration = maxf(TAKEOVER_WARN_SECONDS, duration)
	h.takeover_color = TAKEOVER_COLOR
	h.takeover_node_pos = _takeover_node_at(h)
	h.takeover_visual = _build_takeover_visual(h, source)
	takeovers_started += 1
	return true


func interrupt_takeover(h: HuskUnit, by := "tap") -> bool:
	if h == null or not is_instance_valid(h) or not h.takeover_active:
		return false
	var source := h.takeover_source
	var node_pos := h.takeover_node_pos
	h.clear_takeover()
	takeovers_interrupted += 1
	h.overcharged = true
	h.overcharge_left = maxf(h.overcharge_left, TAKEOVER_OVERCHARGE_SECONDS)
	h.overclock_left = maxf(h.overclock_left, TAKEOVER_OVERCHARGE_SECONDS)
	h.shift_left = SHIFT_SECONDS
	last_counter_hack = {
		"husk": h.kind,
		"source": source.name if is_instance_valid(source) else "",
		"by": by,
		"at": node_pos,
		"color": TAKEOVER_COLOR,
		"overcharge_s": TAKEOVER_OVERCHARGE_SECONDS,
		"frame": Engine.get_physics_frames(),
	}
	if is_instance_valid(source) and source.has_method("on_takeover_interrupted"):
		source.on_takeover_interrupted(h)
	if combat != null and combat.effects != null:
		combat.effects.ring(h.global_position, maxf(2.4, h.body_radius * 2.2), Palette.AMBER)
		combat.effects.spark(node_pos, Palette.AMBER)
	return true


func _takeover_node_at(h: HuskUnit) -> Vector3:
	return h.global_position + Vector3.UP * (h.half_height + 1.4)


func _build_takeover_visual(h: HuskUnit, source: Node) -> Node3D:
	var root_vis := Node3D.new()
	root_vis.name = "MindTakeoverTelegraph"
	root_vis.set_meta("color", TAKEOVER_COLOR)
	root_vis.set_meta("warn_seconds", h.takeover_duration)
	var ring := MeshInstance3D.new()
	ring.name = "TakeoverRing"
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(1.2, h.body_radius * 1.4)
	torus.outer_radius = torus.inner_radius + 0.22
	ring.mesh = torus
	ring.material_override = Palette.unshaded(TAKEOVER_COLOR)
	ring.position = Vector3(0.0, 0.2, 0.0)
	root_vis.add_child(ring)

	var node_orb := MeshInstance3D.new()
	node_orb.name = "TakeoverNode"
	var sphere := SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 1.1
	node_orb.mesh = sphere
	node_orb.material_override = Palette.solid(TAKEOVER_COLOR, 2.2)
	node_orb.position = Vector3(0.0, h.half_height + 1.4, 0.0)
	root_vis.add_child(node_orb)

	var tether := MeshInstance3D.new()
	tether.name = "TakeoverTether"
	var beam := BoxMesh.new()
	beam.size = Vector3(0.14, 0.14, 1.0)
	tether.mesh = beam
	tether.material_override = Palette.unshaded(TAKEOVER_COLOR)
	tether.top_level = true
	root_vis.add_child(tether)

	h.add_child(root_vis)
	_sync_takeover_tether(h, root_vis, source, 0.0)
	return root_vis


func _sync_takeover_tether(h: HuskUnit, root_vis: Node3D, source: Node, progress: float) -> void:
	if root_vis == null or not is_instance_valid(root_vis):
		return
	var ring := root_vis.get_node_or_null("TakeoverRing") as MeshInstance3D
	if ring != null:
		var s := lerpf(1.45, 0.72, clampf(progress, 0.0, 1.0))
		ring.scale = Vector3(s, 1.0, s)
	var orb := root_vis.get_node_or_null("TakeoverNode") as MeshInstance3D
	if orb != null:
		var pulse := 1.0 + 0.25 * clampf(progress, 0.0, 1.0)
		orb.scale = Vector3.ONE * pulse
	var tether := root_vis.get_node_or_null("TakeoverTether") as MeshInstance3D
	if tether != null and is_instance_valid(source):
		var from_pt: Vector3 = source.lens_point() if source.has_method("lens_point") else (
			(source.warden.global_position + Vector3.UP * 3.0) if (source.get("warden") != null and is_instance_valid(source.warden)) else (
				(source as Node3D).global_position + Vector3.UP * 2.5 if source is Node3D else h.takeover_node_pos))
		var to_pt := h.takeover_node_pos
		var span := to_pt - from_pt
		var len_m := maxf(0.1, span.length())
		tether.global_position = (from_pt + to_pt) * 0.5
		if span.length() > 0.05:
			var up_v := Vector3.UP if absf(span.normalized().y) < 0.98 else Vector3.RIGHT
			tether.global_basis = Basis.looking_at(span.normalized(), up_v)
		tether.scale = Vector3(1.0, 1.0, len_m)


func _step_takeover(h: HuskUnit, delta: float, ball_pos: Vector3) -> bool:
	if not is_instance_valid(h.takeover_source) or (h.takeover_source.has_method("is_dead") and h.takeover_source.is_dead()):
		h.clear_takeover()
		return false
	h.takeover_node_pos = _takeover_node_at(h)
	if ball_pos.is_finite():
		var dist3 := ball_pos.distance_to(h.takeover_node_pos)
		var flat_d := Vector2(ball_pos.x - h.takeover_node_pos.x, ball_pos.z - h.takeover_node_pos.z).length()
		if dist3 <= TAKEOVER_NODE_RADIUS + 1.1 or (flat_d <= TAKEOVER_NODE_RADIUS + 1.0 and absf(ball_pos.y - h.global_position.y) <= 4.0):
			interrupt_takeover(h, "tap")
			return false
	h.takeover_elapsed += delta
	var progress := clampf(h.takeover_elapsed / maxf(0.1, h.takeover_duration), 0.0, 1.0)
	_sync_takeover_tether(h, h.takeover_visual, h.takeover_source, progress)
	if h.takeover_elapsed >= h.takeover_duration:
		var source := h.takeover_source
		h.clear_takeover()
		takeovers_completed += 1
		if is_instance_valid(source) and source.has_method("on_takeover_completed"):
			source.on_takeover_completed(h)
		if combat != null and combat.effects != null:
			combat.effects.ring(h.global_position, maxf(2.4, h.body_radius * 2.0), TAKEOVER_COLOR)
		return true
	return false


func _on_shot_fired(_weapon_id: String, from: Vector3, to: Vector3) -> void:
	for h in husks:
		if not is_instance_valid(h) or not h.takeover_active:
			continue
		var closest := Geometry3D.get_closest_point_to_segment(h.takeover_node_pos, from, to)
		if closest.distance_to(h.takeover_node_pos) <= TAKEOVER_NODE_RADIUS + 0.6:
			interrupt_takeover(h, "shot")
			return


func reset() -> void:
	_reset()


func _reset() -> void:
	for w in wrecks:
		_free_marker(w)
	wrecks.clear()
	for h in husks:
		_free_husk(h)
	husks.clear()
	_surge_window = 0.0
	last_severance = {}
	last_counter_hack = {}
	if is_inside_tree():
		AttackBudget.reset_ally(get_tree())
